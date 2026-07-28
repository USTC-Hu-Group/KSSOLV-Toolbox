function structure=fix_pbc(structure,matrix)
%FIX_PBC Rebuild a structure with deterministic [0,1) representatives.
if nargin<2||isempty(matrix),matrix=structure.lattice.matrix;end
coordinates=mod(structure.frac_coords,1);
nearBoundary=abs(coordinates)<1e-8|abs(coordinates-1)<1e-8;
coordinates(nearBoundary)=0;
coordinates=round(coordinates,7);
structure=kssolv.analysis.matgenlab.core.Structure( ...
    kssolv.analysis.matgenlab.core.Lattice(matrix), ...
    structure.species_and_occu,coordinates, ...
    site_properties=structure.site_properties);
end
