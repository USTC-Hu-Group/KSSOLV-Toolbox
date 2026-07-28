function ax=plot_brillouin_zone_from_kpath(kpath,ax,varargin)
%PLOT_BRILLOUIN_ZONE_FROM_KPATH Plot the paths and labels of a HighSymmKpath.
if nargin<2,ax=[];end
data=kpath.kpath;points=getMember(data,"kpoints");paths=getMember(data,"path");
map=asMap(points);paths=asCell(paths);lines=cell(size(paths));
for ii=1:numel(paths)
    names=cellstr(string(paths{ii}));lines{ii}=cell2mat(cellfun(@(k)reshape(map(k),1,3),names,"UniformOutput",false).');
end
fig=kssolv.analysis.matgenlab.electronic_structure.plot_brillouin_zone( ...
    kpath.prim_rec,"lines",lines,"labels",map,"ax",ax,varargin{:});
ax=findobj(fig,"Type","axes");
end
function value=getMember(input,name),value=input.(name);end
function value=asMap(input),if isa(input,"containers.Map"),value=input;else,value=containers.Map("KeyType","char","ValueType","any");names=fieldnames(input);for ii=1:numel(names),value(names{ii})=input.(names{ii});end,end,end
function value=asCell(input),if iscell(input),value=input;else,value=num2cell(input);end,end
