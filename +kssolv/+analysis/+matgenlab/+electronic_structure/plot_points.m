function [fig,ax]=plot_points(points,lattice,coordsAreCartesian,fold,ax,varargin)
%PLOT_POINTS Draw reciprocal-space points, optionally folded into the BZ.
if nargin<2,lattice=[];end
if nargin<3||isempty(coordsAreCartesian),coordsAreCartesian=false;end
if nargin<4||isempty(fold),fold=false;end
if nargin<5||isempty(ax),fig=figure("Visible","off");ax=axes(fig);view(ax,3);axis(ax,"equal");else,fig=ax.Parent;end
if (~coordsAreCartesian||fold)&&isempty(lattice),error("KSSOLV:Matgenlab:PlotPoints:Lattice","Conversion or folding requires a lattice.");end
options=struct(color="b",size=36);options=parseOptions(options,varargin);points=double(points);
for ii=1:size(points,1)
    point=points(ii,:);
    if fold,point=kssolv.analysis.matgenlab.electronic_structure.fold_point(point,lattice,coordsAreCartesian);
    elseif ~coordsAreCartesian,point=lattice.get_cartesian_coords(point);end
    scatter3(ax,point(1),point(2),point(3),options.size,options.color,"filled");
end
end
function output=parseOptions(output,input),names=fieldnames(output);ii=1;while ii<=numel(input),key=names{strcmpi(string(input{ii}),string(names))};output.(key)=input{ii+1};ii=ii+2;end,end
