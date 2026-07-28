function [fig,ax]=plot_lattice_vectors(lattice,ax,varargin)
%PLOT_LATTICE_VECTORS Draw the three lattice basis vectors.
if nargin<2||isempty(ax),fig=figure("Visible","off");ax=axes(fig);view(ax,3);axis(ax,"equal");else,fig=ax.Parent;end
options=struct(color="g",linewidth=3);options=parseOptions(options,varargin);
origin=lattice.get_cartesian_coords([0,0,0]);hold(ax,"on");
for vector=eye(3).'
    target=lattice.get_cartesian_coords(vector.');
    plot3(ax,[origin(1),target(1)],[origin(2),target(2)],[origin(3),target(3)], ...
        "Color",options.color,"LineWidth",options.linewidth);
end
end
function output=parseOptions(output,input),names=fieldnames(output);ii=1;while ii<=numel(input),key=names{strcmpi(string(input{ii}),string(names))};output.(key)=input{ii+1};ii=ii+2;end,end
