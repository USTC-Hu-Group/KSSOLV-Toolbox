function [fig,ax]=plot_wigner_seitz(lattice,ax,varargin)
%PLOT_WIGNER_SEITZ Draw unique Wigner-Seitz cell edges.
if nargin<2||isempty(ax),[fig,ax]=axes3d();else,fig=ax.Parent;end
options=struct(color="k",linewidth=1);options=parseOptions(options,varargin);
facets=lattice.get_wigner_seitz_cell();edges=zeros(0,6);
for ii=1:numel(facets)
    face=double(facets{ii});
    for aa=1:size(face,1)
        bb=mod(aa,size(face,1))+1;
        pair=sortrows(face([aa,bb],:));
        edges(end+1,:)=[pair(1,:),pair(2,:)]; %#ok<AGROW>
    end
end
edges=unique(round(edges,12),"rows");hold(ax,"on");
for ii=1:size(edges,1),plot3(ax,edges(ii,[1,4]),edges(ii,[2,5]),edges(ii,[3,6]), ...
        "Color",options.color,"LineWidth",options.linewidth);end
end
function [fig,ax]=axes3d(),fig=figure("Visible","off");ax=axes(fig);view(ax,3);axis(ax,"equal");end
function output=parseOptions(output,input),names=fieldnames(output);ii=1;while ii<=numel(input),key=names{strcmpi(string(input{ii}),string(names))};output.(key)=input{ii+1};ii=ii+2;end,end
