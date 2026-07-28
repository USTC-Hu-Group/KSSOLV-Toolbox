function tf = in_coord_list(coord_list, coord, atol)
%IN_COORD_LIST Test whether a Cartesian coordinate occurs in a list.
if nargin < 3, atol = 1e-8; end
tf = ~isempty(kssolv.analysis.matgenlab.util.find_in_coord_list( ...
    coord_list, coord, atol));
end
