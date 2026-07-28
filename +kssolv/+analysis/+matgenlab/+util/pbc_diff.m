function difference = pbc_diff(frac_coords1, frac_coords2, pbc)
%PBC_DIFF Fractional displacement wrapped into the nearest periodic image.
if nargin < 3, pbc = [true, true, true]; end
pbc = logical(reshape(pbc, 1, []));
if numel(pbc) ~= 3
    error("KSSOLV:Matgenlab:Coord:InvalidPbc", ...
        "pbc must have three elements.");
end
difference = double(frac_coords1) - double(frac_coords2);
difference = difference - round(difference) .* double(pbc);
end
