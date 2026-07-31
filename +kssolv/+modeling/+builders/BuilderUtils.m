classdef BuilderUtils
    %BUILDERUTILS Geometry and metadata helpers for native model builders.

    methods (Static)
        function requireStructure(value)
            if ~isa(value, ...
                    "kssolv.analysis.matgenlab.core.IStructure")
                error("KSSOLV:Modeling:BuilderStructure", ...
                    "The builder requires a periodic matgenlab structure.");
            end
            if value.num_sites < 1
                error("KSSOLV:Modeling:BuilderEmpty", ...
                    "The input structure cannot be empty.");
            end
        end

        function requireTwoDimensional(value)
            kssolv.modeling.builders.BuilderUtils. ...
                requireStructure(value);
            if norm(cross(value.lattice.matrix(1, :), ...
                    value.lattice.matrix(2, :))) <= 1e-10
                error("KSSOLV:Modeling:DegenerateLayer", ...
                    "The first two lattice vectors must span a plane.");
            end
        end

        function output = fromCartesian(source, latticeMatrix, ...
                coordinates, indices, pbc, extraProperties)
            arguments
                source
                latticeMatrix (3,3) double
                coordinates (:,3) double
                indices
                pbc (1,3) logical
                extraProperties (1,1) struct = struct()
            end
            indices = reshape(double(indices), 1, []);
            if size(coordinates, 1) ~= numel(indices)
                error("KSSOLV:Modeling:BuilderCoordinates", ...
                    "Coordinate and site-index counts must match.");
            end
            properties = ...
                kssolv.modeling.builders.BuilderUtils. ...
                subsetProperties(source.site_properties, indices);
            names = fieldnames(extraProperties);
            for nameIndex = 1:numel(names)
                name = names{nameIndex};
                values = extraProperties.(name);
                if numel(values) ~= numel(indices)
                    error("KSSOLV:Modeling:BuilderProperty", ...
                        "Property '%s' must contain one value per site.", ...
                        name);
                end
                properties.(name) = reshape(values, 1, []);
            end
            lattice = kssolv.analysis.matgenlab.core.Lattice( ...
                latticeMatrix, pbc);
            output = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, source.species_and_occu(indices), coordinates, ...
                coords_are_cartesian = true, ...
                site_properties = properties, ...
                labels = source.labels(indices), ...
                properties = source.structure_properties, ...
                skip_checks = true);
        end

        function properties = subsetProperties(properties, indices)
            names = fieldnames(properties);
            for nameIndex = 1:numel(names)
                name = names{nameIndex};
                values = properties.(name);
                if iscell(values)
                    properties.(name) = values(indices);
                elseif isvector(values)
                    properties.(name) = values(indices);
                else
                    properties.(name) = values(indices, :);
                end
            end
        end

        function properties = combineProperties(first, second, ...
                firstCount, secondCount)
            firstNames = string(fieldnames(first));
            secondNames = string(fieldnames(second));
            names = unique([firstNames; secondNames]);
            properties = struct();
            for nameIndex = 1:numel(names)
                name = char(names(nameIndex));
                values = cell(1, firstCount + secondCount);
                if isfield(first, name)
                    values(1:firstCount) = ...
                        kssolv.modeling.builders.BuilderUtils. ...
                        propertyCells(first.(name), firstCount);
                end
                if isfield(second, name)
                    values(firstCount + (1:secondCount)) = ...
                        kssolv.modeling.builders.BuilderUtils. ...
                        propertyCells(second.(name), secondCount);
                end
                properties.(name) = values;
            end
        end

        function [first, second, axis] = frame(axisVector, preferred)
            axis = reshape(double(axisVector), 1, 3);
            if norm(axis) <= 1e-12
                error("KSSOLV:Modeling:BuilderAxis", ...
                    "The periodic-axis vector cannot be zero.");
            end
            axis = axis / norm(axis);
            first = reshape(double(preferred), 1, 3);
            first = first - dot(first, axis) * axis;
            if norm(first) <= 1e-10
                basis = eye(3);
                [~, index] = min(abs(basis * axis.'));
                first = basis(index, :) - ...
                    dot(basis(index, :), axis) * axis;
            end
            first = first / norm(first);
            second = cross(axis, first);
            second = second / norm(second);
        end

        function vector = inPlanePerpendicular(lattice, direction, limit)
            if nargin < 3, limit = 40; end
            direction = reshape(double(direction), 1, 2);
            if all(direction == 0) || any(direction ~= fix(direction))
                error("KSSOLV:Modeling:BuilderDirection", ...
                    "An in-plane direction must contain two nonzero integers.");
            end
            matrix = lattice.matrix;
            target = direction * matrix(1:2, :);
            bestScore = Inf;
            vector = [];
            for first = -limit:limit
                for second = -limit:limit
                    candidate = [first, second];
                    if ~any(candidate) || ...
                            abs(det([candidate; direction])) < 1
                        continue
                    end
                    cartesian = candidate * matrix(1:2, :);
                    cosine = abs(dot(cartesian, target)) / ...
                        (norm(cartesian) * norm(target));
                    score = cosine + 1e-8 * norm(cartesian);
                    if score < bestScore
                        vector = candidate;
                        bestScore = score;
                    end
                end
            end
            if isempty(vector)
                error("KSSOLV:Modeling:BuilderDirectionSearch", ...
                    "Unable to find an independent in-plane lattice vector.");
            end
            divisor = gcd(abs(round(vector(1))), ...
                abs(round(vector(2))));
            if divisor > 1
                vector = vector / divisor;
            end
        end

        function [first, second] = transverseIntegerBasis( ...
                lattice, direction, limit)
            if nargin < 3, limit = 5; end
            direction = reshape(double(direction), 1, 3);
            if all(direction == 0) || any(direction ~= fix(direction))
                error("KSSOLV:Modeling:BuilderDirection", ...
                    "A wire direction must contain three integers.");
            end
            axis = direction * lattice.matrix;
            candidates = zeros(0, 5);
            for a = -limit:limit
                for b = -limit:limit
                    for c = -limit:limit
                        vector = [a, b, c];
                        if ~any(vector) || ...
                                rank([direction; vector]) < 2
                            continue
                        end
                        cartesian = vector * lattice.matrix;
                        perpendicular = cartesian - ...
                            dot(cartesian, axis) / dot(axis, axis) * axis;
                        if norm(perpendicular) <= 1e-8
                            continue
                        end
                        score = abs(dot(cartesian, axis)) / ...
                            (norm(cartesian) * norm(axis));
                        candidates(end + 1, :) = [vector, score, ...
                            norm(perpendicular)]; %#ok<AGROW>
                    end
                end
            end
            [~, order] = sortrows(candidates(:, 4:5), [1, 2]);
            candidates = candidates(order, :);
            first = candidates(1, 1:3);
            second = [];
            for index = 2:size(candidates, 1)
                trial = candidates(index, 1:3);
                if abs(det([first; trial; direction])) >= 1
                    second = trial;
                    break
                end
            end
            if isempty(second)
                error("KSSOLV:Modeling:BuilderBasisSearch", ...
                    "Unable to find a transverse integer basis.");
            end
        end

        function strain = inPlanePrincipalStrain(referencePlane, ...
                sourcePlane)
            % Return the largest principal stretch needed to map the
            % source 2-D lattice onto the reference lattice.  Comparing
            % Gram matrices directly approximately doubles small isotropic
            % strains and therefore does not represent a strain limit.
            reference = planeCoordinates(referencePlane);
            source = planeCoordinates(sourcePlane);
            deformation = source \ reference;
            stretches = svd(deformation);
            strain = max(abs(stretches - 1));

            function coordinates = planeCoordinates(plane)
                if ~isequal(size(plane), [2, 3])
                    error("KSSOLV:Modeling:PlaneShape", ...
                        "An in-plane lattice must contain two 3-D vectors.");
                end
                first = plane(1, :);
                normal = cross(first, plane(2, :));
                if norm(first) <= 1e-12 || norm(normal) <= 1e-12
                    error("KSSOLV:Modeling:DegeneratePlane", ...
                        "The in-plane lattice vectors must be independent.");
                end
                first = first / norm(first);
                normal = normal / norm(normal);
                second = cross(normal, first);
                coordinates = [plane * first.', plane * second.'];
            end
        end

        function value = positiveInteger(value, name)
            value = double(value);
            if ~isscalar(value) || ~isfinite(value) || ...
                    value < 1 || value ~= fix(value)
                error("KSSOLV:Modeling:BuilderInteger", ...
                    "%s must be a positive integer.", name);
            end
        end

        function value = positiveScalar(value, name)
            value = double(value);
            if ~isscalar(value) || ~isfinite(value) || value <= 0
                error("KSSOLV:Modeling:BuilderScalar", ...
                    "%s must be a positive finite scalar.", name);
            end
        end
    end

    methods (Static, Access = private)
        function values = propertyCells(input, count)
            if iscell(input)
                values = reshape(input, 1, []);
            elseif isvector(input)
                values = num2cell(reshape(input, 1, []));
            else
                values = num2cell(input, 2).';
            end
            if numel(values) ~= count
                error("KSSOLV:Modeling:BuilderPropertyLength", ...
                    "A site property has an invalid value count.");
            end
        end
    end
end
