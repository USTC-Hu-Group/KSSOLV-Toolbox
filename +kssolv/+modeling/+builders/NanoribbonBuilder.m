classdef NanoribbonBuilder
    %NANORIBBONBUILDER Cut a rigid, one-dimensionally periodic ribbon.

    methods (Static)
        function ribbon = build(layer, options)
            arguments
                layer
                options.width (1,1) double = 4
                options.length (1,1) double = 1
                options.edgeType {mustBeTextScalar} = "zigzag"
                options.vacuum (1,1) double = 8
                options.maximumAtoms (1,1) double = 100000
            end
            import kssolv.modeling.builders.BuilderUtils
            BuilderUtils.requireTwoDimensional(layer);
            width = BuilderUtils.positiveInteger( ...
                options.width, "Ribbon width");
            lengthValue = BuilderUtils.positiveInteger( ...
                options.length, "Ribbon length");
            vacuum = BuilderUtils.positiveScalar( ...
                options.vacuum, "Vacuum");
            maximumAtoms = BuilderUtils.positiveInteger( ...
                options.maximumAtoms, "Maximum atom count");
            edgeType = lower(string(options.edgeType));
            switch edgeType
                case "zigzag"
                    direction = [1, 0];
                case "armchair"
                    direction = [1, 1];
                otherwise
                    error("KSSOLV:Modeling:NanoribbonEdge", ...
                        "Edge type must be 'zigzag' or 'armchair'.");
            end
            transverse = BuilderUtils.inPlanePerpendicular( ...
                layer.lattice, direction, 40);
            transform = [
                width * transverse, 0
                lengthValue * direction, 0
                0, 0, 1
                ];
            predicted = abs(round(det(transform))) * layer.num_sites;
            if predicted > maximumAtoms
                error("KSSOLV:Modeling:NanoribbonAtomLimit", ...
                    "The requested nanoribbon would contain %d atoms " + ...
                    "(limit %d).", predicted, maximumAtoms);
            end
            sheet = layer * transform;
            matrix = sheet.lattice.matrix;
            axisVector = matrix(2, :);
            normal = cross(matrix(1, :), axisVector);
            normal = normal / norm(normal);
            widthUnit = cross(axisVector / norm(axisVector), normal);
            widthUnit = widthUnit / norm(widthUnit);
            axisUnit = axisVector / norm(axisVector);
            positions = sheet.cart_coords;
            x = positions * widthUnit.';
            y = positions * axisUnit.';
            z = positions * normal.';
            x = x - min(x) + vacuum;
            z = z - min(z) + vacuum;
            xLength = max(x) - min(x) + 2 * vacuum;
            zLength = max(z) - min(z) + 2 * vacuum;
            yLength = norm(axisVector);
            coordinates = [x, mod(y, yLength), z];
            lattice = diag([xLength, yLength, zLength]);
            indices = 1:sheet.num_sites;
            ribbon = BuilderUtils.fromCartesian( ...
                sheet, lattice, coordinates, indices, ...
                [false, true, false]);
            ribbon.properties.nanoribbon = struct( ...
                "edge_type", edgeType, ...
                "width", width, "length", lengthValue);
        end
    end
end
