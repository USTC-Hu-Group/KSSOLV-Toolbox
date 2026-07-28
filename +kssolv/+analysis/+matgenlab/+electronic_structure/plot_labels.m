function [fig,ax]=plot_labels(labels,lattice,coordsAreCartesian,ax,varargin)
%PLOT_LABELS Annotate reciprocal-space coordinates.
if nargin<2,lattice=[];end
if nargin<3||isempty(coordsAreCartesian),coordsAreCartesian=false;end
if nargin<4||isempty(ax),fig=figure("Visible","off");ax=axes(fig);view(ax,3);axis(ax,"equal");else,fig=ax.Parent;end
if ~coordsAreCartesian&&isempty(lattice),error("KSSOLV:Matgenlab:PlotLabels:Lattice","Fractional coordinates require a lattice.");end
options=struct(color="b",size=25);options=parseOptions(options,varargin);
source=asMap(labels);keys=source.keys;hold(ax,"on");
for ii=1:numel(keys)
    point=reshape(double(source(keys{ii})),1,3);if ~coordsAreCartesian,point=lattice.get_cartesian_coords(point);end
    text(ax,point(1)+.01,point(2)+.01,point(3)+.01,keys{ii}, ...
        "Color",options.color,"FontSize",options.size);
end
end
function value=asMap(input),if isa(input,"containers.Map"),value=input;else,value=containers.Map("KeyType","char","ValueType","any");names=fieldnames(input);for ii=1:numel(names),value(names{ii})=input.(names{ii});end,end,end
function output=parseOptions(output,input),names=fieldnames(output);ii=1;while ii<=numel(input),key=names{strcmpi(string(input{ii}),string(names))};output.(key)=input{ii+1};ii=ii+2;end,end
