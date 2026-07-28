classdef GeneticOrderMatcher < ...
        kssolv.analysis.matgenlab.core.KabschMatcher
    %GENETICORDERMATCHER Fragment-pruned exhaustive molecular ordering.

    properties (SetAccess = private)
        threshold (1,1) double
        N (1,1) double
    end

    methods
        function obj = GeneticOrderMatcher(target, threshold)
            obj@kssolv.analysis.matgenlab.core.KabschMatcher(target);
            obj.threshold = double(threshold);
            obj.N = target.num_sites;
        end

        function values = match(obj, molecule)
            orders = obj.permutations(molecule);
            values = cell(1, numel(orders));
            for index = 1:numel(orders)
                order = orders{index};
                reordered = obj.moleculeFrom(molecule, order, ...
                    molecule.cart_coords(order, :));
                [rotation, translation, rmsd] = ...
                    match@kssolv.analysis.matgenlab.core. ...
                    KabschMatcher(obj, reordered);
                values{index} = {order, rotation, translation, rmsd};
            end
        end

        function values = fit(obj, molecule)
            matches = obj.match(molecule);
            values = cell(1, numel(matches));
            for index = 1:numel(matches)
                matchValue = matches{index};
                order = matchValue{1};
                coordinates = molecule.cart_coords(order, :) * ...
                    matchValue{2} + matchValue{3};
                fitted = obj.moleculeFrom(molecule, order, coordinates);
                values{index} = {fitted, matchValue{4}};
            end
        end

        function orders = permutations(obj, molecule)
            sourceAtoms = molecule.atomic_numbers;
            targetAtoms = obj.target.atomic_numbers;
            if ~isequal(sort(sourceAtoms), sort(targetAtoms))
                error("KSSOLV:Matgenlab:OrderMatcher:Composition", ...
                    "The number of the same species are not matching.");
            end
            sourceCoordinates = molecule.cart_coords;
            targetCoordinates = obj.target.cart_coords;
            partial = num2cell(find(sourceAtoms == targetAtoms(1)).');
            partial = cellfun(@(value) value(:).', partial, ...
                "UniformOutput", false);
            for targetIndex = 2:obj.N
                targetFragment = targetCoordinates(1:targetIndex, :);
                targetFragment = targetFragment - mean(targetFragment, 1);
                next = cell(1, 0);
                for partialIndex = 1:numel(partial)
                    prefix = partial{partialIndex};
                    for sourceIndex = 1:obj.N
                        if any(prefix == sourceIndex) || ...
                                sourceAtoms(sourceIndex) ~= ...
                                targetAtoms(targetIndex)
                            continue
                        end
                        order = [prefix, sourceIndex];
                        sourceFragment = sourceCoordinates(order, :);
                        sourceFragment = sourceFragment - ...
                            mean(sourceFragment, 1);
                        rotation = obj.kabsch( ...
                            sourceFragment, targetFragment);
                        difference = sourceFragment * rotation - ...
                            targetFragment;
                        rmsd = sqrt(mean(sum(difference.^2, 2)));
                        if rmsd <= obj.threshold
                            next{end + 1} = order; %#ok<AGROW>
                        end
                    end
                end
                partial = next;
            end
            orders = partial;
        end

        function value = asDict(obj)
            value = asDict@kssolv.analysis.matgenlab.core.KabschMatcher(obj);
            value.threshold = obj.threshold;
        end
    end
end
