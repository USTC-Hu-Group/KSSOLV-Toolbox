function [fig,ax]=plot_path(line,lattice,coordsAreCartesian,ax,varargin)
%PLOT_PATH Draw a piecewise reciprocal-space path.
if nargin<2,lattice=[];end
if nargin<3||isempty(coordsAreCartesian),coordsAreCartesian=false;end
if nargin<4||isempty(ax),fig=figure("Visible","off");ax=axes(fig);view(ax,3);axis(ax,"equal");else,fig=ax.Parent;end
if ~coordsAreCartesian&&isempty(lattice),error("KSSOLV:Matgenlab:PlotPath:Lattice","Fractional coordinates require a lattice.");end
options=struct(color="r",linewidth=3);options=parseOptions(options,varargin);
line=double(line);if ~coordsAreCartesian,line=lattice.get_cartesian_coords(line);end
plot3(ax,line(:,1),line(:,2),line(:,3),"Color",options.color,"LineWidth",options.linewidth);
end
function output=parseOptions(output,input),names=fieldnames(output);ii=1;while ii<=numel(input),key=names{strcmpi(string(input{ii}),string(names))};output.(key)=input{ii+1};ii=ii+2;end,end
