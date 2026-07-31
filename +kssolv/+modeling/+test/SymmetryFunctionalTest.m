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
    end
end
