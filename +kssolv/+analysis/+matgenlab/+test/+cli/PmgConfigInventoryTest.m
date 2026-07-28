classdef PmgConfigInventoryTest < matlab.unittest.TestCase
    properties
        Oracle
        Root
    end

    methods (TestMethodSetup)
        function prepare(testCase)
            testCase.Oracle = jsondecode(fileread(fullfile(pwd, "dev", ...
                "matgenlab", "oracles", "pmg_config_2026.5.4.json")));
            testCase.Root = string(tempname);
            mkdir(testCase.Root);
        end
    end

    methods (TestMethodTeardown)
        function clean(testCase)
            if isfolder(testCase.Root), rmdir(testCase.Root, "s"); end
        end
    end

    methods (Test)
        function cp2kResourcesMatchFrozenOracle(testCase)
            source = fullfile(testCase.Root, "cp2k");
            target = fullfile(testCase.Root, "resources");
            mkdir(source);
            writeText(fullfile(source, "GTH_POTENTIALS"), potentialText());
            writeText(fullfile(source, "BASIS_TEST"), basisText());
            writeText(fullfile(source, "OTHER_POTENTIAL"), ...
                "Notium INVALID" + newline);

            kssolv.analysis.matgenlab.cli.pmg_config.setup_cp2k_data( ...
                [source, target]);
            files = dir(target);
            testCase.verifyEqual(sum(~[files.isdir]), ...
                double(testCase.Oracle.cp2k.element_file_count));
            hydrogen = string(fileread(fullfile(target, "H")));
            testCase.verifyTrue(contains(hydrogen, ...
                string(testCase.Oracle.cp2k.potential_hash)));
            testCase.verifyTrue(contains(hydrogen, ...
                string(testCase.Oracle.cp2k.basis_hash)));
            testCase.verifyTrue(contains(hydrogen, ...
                string(testCase.Oracle.cp2k.potential_filename)));
            testCase.verifyTrue(contains(hydrogen, ...
                string(testCase.Oracle.cp2k.basis_filename)));
            testCase.verifyTrue(contains(hydrogen, ...
                string(testCase.Oracle.cp2k.potential_name)));
            testCase.verifyTrue(contains(hydrogen, ...
                string(testCase.Oracle.cp2k.basis_name)));
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.cli.pmg_config. ...
                setup_cp2k_data([source, target]), ...
                "KSSOLV:Matgenlab:PmgConfig:DestinationExists");
        end

        function potcarsAreMappedRenamedAndCompressed(testCase)
            source = fullfile(testCase.Root, "potcars");
            target = fullfile(testCase.Root, "normalized");
            iron = fullfile(source, "potpaw_PBE_54", "Fe");
            osmium = fullfile(source, "potpaw_PBE.64", "Osmium");
            mkdir(iron);
            mkdir(osmium);
            writeText(fullfile(iron, "POTCAR"), "iron-payload");
            writeText(fullfile(osmium, "POTCAR"), "osmium-payload");

            kssolv.analysis.matgenlab.cli.pmg_config.setup_potcars( ...
                [source, target]);
            ironFile = fullfile(target, ...
                string(testCase.Oracle.potcar_mapping.potpaw_PBE_54), ...
                "POTCAR.Fe.gz");
            osmiumFile = fullfile(target, ...
                string(testCase.Oracle.potcar_mapping.potpaw_PBE_64), ...
                "POTCAR." + string(testCase.Oracle.potcar_mapping.Osmium) + ...
                ".gz");
            testCase.verifyEqual(readGzip(ironFile, testCase.Root), ...
                "iron-payload");
            testCase.verifyEqual(readGzip(osmiumFile, testCase.Root), ...
                "osmium-payload");
        end

        function configWriteAndBackupMatchFrozenOracle(testCase)
            config = fullfile(testCase.Root, ".pmgrc.yaml");
            writeText(config, "EXISTING: old" + newline + ...
                "FLAG: true" + newline);
            tokens = ["EXISTING", "new", "FALSE_VAL", "false", ...
                "NONE_VAL", "none", "NUMBER", "3.5"];
            kssolv.analysis.matgenlab.cli.pmg_config.add_config_var( ...
                tokens, ".bak", "config_path", config);
            testCase.verifyEqual(string(fileread(config)), ...
                string(testCase.Oracle.config_text));
            testCase.verifyEqual(string(fileread(config + ".bak")), ...
                string(testCase.Oracle.config_backup_text));
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.cli.pmg_config.add_config_var( ...
                "UNPAIRED", "", "config_path", config), ...
                "KSSOLV:Matgenlab:PmgConfig:UnevenTokens");
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.cli.pmg_config.add_config_var( ...
                ["A", "B"], ""), ...
                "KSSOLV:Matgenlab:PmgConfig:ConfigPath");
        end

        function enumBuildUsesInjectedBoundaries(testCase)
            state = kssolv.analysis.matgenlab.cli.pmg_config.build_enum( ...
                "gfortran", "work_dir", testCase.Root, ...
                "transport", @enumTransport, "executor", @enumExecutor);
            testCase.verifyTrue(state);
            testCase.verifyTrue(isfile(fullfile(testCase.Root, "enum.x")));
            testCase.verifyFalse(isfolder(fullfile(testCase.Root, "enumlib")));
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.cli.pmg_config.build_enum( ...
                "gfortran", "work_dir", testCase.Root), ...
                "KSSOLV:Matgenlab:PmgConfig:Injection");
        end

        function baderBuildUsesInjectedBoundaries(testCase)
            state = kssolv.analysis.matgenlab.cli.pmg_config.build_bader( ...
                "gfortran", "work_dir", testCase.Root, ...
                "transport", @baderTransport, "executor", @baderExecutor);
            testCase.verifyTrue(state);
            testCase.verifyTrue(isfile(fullfile(testCase.Root, "bader")));
            testCase.verifyFalse(isfile(fullfile( ...
                testCase.Root, "bader.tar.gz")));
            testCase.verifyFalse(isfolder(fullfile( ...
                testCase.Root, "bader-source")));
        end

        function installDetectsCompilerThroughExecutor(testCase)
            kssolv.analysis.matgenlab.cli.pmg_config.install_software( ...
                "enumlib", "work_dir", testCase.Root, ...
                "transport", @enumTransport, ...
                "executor", @installExecutor);
            testCase.verifyTrue(isfile(fullfile(testCase.Root, "enum.x")));
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.cli.pmg_config.install_software( ...
                "unknown", "work_dir", testCase.Root, ...
                "transport", @enumTransport, ...
                "executor", @installExecutor), ...
                "KSSOLV:Matgenlab:PmgConfig:Software");
        end

        function configureDispatchUsesUpstreamPriority(testCase)
            config = fullfile(testCase.Root, "dispatch.yaml");
            cp2kSource = fullfile(testCase.Root, "unused-source");
            cp2kTarget = fullfile(testCase.Root, "unused-target");
            mkdir(cp2kSource);
            args = struct("var_spec", ["SELECTED", "yes"], ...
                "backup", "", "config_path", config, ...
                "cp2k_data_dirs", [cp2kSource, cp2kTarget]);
            kssolv.analysis.matgenlab.cli.pmg_config.configure_pmg(args);
            testCase.verifyEqual(string(fileread(config)), ...
                "SELECTED: 'yes'" + newline);
            testCase.verifyFalse(isfolder(cp2kTarget));
            testCase.verifyEqual( ...
                reshape(string(testCase.Oracle.dispatch_priority), 1, []), ...
                ["potcar_dirs", "install", "var_spec", ...
                "cp2k_data_dirs"]);
        end
    end
