function tf = is_coord_subset(subset, superset, atol)
%IS_COORD_SUBSET Test whether each coordinate has a match in a superset.
if nargin < 3, atol = 1e-8; end
subset = normalizeCoords(subset);
superset = normalizeCoords(superset);
if size(subset, 2) ~= size(superset, 2)
    error("KSSOLV:Matgenlab:Coord:DimensionMismatch", ...
        "Coordinate dimensions must agree.");
end
if isempty(subset), tf = true; return; end
if isempty(superset), tf = false; return; end
tol = reshape(double(atol), 1, []);
if isscalar(tol), tol = repmat(tol, 1, size(subset, 2)); end
tf = true;
for idx = 1:size(subset, 1)
    if ~any(all(abs(superset - subset(idx, :)) < tol, 2))
        tf = false;
        return
    end
end
end

function coords = normalizeCoords(coords)
coords = double(coords);
if isempty(coords)
    if isequal(size(coords), [0, 0]), coords = zeros(0, 3); end
elseif isvector(coords)
    coords = reshape(coords, 1, []);
end
end
