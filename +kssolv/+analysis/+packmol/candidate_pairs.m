function pairs = candidate_pairs(coordinates, cutoff, pbcMinimum, pbcMaximum)
%CANDIDATE_PAIRS Build Packmol-style linked-cell candidate atom pairs.

n = size(coordinates, 1);
if n < 2
    pairs = zeros(0, 2);
    return
end
usingPbc = nargin >= 4 && ~isempty(pbcMinimum);
if usingPbc
    minimum = pbcMinimum;
    maximum = pbcMaximum;
    lengthBox = maximum - minimum;
    work = kssolv.analysis.packmol.v_in_box( ...
        coordinates, minimum, lengthBox);
else
    minimum = min(coordinates, [], 1) - cutoff;
    maximum = max(coordinates, [], 1) + cutoff;
    lengthBox = max(maximum - minimum, cutoff);
    work = coordinates;
end
requestedSide = max(1.01 * cutoff, eps);
cellCount = max(1, floor(lengthBox / requestedSide));
cellLength = lengthBox ./ cellCount;
subscripts = floor((work - minimum) ./ cellLength) + 1;
subscripts = min(max(subscripts, 1), cellCount);
linear = sub2ind(cellCount, ...
    subscripts(:, 1), subscripts(:, 2), subscripts(:, 3));
members = accumarray(linear, (1:n).', [prod(cellCount), 1], ...
    @(values) {values}, {zeros(0, 1)});
occupied = find(~cellfun(@isempty, members));
blocks = cell(0, 1);
for occupiedIndex = 1:numel(occupied)
    firstCell = occupied(occupiedIndex);
    [cx, cy, cz] = ind2sub(cellCount, firstCell);
    firstAtoms = members{firstCell};
    for dx = -1:1
        for dy = -1:1
            for dz = -1:1
                neighbor = [cx + dx, cy + dy, cz + dz];
                if usingPbc
                    neighbor = mod(neighbor - 1, cellCount) + 1;
                elseif any(neighbor < 1 | neighbor > cellCount)
                    continue
                end
                secondCell = sub2ind(cellCount, ...
                    neighbor(1), neighbor(2), neighbor(3));
                secondAtoms = members{secondCell};
                if isempty(secondAtoms)
                    continue
                end
                [firstGrid, secondGrid] = ndgrid(firstAtoms, secondAtoms);
                block = sort([firstGrid(:), secondGrid(:)], 2);
                block(block(:, 1) == block(:, 2), :) = [];
                if ~isempty(block)
                    blocks{end + 1, 1} = block; %#ok<AGROW>
                end
            end
        end
    end
end
if isempty(blocks)
    pairs = zeros(0, 2);
else
    pairs = unique(vertcat(blocks{:}), "rows");
end
end
