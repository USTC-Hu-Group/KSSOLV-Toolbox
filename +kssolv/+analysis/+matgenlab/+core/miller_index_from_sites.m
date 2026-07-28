function index=miller_index_from_sites(lattice,coords,varargin)
%MILLER_INDEX_FROM_SITES Fit the integer Miller plane through coordinates.
options=struct("coords_are_cartesian",true,"round_dp",4,"verbose",true);
for position=1:2:numel(varargin)
    options.(char(string(varargin{position})))=varargin{position+1};
end
if ~isa(lattice,"kssolv.analysis.matgenlab.core.Lattice")
    lattice=kssolv.analysis.matgenlab.core.Lattice(lattice);
end
index=lattice.get_miller_index_from_coords(coords, ...
    options.coords_are_cartesian,options.round_dp,options.verbose);
end
