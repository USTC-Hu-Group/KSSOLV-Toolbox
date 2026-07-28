classdef VoronoiNN < kssolv.analysis.matgenlab.core.NearNeighbors
    %#ok<*ALIGN,*AGROW>
    %VORONOINN Voronoi-facet near-neighbor strategy.
    properties
        tol (1,1) double=0
        targets=[]
        cutoff (1,1) double=13
        allow_pathological (1,1) logical=false
        weight (1,1) string="solid_angle"
        extra_nn_info (1,1) logical=true
        compute_adj_neighbors (1,1) logical=true
    end
    methods
        function obj=VoronoiNN(varargin)
            obj.structures_allowed=true;obj.molecules_allowed=false;
            options=struct(tol=0,targets=[],cutoff=13,allow_pathological=false, ...
                weight="solid_angle",extra_nn_info=true,compute_adj_neighbors=true);
            options=parse(options,varargin);
            names=fieldnames(options);
            for ii=1:numel(names),obj.(names{ii})=options.(names{ii});end
        end
        function poly=get_voronoi_polyhedra(obj,structure,n)
            center=structure(n);
            neighbors=structure.get_sites_in_sphere(center.coords,obj.cutoff);
            if numel(neighbors)<5
                error("KSSOLV:Matgenlab:VoronoiNN:Cutoff", ...
                    "Insufficient sites for a three-dimensional Voronoi tessellation.");
            end
            distances=cellfun(@(item)item.nn_distance,neighbors);
            central=find(distances<1e-8 & ...
                cellfun(@(item)item.index==n,neighbors),1);
            if isempty(central),error("KSSOLV:Matgenlab:VoronoiNN:Center", ...
                    "Central site was not found in tessellation.");end
            coordinates=cell2mat(cellfun(@(item)item.coords,neighbors, ...
                "UniformOutput",false).');
            try
                [vertices,cells]=voronoin(coordinates);
            catch exception
                wrapped=MException("KSSOLV:Matgenlab:VoronoiNN:Tessellation", ...
                    "Voronoi tessellation failed; increase cutoff.");
                throw(addCause(wrapped,exception));
            end
            centralVertices=cells{central};
            poly={};facetVertices={};
            for jj=1:numel(neighbors)
                if jj==central,continue,end
                shared=intersect(centralVertices,cells{jj},"stable");
                infinite=any(shared==1);
                shared(shared==1)=[];
                if numel(shared)<3
                    if infinite&&~obj.allow_pathological
                        error("KSSOLV:Matgenlab:VoronoiNN:Pathological", ...
                            "Infinite vertex in Voronoi construction.");
                    end
                    continue
                end
                face=vertices(shared,:);
                [face,shared]=orderedFace(face,shared, ...
                    neighbors{jj}.coords-center.coords);
                angle=kssolv.analysis.matgenlab.core.solid_angle(center.coords,face);
                faceDistance=norm(center.coords-neighbors{jj}.coords)/2;
                area=polygonArea(face,neighbors{jj}.coords-center.coords);
                volume=area*faceDistance/3;
                normal=(neighbors{jj}.coords-center.coords);
                normal=normal/norm(normal);
                stats=struct(site=neighbors{jj},normal=normal, ...
                    solid_angle=angle,volume=volume,face_dist=faceDistance, ...
                    area=area,n_verts=size(face,1),verts=shared, ...
                    adj_neighbors=[]);
                if obj.inTargets(neighbors{jj}),poly{end+1}=stats;
                    facetVertices{end+1}=shared;
                end
            end
            if isempty(poly)
                error("KSSOLV:Matgenlab:VoronoiNN:NoNeighbors", ...
                    "No Voronoi neighbors found; increase cutoff.");
            end
            if obj.compute_adj_neighbors
                for ii=1:numel(poly)
                    adjacent=[];
                    for jj=1:numel(poly)
                        if ii~=jj&&numel(intersect( ...
                                facetVertices{ii},facetVertices{jj}))==2
                            adjacent(end+1)=jj;
                        end
                    end
                    poly{ii}.adj_neighbors=adjacent;
                end
            end
            function [ordered,orderedIds]=orderedFace(face,ids,normal)
                centroid=mean(face,1);normal=normal/norm(normal);
                reference=face(1,:)-centroid;reference=reference/norm(reference);
                perpendicular=cross(normal,reference);
                angles=atan2((face-centroid)*perpendicular.', ...
                    (face-centroid)*reference.');
                [~,order]=sort(angles);ordered=face(order,:);orderedIds=ids(order);
            end
            function area=polygonArea(face,normal)
                normal=normal/norm(normal);areaVector=[0,0,0];
                for kk=1:size(face,1)
                    next=mod(kk,size(face,1))+1;
                    areaVector=areaVector+cross(face(kk,:),face(next,:));
                end
                area=abs(dot(areaVector,normal))/2;
            end
        end
        function value=get_all_voronoi_polyhedra(obj,structure)
            value=cell(1,structure.num_sites);
            for ii=1:structure.num_sites,value{ii}=obj.get_voronoi_polyhedra(structure,ii);end
        end
        function info=get_nn_info(obj,structure,n)
            poly=obj.get_voronoi_polyhedra(structure,n);info={};
            weights=cellfun(@(item)item.(obj.weight),poly);maximum=max(weights);
            for ii=1:numel(poly)
                if weights(ii)>obj.tol*maximum
                    entry=obj.makeInfo(poly{ii}.site,weights(ii)/maximum);
                    if obj.extra_nn_info
                        stats=rmfield(poly{ii},"site");entry.poly_info=stats;
                    end
                    info{end+1}=entry;
                end
            end
        end
        function value=get_all_nn_info(obj,structure)
            cells=obj.get_all_voronoi_polyhedra(structure);
            value=cell(1,numel(cells));
            for ii=1:numel(cells)
                poly=cells{ii};weights=cellfun(@(item)item.(obj.weight),poly);
                maximum=max(weights);info={};
                for jj=1:numel(poly)
                    if weights(jj)>obj.tol*maximum
                        entry=obj.makeInfo(poly{jj}.site,weights(jj)/maximum);
                        if obj.extra_nn_info,entry.poly_info=rmfield(poly{jj},"site");end
                        info{end+1}=entry;
                    end
                end
                value{ii}=info;
            end
        end
    end
    methods (Access=private)
        function tf=inTargets(obj,site)
            if isempty(obj.targets),tf=true;return,end
            targets=obj.targets;if ~iscell(targets),targets=num2cell(targets);end
            [species,~]=site.species.items();tf=false;
            for ii=1:numel(species)
                tf=tf||any(cellfun(@(target)species{ii}.symbol== ...
                    kssolv.analysis.matgenlab.core.getElSp(target).symbol,targets));
            end
        end
    end
end

function output=parse(output,input)
names=fieldnames(output);ii=1;pos=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&& ...
            any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};ii=ii+2;
    else,output.(names{pos})=input{ii};pos=pos+1;ii=ii+1;end
end
end
