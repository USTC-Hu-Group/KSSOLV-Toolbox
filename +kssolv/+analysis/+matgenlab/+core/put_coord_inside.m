function coordinate=put_coord_inside(lattice,cartCoordinate)
%PUT_COORD_INSIDE Wrap a Cartesian coordinate into its periodic unit cell.
if ~isa(lattice,"kssolv.analysis.matgenlab.core.Lattice")
    error("KSSOLV:Matgenlab:Adsorption:Lattice", ...
        "lattice must be a Lattice.");
end
wasVector=isvector(cartCoordinate);
fractional=lattice.get_fractional_coords(double(cartCoordinate));
periodic=reshape(logical(lattice.pbc),1,3);
fractional(:,periodic)=fractional(:,periodic)- ...
    floor(fractional(:,periodic));
coordinate=lattice.get_cartesian_coords(fractional);
if wasVector,coordinate=reshape(coordinate,1,3);end
end
