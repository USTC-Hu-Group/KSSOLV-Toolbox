function [fig,ax]=plot_wigner_seitz(lattice,ax,varargin)
%PLOT_WIGNER_SEITZ Draw unique Wigner-Seitz cell edges.
if nargin<2||isempty(ax),[fig,ax]=axes3d();else,fig=ax.Parent;end
options=struct(color="k",linewidth=1);options=parseOptions(options,varargin);
facets=lattice.get_wigner_seitz_cell();edges=zeros(0,6);
for ii=1:numel(facets)
    face=double(facets{ii});
    for aa=1:size(face,1)
        for bb=aa+1:size(face,1)
            pair=[face(aa,:),face(bb,:)];shared=0;
            for jj=1:numel(facets)
                other=double(facets{jj});
                if any(all(abs(other-pair(1,1:3))<1e-10,2))&& ...
                        any(all(abs(other-pair(1,4:6))<1e-10,2))
                    shared=shared+1;
                end
            end
            if shared>=2,edges(end+1,:)=pair;end %#ok<AGROW>
        end
    end
end
edges=unique(round(edges,12),"rows");hold(ax,"on");
for ii=1:size(edges,1),plot3(ax,edges(ii,[1,4]),edges(ii,[2,5]),edges(ii,[3,6]), ...
        "Color",options.color,"LineWidth",options.linewidth);end
end
function [fig,ax]=axes3d(),fig=figure("Visible","off");ax=axes(fig);view(ax,3);axis(ax,"equal");end
function output=parseOptions(output,input),names=fieldnames(output);ii=1;while ii<=numel(input),key=names{strcmpi(string(input{ii}),string(names))};output.(key)=input{ii+1};ii=ii+2;end,end
