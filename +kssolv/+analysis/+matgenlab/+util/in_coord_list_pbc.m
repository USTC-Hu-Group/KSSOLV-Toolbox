function tf = in_coord_list_pbc(fcoord_list, fcoord, atol, pbc)
%IN_COORD_LIST_PBC Test for a fractional-coordinate match under periodicity.
if nargin < 3, atol = 1e-8; end
if nargin < 4, pbc = [true, true, true]; end
tf = ~isempty(kssolv.analysis.matgenlab.util.find_in_coord_list_pbc( ...
    fcoord_list, fcoord, atol, pbc));
end
