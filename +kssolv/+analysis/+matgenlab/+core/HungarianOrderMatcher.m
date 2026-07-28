classdef HungarianOrderMatcher < ...
        kssolv.analysis.matgenlab.core.KabschMatcher
    %HUNGARIANORDERMATCHER Fast inertia-axis and assignment ordering.

    methods
        function obj = HungarianOrderMatcher(target)
            obj@kssolv.analysis.matgenlab.core.KabschMatcher(target);
        end

        function [indices, rotation, translation, rmsd] = match(obj, molecule)
            if ~isequal(sort(molecule.atomic_numbers), ...
                    sort(obj.target.atomic_numbers))
                error("KSSOLV:Matgenlab:OrderMatcher:Composition", ...
                    "The number of the same species are not matching.");
            end
            sourceCenter = molecule.center_of_mass;
            targetCenter = obj.target.center_of_mass;
            source = molecule.cart_coords - sourceCenter;
            destination = obj.target.cart_coords - targetCenter;
            sourceWeights = cellfun(@(site) site.species.weight, ...
                molecule.sites);
            targetWeights = cellfun(@(site) site.species.weight, ...
                obj.target.sites);
            candidates = obj.permutations( ...
                molecule.atomic_numbers, source, sourceWeights, ...
                obj.target.atomic_numbers, destination, targetWeights);
            rmsd = Inf;
            indices = [];
            rotation = [];
            for index = 1:numel(candidates)
                order = candidates{index};
                trial = source(order, :);
                trialRotation = obj.kabsch(trial, destination);
                difference = trial * trialRotation - destination;
                trialRmsd = sqrt(mean(sum(difference.^2, 2)));
                if trialRmsd < rmsd
                    indices = order;
                    rotation = trialRotation;
                    rmsd = trialRmsd;
                end
            end
            translation = targetCenter - sourceCenter * rotation;
        end

        function [molecule, rmsd] = fit(obj, source)
            [indices, rotation, translation, rmsd] = obj.match(source);
            coordinates = source.cart_coords(indices, :) * rotation + ...
                translation;
            molecule = obj.moleculeFrom(source, indices, coordinates);
        end
    end

    methods (Static)
        function values = permutations(sourceAtoms, sourceCoordinates, ...
                sourceWeights, targetAtoms, targetCoordinates, targetWeights)
            sourceAxis = ...
                kssolv.analysis.matgenlab.core.HungarianOrderMatcher. ...
                get_principal_axis(sourceCoordinates, sourceWeights);
            targetAxis = ...
                kssolv.analysis.matgenlab.core.HungarianOrderMatcher. ...
                get_principal_axis(targetCoordinates, targetWeights);
            values = cell(1, 2);
            for signIndex = 1:2
                signValue = 3 - 2 * signIndex;
                alignment = ...
                    kssolv.analysis.matgenlab.core.HungarianOrderMatcher. ...
                    rotation_matrix_vectors(targetAxis, ...
                    signValue * sourceAxis);
                rotatedSource = sourceCoordinates * alignment;
                order = zeros(1, numel(sourceAtoms));
                elements = unique(sourceAtoms);
                for element = elements
                    sourceIndices = find(sourceAtoms == element);
                    targetIndices = find(targetAtoms == element);
                    cost = zeros(numel(targetIndices), ...
                        numel(sourceIndices));
                    for first = 1:numel(targetIndices)
                        cost(first, :) = vecnorm( ...
                            rotatedSource(sourceIndices, :) - ...
                            targetCoordinates(targetIndices(first), :), ...
                            2, 2).';
                    end
                    assignment = kssolv.analysis.matgenlab.core. ...
                        get_linear_assignment_solution(cost);
                    order(targetIndices) = sourceIndices(assignment);
                end
                values{signIndex} = order;
            end
        end

        function axis = get_principal_axis(coordinates, weights)
            tensor = zeros(3);
            for index = 1:size(coordinates, 1)
                x = coordinates(index, 1);
                y = coordinates(index, 2);
                z = coordinates(index, 3);
                weight = weights(index);
                tensor = tensor + weight * [
                    y*y + z*z, -x*y, -x*z
                    -x*y, x*x + z*z, -y*z
                    -x*z, -y*z, x*x + y*y
                    ];
            end
            [vectors, values] = eig(tensor, "vector");
            [~, index] = min(values);
            axis = vectors(:, index).';
        end

        function matrix = rotation_matrix_vectors(first, second)
            first = reshape(double(first), 1, 3);
            second = reshape(double(second), 1, 3);
            first = first / norm(first);
            second = second / norm(second);
            if norm(first - second) <= 1e-8
                matrix = eye(3);
                return
            elseif norm(first + second) <= 1e-8
                matrix = diag([-1, 1, -1]);
                return
            end
            vector = cross(first, second);
            cosine = dot(first, second);
            skew = [
                0, -vector(3), vector(2)
                vector(3), 0, -vector(1)
                -vector(2), vector(1), 0
                ];
            matrix = eye(3) + skew + ...
                skew * skew * ((1 - cosine) / dot(vector, vector));
        end
    end
end
