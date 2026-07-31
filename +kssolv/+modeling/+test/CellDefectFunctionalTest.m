classdef CellDefectFunctionalTest < matlab.unittest.TestCase
    %CELLDEFECTFUNCTIONALTEST Execute cell-wide and defect menu commands.

    properties (TestParameter)
        CellCommand = { ...
            "build_supercell", "redefine_lattice", ...
            "orthogonalize_cell", "strain_structure", ...
            "perturb_structure"}
        DefectCommand = {"create_point_defects", "generate_sqs_model"}
    end

    methods (Test)
        function cellCommandIsFunctional(testCase, CellCommand)
            commandId = string(CellCommand);
            model = testCase.cellInput(commandId);
            parameters = testCase.cellParameters(commandId, model);
            result = ...
                kssolv.modeling.test.ModelingFunctionalTestUtils. ...
                execute(testCase, model, commandId, parameters);
            testCase.verifyTrue(result.changed);
            testCase.verifyCellResult( ...
                commandId, model, result.model, parameters);
        end

        function incompatibleCellHasActionableOrthogonalizationError(testCase)
            model = kssolv.analysis.matgenlab.core.Structure( ...
                [3, 0, 0; .4, 3.2, 0; .2, .3, 3.5], ...
                {"Si"}, [0, 0, 0]);
            parameters = struct( ...
                "minimumLength", min(model.lattice.lengths), ...
                "maximumLength", max(model.lattice.lengths) * 4, ...
                "maximumAtoms", 5000, "angleTolerance", .1);
            testCase.verifyError(@() ...
                kssolv.modeling.CommandExecutor.execute( ...
                model, "orthogonalize_cell", parameters), ...
                "KSSOLV:Modeling:OrthogonalCellNotFound");
        end

        function defectCommandIsFunctional(testCase, DefectCommand)
            commandId = string(DefectCommand);
            [model, parameters] = testCase.defectCase(commandId);
            result = ...
                kssolv.modeling.test.ModelingFunctionalTestUtils. ...
                execute(testCase, model, commandId, parameters);
            testCase.verifyTrue(result.changed);
            if commandId == "create_point_defects"
                testCase.verifyEqual(result.model.num_sites, ...
                    model.num_sites - 1);
            else
                testCase.verifyTrue(result.model.is_ordered);
                testCase.verifyEqual(result.model.num_sites, 2);
            end
        end
    end

    methods (Static, Access = private)
        function model = cellInput(commandId)
            if commandId == "orthogonalize_cell"
                model = ...
                    kssolv.modeling.test. ...
                    ModelingFunctionalTestUtils.graphene();
            else
                model = ...
                    kssolv.modeling.test. ...
                    ModelingFunctionalTestUtils.baseStructure();
            end
        end

        function parameters = cellParameters(commandId, model)
            switch commandId
                case "build_supercell"
                    parameters = struct("scalingMatrix", [2, 1, 1]);
                case "redefine_lattice"
                    parameters = struct( ...
                        "matrix", model.lattice.matrix * 1.1);
                case "orthogonalize_cell"
                    parameters = struct( ...
                        "minimumLength", min(model.lattice.lengths), ...
                        "maximumLength", ...
                        max(model.lattice.lengths) * 4, ...
                        "maximumAtoms", 5000, ...
                        "angleTolerance", .1);
                case "strain_structure"
                    parameters = struct("strain", .02);
                case "perturb_structure"
                    parameters = struct( ...
                        "distance", .08, ...
                        "minimumDistance", .02, "seed", 23);
            end
        end

        function [model, parameters] = defectCase(commandId)
            if commandId == "create_point_defects"
                model = ...
                    kssolv.modeling.test. ...
                    ModelingFunctionalTestUtils.baseStructure();
                parameters = struct( ...
                    "defectType", "vacancy", "indices", 2);
                return
            end
            composition = ...
                kssolv.analysis.matgenlab.core.Composition( ...
                {"Si", .5; "Ge", .5});
            model = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {composition}, [0, 0, 0]);
            parameters = struct("scaling", 2, "searchTime", 1);
        end

        function verifyCellResult(commandId, input, output, parameters)
            switch commandId
                case "build_supercell"
                    assert(output.num_sites == input.num_sites * 2);
                    assert(abs(output.volume - input.volume * 2) < 1e-9);
                case "redefine_lattice"
                    assert(norm(output.cart_coords - ...
                        input.cart_coords, "fro") < 1e-10);
                case "orthogonalize_cell"
                    angles = output.lattice.angles;
                    assert(max(abs(angles - 90)) < 10);
                    assert(output.num_sites <= parameters.maximumAtoms);
                case "strain_structure"
                    assert(abs(output.volume / input.volume - 1.02^3) < 1e-10);
                case "perturb_structure"
                    assert(norm(output.cart_coords - ...
                        input.cart_coords, "fro") > 0);
            end
        end
    end
end
