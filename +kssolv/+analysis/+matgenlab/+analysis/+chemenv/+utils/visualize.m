function value=visualize(cg,varargin)
%VISUALIZE Display a model coordination geometry in MATLAB.
opts=parseNamed(struct(zoom=[],vis=[],factor=1,view_index=true, ...
    faces_color_override=[]),varargin{:});
coords=opts.factor*[cg.central_site;cg.points+cg.central_site];
if isempty(opts.vis),fig=figure("Visible","off");ax=axes(fig);
else,ax=opts.vis;end
hold(ax,"on");scatter3(ax,coords(1,1),coords(1,2),coords(1,3),60,"filled");
kssolv.analysis.matgenlab.analysis.chemenv.utils.draw_cg(ax,coords(1,:), ...
    num2cell(coords(2:end,:),2),"cg",cg, ...
    "faces_color_override",opts.faces_color_override);
if opts.view_index
    for ii=2:size(coords,1)
        text(ax,coords(ii,1),coords(ii,2),coords(ii,3),string(ii-2));
    end
end
if ~isempty(opts.zoom),camzoom(ax,opts.zoom);end
value=ax;
end
function opts=parseNamed(opts,varargin)
for ii=1:2:numel(varargin)
    opts.(char(string(varargin{ii})))=varargin{ii+1};
end
end
