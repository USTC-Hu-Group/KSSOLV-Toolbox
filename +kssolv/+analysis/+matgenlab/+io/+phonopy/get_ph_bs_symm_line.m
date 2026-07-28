function bands=get_ph_bs_symm_line(path,hasNac,labelsDict)
%GET_PH_BS_SYMM_LINE Read a phonopy band.yaml file.
if nargin<2,hasNac=false;end
if nargin<3,labelsDict=[];end
data=kssolv.analysis.matgenlab.util.yaml_load(path);
bands=kssolv.analysis.matgenlab.io.phonopy. ...
    get_ph_bs_symm_line_from_dict(data,hasNac,labelsDict);
end
