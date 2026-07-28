function indices = find_in_coord_list(coord_list, coord, atol)
%FIND_IN_COORD_LIST Find matching Cartesian coordinates (MATLAB indices).
% Compatible with pymatgen.util.coord.find_in_coord_list.
if nargin < 3, atol = 1e-8; end
if isempty(coord_list)
    indices = zeros(0, 1);
    return
end
coords = double(coord_list);
coord = reshape(double(coord), 1, []);
if size(coords, 2) ~= numel(coord)
    error("KSSOLV:Matgenlab:Coord:DimensionMismatch", ...
        "Coordinate dimensions must agree.");
end
tol = reshape(double(atol), 1, []);
if isscalar(tol), tol = repmat(tol, 1, size(coords, 2)); end
if numel(tol) ~= size(coords, 2)
    error("KSSOLV:Matgenlab:Coord:InvalidTolerance", ...
        "atol must be scalar or have one value per coordinate dimension.");
end
indices = find(all(abs(coords - coord) < tol, 2));
end
