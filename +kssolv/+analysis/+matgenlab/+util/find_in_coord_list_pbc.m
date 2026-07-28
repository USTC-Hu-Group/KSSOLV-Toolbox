function indices = find_in_coord_list_pbc(frac_coord_list, frac_coord, atol, pbc)
%FIND_IN_COORD_LIST_PBC Find fractional-coordinate matches under periodicity.
% Returned indices follow MATLAB's one-based indexing.
if nargin < 3, atol = 1e-8; end
if nargin < 4, pbc = [true, true, true]; end
if isempty(frac_coord_list)
    indices = zeros(0, 1);
    return
end
coords = double(frac_coord_list);
if isvector(coords), coords = reshape(coords, 1, 3); end
coord = reshape(double(frac_coord), 1, 3);
pbc = logical(reshape(pbc, 1, 3));
tol = reshape(double(atol), 1, []);
if isscalar(tol), tol = repmat(tol, 1, 3); end
delta = coords - coord;
delta(:, pbc) = delta(:, pbc) - round(delta(:, pbc));
indices = find(all(abs(delta) < tol, 2));
end
