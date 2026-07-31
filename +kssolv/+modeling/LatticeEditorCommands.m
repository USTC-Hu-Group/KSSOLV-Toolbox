classdef LatticeEditorCommands
    %LATTICEEDITORCOMMANDS Lattice transformations preserving site metadata.

    methods (Static)
        function ids = commandIds()
            ids = [
                "apply_strain"
                "edit_lattice"
                "mirror_lattice"
                "rotate_lattice"
                "swap_axes"
                ];
        end

        function value = supports(commandId)
            value = any(kssolv.modeling.LatticeEditorCommands.commandIds() == ...
                string(commandId));
        end

        function result = execute(model, commandId, parameters)
            import kssolv.modeling.ParameterUtils
            commandId = string(commandId);
            switch commandId
                case "apply_strain"
                    strain = ParameterUtils.get(parameters, "strain", 0);
                    model = model.apply_strain(strain);
                case "edit_lattice"
                    matrix = ParameterUtils.matrix(parameters, "matrix", ...
                        3, 3, model.lattice.matrix);
                    preserveCartesian = ParameterUtils.logical( ...
                        parameters, "preserveCartesian", false);
                    model = kssolv.modeling.LatticeEditorCommands. ...
                        replaceLattice(model, matrix, preserveCartesian);
                case "mirror_lattice"
                    axisIndex = double(ParameterUtils.get( ...
                        parameters, "axisIndex", 1));
                    mustBeMember(axisIndex, 1:3);
                    matrix = model.lattice.matrix;
                    matrix(axisIndex, :) = -matrix(axisIndex, :);
                    model = kssolv.modeling.LatticeEditorCommands. ...
                        replaceLattice(model, matrix, false);
                case "rotate_lattice"
                    angle = deg2rad(double(ParameterUtils.get( ...
                        parameters, "angleDegrees", 0)));
                    axis = ParameterUtils.vector( ...
                        parameters, "axis", 3, [0, 0, 1]);
                    rotation = kssolv.modeling.LatticeEditorCommands. ...
                        rotationMatrix(axis, angle);
                    matrix = model.lattice.matrix * rotation.';
                    model = kssolv.modeling.LatticeEditorCommands. ...
                        replaceLattice(model, matrix, false);
                case "swap_axes"
                    order = ParameterUtils.vector( ...
                        parameters, "order", 3, [2, 1, 3]);
                    if ~isequal(sort(order), 1:3) || any(order ~= fix(order))
                        error("KSSOLV:Modeling:AxisOrder", ...
                            "Axis order must be a permutation of [1 2 3].");
                    end
                    model = kssolv.modeling.LatticeEditorCommands. ...
                        reorderAxes(model, order);
                otherwise
                    error("KSSOLV:Modeling:LatticeCommand", ...
                        "Unsupported Lattice Editor command '%s'.", commandId);
            end
            result = struct( ...
                "model", model, "changed", true, ...
                "message", "Lattice updated.");
        end
    end

    methods (Static, Access = private)
        function model = replaceLattice(model, matrix, preserveCartesian)
            lattice = kssolv.analysis.matgenlab.core.Lattice( ...
                matrix, model.pbc);
            if ~preserveCartesian
                model = model.set_lattice_preserve_fractional(lattice);
                return
            end
            coordinates = model.cart_coords;
            model = model.set_lattice_preserve_fractional(lattice);
            for index = 1:model.num_sites
                model = model.replace(index, [], coordinates(index, :), ...
                    coords_are_cartesian = true);
            end
        end

        function model = reorderAxes(model, order)
            fractional = model.frac_coords(:, order);
            matrix = model.lattice.matrix(order, :);
            model = kssolv.modeling.LatticeEditorCommands. ...
                replaceLattice(model, matrix, false);
            for index = 1:model.num_sites
                model = model.replace(index, [], fractional(index, :), ...
                    coords_are_cartesian = false);
            end
        end

        function matrix = rotationMatrix(axis, angle)
            axis = axis / norm(axis);
            if any(~isfinite(axis))
                error("KSSOLV:Modeling:RotationAxis", ...
                    "Rotation axis cannot be zero.");
            end
            skew = [
                0, -axis(3), axis(2)
                axis(3), 0, -axis(1)
                -axis(2), axis(1), 0
                ];
            matrix = eye(3) + sin(angle) * skew + ...
                (1 - cos(angle)) * (skew * skew);
        end
    end
end
