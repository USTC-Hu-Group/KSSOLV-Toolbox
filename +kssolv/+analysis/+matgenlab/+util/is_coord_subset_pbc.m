function tf = is_coord_subset_pbc(subset, superset, atol, mask, pbc)
%IS_COORD_SUBSET_PBC Test fractional-coordinate subset membership.
if nargin < 3, atol = 1e-8; end
if nargin < 4 || isempty(mask)
    mask = false(size(subset, 1), size(superset, 1));
end
if nargin < 5, pbc = [true, true, true]; end
subset = normalizeFracCoords(subset);
superset = normalizeFracCoords(superset);
mask = logical(mask);
if ~isequal(size(mask), [size(subset, 1), size(superset, 1)])
    error("KSSOLV:Matgenlab:Coord:InvalidMask", ...
        "mask must have size subset-by-superset.");
end
tol = reshape(double(atol), 1, []);
if isscalar(tol), tol = repmat(tol, 1, 3); end
pbc = logical(reshape(pbc, 1, 3));
tf = true;
for row = 1:size(subset, 1)
    delta = subset(row, :) - superset;
    delta(:, pbc) = delta(:, pbc) - round(delta(:, pbc));
    allowedMatch = all(abs(delta) <= tol, 2) & ~mask(row, :).';
    if ~any(allowedMatch)
        tf = false;
        return
    end
end
end

function coords = normalizeFracCoords(coords)
coords = double(coords);
if isempty(coords), coords = zeros(0, 3);
elseif isvector(coords) && numel(coords) == 3, coords = reshape(coords, 1, 3);
elseif ~ismatrix(coords) || size(coords, 2) ~= 3
    error("KSSOLV:Matgenlab:Coord:InvalidCoordinates", ...
        "Fractional coordinates must be N-by-3.");
end
end
