function result=get_gruneisen_ph_bs_symm_line( ...
        path,structure,structurePath,labelsDict,fit)
%GET_GRUNEISEN_PH_BS_SYMM_LINE Read a Gruneisen band YAML.
if nargin<2,structure=[];end
if nargin<3,structurePath=[];end
if nargin<4,labelsDict=[];end
if nargin<5,fit=false;end
data=kssolv.analysis.matgenlab.util.yaml_load(path);
result=kssolv.analysis.matgenlab.io.phonopy. ...
    get_gs_ph_bs_symm_line_from_dict( ...
    data,structure,structurePath,labelsDict,fit);
end
