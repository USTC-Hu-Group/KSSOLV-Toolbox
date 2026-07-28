function [directGap,indirectGap]=get_dir_indir_gap(run)
%GET_DIR_INDIR_GAP Direct and fundamental gaps from vasprun.xml.
if nargin<1,run="";end
vasprun=kssolv.analysis.matgenlab.io.vasp.Vasprun(run);
bands=vasprun.get_band_structure();
directGap=bands.get_direct_band_gap();
gap=bands.get_band_gap();
indirectGap=gap.energy;
end
