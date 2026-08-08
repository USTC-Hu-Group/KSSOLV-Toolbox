classdef SymmetryFunctionalTest < matlab.unittest.TestCase
    %SYMMETRYFUNCTIONALTEST Execute every symmetry menu command.

    properties (TestParameter)
        SymmetryCommand = { ...
            "find_symmetry", "primitive_cell", ...
            "conventional_cell", "wigner_seitz_cell"}
    end

    methods (Test)
        function symmetryCommandIsFunctional(testCase, SymmetryCommand)
            commandId = string(SymmetryCommand);
            model = ...
                kssolv.modeling.test. ...
                ModelingFunctionalTestUtils.simpleCubic();
            parameters = struct( ...
                "symprec", .01, "angleTolerance", 5);
            result = ...
                kssolv.modeling.test.ModelingFunctionalTestUtils. ...
                execute(testCase, model, commandId, parameters);
            switch commandId
                case "find_symmetry"
                    testCase.verifyFalse(result.changed);
                    testCase.verifyEqual(result.data.number, 221);
                case {"primitive_cell", "conventional_cell"}
                    testCase.verifyTrue(result.changed);
                    testCase.verifyEqual(result.model.num_sites, 1);
                case "wigner_seitz_cell"
                    testCase.verifyFalse(result.changed);
                    testCase.verifyEqual(numel(result.data), 6);
            end
        end

        function toleranceControlsEquivalentAtomDetection(testCase)
            lattice = 4 * eye(3);
            coordinates = [
                0, 0, 0
                0.00125, 0.5, 0.5
                0.5, 0, 0.5
                0.5, 0.5, 0
                ];
            model = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, {"Si", "Si", "Si", "Si"}, coordinates);

            fine = kssolv.modeling.CommandExecutor.execute( ...
                model, "find_symmetry", struct( ...
                "symprec", 0.001, "angleTolerance", 5));
            good = kssolv.modeling.CommandExecutor.execute( ...
                model, "find_symmetry", struct( ...
                "symprec", 0.01, "angleTolerance", 5));

            testCase.verifyGreaterThan( ...
                numel(unique(fine.data.equivalent_atoms)), 1);
            testCase.verifyEqual( ...
                numel(unique(good.data.equivalent_atoms)), 1);
            testCase.verifyNotEqual(fine.data.number, good.data.number);
        end
    end
end
