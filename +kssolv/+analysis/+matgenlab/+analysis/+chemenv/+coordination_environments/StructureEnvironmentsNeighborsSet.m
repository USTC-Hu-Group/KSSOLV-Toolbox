%#ok<*ALIGN,*PROP>
classdef StructureEnvironmentsNeighborsSet < handle
    %STRUCTUREENVIRONMENTSNEIGHBORSSET One Voronoi-derived neighbor subset.
    properties
        structure
        isite (1,1) double
        detailed_voronoi
        voronoi cell={}
        site_voronoi_indices (1,:) double=[]
        sources cell={}
        local_planes=[]
        separations=[]
    end
    properties (Dependent)
        neighb_coords
        neighb_coordsOpt
        neighb_sites
        neighb_sites_and_indices
        coords
        normalized_distances
        normalized_angles
        distances
        angles
        info
        source
    end
    methods
        function obj=StructureEnvironmentsNeighborsSet( ...
                structure,isite,detailedVoronoi,siteVoronoiIndices,varargin)
            opts=parseOptions(struct(sources=[]),varargin{:});
            obj.structure=structure;obj.isite=double(isite);
            obj.detailed_voronoi=detailedVoronoi;
            obj.voronoi=detailedVoronoi.voronoi_list2{obj.isite};
            indices=sort(reshape(double(siteVoronoiIndices),1,[]));
            if numel(unique(indices))~=numel(indices)
                error("KSSOLV:Matgenlab:ChemEnv:DuplicateNeighbors", ...
                    "Neighbor set contains duplicate indices.");
            end
            obj.site_voronoi_indices=indices;
            if isempty(opts.sources),obj.sources={struct(origin="UNKNOWN")};
            elseif iscell(opts.sources),obj.sources=reshape(opts.sources,1,[]);
            elseif isstruct(opts.sources),obj.sources=num2cell(opts.sources(:)).';
            else,obj.sources={opts.sources};end
        end
        function value=get_neighb_voronoi_indices(obj,varargin)
            opts=parseOptions(struct(permutation=[]),varargin{:});
            perm=reshape(double(opts.permutation),1,[]);
            if any(perm==0),perm=perm+1;end
            value=obj.site_voronoi_indices(perm);
        end
        function value=get.neighb_coords(obj)
            value=cell2mat(cellfun(@(i)obj.voronoi{i}.site.coords, ...
                num2cell(obj.site_voronoi_indices), ...
                "UniformOutput",false).');
        end
        function value=get.neighb_coordsOpt(obj),value=obj.neighb_coords;end
        function value=get.neighb_sites(obj)
            value=cellfun(@(i)obj.voronoi{i}.site, ...
                num2cell(obj.site_voronoi_indices),"UniformOutput",false);
        end
        function value=get.neighb_sites_and_indices(obj)
            value=cell(1,numel(obj.site_voronoi_indices));
            for ii=1:numel(value)
                data=obj.voronoi{obj.site_voronoi_indices(ii)};
                value{ii}=struct(site=data.site,index=data.index);
            end
        end
        function value=get.coords(obj)
            value=[obj.structure.sites{obj.isite}.coords;obj.neighb_coords];
        end
        function value=get.normalized_distances(obj)
            value=fieldValues(obj,"normalized_distance");
        end
        function value=get.normalized_angles(obj)
            value=fieldValues(obj,"normalized_angle");
        end
        function value=get.distances(obj),value=fieldValues(obj,"distance");end
        function value=get.angles(obj),value=fieldValues(obj,"angle");end
        function value=get.info(obj)
            na=obj.normalized_angles;nd=obj.normalized_distances;
            aa=obj.angles;dd=obj.distances;
            value=struct(normalized_angles=na,normalized_distances=nd, ...
                normalized_angles_sum=sum(na), ...
                normalized_angles_mean=mean(na), ...
                normalized_angles_std=std(na,1), ...
                normalized_angles_min=min(na), ...
                normalized_angles_max=max(na), ...
                normalized_distances_mean=mean(nd), ...
                normalized_distances_std=std(nd,1), ...
                normalized_distances_min=min(nd), ...
                normalized_distances_max=max(nd),angles=aa,distances=dd, ...
                angles_sum=sum(aa),angles_mean=mean(aa), ...
                angles_std=std(aa,1),angles_min=min(aa),angles_max=max(aa), ...
                distances_mean=mean(dd),distances_std=std(dd,1), ...
                distances_min=min(dd),distances_max=max(dd));
        end
        function value=distance_plateau(obj)
            allValues=sort(cellfun(@(x)x.normalized_distance,obj.voronoi), ...
                "descend");maximum=max(obj.normalized_distances);
            index=find(abs(allValues-maximum)<= ...
                obj.detailed_voronoi.normalized_distance_tolerance,1);
            if isempty(index),error("KSSOLV:Matgenlab:Plateau", ...
                    "Distance plateau not found.");end
            if index==1,value=Inf;else,value=allValues(index-1)-maximum;end
        end
        function value=angle_plateau(obj)
            allValues=sort(cellfun(@(x)x.normalized_angle,obj.voronoi));
            minimum=min(obj.normalized_angles);
            index=find(abs(allValues-minimum)<= ...
                obj.detailed_voronoi.normalized_angle_tolerance,1);
            if isempty(index),error("KSSOLV:Matgenlab:Plateau", ...
                    "Angle plateau not found.");end
            if index==1,value=minimum;else,value=minimum-allValues(index-1);end
        end
        function value=voronoi_grid_surface_points(obj,varargin)
            opts=parseOptions(struct(additional_condition=1, ...
                other_origins="DO_NOTHING"),varargin{:});
            selected={};
            for ii=1:numel(obj.sources)
                source=obj.sources{ii};
                if string(source.origin)=="dist_ang_ac_voronoi"&& ...
                        source.ac==opts.additional_condition
                    selected{end+1}=source; %#ok<AGROW>
                elseif string(source.origin)~="dist_ang_ac_voronoi"&& ...
                        string(opts.other_origins)~="DO_NOTHING"
                    error("KSSOLV:Matgenlab:NotImplemented", ...
                        "Non-Voronoi sources are not implemented.");
                end
            end
            if isempty(selected),value=[];return,end
            rectangles=zeros(numel(selected),4);
            for ii=1:numel(selected)
                rectangles(ii,:)=[selected{ii}.dp_dict.min, ...
                    selected{ii}.dp_dict.next,selected{ii}.ap_dict.max, ...
                    selected{ii}.ap_dict.next];
            end
            xs=unique(rectangles(:,1:2));ys=unique(rectangles(:,3:4));
            edges=zeros(numel(xs)*numel(ys),1);
            for ii=1:size(rectangles,1)
                corners=[findClose(xs,rectangles(ii,1)), ...
                    findClose(ys,rectangles(ii,3)); ...
                    findClose(xs,rectangles(ii,1)), ...
                    findClose(ys,rectangles(ii,4)); ...
                    findClose(xs,rectangles(ii,2)), ...
                    findClose(ys,rectangles(ii,3)); ...
                    findClose(xs,rectangles(ii,2)), ...
                    findClose(ys,rectangles(ii,4))];
                for jj=1:4
                    linear=sub2ind([numel(xs),numel(ys)], ...
                        corners(jj,1),corners(jj,2));
                    edges(linear)=edges(linear)+1;
                end
            end
            [ix,iy]=ind2sub([numel(xs),numel(ys)],find(mod(edges,2)==1));
            points=[ix,iy];ordered=points(1,:);points(1,:)=[];
            moveY=true;
            while ~isempty(points)
                if moveY,match=find(points(:,1)==ordered(end,1),1);
                else,match=find(points(:,2)==ordered(end,2),1);end
                if isempty(match),break,end
                ordered(end+1,:)=points(match,:); %#ok<AGROW>
                points(match,:)=[];moveY=~moveY;
            end
            value=[xs(ordered(:,1)),ys(ordered(:,2))];
        end
        function value=get.source(obj)
            if numel(obj.sources)~=1,error("KSSOLV:Matgenlab:Source", ...
                    "Number of sources differs from one.");end
            value=obj.sources{1};
        end
        function add_source(obj,source)
            if ~any(cellfun(@(x)isequaln(x,source),obj.sources))
                obj.sources{end+1}=source;
            end
        end
        function value=length(obj),value=numel(obj.site_voronoi_indices);end
        function value=char(obj)
            value=sprintf(['Neighbors Set for site #%d :\n' ...
                ' - Coordination number : %d\n - Voronoi indices : %s\n'], ...
                obj.isite,numel(obj.site_voronoi_indices), ...
                strjoin(string(obj.site_voronoi_indices),", "));
        end
        function value=string(obj),value=string(char(obj));end
        function value=as_dict(obj)
            value=struct(isite=obj.isite-1, ...
                site_voronoi_indices=obj.site_voronoi_indices-1, ...
                sources={obj.sources});
        end
    end
    methods (Static)
        function obj=from_dict(value,structure,detailedVoronoi)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.StructureEnvironmentsNeighborsSet( ...
                structure,double(value.isite)+1,detailedVoronoi, ...
                reshape(double(value.site_voronoi_indices),1,[])+1, ...
                "sources",value.sources);
        end
    end
end
function value=fieldValues(obj,name)
value=cellfun(@(i)obj.voronoi{i}.(name), ...
    num2cell(obj.site_voronoi_indices));
end
function opts=parseOptions(opts,varargin)
names=fieldnames(opts);pos=1;
while pos<=numel(varargin)&&~(ischar(varargin{pos})||isstring(varargin{pos}))
    opts.(names{pos})=varargin{pos};pos=pos+1;
end
for ii=pos:2:numel(varargin),opts.(char(string(varargin{ii})))=varargin{ii+1};end
end
function index=findClose(values,target)
index=find(abs(values-target)<=1e-10,1);
end
