classdef AddAdsorbateTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    %ADDADSORBATETRANSFORMATION Add an adsorbate at distinct surface sites.
    properties (SetAccess=private)
        adsorbate
        selective_dynamics (1,1) logical
        height (1,1) double
        mi_vec
        repeat
        min_lw (1,1) double
        translate (1,1) logical
        reorient (1,1) logical
        find_args
    end
    methods
        function obj=AddAdsorbateTransformation(adsorbate, ...
                selectiveDynamics,height,miVec,repeat,minLw, ...
                translate,reorient,findArgs)
            if nargin<2,selectiveDynamics=false;end
            if nargin<3,height=.9;end
            if nargin<4,miVec=[];end
            if nargin<5,repeat=[];end
            if nargin<6,minLw=5;end
            if nargin<7,translate=true;end
            if nargin<8,reorient=true;end
            if nargin<9,findArgs=struct();end
            obj.adsorbate=adsorbate;
            obj.selective_dynamics=selectiveDynamics;
            obj.height=height;obj.mi_vec=miVec;obj.repeat=repeat;
            obj.min_lw=minLw;obj.translate=translate;
            obj.reorient=reorient;obj.find_args=findArgs;
        end

        function result=apply_transformation(obj,structure,returnRankedList)
            if nargin<3,returnRankedList=false;end
            slab=obj.prepareSlab(structure);
            [indices,normal]=obj.surfaceSites(slab);
            structures=cell(1,numel(indices));
            distance=2;
            if isstruct(obj.find_args)&&isfield(obj.find_args,"distance")
                distance=obj.find_args.distance;
            end
            for outputIndex=1:numel(indices)
                site=slab(indices(outputIndex));
                molecule=obj.adsorbate.copy();
                coordinates=molecule.cart_coords;
                if obj.translate
                    coordinates=coordinates-molecule.center_of_mass;
                end
                if obj.reorient
                    molecularAxis=coordinates(end,:)-coordinates(1,:);
                    if norm(molecularAxis)>1e-12
                        rotation= ...
                            kssolv.analysis.matgenlab.transformations. ...
                            AddAdsorbateTransformation.alignRotation( ...
                            molecularAxis,normal);
                        coordinates=coordinates*rotation.';
                    end
                end
                anchor=site.coords+distance*normal;
                candidate=slab.copy();
                species=molecule.species_and_occu;
                properties=molecule.site_properties;
                for atom=1:molecule.num_sites
                    props=struct();
                    names=fieldnames(properties);
                    for field=1:numel(names)
                        values=properties.(names{field});
                        if iscell(values),props.(names{field})=values{atom};
                        else,props.(names{field})=values(atom,:);end
                    end
                    candidate=candidate.append(species{atom}, ...
                        coordinates(atom,:)+anchor, ...
                        coords_are_cartesian=true,properties=props);
                end
                structures{outputIndex}=candidate;
            end
            count=kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                rankedCount(returnRankedList);
            if count==0
                result=structures{1};
            else
                count=min(count,numel(structures));
                result=cell(1,count);
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
        function slab=prepareSlab(obj,structure)
            slab=structure.copy();
            if isempty(obj.repeat)
                lengths=slab.lattice.lengths;
                repeat=max(1,ceil(obj.min_lw./lengths));
                repeat(3)=1;
            else
                repeat=obj.repeat;
            end
            if any(double(repeat)~=1),slab=slab*double(repeat);end
            if obj.selective_dynamics
                [surface,~]=obj.surfaceSites(slab);
                values=false(slab.num_sites,3);values(surface,:)=true;
                slab=kssolv.analysis.matgenlab.transformations.internal. ...
                    Utils.addSiteProperties(slab, ...
                    struct("selective_dynamics",values));
            end
        end
        function [indices,normal]=surfaceSites(obj,slab)
            normal=cross(slab.lattice.matrix(1,:), ...
                slab.lattice.matrix(2,:));
            normal=normal/max(norm(normal),eps);
            if ~isempty(obj.mi_vec)
                normal=reshape(double(obj.mi_vec),1,3);
                normal=normal/max(norm(normal),eps);
            end
            projection=slab.cart_coords*normal.';
            maximum=max(projection);
            indices=find(projection>=maximum-obj.height);
            if isempty(indices),[~,indices]=max(projection);end
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                AddAdsorbateTransformation(value.adsorbate, ...
                value.selective_dynamics,value.height,value.mi_vec, ...
                value.repeat,value.min_lw,value.translate,value.reorient, ...
                value.find_args);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                AddAdsorbateTransformation.from_dict(value);end
    end
    methods (Static,Access=private)
        function rotation=alignRotation(from,to)
            from=from/norm(from);to=to/norm(to);
            crossVector=cross(from,to);s=norm(crossVector);
            c=max(-1,min(1,dot(from,to)));
            if s<1e-12
                if c>0,rotation=eye(3);else
                    axis=null(from).';axis=axis(1,:);
                    rotation=2*(axis.'*axis)-eye(3);
                end
                return
            end
            skew=[0,-crossVector(3),crossVector(2); ...
                crossVector(3),0,-crossVector(1); ...
                -crossVector(2),crossVector(1),0];
            rotation=eye(3)+skew+skew*skew*((1-c)/(s*s));
        end
    end
end
