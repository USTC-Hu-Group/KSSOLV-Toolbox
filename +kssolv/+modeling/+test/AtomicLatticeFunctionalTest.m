classdef AtomicLatticeFunctionalTest < matlab.unittest.TestCase
    %ATOMICLATTICEFUNCTIONALTEST Execute every atom/lattice menu command.

    properties (TestParameter)
        AtomicCommand = { ...
            "add_atom", "center_atoms", "delete_atoms", "merge_atoms", ...
            "fix_atoms", "mirror_atoms", "move_atoms", "perturb_atoms", ...
            "sort_atoms", "rotate_atoms", "substitute_atoms", ...
            "translate_atoms"}
        LatticeCommand = { ...
            "apply_strain", "edit_lattice", "mirror_lattice", ...
            "rotate_lattice", "swap_axes"}
    end

    methods (Test)
        function atomicCommandIsFunctional(testCase, AtomicCommand)
            commandId = string(AtomicCommand);
            [model, parameters] = testCase.atomicCase(commandId);
            result = ...
                kssolv.modeling.test.ModelingFunctionalTestUtils. ...
                execute(testCase, model, commandId, parameters);
            testCase.verifyTrue(result.changed);
            testCase.verifyAtomicResult(commandId, model, result.model);
        end

        function latticeCommandIsFunctional(testCase, LatticeCommand)
            commandId = string(LatticeCommand);
            model = ...
                kssolv.modeling.test. ...
                ModelingFunctionalTestUtils.baseStructure();
            parameters = testCase.latticeParameters(commandId);
            result = ...
                kssolv.modeling.test.ModelingFunctionalTestUtils. ...
                execute(testCase, model, commandId, parameters);
            testCase.verifyTrue(result.changed);
            testCase.verifyLatticeResult( ...
                commandId, model, result.model, parameters);
        end
    end

    methods (Static, Access = private)
        function [model, parameters] = atomicCase(commandId)
            model = ...
                kssolv.modeling.test. ...
                ModelingFunctionalTestUtils.baseStructure();
            switch commandId
                case "add_atom"
                    parameters = struct( ...
                        "species", "H", ...
                        "coordinates", [.35, .35, .35]);
                case "center_atoms"
                    parameters = struct( ...
                        "indices", [1, 2], "center", [.5, .5, .5]);
                case "delete_atoms"
                    parameters = struct("indices", 2);
                case "merge_atoms"
                    model = ...
                        kssolv.modeling.test. ...
                        ModelingFunctionalTestUtils.duplicateStructure();
                    parameters = struct( ...
                        "tolerance", .01, "mode", "delete");
                case "fix_atoms"
                    parameters = struct("indices", 1);
                case "mirror_atoms"
                    parameters = struct( ...
                        "indices", 1, "normal", [1, 0, 0], ...
                        "point", [2.5, 0, 0]);
                case "move_atoms"
                    parameters = struct( ...
                        "indices", 1, "coordinates", [1, 2, 3], ...
                        "cartesian", true);
                case "perturb_atoms"
                    parameters = struct( ...
                        "distance", .1, ...
                        "minimumDistance", .05, "seed", 17);
                case "sort_atoms"
                    parameters = struct("reverse", true);
                case "rotate_atoms"
                    parameters = struct( ...
                        "indices", 1, "angleDegrees", 90, ...
                        "axis", [0, 0, 1], "anchor", [0, 0, 0]);
                case "substitute_atoms"
                    parameters = struct( ...
                        "indices", 1, "species", "C");
                case "translate_atoms"
                    parameters = struct( ...
                        "indices", 1, "vector", [.1, 0, 0], ...
                        "fractional", true);
            end
        end

        function parameters = latticeParameters(commandId)
            switch commandId
                case "apply_strain"
                    parameters = struct("strain", [.01, .02, .03]);
                case "edit_lattice"
                    parameters = struct( ...
                        "matrix", diag([5.5, 6.5, 7.5]), ...
                        "preserveCartesian", false);
                case "mirror_lattice"
                    parameters = struct("axisIndex", 1);
                case "rotate_lattice"
                    parameters = struct( ...
                        "angleDegrees", 30, "axis", [0, 0, 1]);
                case "swap_axes"
                    parameters = struct("order", [2, 3, 1]);
            end
        end

        function verifyAtomicResult(commandId, input, output)
            switch commandId
                case "add_atom"
                    assert(output.num_sites == input.num_sites + 1);
                case "center_atoms"
                    center = mean(output.frac_coords, 1);
                    assert(norm(center - [.5, .5, .5]) < 1e-10);
                case "delete_atoms"
                    assert(output.num_sites == input.num_sites - 1);
                case "merge_atoms"
                    assert(output.num_sites == input.num_sites - 1);
                case "fix_atoms"
                    fixed = output(1).site_properties.selective_dynamics;
                    assert(isequal(fixed, [false, false, false]));
                case "move_atoms"
                    assert(norm(output.cart_coords(1, :) - [1, 2, 3]) < 1e-10);
                case "perturb_atoms"
                    assert(norm(output.cart_coords - input.cart_coords, "fro") > 0);
                case "rotate_atoms"
                    initialDistance = ...
                        input.lattice.get_distance_and_image( ...
                        [0, 0, 0], input.frac_coords(1, :));
                    finalDistance = ...
                        output.lattice.get_distance_and_image( ...
                        [0, 0, 0], output.frac_coords(1, :));
                    assert(abs(finalDistance - initialDistance) < 1e-10);
                case "substitute_atoms"
                    assert(output(1).species_string == "C");
                case "translate_atoms"
                    delta = output.frac_coords(1, :) - input.frac_coords(1, :);
                    assert(norm(delta - [.1, 0, 0]) < 1e-10);
                otherwise
                    assert(output.num_sites == input.num_sites);
            end
        end

        function verifyLatticeResult(commandId, input, output, parameters)
            switch commandId
                case "apply_strain"
                    expected = input.lattice.matrix .* ...
                        (1 + parameters.strain).';
                    assert(norm(output.lattice.matrix - expected, "fro") < 1e-10);
                case "edit_lattice"
                    assert(norm(output.lattice.matrix - ...
                        parameters.matrix, "fro") < 1e-10);
                case "mirror_lattice"
                    assert(norm(output.lattice.matrix(1, :) + ...
                        input.lattice.matrix(1, :)) < 1e-10);
                case "rotate_lattice"
                    assert(norm(output.distance_matrix - ...
                        input.distance_matrix, "fro") < 1e-10);
                case "swap_axes"
                    assert(norm(output.cart_coords - ...
                        input.cart_coords, "fro") < 1e-10);
            end
        end
    end
end
