classdef BruteForceOrderMatcher < ...
        kssolv.analysis.matgenlab.core.KabschMatcher
    %BRUTEFORCEORDERMATCHER Exhaustive within-species molecular ordering.

    methods
        function obj = BruteForceOrderMatcher(target)
            obj@kssolv.analysis.matgenlab.core.KabschMatcher(target);
        end

        function [indices, rotation, translation, rmsd] = ...
                match(obj, molecule, ignore_warning, break_on_tol)
            if nargin < 3, ignore_warning = false; end
            if nargin < 4, break_on_tol = []; end
            if ~isequal(sort(molecule.atomic_numbers), ...
                    sort(obj.target.atomic_numbers))
                error("KSSOLV:Matgenlab:OrderMatcher:Composition", ...
                    "The number of the same species are not matching.");
            end
            [~, ~, groups] = unique(molecule.atomic_numbers);
            counts = accumarray(groups(:), 1);
            numberPermutations = prod(arrayfun(@factorial, counts));
            if ~ignore_warning && numberPermutations > 1e6
                error("KSSOLV:Matgenlab:OrderMatcher:TooManyPermutations", ...
                    "The number of all possible permutations (%g) is not " + ...
                    "feasible to run this method.", numberPermutations);
            end

            source = molecule.cart_coords;
            destination = obj.target.cart_coords;
            sourceCenter = mean(source, 1);
            destinationCenter = mean(destination, 1);
            centeredSource = source - sourceCenter;
            centeredDestination = destination - destinationCenter;
            [~, targetOrder] = sort(obj.target.atomic_numbers);
            orderedDestination = centeredDestination(targetOrder, :);
            candidates = obj.permutations(molecule.atomic_numbers);
            rmsd = Inf;
            bestOrder = [];
            rotation = [];
            for index = 1:numel(candidates)
                order = candidates{index};
                trial = centeredSource(order, :);
                trialRotation = ...
                    kssolv.analysis.matgenlab.core.KabschMatcher. ...
                    kabsch(trial, orderedDestination);
                difference = trial * trialRotation - orderedDestination;
                trialRmsd = sqrt(mean(sum(difference.^2, 2)));
                if trialRmsd < rmsd
                    rmsd = trialRmsd;
                    bestOrder = order;
                    rotation = trialRotation;
                end
                if ~isempty(break_on_tol) && rmsd < break_on_tol, break; end
            end
            translation = destinationCenter - sourceCenter * rotation;
            inverseTargetOrder = zeros(size(targetOrder));
            inverseTargetOrder(targetOrder) = 1:numel(targetOrder);
            indices = bestOrder(inverseTargetOrder);
        end

        function [molecule, rmsd] = ...
                fit(obj, source, ignore_warning, break_on_tol)
            if nargin < 3, ignore_warning = false; end
            if nargin < 4, break_on_tol = []; end
            [indices, rotation, translation, rmsd] = ...
                obj.match(source, ignore_warning, break_on_tol);
            coordinates = source.cart_coords(indices, :) * rotation + ...
                translation;
            molecule = obj.moleculeFrom(source, indices, coordinates);
        end
    end

    methods (Static)
        function values = permutations(atoms)
            atoms = reshape(atoms, 1, []);
            elements = unique(atoms, "sorted");
            blocks = cell(1, numel(elements));
            for index = 1:numel(elements)
                members = find(atoms == elements(index));
                if numel(members) <= 1
                    blocks{index} = members;
                else
                    % MATLAB's PERMS order is the reverse of Python's
                    % itertools.permutations order used by pymatgen.
                    blocks{index} = flipud(perms(members));
                end
            end
            values = {zeros(1, 0)};
            for blockIndex = 1:numel(blocks)
                block = blocks{blockIndex};
                if isvector(block), block = reshape(block, 1, []); end
                combined = cell(1, numel(values) * size(block, 1));
                output = 0;
                for prefix = 1:numel(values)
                    for row = 1:size(block, 1)
                        output = output + 1;
                        combined{output} = [values{prefix}, block(row, :)];
                    end
                end
                values = combined;
            end
        end
    end
end
