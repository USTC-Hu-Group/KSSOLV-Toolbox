function axesHandle=periodic_table_heatmap(elementalData,varargin)
%PERIODIC_TABLE_HEATMAP Draw element-valued cells in periodic-table layout.
if nargin<1||isempty(elementalData),elementalData=struct();end
options=struct("cbar_label","","cbar_label_size",14, ...
    "show_plot",false,"cmap","hot","cmap_range",[], ...
    "blank_color",[.5,.5,.5],"edge_color","white", ...
    "value_format","","value_fontsize",10,"symbol_fontsize",14, ...
    "max_row",9,"readable_fontcolor",false,"pymatviz",false);
options=parseOptions(options,varargin{:});
if options.max_row<=0
    error("KSSOLV:Matgenlab:Plotting:MaxRow", ...
        "The input argument max_row must be positive.");
end
maxRow=min(options.max_row,9);
[symbols,values]=mappingData(elementalData);
if isempty(values),values=0;end
if isempty(options.cmap_range),limits=[min(values),max(values)];
else,limits=double(options.cmap_range);end
if limits(1)==limits(2),limits=limits+[-.5,.5];end
figureHandle=figure("Visible","off","Position",[100,100,1200,800]);
axesHandle=axes(figureHandle);hold(axesHandle,"on");
colorMap=selectMap(options.cmap,256);
colormap(axesHandle,colorMap);clim(axesHandle,limits);
for atomicNumber=1:118
    element=kssolv.analysis.matgenlab.core.Element.fromZ(atomicNumber);
    [row,group]=plotPosition(element);
    if row>maxRow||isnan(group),continue,end
    match=find(symbols==element.symbol,1);
    if isempty(match),color=options.blank_color;value=NaN;
    else
        value=values(match);
        fraction=(value-limits(1))/(limits(2)-limits(1));
        colorIndex=1+round(max(0,min(1,fraction))*255);
        color=colorMap(colorIndex,:);
    end
    rectangle(axesHandle,"Position",[group-1,row-1,1,1], ...
        "FaceColor",color,"EdgeColor",options.edge_color);
    text(axesHandle,group-.5,row-.68,element.symbol, ...
        "HorizontalAlignment","center", ...
        "FontSize",options.symbol_fontsize);
    if ~isnan(value)&&strlength(string(options.value_format))>0
        label=sprintf(char(options.value_format),value);
        text(axesHandle,group-.5,row-.32,label, ...
            "HorizontalAlignment","center", ...
            "FontSize",options.value_fontsize);
    end
end
set(axesHandle,"YDir","reverse");axis(axesHandle,[0,18,0,maxRow]);
axis(axesHandle,"off");hold(axesHandle,"off");
colorbarHandle=colorbar(axesHandle);
colorbarHandle.Label.String=options.cbar_label;
colorbarHandle.Label.FontSize=options.cbar_label_size;
if options.show_plot,figureHandle.Visible="on";drawnow;end
end
function [symbols,values]=mappingData(data)
if isa(data,"containers.Map")
    symbols=string(keys(data));raw=data.values();
    values=cellfun(@double,raw);
elseif isstruct(data)
    names=fieldnames(data);symbols=string(names);
    values=cellfun(@(name)double(data.(name)),names);
else
    error("KSSOLV:Matgenlab:Plotting:ElementData", ...
        "elementalData must be a struct or containers.Map.");
end
values=reshape(values,1,[]);
end
function [row,group]=plotPosition(element)
if element.Z>=57&&element.Z<=71
    row=8;group=element.Z-54;
elseif element.Z>=89&&element.Z<=103
    row=9;group=element.Z-86;
else
    row=element.row;group=element.group;
end
end
function map=selectMap(name,count)
name=lower(string(name));
switch name
    case {"gray","grey"},map=gray(count);
    case {"parula","viridis"},map=parula(count);
    case {"jet","plasma"},map=jet(count);
    otherwise,map=hot(count);
end
end
function options=parseOptions(options,varargin)
names=fieldnames(options);
for index=1:2:numel(varargin)
    if index==numel(varargin),break,end
    match=find(strcmpi(string(varargin{index}),string(names)),1);
    if ~isempty(match),options.(names{match})=varargin{index+1};end
end
end
