function [energies,absorption,directGap,indirectGap]=optics(path)
%OPTICS Extract VASP absorption and electronic gaps.
if nargin<1,path="";end
[directGap,indirectGap]= ...
    kssolv.analysis.matgenlab.analysis.solar.get_dir_indir_gap(path);
run=kssolv.analysis.matgenlab.io.vasp.Vasprun(path);
[energies,absorption]= ...
    kssolv.analysis.matgenlab.analysis.solar. ...
    absorption_coefficient(run.dielectric);
end
