function indices = coord_list_mapping(subset, superset, atol)
%COORD_LIST_MAPPING Map unique Cartesian subset rows into a superset.
% Returned indices follow MATLAB's one-based indexing.
if nargin < 3, atol = 1e-8; end
subset = normalizeCoords(subset);
superset = normalizeCoords(superset);
if size(subset, 2) ~= size(superset, 2)
    error("KSSOLV:Matgenlab:Coord:DimensionMismatch", ...
        "Coordinate dimensions must agree.");
end
tol = reshape(double(atol), 1, []);
if isscalar(tol), tol = repmat(tol, 1, size(subset, 2)); end
indices = zeros(size(subset, 1), 1);
for row = 1:size(subset, 1)
    % numpy.isclose uses atol + rtol*abs(reference), with rtol=1e-5.
    close = all(abs(superset - subset(row, :)) <= ...
        tol + 1e-5 * abs(superset), 2);
    matches = find(close);
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

function coords = normalizeCoords(coords)
coords = double(coords);
if isempty(coords)
    if isequal(size(coords), [0, 0]), coords = zeros(0, 3); end
elseif isvector(coords)
    coords = reshape(coords, 1, []);
end
end
