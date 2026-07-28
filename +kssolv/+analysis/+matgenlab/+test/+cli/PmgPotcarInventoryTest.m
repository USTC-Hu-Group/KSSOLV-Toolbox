classdef PmgPotcarInventoryTest < matlab.unittest.TestCase
    % Frozen pymatgen 2026.5.4 pmg-potcar compatibility tests.

    properties
        Oracle
        Root
    end

    methods (TestMethodSetup)
        function prepare(testCase)
            here = fileparts(mfilename("fullpath"));
            repository = here;
            for index = 1:5
                repository = fileparts(repository);
            end
            oraclePath = fullfile(repository, "dev", "matgenlab", ...
                "oracles", "pmg_potcar_2026.5.4.json");
            testCase.Oracle = jsondecode(fileread(oraclePath));
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
        function recursivelyVisitsFrozenFileSet(testCase)
            materializeFixture(testCase.Root, testCase.Oracle.fixture_tree);
            logPath = fullfile(testCase.Root, "visits.log");
            callback = @(directory, filename) appendVisit( ...
                logPath, testCase.Root, directory, filename);

            visited = kssolv.analysis.matgenlab.cli.pmg_potcar.proc_dir( ...
                testCase.Root, callback);
            actual = splitlines(strtrim(string(fileread(logPath))));
            actual = sort(actual);
            expectedEntries = testCase.Oracle.proc_dir_visits;
            expected = strings(numel(expectedEntries), 1);
            for index = 1:numel(expectedEntries)
                entry = expectedEntries{index};
                expected(index) = string(entry{1}) + "|" + string(entry{2});
            end
            testCase.verifyEqual(actual, sort(expected));
            testCase.verifyNumElements(visited, numel(expected));
        end

        function specificationGenerationMatchesFrozenOracle(testCase)
            materializeFixture(testCase.Root, testCase.Oracle.fixture_tree);
            result = kssolv.analysis.matgenlab.cli.pmg_potcar.gen_potcar( ...
                testCase.Root, "POTCAR.spec", ...
                "functional", "PBE", ...
                "potcar_factory", @fakeFactory, ...
                "potcar_writer", @writeFakePotcar);

            expected = testCase.Oracle.gen_potcar.construction;
            testCase.verifyTrue(result.generated);
            testCase.verifyEqual(result.symbols, ...
                reshape(string(expected.symbols), 1, []));
            testCase.verifyEqual(result.functional, ...
                string(expected.functional));
            testCase.verifyEqual(string(fileread(result.output_path)), ...
                "Fe,O|PBE");
            skipped = kssolv.analysis.matgenlab.cli.pmg_potcar.gen_potcar( ...
                testCase.Root, "other.txt");
            testCase.verifyFalse(skipped.generated);
        end

        function symbolDispatchUsesExplicitOutput(testCase)
            output = fullfile(testCase.Root, "explicit.POTCAR");
            args = struct("functional", "PBE_54", ...
                "recursive", "", "symbols", ["Na", "Cl"], ...
                "output", output, ...
                "potcar_factory", @fakeFactory, ...
                "potcar_writer", @writeFakePotcar);
            [stdout, result] = capture(@() ...
                kssolv.analysis.matgenlab.cli.pmg_potcar. ...
                generate_potcar(args));

            expected = testCase.Oracle.generate_symbols.construction;
            testCase.verifyEqual(stdout, ...
                string(testCase.Oracle.generate_symbols.stdout));
            testCase.verifyTrue(result.success);
            testCase.verifyEqual(result.functional, ...
                string(expected.functional));
            testCase.verifyEqual(result.symbols, ...
                reshape(string(expected.symbols), 1, []));
            testCase.verifyEqual(string(fileread(output)), ...
                "Na,Cl|PBE_54");

            args = rmfield(args, "output");
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.cli.pmg_potcar. ...
                generate_potcar(args), ...
                "KSSOLV:Matgenlab:PmgPotcar:OutputRequired");
        end

        function recursiveDispatchGeneratesEverySpecification(testCase)
            materializeFixture(testCase.Root, testCase.Oracle.fixture_tree);
            nested = fullfile(testCase.Root, "nested");
            previous = getenv("PMG_DEFAULT_FUNCTIONAL");
            cleanup = onCleanup(@() restoreFunctional(previous));
            setenv("PMG_DEFAULT_FUNCTIONAL", "PBE");
            kssolv.analysis.matgenlab.core.Settings.refresh();
            args = struct("functional", "LDA", ...
                "recursive", testCase.Root, ...
                "symbols", "ignored", ...
                "potcar_factory", @fakeFactory, ...
                "potcar_writer", @writeFakePotcar);
            result = kssolv.analysis.matgenlab.cli.pmg_potcar. ...
                generate_potcar(args);
            testCase.verifyEqual(result.mode, "recursive");
            testCase.verifyEqual(string(fileread( ...
                fullfile(testCase.Root, "POTCAR"))), "Fe,O|PBE");
            testCase.verifyEqual(string(fileread( ...
                fullfile(nested, "POTCAR"))), "Li,F|PBE");
            generatedFunctionals = ["PBE", "PBE"];
            testCase.verifyEqual(sort(generatedFunctionals), ...
                sort(reshape(string( ...
                    testCase.Oracle.recursive_functionals), 1, [])));
            clear cleanup
            restoreFunctional(previous);
        end

        function outputAndFailureTextMatchFrozenOracle(testCase)
            invalidOutput = fullfile(testCase.Root, "invalid.POTCAR");
            invalid = struct("functional", "NOT_A_FUNCTIONAL", ...
                "recursive", "", "symbols", "Na", ...
                "output", invalidOutput, ...
                "potcar_factory", @fakeFactory, ...
                "potcar_writer", @writeFakePotcar);
            [stdout, result] = capture(@() ...
                kssolv.analysis.matgenlab.cli.pmg_potcar. ...
                generate_potcar(invalid));
            testCase.verifyEqual(stdout, ...
                string(testCase.Oracle.invalid_stdout));
            testCase.verifyFalse(result.success);
            testCase.verifyFalse(isfile(invalidOutput));

            [stdout, result] = capture(@() ...
                kssolv.analysis.matgenlab.cli.pmg_potcar. ...
                generate_potcar(struct()));
            testCase.verifyEqual(stdout, string(testCase.Oracle.noop_stdout));
            testCase.verifyEqual(result.mode, "none");
        end

        function rejectsImplicitOrInvalidFilesystemTargets(testCase)
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.cli.pmg_potcar.proc_dir( ...
                    fullfile(testCase.Root, "missing"), @(~, ~) []), ...
                "KSSOLV:Matgenlab:PmgPotcar:DirectoryMissing");
            args = struct("symbols", "Fe", ...
                "output", fullfile(testCase.Root, "missing", "POTCAR"), ...
                "potcar_factory", @fakeFactory, ...
                "potcar_writer", @writeFakePotcar);
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.cli.pmg_potcar. ...
                generate_potcar(args), ...
                "KSSOLV:Matgenlab:PmgPotcar:OutputDirectory");
        end
    end
