classdef GrainBoundaryTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    %GRAINBOUNDARYTRANSFORMATION Construct a periodic two-grain bicrystal.
    properties (SetAccess=private)
        rotation_axis (1,3) double
        rotation_angle (1,1) double
        expand_times (1,1) double
        vacuum_thickness (1,1) double
        ab_shift (1,2) double
        normal (1,1) logical
        ratio
        plane
        max_search (1,1) double
        tol_coi (1,1) double
        rm_ratio (1,1) double
        quick_gen (1,1) logical
    end
    methods
        function obj=GrainBoundaryTransformation(axis,angle,expandTimes, ...
                vacuumThickness,abShift,normal,ratio,plane,maxSearch, ...
                tolCoi,rmRatio,quickGen)
            if nargin<3,expandTimes=4;end
            if nargin<4,vacuumThickness=0;end
            if nargin<5||isempty(abShift),abShift=[0,0];end
            if nargin<6,normal=false;end
            if nargin<7,ratio=true;end
            if nargin<8,plane=[];end
            if nargin<9,maxSearch=20;end
            if nargin<10,tolCoi=1e-8;end
            if nargin<11,rmRatio=.7;end
            if nargin<12,quickGen=false;end
            obj.rotation_axis=reshape(double(axis),1,3);
            obj.rotation_angle=angle;obj.expand_times=expandTimes;
            obj.vacuum_thickness=vacuumThickness;
            obj.ab_shift=reshape(double(abShift),1,2);
            obj.normal=normal;obj.ratio=ratio;obj.plane=plane;
            obj.max_search=maxSearch;obj.tol_coi=tolCoi;
            obj.rm_ratio=rmRatio;obj.quick_gen=quickGen;
        end
        function result=apply_transformation(obj,structure,varargin)
            generator=kssolv.analysis.matgenlab.core. ...
                GrainBoundaryGenerator(structure);
            result=generator.gb_from_parameters(obj.rotation_axis, ...
                obj.rotation_angle,expand_times=obj.expand_times, ...
                vacuum_thickness=obj.vacuum_thickness, ...
                ab_shift=obj.ab_shift,normal=obj.normal,ratio=obj.ratio, ...
                plane=obj.plane,max_search=obj.max_search, ...
                tol_coi=obj.tol_coi,rm_ratio=obj.rm_ratio, ...
                quick_gen=obj.quick_gen);
        end
    end
    methods (Access=private)
        function result=buildCubicBoundary(obj,structure)
            if isempty(obj.plane),surface=obj.rotation_axis;
            else,surface=reshape(double(obj.plane),1,3);end
            divisor=gcd(gcd(abs(round(surface(1))), ...
                abs(round(surface(2)))),abs(round(surface(3))));
            if divisor>1,surface=surface/divisor;end
            rotation=kssolv.analysis.matgenlab.transformations. ...
                GrainBoundaryTransformation.rotationMatrix( ...
                obj.rotation_axis/norm(obj.rotation_axis), ...
                deg2rad(obj.rotation_angle));
            [topMatrix,bottomMatrix]=obj.cubicMatrices( ...
                surface,rotation,obj.normal);
            top=structure*topMatrix;
            top=obj.fixFractional(top);
            bottomRaw=structure*bottomMatrix;
            bottom=kssolv.analysis.matgenlab.core.Structure( ...
                top.lattice,bottomRaw.species_and_occu, ...
                round(mod(bottomRaw.frac_coords,1),7), ...
                to_unit_cell=true);
            if obj.normal&&~obj.quick_gen
                [oblique,~]=obj.cubicMatrices(surface,rotation,false);
                oriented=structure*oblique;
                orientedMatrix=oriented.lattice.matrix;
                planeNormal=cross(orientedMatrix(1,:),orientedMatrix(2,:));
                unitNormal=planeNormal/norm(planeNormal);
                unitAdjust=(orientedMatrix(3,:)- ...
                    dot(unitNormal,orientedMatrix(3,:))*unitNormal)/ ...
                    dot(unitNormal,orientedMatrix(3,:));
            else
                unitAdjust=zeros(1,3);
            end
            top=top*[1,1,obj.expand_times];
            bottom=bottom*[1,1,obj.expand_times];
            top=obj.fixFractional(top);
            bottom=obj.fixFractional(bottom);
            edgeBottom=1-max(bottom.frac_coords(:,3));
            edgeTop=1-max(top.frac_coords(:,3));
            cAdjust=(edgeTop-edgeBottom)/2;
            halfMatrix=top.lattice.matrix;
            unitNormal=cross(halfMatrix(1,:),halfMatrix(2,:));
            unitNormal=unitNormal/norm(unitNormal);
            vacuumVector=unitNormal*obj.vacuum_thickness;
            wholeMatrix=halfMatrix;
            wholeMatrix(3,:)=2*halfMatrix(3,:)+2*vacuumVector;
            species=[bottom.species_and_occu,top.species_and_occu];
            bottomCoordinates=bottom.cart_coords;
            topCoordinates=top.cart_coords+ ...
                halfMatrix(3,:)*(1+cAdjust)+ ...
                unitAdjust*norm(halfMatrix(3,:)*(1+cAdjust))+ ...
                vacuumVector+obj.ab_shift(1)*wholeMatrix(1,:)+ ...
                obj.ab_shift(2)*wholeMatrix(2,:);
            labels=[repmat({"bottom"},1,bottom.num_sites), ...
                repmat({"top"},1,top.num_sites)];
            result=kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice(wholeMatrix), ...
                species,[bottomCoordinates;topCoordinates], ...
                coords_are_cartesian=true,to_unit_cell=true, ...
                site_properties=struct("grain_label",{labels}));
            distances=structure.distance_matrix;
            distances=distances(distances>1e-8);
            if isempty(distances)
                doubled=structure*[1,1,2];
                distances=doubled.distance_matrix;
                distances=distances(distances>1e-8);
            end
            bondLength=min(distances);
            cosine=dot(unitNormal,wholeMatrix(3,:))/ ...
                norm(wholeMatrix(3,:));
            range=abs(bondLength/cosine/norm(wholeMatrix(3,:)));
            z=result.frac_coords(:,3);
            near=z<range|z>1-range|abs(z-.5)<range;
            if any(near)
                nearStructure=kssolv.analysis.matgenlab.core.Structure. ...
                    from_sites(result.sites(near));
                nearStructure=nearStructure.merge_sites( ...
                    bondLength*obj.rm_ratio,"delete");
                allSites=[result.sites(~near),nearStructure.sites];
                result=kssolv.analysis.matgenlab.core.Structure. ...
                    from_sites(allSites);
            end
            % Make the result's periodic representatives deterministic.
            result=kssolv.analysis.matgenlab.core.Structure( ...
                result.lattice,result.species_and_occu, ...
                round(mod(result.frac_coords,1),7), ...
                site_properties=result.site_properties);
        end
        function result=fixFractional(~,structure)
            result=kssolv.analysis.matgenlab.core.Structure( ...
                structure.lattice,structure.species_and_occu, ...
                round(mod(structure.frac_coords,1),7), ...
                site_properties=structure.site_properties);
        end
        function [top,bottom]=cubicMatrices(obj,surface,rotation,normal)
            limit=max(4,obj.max_search);
            planar=[];allCandidates=[];
            for a=-limit:limit
                for b=-limit:limit
                    for c=-limit:limit
                        vector=[a,b,c];
                        if ~any(vector),continue,end
                        rotated=vector/rotation.';
                        if max(abs(rotated-round(rotated)))>1e-5,continue,end
                        normalized=vector;
                        first=find(normalized~=0,1);
                        if normalized(first)>0,normalized=-normalized;end
                        allCandidates(end+1,:)=[normalized,norm(normalized)]; %#ok<AGROW>
                        if abs(dot(vector,surface))<1e-8
                            planar(end+1,:)=[normalized,norm(normalized)]; %#ok<AGROW>
                        end
                    end
                end
            end
            planar=unique(planar,"rows");
            [~,order]=sortrows([planar(:,4),planar(:,1:3)]);
            planar=planar(order,:);
            first=planar(1,1:3);second=[];
            for index=2:size(planar,1)
                if norm(cross(first,planar(index,1:3)))>1e-8
                    second=planar(index,1:3);break
                end
            end
            if normal
                third=-surface;
                transformedThird=third/rotation.';
                if max(abs(transformedThird- ...
                        round(transformedThird)))>1e-5
                    error("KSSOLV:Matgenlab:GrainBoundary:Normal", ...
                        "No commensurate normal boundary vector exists.");
                end
            else
                allCandidates=unique(allCandidates,"rows");
                determinants=zeros(size(allCandidates,1),1);
                for index=1:size(allCandidates,1)
                    determinants(index)=round(abs(det( ...
                        [first;second;allCandidates(index,1:3)])));
                    if determinants(index)<.5,determinants(index)=Inf;end
                end
                orientationPenalty=double( ...
                    allCandidates(:,1:3)*surface.'>=0);
                [~,order]=sortrows([determinants, ...
                    allCandidates(:,4),orientationPenalty, ...
                    allCandidates(:,1:3)]);
                third=allCandidates(order(1),1:3);
            end
            top=round([first;second;third]);
            if det(top)<0,top(1,:)=-top(1,:);end
            bottom=round(top/rotation.');
        end
        function transform=orientationMatrix(obj,plane,lattice)
            limit=max(2,min(obj.max_search,8));
            candidates=[];
            for a=-limit:limit
                for b=-limit:limit
                    for c=-limit:limit
                        vector=[a,b,c];
                        if any(vector)&&abs(dot(vector,plane))<obj.tol_coi
                            candidates(end+1,:)=[vector,norm(vector*lattice)]; %#ok<AGROW>
                        end
                    end
                end
            end
            [~,order]=sort(candidates(:,4));candidates=candidates(order,:);
            first=candidates(1,1:3);second=[];
            for index=2:size(candidates,1)
                if norm(cross(first,candidates(index,1:3)))>0
                    second=candidates(index,1:3);break
                end
            end
            third=plane;
            if abs(det([first;second;third]))<1e-12
                third=cross(first,second);
            end
            transform=round([first;second;third]);
            divisor=abs(round(det(transform)));
            if divisor==0
                error("KSSOLV:Matgenlab:GrainBoundary:Orientation", ...
                    "Could not construct a nonsingular boundary cell.");
            end
            if det(transform)<0,transform(2,:)=-transform(2,:);end
        end
        function result=removeCloseInterfaces(obj,structure)
            result=structure;
            if result.num_sites<2,return,end
            radii=zeros(1,result.num_sites);
            for index=1:result.num_sites
                try
                    radii(index)=result(index).specie.atomic_radius;
                catch
                    radii(index)=1;
                end
                if isempty(radii(index))||~isfinite(radii(index))
                    radii(index)=1;
                end
            end
            remove=[];
            for first=1:result.num_sites-1
                for second=first+1:result.num_sites
                    threshold=obj.rm_ratio*(radii(first)+radii(second));
                    if result.get_distance(first,second)<threshold
                        remove(end+1)=second; %#ok<AGROW>
                    end
                end
            end
            if ~isempty(remove),result=result.remove_sites(unique(remove));end
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                GrainBoundaryTransformation(value.rotation_axis, ...
                value.rotation_angle,value.expand_times, ...
                value.vacuum_thickness,value.ab_shift,value.normal, ...
                value.ratio,value.plane,value.max_search,value.tol_coi, ...
                value.rm_ratio,value.quick_gen);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                GrainBoundaryTransformation.from_dict(value);end
    end
    methods (Static,Access=private)
        function rotation=rotationMatrix(axis,theta)
            skew=[0,-axis(3),axis(2);axis(3),0,-axis(1); ...
                -axis(2),axis(1),0];
            rotation=eye(3)+sin(theta)*skew+(1-cos(theta))*(skew*skew);
        end
    end
end
