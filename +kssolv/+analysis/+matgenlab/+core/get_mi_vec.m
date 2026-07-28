function vector=get_mi_vec(slab)
%GET_MI_VEC Return the unit normal to the first two slab lattice vectors.
if ~isa(slab,"kssolv.analysis.matgenlab.core.IStructure")
    error("KSSOLV:Matgenlab:Adsorption:Structure", ...
        "slab must be a Structure or Slab.");
end
vector=cross(slab.lattice.matrix(1,:),slab.lattice.matrix(2,:));
magnitude=norm(vector);
if magnitude<=eps(max(1,norm(slab.lattice.matrix,"fro")))
    error("KSSOLV:Matgenlab:Adsorption:SurfaceNormal", ...
        "The first two lattice vectors do not define a surface plane.");
end
vector=vector/magnitude;
end
