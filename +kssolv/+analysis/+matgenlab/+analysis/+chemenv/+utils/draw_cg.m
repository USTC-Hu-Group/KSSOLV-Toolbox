%#ok<*ALIGN>
function value=draw_cg(vis,site,neighbors,varargin)
%DRAW_CG Draw a coordination geometry using a visualizer or MATLAB axes.
opts=parseNamed(struct(cg=[],perm=[],perfect2local_map=[], ...
    show_perfect=false,csm_info=[], ...
    symmetry_measure_type="csm_wcs_ctwcc",perfect_radius=.1, ...
    show_distorted=true,faces_color_override=[]),varargin{:});
if ~isempty(opts.perm)&&~isempty(opts.perfect2local_map)
    error("KSSOLV:Matgenlab:ChemEnv:Permutation", ...
        "Provide perm or perfect2local_map, not both.");
end
coords=siteCoords(neighbors);center=siteCoords({site});
if isempty(vis)||isgraphics(vis)
    if isempty(vis),fig=figure("Visible","off");ax=axes(fig);
    elseif isa(vis,"matlab.graphics.axis.Axes"),ax=vis;
    else,ax=axes(vis);end
    hold(ax,"on");
    if opts.show_distorted
        scatter3(ax,coords(:,1),coords(:,2),coords(:,3),30,"filled");
        for ii=1:size(coords,1)
            plot3(ax,[center(1) coords(ii,1)], ...
                [center(2) coords(ii,2)],[center(3) coords(ii,3)],"k-");
        end
    end
    if ~isempty(opts.cg)&&size(coords,1)>=3&&opts.show_distorted
        faces=opts.cg.faces(coords,"permutation",opts.perm);
        color=[.3 .6 .9];if ~isempty(opts.faces_color_override)
            color=opts.faces_color_override;end
        for ii=1:numel(faces)
            patch(ax,"Vertices",faces{ii},"Faces",1:size(faces{ii},1), ...
                "FaceColor",color,"FaceAlpha",.25);
        end
    end
    axis(ax,"equal");value=ax;
else
    if opts.show_distorted
        vis.add_bonds(neighbors,site);
        for ii=1:numel(neighbors),vis.add_site(neighbors{ii});end
    end
    value=vis;
end
if opts.show_perfect&&isempty(opts.csm_info)
    error("KSSOLV:Matgenlab:ChemEnv:PerfectGeometry", ...
        "csm_info is required to draw the perfect geometry.");
end
end
function value=siteCoords(sites)
if ~iscell(sites),sites=num2cell(sites);end
value=zeros(numel(sites),3);
for ii=1:numel(sites)
    if isnumeric(sites{ii}),value(ii,:)=sites{ii};
    else,value(ii,:)=sites{ii}.coords;end
end
end
function opts=parseNamed(opts,varargin)
for ii=1:2:numel(varargin)
    opts.(char(string(varargin{ii})))=varargin{ii+1};
end
end
