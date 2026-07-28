function distances = all_distances(coords1, coords2)
%ALL_DISTANCES Pairwise Euclidean distances between Cartesian coordinates.
coords1 = double(coords1);
coords2 = double(coords2);
if isvector(coords1) && ~isempty(coords1), coords1 = reshape(coords1, 1, []); end
if isvector(coords2) && ~isempty(coords2), coords2 = reshape(coords2, 1, []); end
if size(coords1, 2) ~= size(coords2, 2)
    error("KSSOLV:Matgenlab:Coord:DimensionMismatch", ...
        "Coordinate dimensions must agree.");
end
distances = zeros(size(coords1, 1), size(coords2, 1));
for idx = 1:size(coords1, 1)
    distances(idx, :) = vecnorm(coords2 - coords1(idx, :), 2, 2).';
end
end
