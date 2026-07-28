function indices = coord_list_mapping_pbc(subset, superset, atol, pbc)
%COORD_LIST_MAPPING_PBC Map fractional subset rows under periodicity.
% Returned indices follow MATLAB's one-based indexing.
if nargin < 3, atol = 1e-8; end
if nargin < 4, pbc = [true, true, true]; end
subset = normalizeFracCoords(subset);
superset = normalizeFracCoords(superset);
tol = normalizeTolerance(atol);
pbc = normalizePbc(pbc);
indices = zeros(size(subset, 1), 1);
for row = 1:size(subset, 1)
    delta = subset(row, :) - superset;
    delta(:, pbc) = delta(:, pbc) - round(delta(:, pbc));
    matches = find(all(abs(delta) <= tol, 2));
    if isempty(matches)
        error("KSSOLV:Matgenlab:Coord:NotSubset", ...
            "not a subset of superset");
    end
    if numel(matches) ~= 1
        error("KSSOLV:Matgenlab:Coord:DuplicateSuperset", ...
            "Something wrong with the inputs, likely duplicates in superset");
    end
    indices(row) = matches;
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

function tol = normalizeTolerance(atol)
tol = reshape(double(atol), 1, []);
if isscalar(tol), tol = repmat(tol, 1, 3); end
if numel(tol) ~= 3 || any(tol < 0)
    error("KSSOLV:Matgenlab:Coord:InvalidTolerance", ...
        "atol must be nonnegative scalar or three-element vector.");
end
end

function pbc = normalizePbc(pbc)
pbc = logical(reshape(pbc, 1, []));
if numel(pbc) ~= 3
    error("KSSOLV:Matgenlab:Coord:InvalidPbc", ...
        "pbc must have three elements.");
end
end