end

function output = fakeFactory(symbols, functional)
output = struct("symbols", reshape(string(symbols), 1, []), ...
    "functional", string(functional));
end

function writeFakePotcar(potcar, outputPath)
writeText(outputPath, ...
    strjoin(potcar.symbols, ",") + "|" + potcar.functional);
end

function appendVisit(logPath, root, directory, filename)
relative = erase(string(directory), string(root));
relative = strip(relative, filesep);
if relative == "", relative = "."; end
file = fopen(logPath, "a", "n", "UTF-8");
assert(file >= 0);
cleanup = onCleanup(@() fclose(file));
fprintf(file, "%s|%s\n", relative, filename);
clear cleanup
end

function [output, value] = capture(functionHandle) %#ok<STOUT,INUSD>
output = string(evalc("value = functionHandle();"));
end

function writeText(path, text)
file = fopen(path, "w", "n", "UTF-8");
assert(file >= 0);
cleanup = onCleanup(@() fclose(file));
fwrite(file, char(text), "char");
clear cleanup
end

function materializeFixture(root, fixtureTree)
names = fieldnames(fixtureTree);
for index = 1:numel(names)
    relative = replace(string(names{index}), "_", ".");
    if names{index} == "nested_POTCAR_spec"
        relative = fullfile("nested", "POTCAR.spec");
    end
    destination = fullfile(root, relative);
    parent = fileparts(destination);
    if ~isfolder(parent), mkdir(parent); end
    writeText(destination, string(fixtureTree.(names{index})));
end
end

function restoreFunctional(value)
setenv("PMG_DEFAULT_FUNCTIONAL", value);
kssolv.analysis.matgenlab.core.Settings.refresh();
end
