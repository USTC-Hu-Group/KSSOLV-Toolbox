function [qpoints,labels]=phonopy_high_symm_path(structure,lineDensity)
%PHONOPY_HIGH_SYMM_PATH Generate a Setyawan-Curtarolo style path.
if nargin<2||isempty(lineDensity),lineDensity=20;end
path=kssolv.analysis.matgenlab.symmetry.HighSymmKpath(structure);
[qpoints,labels]=path.get_kpoints(lineDensity,false);
end
