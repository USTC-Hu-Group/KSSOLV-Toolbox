classdef SubstituteSurfaceSiteTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    %SUBSTITUTESURFACESITETRANSFORMATION Substitute distinct slab surfaces.
    properties (SetAccess=private)
        atom
        selective_dynamics (1,1) logical
        height (1,1) double
        mi_vec
        target_species
        sub_both_sides (1,1) logical
        range_tol (1,1) double
        dist_from_surf (1,1) double
    end
    methods
        function obj=SubstituteSurfaceSiteTransformation(atom, ...
                selectiveDynamics,height,miVec,targetSpecies,bothSides, ...
                rangeTol,distance)
            if nargin<2,selectiveDynamics=false;end
            if nargin<3,height=.9;end
            if nargin<4,miVec=[];end
            if nargin<5,targetSpecies=[];end
            if nargin<6,bothSides=false;end
            if nargin<7,rangeTol=1e-2;end
            if nargin<8,distance=0;end
            obj.atom=atom;obj.selective_dynamics=selectiveDynamics;
            obj.height=height;obj.mi_vec=miVec;
            obj.target_species=targetSpecies;
            obj.sub_both_sides=bothSides;obj.range_tol=rangeTol;
            obj.dist_from_surf=distance;
        end
        function result=apply_transformation(obj,structure,returnRankedList)
            if nargin<3,returnRankedList=false;end
            normal=cross(structure.lattice.matrix(1,:), ...
                structure.lattice.matrix(2,:));
            normal=normal/max(norm(normal),eps);
            if ~isempty(obj.mi_vec)
                normal=reshape(double(obj.mi_vec),1,3);
                normal=normal/max(norm(normal),eps);
            end
            projection=structure.cart_coords*normal.';
            top=max(projection)-obj.dist_from_surf;
            candidates=find(abs(projection-top)<= ...
                max(obj.range_tol,obj.height));
            candidates=obj.filterSpecies(structure,candidates);
            if isempty(candidates)
                error("KSSOLV:Matgenlab:SurfaceSubstitution:NoSites", ...
                    "No surface sites satisfy the substitution criteria.");
            end
            structures=cell(1,numel(candidates));
            for outputIndex=1:numel(candidates)
                candidate=structure.replace(candidates(outputIndex),obj.atom);
                if obj.sub_both_sides
                    target=min(projection)+obj.dist_from_surf;
                    bottom=find(abs(projection-target)<= ...
                        max(obj.range_tol,obj.height));
                    bottom=obj.filterSpecies(structure,bottom);
                    if ~isempty(bottom)
                        topFrac=structure(candidates(outputIndex)).frac_coords;
                        bottomFrac=structure.frac_coords(bottom,:);
                        delta=bottomFrac(:,1:2)-topFrac(1:2);
                        delta=delta-round(delta);
                        [~,best]=min(sum(delta.^2,2));
                        candidate=candidate.replace(bottom(best),obj.atom);
                    end
                end
                if obj.selective_dynamics
                    values=false(candidate.num_sites,3);
                    values(candidates(outputIndex),:)=true;
                    candidate=kssolv.analysis.matgenlab.transformations. ...
                        internal.Utils.addSiteProperties(candidate, ...
                        struct("selective_dynamics",values));
                end
                structures{outputIndex}=candidate;
            end
            count=kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                rankedCount(returnRankedList);
            if count==0,result=structures{1};else
                count=min(count,numel(structures));result=cell(1,count);
                for index=1:count
                    result{index}=struct("structure",structures{index});
                end
            end
        end
    end
    methods (Access=protected)
        function value=oneToMany(~),value=true;end
    end
    methods (Access=private)
        function indices=filterSpecies(obj,structure,indices)
            if isempty(obj.target_species),return,end
            targets=string(obj.target_species);
            keep=false(size(indices));
            for index=1:numel(indices)
                site=structure(indices(index));
                [species,~]=site.species.items();
                keep(index)=any(arrayfun(@(item)any( ...
                    targets==string(species{item})| ...
                    targets==species{item}.symbol),1:numel(species)));
            end
            indices=indices(keep);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                SubstituteSurfaceSiteTransformation(value.atom, ...
                value.selective_dynamics,value.height,value.mi_vec, ...
                value.target_species,value.sub_both_sides, ...
                value.range_tol,value.dist_from_surf);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                SubstituteSurfaceSiteTransformation.from_dict(value);end
    end
end
