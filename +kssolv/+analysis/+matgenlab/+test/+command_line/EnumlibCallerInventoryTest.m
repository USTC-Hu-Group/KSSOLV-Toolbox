classdef EnumlibCallerInventoryTest < matlab.unittest.TestCase
    methods (Test)
        function generatedInputMatchesFrozenUpstream(testCase)
            oracle = loadOracle();
            half = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {struct("Si", 0.5)}, [0, 0, 0]);
            adaptor = adaptorWith(half, @emptyEnumeration);
            testCase.verifyError(@() adaptor.run(), ...
                "KSSOLV:Matgenlab:Enumlib:Enumeration");
            testCase.verifyEqual(adaptor.generated_input, ...
                string(oracle.cases.half_occupied_si.input));
            testCase.verifyEqual(speciesNames(adaptor.index_species), ...
                string(oracle.cases.half_occupied_si.index_species).');

            mixed = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {struct("Li", 0.25), "O"}, ...
                [0, 0, 0; 0.5, 0.5, 0.5]);
            second = ...
                kssolv.analysis.matgenlab.command_line.enumlib_caller. ...
                EnumlibAdaptor(mixed, 1, 1, 0.1, 0.001, false, ...
                false, [], executor = @emptyEnumeration);
            testCase.verifyError(@() second.run(), ...
                "KSSOLV:Matgenlab:Enumlib:Enumeration");
            testCase.verifyEqual(second.generated_input, ...
                string(oracle.cases.quarter_li_with_ordered_o.input));
            testCase.verifyEqual(numel(second.ordered_sites), ...
                oracle.cases.quarter_li_with_ordered_o.ordered_sites);
        end

        function runParsesRunTotAndMakestrPoscar(testCase)
            oracle = loadOracle();
            half = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {struct("Si", 0.5)}, [0, 0, 0]);
            adaptor = adaptorWith(half, @(request) poscarResult( ...
                request, oracle.run_tot_stdout));
            adaptor.run();
            testCase.verifyNumElements(adaptor.structures, ...
                oracle.run_tot_count);
            result = adaptor.structures{1};
            testCase.verifyEqual(result.formula, "Si1");
            testCase.verifyEqual(result.lattice.matrix, eye(3) * 4, ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(result.frac_coords, [0, 0, 0], ...
                "AbsTol", 1e-12);
        end

        function directStructuresAndExecutorContract(testCase)
            half = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {struct("Si", 0.5)}, [0, 0, 0]);
            ordered = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {"Si"}, [0, 0, 0]);
            adaptor = adaptorWith(half, ...
                @(request) directResult(request, ordered));
            adaptor.run();
            testCase.verifyEqual(adaptor.structures{1}, ordered);
        end

        function boundaryAndFailureSemanticsAreStable(testCase)
            half = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {struct("Si", 0.5)}, [0, 0, 0]);
            missing = ...
                kssolv.analysis.matgenlab.command_line.enumlib_caller. ...
                EnumlibAdaptor(half);
            testCase.verifyError(@() missing.run(), ...
                "KSSOLV:Matgenlab:Enumlib:ExecutorRequired");

            timed = ...
                kssolv.analysis.matgenlab.command_line.enumlib_caller. ...
                EnumlibAdaptor(half, 1, 1, 0.1, 0.001, false, ...
                true, 0.05, executor = ...
                @(~) struct("timed_out", true));
            testCase.verifyError(@() timed.run(), ...
                "KSSOLV:Matgenlab:Enumlib:Timeout");

            failed = adaptorWith(half, ...
                @(~) struct("status", 9, "stderr", "enum failed"));
            testCase.verifyError(@() failed.run(), ...
                "KSSOLV:Matgenlab:Enumlib:Execution");
        end

        function frozenOfficialFixtureLoads(testCase)
            fixture = fullfile(fileparts(mfilename("fullpath")), ...
                "+fixtures", "+enumlib", "EnumerateTest.json.gz");
            temporary = string(tempname);
            mkdir(temporary);
            cleanup = onCleanup(@() rmdir(temporary, "s"));
            extracted = gunzip(fixture, temporary);
            structure = ...
                kssolv.analysis.matgenlab.core.Structure.from_file( ...
                extracted{1});
            testCase.verifyFalse(structure.is_ordered);
            testCase.verifyGreaterThan(structure.num_sites, 0);
            clear cleanup
        end

        function enumErrorIsMException(testCase)
            exception = ...
                kssolv.analysis.matgenlab.command_line.enumlib_caller. ...
                EnumError();
            testCase.verifyClass(exception, ...
                "kssolv.analysis.matgenlab.command_line.enumlib_caller.EnumError");
            testCase.verifyEqual(exception.identifier, ...
                'KSSOLV:Matgenlab:Enumlib:Enumeration');
            testCase.verifyEqual(exception.message, ...
                'Unable to enumerate structure.');
        end
    end
end

function adaptor = adaptorWith(structure, executor)
adaptor = kssolv.analysis.matgenlab.command_line.enumlib_caller. ...
    EnumlibAdaptor(structure, executor = executor);
end

function response = emptyEnumeration(~)
response = struct("enum_stdout", ...
    sprintf("enum RunTot\n1 something 0\n"));
end

function response = poscarResult(request, output)
assert(request.enum_input_filename == "struct_enum.in");
assert(request.enum_command_role == "enumlib");
assert(request.makestr_command_role == "makestr");
assert(isempty(request.timeout_seconds));
poscar = sprintf(char(join([ ...
    "enum derivative\n1\n"
    "4 0 0\n0 4 0\n0 0 4\n"
    "H\n1\nDirect\n0 0 0\n"], "")));
response = struct("enum_stdout", output, ...
    "poscar_texts", {repmat({poscar}, 1, 7)});
end

function response = directResult(request, structure)
assert(contains(request.enum_input, "0/1"));
response = struct("count", 1, "structures", {{structure}});
end

function names = speciesNames(species)
names = strings(1, numel(species));
for index = 1:numel(species)
    names(index) = string(species{index});
end
end

function oracle = loadOracle()
root = fileparts(fileparts(fileparts(fileparts(fileparts( ...
    fileparts(mfilename("fullpath")))))));
oracle = jsondecode(fileread(fullfile(root, "dev", "matgenlab", ...
    "oracles", "enumlib_caller_2026.7.24.json")));
end
