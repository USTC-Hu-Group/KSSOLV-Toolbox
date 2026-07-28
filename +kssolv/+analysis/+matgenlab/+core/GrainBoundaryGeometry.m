classdef GrainBoundaryGeometry < ...
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
        cubic_system (1,1) logical
        lattice_type (1,1) string
    end
    methods
        function obj=GrainBoundaryGeometry(axis,angle,expandTimes, ...
                vacuumThickness,abShift,normal,ratio,plane,maxSearch, ...
                tolCoi,rmRatio,quickGen,cubicSystem,latticeType)
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
            if nargin<13,cubicSystem=false;end
            if nargin<14,latticeType="";end
            obj.rotation_axis=reshape(double(axis),1,3);
            obj.rotation_angle=angle;obj.expand_times=expandTimes;
            obj.vacuum_thickness=vacuumThickness;
            obj.ab_shift=reshape(double(abShift),1,2);
            obj.normal=normal;obj.ratio=ratio;obj.plane=plane;
            obj.max_search=maxSearch;obj.tol_coi=tolCoi;
            obj.rm_ratio=rmRatio;obj.quick_gen=quickGen;
            obj.cubic_system=cubicSystem;
            obj.lattice_type=string(latticeType);
        end
        function result=apply_transformation(obj,structure,varargin)
            lengths=structure.lattice.lengths;
            if strlength(obj.lattice_type)>0||obj.cubic_system|| ...
                    (max(lengths)-min(lengths)<1e-6&& ...
                    all(abs(structure.lattice.angles-90)<1e-6))
                result=obj.buildCubicBoundary(structure);
                return
            end
            % Search a small integer coincidence supercell in the plane
            % normal to the requested GB plane (or rotation axis for twist).
            if isempty(obj.plane),boundaryPlane=obj.rotation_axis;else
                boundaryPlane=reshape(double(obj.plane),1,3);
            end
            transform=obj.orientationMatrix( ...
                boundaryPlane,structure.lattice.matrix);
            grain=structure*transform;
            grain=grain*[1,1,max(1,round(obj.expand_times))];
            matrix=grain.lattice.matrix;
            axisCartesian=obj.rotation_axis*structure.lattice.matrix;
            axisCartesian=axisCartesian/max(norm(axisCartesian),eps);
            rotation=kssolv.analysis.matgenlab.core. ...
                GrainBoundaryGeometry.rotationMatrix( ...
                axisCartesian,deg2rad(obj.rotation_angle));
            lower=grain.copy();
            upperCoordinates=grain.cart_coords;
            center=mean(upperCoordinates,1);
            upperCoordinates=(upperCoordinates-center)*rotation.'+center;
            upperFractional=upperCoordinates/matrix;
            upperFractional(:,1:2)=upperFractional(:,1:2)+obj.ab_shift;
            lowerFractional=lower.frac_coords;
            lowerFractional(:,3)=lowerFractional(:,3)/2;
            upperFractional(:,3)=mod(upperFractional(:,3),1)/2+.5;
            newMatrix=matrix;newMatrix(3,:)=newMatrix(3,:)*2;
            if obj.vacuum_thickness>0
                height=abs(dot(newMatrix(3,:),cross(newMatrix(1,:), ...
                    newMatrix(2,:))))/norm(cross(newMatrix(1,:),newMatrix(2,:)));
                newMatrix(3,:)=newMatrix(3,:)* ...
                    ((height+obj.vacuum_thickness)/height);
            end
            species=[lower.species_and_occu,grain.species_and_occu];
            coordinates=[lowerFractional;upperFractional];
            result=kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice(newMatrix), ...
                species,coordinates);
            result=obj.removeCloseInterfaces(result);
            labels=[repmat({"bottom"},1,lower.num_sites), ...
                repmat({"top"},1,grain.num_sites)];
            if numel(labels)>result.num_sites
                labels=labels(1:result.num_sites);
            end
            result=kssolv.analysis.matgenlab.transformations.internal. ...
                Utils.addSiteProperties(result, ...
                struct("grain_label",{labels}));
        end
    end
    methods (Access=private)
        function result=buildCubicBoundary(obj,structure)
            useCubicSearch=obj.cubic_system||strlength(obj.lattice_type)==0;
            if useCubicSearch
                if isempty(obj.plane),surface=obj.rotation_axis;
                else,surface=reshape(double(obj.plane),1,3);end
                divisor=gcd(gcd(abs(round(surface(1))), ...
                    abs(round(surface(2)))),abs(round(surface(3))));
                if divisor>1,surface=surface/divisor;end
                crystalMatrix=structure.lattice.matrix;
                axisCartesian=obj.rotation_axis*crystalMatrix;
                axisCartesian=axisCartesian/norm(axisCartesian);
                cartesianRotation=kssolv.analysis.matgenlab.core. ...
                    GrainBoundaryGeometry.rotationMatrix( ...
                    axisCartesian,deg2rad(obj.rotation_angle));
                inverseCrystalRotation= ...
                    crystalMatrix*cartesianRotation/crystalMatrix;
                [topMatrix,bottomMatrix]=obj.cubicMatrices( ...
                    surface,inverseCrystalRotation,obj.normal, ...
                    crystalMatrix);
            else
                surface=obj.plane;
                [topMatrix,bottomMatrix]=kssolv.analysis.matgenlab.core. ...
                    GrainBoundaryGenerator.get_trans_mat( ...
                    obj.rotation_axis,obj.rotation_angle, ...
                    normal=obj.normal,lat_type=obj.lattice_type, ...
                    ratio=obj.ratio,surface=surface, ...
                    max_search=obj.max_search, ...
                    quick_gen=obj.quick_gen);
            end
            top=structure*topMatrix;
            top=obj.fixFractional(top);
            bottomRaw=structure*bottomMatrix;
            bottom=kssolv.analysis.matgenlab.core.Structure( ...
                top.lattice,bottomRaw.species_and_occu, ...
                round(mod(bottomRaw.frac_coords,1),7), ...
                to_unit_cell=true);
            if obj.normal&&~obj.quick_gen
                if useCubicSearch
                    [oblique,~]=obj.cubicMatrices( ...
                        surface,inverseCrystalRotation,false, ...
                        structure.lattice.matrix);
                else
                    [oblique,~]=kssolv.analysis.matgenlab.core. ...
                        GrainBoundaryGenerator.get_trans_mat( ...
                        obj.rotation_axis,obj.rotation_angle, ...
                        normal=false,lat_type=obj.lattice_type, ...
                        ratio=obj.ratio,surface=surface, ...
                        max_search=obj.max_search, ...
                        quick_gen=obj.quick_gen);
                end
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
        function [top,bottom]=cubicMatrices(obj,surface,inverseTransform, ...
                normal,crystalMatrix)
            if nargin<5,crystalMatrix=eye(3);end
            limit=max(4,obj.max_search);
            planar=[];allCandidates=[];
            for a=-limit:limit
                for b=-limit:limit
                    for c=-limit:limit
                        vector=[a,b,c];
                        if ~any(vector),continue,end
                        rotated=vector*inverseTransform;
                        if max(abs(rotated-round(rotated)))>1e-5,continue,end
                        direction=reduceDirection(vector);
                        normalized=vector;
                        if dot(normalized,direction)<0
                            normalized=-normalized;
                        end
                        allCandidates(end+1,:)=[normalized, ...
                            norm(normalized),direction]; %#ok<AGROW>
                        if abs(dot(vector,surface))<1e-8
                            planar(end+1,:)=[normalized, ...
                                norm(normalized),direction]; %#ok<AGROW>
                        end
                    end
                end
            end
            planar=unique(planar,"rows");
            [~,order]=sortrows([planar(:,4),planar(:,1:3)]);
            planar=planar(order,:);
            [~,keep]=unique(planar(:,5:7),"rows","stable");
            planar=planar(sort(keep),:);
            allCandidates=unique(allCandidates,"rows");
            [~,order]=sortrows([allCandidates(:,4), ...
                allCandidates(:,1:3)]);
            allCandidates=allCandidates(order,:);
            [~,keep]=unique(allCandidates(:,5:7),"rows","stable");
            allCandidates=allCandidates(sort(keep),:);
            if normal
                reciprocalNormal=surface/crystalMatrix.';
                cartesian=allCandidates(:,1:3)*crystalMatrix;
                parallel=vecnorm(cross(cartesian, ...
                    repmat(reciprocalNormal,size(cartesian,1),1),2), ...
                    2,2)<1e-7;
                indices=find(parallel);
                if isempty(indices)
                    error("KSSOLV:Matgenlab:GrainBoundary:Normal", ...
                        "No commensurate normal boundary vector exists.");
                end
                [~,localIndex]=min(vecnorm(cartesian(indices,:),2,2));
                third=allCandidates(indices(localIndex),1:3);
            else
                third=[];
            end
            bestScore=[Inf,Inf,Inf];first=[];second=[];thirdIndex=0;
            for firstIndex=1:size(planar,1)-1
                firstVector=planar(firstIndex,1:3);
                for secondIndex=firstIndex+1:size(planar,1)
                    secondVector=planar(secondIndex,1:3);
                    crossVector=cross(firstVector,secondVector);
                    if norm(crossVector)<1e-8,continue,end
                    if normal
                        determinant=abs(dot(crossVector,third));
                        candidateThirdIndex=0;
                    else
                        determinants=abs(allCandidates(:,1:3)* ...
                            crossVector.');
                        determinants(determinants<.5)=Inf;
                        [determinant,candidateThirdIndex]=min(determinants);
                    end
                    score=[round(determinant),norm(crossVector), ...
                        planar(firstIndex,4)+planar(secondIndex,4)];
                    if lexicographicLess(score,bestScore)
                        bestScore=score;first=firstVector;
                        second=secondVector;
                        thirdIndex=candidateThirdIndex;
                    end
                end
            end
            if isempty(first)
                error("KSSOLV:Matgenlab:GrainBoundary:Surface", ...
                    "Cannot find independent CSL surface vectors.");
            end
            if ~normal,third=allCandidates(thirdIndex,1:3);end
            top=round([first;second;third]);
            if det(top)<0,top(1,:)=-top(1,:);end
            % Match pymatgen's deterministic CSL slab orientation.  The
            % upstream nonnegative-coefficient search chooses the
            % lexicographically negative representative for the first
            % in-plane vector.  Negating both in-plane rows preserves the
            % right-handed basis and the boundary-plane normal.
            firstNonzero=find(top(1,:)~=0,1);
            if ~isempty(firstNonzero)&&top(1,firstNonzero)>0
                top(1:2,:)=-top(1:2,:);
            end
            bottom=round(top*inverseTransform);
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
            obj=kssolv.analysis.matgenlab.core. ...
                GrainBoundaryGeometry(value.rotation_axis, ...
                value.rotation_angle,value.expand_times, ...
                value.vacuum_thickness,value.ab_shift,value.normal, ...
                value.ratio,value.plane,value.max_search,value.tol_coi, ...
                value.rm_ratio,value.quick_gen,readCubicSystem(value), ...
                readLatticeType(value));
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.core. ...
                GrainBoundaryGeometry.from_dict(value);end
    end
    methods (Static,Access=private)
        function rotation=rotationMatrix(axis,theta)
            skew=[0,-axis(3),axis(2);axis(3),0,-axis(1); ...
                -axis(2),axis(1),0];
            rotation=eye(3)+sin(theta)*skew+(1-cos(theta))*(skew*skew);
        end
    end
end
function value=readCubicSystem(data)
if isfield(data,"cubic_system"),value=data.cubic_system;
else,value=false;end
end
function value=readLatticeType(data)
if isfield(data,"lattice_type"),value=string(data.lattice_type);
else,value="";end
end
function direction=reduceDirection(vector)
direction=round(vector);
divisor=0;
for value=abs(direction),divisor=gcd(divisor,value);end
if divisor>0,direction=direction/divisor;end
first=find(direction~=0,1);
if direction(first)<0,direction=-direction;end
end
function tf=lexicographicLess(first,second)
tf=false;
for index=1:numel(first)
    if first(index)<second(index)-1e-10,tf=true;return,end
    if first(index)>second(index)+1e-10,return,end
end
end