end

function output = enumTransport(request)
mkdir(fullfile(request.destination, "symlib", "src"));
mkdir(fullfile(request.destination, "src"));
output = struct("status", 0);
end

function output = enumExecutor(request)
if request.program == "make" && any(request.arguments == "enum.x")
    writeText(fullfile(request.working_directory, "enum.x"), "enum");
end
output = struct("status", 0);
end

function output = installExecutor(request)
if request.action == "probe"
    if request.program == "ifort"
        output = struct("status", 1);
    else
        output = struct("status", 0);
    end
else
    output = enumExecutor(request);
end
end

function output = baderTransport(request)
writeText(request.destination, "frozen archive");
output = struct("status", 0);
end

function output = baderExecutor(request)
if request.action == "extract"
    if ~isfolder(request.destination), mkdir(request.destination); end
    writeText(fullfile(request.destination, "makefile.osx_gfortran"), ...
        "frozen makefile");
elseif request.program == "make"
    writeText(fullfile(request.working_directory, "bader"), "bader");
end
output = struct("status", 0);
end

function text = readGzip(path, root)
folder = fullfile(root, "expanded-" + ...
    string(char(java.util.UUID.randomUUID())));
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, "s"));
files = gunzip(path, folder);
text = string(fileread(files{1}));
clear cleanup
end

function writeText(path, text)
file = fopen(path, "w", "n", "UTF-8");
assert(file >= 0);
cleanup = onCleanup(@() fclose(file));
fwrite(file, char(text), "char");
clear cleanup
end

function text = potentialText()
text = "H GTH-PBE-q1" + newline + ...
    "1" + newline + ...
    "0.20000000 2 -4.17890044 0.72446331" + newline + ...
    "0" + newline;
end

function text = basisText()
text = "H DZVP-MOLOPT-GTH" + newline + ...
    "1" + newline + ...
    "2 0 1 2 1 1" + newline + ...
    "8.3744350009 -0.0283380461 0.0000000000" + newline + ...
    "1.8058681460 -0.1333810052 0.0000000000" + newline;
end
