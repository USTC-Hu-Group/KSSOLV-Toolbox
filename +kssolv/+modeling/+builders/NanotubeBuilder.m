classdef NanotubeBuilder
    %NANOTUBEBUILDER Roll a 2-D periodic layer into a commensurate tube.
    %
    % The chiral-vector construction follows the (n,m) convention used by
    % ASE. Hexagonal layers use the exact primitive axial translation;
    % other 2-D lattices use a bounded integer perpendicular search.

    methods (Static)
        function tube = build(layer, chiralIndices, options)
            arguments
                layer
                chiralIndices (1,2) double
                options.length (1,1) double = 1
                options.vacuum (1,1) double = 8
                options.maximumAtoms (1,1) double = 100000
            end
            import kssolv.modeling.builders.BuilderUtils
            BuilderUtils.requireTwoDimensional(layer);
            n = BuilderUtils.positiveInteger( ...
                chiralIndices(1), "Chiral index n");
            m = double(chiralIndices(2));
            if ~isscalar(m) || ~isfinite(m) || m < 0 || m ~= fix(m)
                error("KSSOLV:Modeling:NanotubeChiralIndex", ...
                    "Chiral index m must be a nonnegative integer.");
            end
            lengthValue = BuilderUtils.positiveInteger( ...
                options.length, "Tube length");
            vacuum = BuilderUtils.positiveScalar( ...
                options.vacuum, "Vacuum");
            maximumAtoms = BuilderUtils.positiveInteger( ...
                options.maximumAtoms, "Maximum atom count");

            axial = ...
                kssolv.modeling.builders.NanotubeBuilder. ...
                axialTranslation(layer, [n, m]);
            transform = [
                n, m, 0
                lengthValue * axial(1), lengthValue * axial(2), 0
                0, 0, 1
                ];
            predicted = abs(round(det(transform))) * layer.num_sites;
            if predicted > maximumAtoms
                error("KSSOLV:Modeling:NanotubeAtomLimit", ...
                    "The requested nanotube would contain %d atoms " + ...
                    "(limit %d).", predicted, maximumAtoms);
            end
            sheet = layer * transform;
            chiralVector = sheet.lattice.matrix(1, :);
            axialVector = sheet.lattice.matrix(2, :);
            normal = cross(chiralVector, axialVector);
            normal = normal / norm(normal);
            chiralUnit = chiralVector / norm(chiralVector);
            axialUnit = axialVector / norm(axialVector);
            coordinates = sheet.cart_coords;
            chiralCoordinate = coordinates * chiralUnit.';
            axialCoordinate = coordinates * axialUnit.';
            normalCoordinate = coordinates * normal.';
            normalCoordinate = normalCoordinate - median(normalCoordinate);

            radius = norm(chiralVector) / (2 * pi);
            angle = 2 * pi * chiralCoordinate / norm(chiralVector);
            radial = radius + normalCoordinate;
            diameter = 2 * max(abs(radial));
            transverse = diameter + 2 * vacuum;
            cartesian = [
                radial .* cos(angle) + transverse / 2, ...
                radial .* sin(angle) + transverse / 2, ...
                mod(axialCoordinate, norm(axialVector))
                ];
            lattice = diag([transverse, transverse, norm(axialVector)]);
            indices = 1:sheet.num_sites;
            metadata = struct();
            metadata.source_site_index = ...
                num2cell(mod(indices - 1, layer.num_sites) + 1);
            tube = BuilderUtils.fromCartesian( ...
                sheet, lattice, cartesian, indices, ...
                [false, false, true], metadata);
            tube.properties.nanotube = struct( ...
                "chiral_indices", [n, m], ...
                "radius", radius, ...
                "axial_translation", axial, ...
                "length", lengthValue);
        end
    end

    methods (Static, Access = private)
        function axial = axialTranslation(layer, chiral)
            angles = layer.lattice.angles;
            isHexagonal = abs(angles(3) - 60) < 1e-4 || ...
                abs(angles(3) - 120) < 1e-4;
            n = chiral(1);
            m = chiral(2);
            if isHexagonal
                axial = [2 * m + n, -(2 * n + m)];
                divisor = gcd(abs(round(axial(1))), ...
                    abs(round(axial(2))));
                if divisor > 0
                    axial = axial / divisor;
                end
            else
                axial = ...
                    kssolv.modeling.builders.BuilderUtils. ...
                    inPlanePerpendicular( ...
                    layer.lattice, chiral, 60);
            end
        end
    end
end
