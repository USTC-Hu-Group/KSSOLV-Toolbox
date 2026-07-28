function neighbors = find_neighbors(label, nx, ny, nz)
%FIND_NEIGHBORS Return in-bound neighboring cube indices.
label = double(label);
if isvector(label), label = reshape(label, [], 1); end
if size(label, 2) == 1
    linear = label(:, 1);
    first = floor(linear / (ny * nz));
    remainder = mod(linear, ny * nz);
    second = floor(remainder / nz);
    third = mod(remainder, nz);
    label = [first, second, third];
elseif size(label, 2) ~= 3
    error("KSSOLV:Matgenlab:Lattice:CubeLabels", ...
        "label must have shape N-by-1 or N-by-3.");
end
offsets = zeros(27, 3);
counter = 0;
for first = -1:1
    for second = -1:1
        for third = -1:1
            counter = counter + 1;
            offsets(counter, :) = [first, second, third];
        end
    end
end
neighbors = cell(size(label, 1), 1);
for index = 1:size(label, 1)
    values = label(index, :) - offsets;
    keep = values(:, 1) >= 0 & values(:, 1) < nx & ...
        values(:, 2) >= 0 & values(:, 2) < ny & ...
        values(:, 3) >= 0 & values(:, 3) < nz;
    neighbors{index} = values(keep, :);
end
end
