function reoriented=reorient_z(structure)
%REORIENT_Z Rotate a structure so its A-B plane normal is Cartesian z.
if ~isa(structure,"kssolv.analysis.matgenlab.core.IStructure")
    error("KSSOLV:Matgenlab:Adsorption:Structure", ...
        "structure must be a Structure or Slab.");
end
reoriented=structure.copy();
reoriented=reoriented.apply_operation( ...
    kssolv.analysis.matgenlab.core.get_rot(reoriented));
end
