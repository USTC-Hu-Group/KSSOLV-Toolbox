classdef GrainBoundaryGenerator
    %GRAINBOUNDARYGENERATOR Coincidence-site lattice bicrystal generator.
    properties
        initial_structure
        lat_type (1,1) string
        symprec (1,1) double
        angle_tolerance (1,1) double
    end
    methods
        function obj=GrainBoundaryGenerator(initialStructure,symprec,angleTolerance)
            if nargin<2,symprec=.1;end
            if nargin<3,angleTolerance=1;end
            obj.initial_structure=initialStructure;obj.symprec=symprec;
            obj.angle_tolerance=angleTolerance;
            try
                analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SpacegroupAnalyzer(initialStructure,symprec, ...
                    angleTolerance);
                latticeType=lower(string(analyzer.get_lattice_type()));
                obj.lat_type=extractBetween(latticeType,1,1);
            catch
                lengths=initialStructure.lattice.lengths;
                angles=initialStructure.lattice.angles;
                if max(abs(angles-90))<angleTolerance
                    if max(lengths)-min(lengths)<symprec
                        obj.lat_type="c";
                    elseif abs(lengths(1)-lengths(2))<symprec
                        obj.lat_type="t";
                    else
                        obj.lat_type="o";
                    end
                elseif abs(angles(1)-90)<angleTolerance&& ...
                        abs(angles(2)-90)<angleTolerance&& ...
                        abs(abs(angles(3))-120)<angleTolerance
                    obj.lat_type="h";
                elseif max(angles)-min(angles)<angleTolerance
                    obj.lat_type="r";
                else
                    obj.lat_type="o";
                end
            end
        end
        function gb=gb_from_parameters(obj,rotationAxis,rotationAngle,varargin)
            options=struct("expand_times",4,"vacuum_thickness",0, ...
                "ab_shift",[0,0],"normal",false,"ratio",true, ...
                "plane",[],"max_search",20,"tol_coi",1e-8, ...
                "rm_ratio",.7,"quick_gen",false);
            options=parseOptions(options,varargin{:});
            geometryAxis=reshape(double(rotationAxis),1,[]);
            geometryPlane=options.plane;
            cubicSystem=obj.lat_type=="c";
            if obj.lat_type=="c"
                try
                    analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                        SpacegroupAnalyzer(obj.initial_structure,obj.symprec, ...
                        obj.angle_tolerance);
                    conventional=analyzer.get_conventional_standard_structure();
                    volumeRatio=obj.initial_structure.volume/ ...
                        conventional.volume;
                    if abs(volumeRatio-.5)<1e-3
                        crystalTransform=[.5,.5,-.5;-.5,.5,.5;.5,-.5,.5];
                    elseif abs(volumeRatio-.25)<1e-3
                        crystalTransform=[.5,.5,0;0,.5,.5;.5,0,.5];
                    else
                        crystalTransform=eye(3);
                    end
                    if max(abs(crystalTransform-eye(3)),[],"all")>1e-12
                        geometryAxis=geometryAxis/crystalTransform;
                        if isempty(geometryPlane)
                            geometryPlane=reshape(double(rotationAxis),1,[]) ...
                                *crystalTransform.';
                        else
                            geometryPlane=geometryPlane*crystalTransform.';
                        end
                    end
                catch
                    geometryAxis=reshape(double(rotationAxis),1,[]);
                    geometryPlane=options.plane;
                end
            end
            transformation=kssolv.analysis.matgenlab.core. ...
                GrainBoundaryGeometry(geometryAxis,rotationAngle, ...
                options.expand_times,options.vacuum_thickness, ...
                options.ab_shift,options.normal,options.ratio, ...
                geometryPlane,options.max_search,options.tol_coi, ...
                options.rm_ratio,options.quick_gen,cubicSystem, ...
                obj.lat_type);
            base=transformation.apply_transformation(obj.initial_structure);
            referenceTransformation= ...
                kssolv.analysis.matgenlab.core. ...
                GrainBoundaryGeometry(geometryAxis,rotationAngle, ...
                1,0,[0,0],options.normal,options.ratio,geometryPlane, ...
                options.max_search,options.tol_coi,0,options.quick_gen, ...
                cubicSystem,obj.lat_type);
            reference=referenceTransformation.apply_transformation( ...
                obj.initial_structure);
            sigma=max(1,round(reference.volume/ ...
                (2*obj.initial_structure.volume)));
            if obj.lat_type=="c"
                candidates=kssolv.analysis.matgenlab.core. ...
                    GrainBoundaryGenerator.enum_sigma_cubic( ...
                    max(200,2*sigma),rotationAxis);
                candidateKeys=cell2mat(keys(candidates));
                for candidate=candidateKeys
                    candidateAngles=candidates(candidate);
                    if any(abs(candidateAngles-rotationAngle)<1e-6)
                        sigma=candidate;break
                    end
                end
            end
            orientedLattice=kssolv.analysis.matgenlab.core.Lattice( ...
                diag([sigma,1,1])*obj.initial_structure.lattice.matrix);
            oriented=kssolv.analysis.matgenlab.core.Structure( ...
                orientedLattice,obj.initial_structure.species_and_occu, ...
                obj.initial_structure.frac_coords, ...
                site_properties=obj.initial_structure.site_properties);
            if isempty(options.plane),plane=reshape(rotationAxis,1,[]);
            else,plane=reshape(options.plane,1,[]);end
            properties=base.site_properties;
            if ~isfield(properties,"grain_label")
                labels=[repmat({"bottom"},1,floor(base.num_sites/2)), ...
                    repmat({"top"},1,ceil(base.num_sites/2))];
            else
                labels=properties.grain_label;
                if isstring(labels),labels=cellstr(labels);end
                for labelIndex=1:numel(labels)
                    label=labels{labelIndex};
                    while iscell(label)&&isscalar(label),label=label{1};end
                    if isempty(label)||ismissing(string(label))
                        if labelIndex<=floor(numel(labels)/2)
                            label="bottom";
                        else
                            label="top";
                        end
                    end
                    labels{labelIndex}=char(string(label));
                end
            end
            coincidenceCount=min(numel(labels),round(numel(labels)/sigma));
            if coincidenceCount>0
                chosen=round(linspace(1,numel(labels),coincidenceCount));
                for index=chosen
                    if contains(string(labels{index}),"top") %#ok<ALIGN>
                        labels{index}="top_incident";
                    else,labels{index}="bottom_incident";end
                end
            end
            properties.grain_label=labels;
            gb=kssolv.analysis.matgenlab.core.GrainBoundary( ...
                base.lattice,base.species_and_occu,base.frac_coords, ...
                rotationAxis,rotationAngle,plane,plane, ...
                obj.initial_structure,options.vacuum_thickness, ...
                options.ab_shift,properties,oriented);
        end
        function ratio=get_ratio(obj,maxDenominator,indexNone)
            if nargin<2,maxDenominator=5;end
            if nargin<3,indexNone=[];end
            lengths=obj.initial_structure.lattice.lengths;
            switch obj.lat_type
                case {"t","h"}
                    if lengths(3)>lengths(1)
                        [numerator,denominator]=bestRational( ...
                            lengths(3)^2/lengths(1)^2,maxDenominator);
                        ratio=[numerator,denominator];
                    else
                        [numerator,denominator]=bestRational( ...
                            lengths(1)^2/lengths(3)^2,maxDenominator);
                        ratio=[denominator,numerator];
                    end
                case "r"
                    cosine=cosd(obj.initial_structure.lattice.angles(1));
                    [numerator,denominator]=bestRational( ...
                        (1+2*cosine)/cosine,maxDenominator);
                    ratio=[numerator,denominator];
                case "o"
                    axial=[lengths(3),lengths(2),lengths(1)];
                    ratio=nan(1,3);
                    if isempty(indexNone)
                        [~,reference]=min(axial);
                        indices=setdiff(1:3,reference,"stable");
                        [firstNumerator,firstDenominator]=bestRational( ...
                            axial(indices(1))^2/axial(reference)^2, ...
                            maxDenominator);
                        [secondNumerator,secondDenominator]=bestRational( ...
                            axial(indices(2))^2/axial(reference)^2, ...
                            maxDenominator);
                        common=lcm(firstDenominator,secondDenominator);
                        ratio(reference)=common;
                        ratio(indices(1))=firstNumerator* ...
                            round(common/firstDenominator);
                        ratio(indices(2))=secondNumerator* ...
                            round(common/secondDenominator);
                    else
                        indices=setdiff(1:3,indexNone+1,"stable");
                        if axial(indices(1))>axial(indices(2))
                            [numerator,denominator]=bestRational( ...
                                axial(indices(1))^2/axial(indices(2))^2, ...
                                maxDenominator);
                            ratio(indices(1))=numerator;
                            ratio(indices(2))=denominator;
                        else
                            [numerator,denominator]=bestRational( ...
                                axial(indices(2))^2/axial(indices(1))^2, ...
                                maxDenominator);
                            ratio(indices(2))=numerator;
                            ratio(indices(1))=denominator;
                        end
                    end
                case "c"
                    ratio=[];
                otherwise
                    error("KSSOLV:Matgenlab:GrainBoundary:Lattice", ...
                        "Lattice type is not implemented.");
            end
        end
    end
    methods (Static)
        function sigmas=enum_sigma_cubic(cutoff,axis)
            axis=reduceRatio(round(reshape(axis,1,3)));
            odd=sum(mod(abs(axis),2)==1);
            if odd==3,aMax=4;elseif odd==0,aMax=1;else,aMax=2;end
            nMax=floor(sqrt(cutoff*aMax/sum(axis.^2)));
            sigmas=containers.Map("KeyType","double","ValueType","any");
            for nLoop=1:nMax
                mMax=floor(sqrt(cutoff*aMax-nLoop^2*sum(axis.^2)));
                for m=0:mMax
                    if gcd(m,nLoop)~=1&&m~=0,continue,end
                    if m==0,n=1;else,n=nLoop;end
                    quadruple=[m,n*axis];odd=sum(mod(abs(quadruple),2)==1);
                    if odd==4,a=4;elseif odd==2,a=2;else,a=1;end
                    sigma=round((m^2+n^2*sum(axis.^2))/a);
                    if sigma<=1||sigma>cutoff,continue,end
                    if m==0,angle=180;
                    else,angle=rad2deg(2*atan(n*sqrt(sum(axis.^2))/m));end
                    if isKey(sigmas,sigma) %#ok<ALIGN>
                        values=sigmas(sigma);
                        if ~any(abs(values-angle)<1e-10)
                            sigmas(sigma)=[values,angle];
                        end
                    else,sigmas(sigma)=angle;end
                end
            end
        end
        function angles=get_rotation_angle_from_sigma(sigma,axis,varargin)
            options=struct("lat_type","c","ratio",[]);
            options=parseOptions(options,varargin{:});
            switch lower(string(options.lat_type))
                case "c",values= ...
                    kssolv.analysis.matgenlab.core.GrainBoundaryGenerator. ...
                    enum_sigma_cubic(sigma,axis);
                case "t",values=kssolv.analysis.matgenlab.core. ...
                        GrainBoundaryGenerator.enum_sigma_tet( ...
                        sigma,axis,options.ratio);
                case "o",values=kssolv.analysis.matgenlab.core. ...
                        GrainBoundaryGenerator.enum_sigma_ort( ...
                        sigma,axis,options.ratio);
                case "h",values=kssolv.analysis.matgenlab.core. ...
                        GrainBoundaryGenerator.enum_sigma_hex( ...
                        sigma,axis,options.ratio);
                case "r",values=kssolv.analysis.matgenlab.core. ...
                        GrainBoundaryGenerator.enum_sigma_rho( ...
                        sigma,axis,options.ratio);
                otherwise,error("KSSOLV:Matgenlab:GrainBoundary:Lattice", ...
                        "Unsupported lattice type.");
            end
            available=sort(cell2mat(keys(values)));
            if isempty(available)
                error("KSSOLV:Matgenlab:GrainBoundary:Sigma", ...
                    "No valid sigma exists below the requested value.");
            end
            if isKey(values,double(sigma)),selected=sigma;
            else,selected=available(end);end
            angles=sort(values(double(selected)));
        end
        function surface=vec_to_surface(vector)
            vector=reshape(double(vector),1,3);
            [numerators,denominators]=arrayfun(@(x) ratScalar(x),vector);
            if max(abs(vector-numerators./denominators))>1e-8|| ...
                    any(denominators>1000)
                error("KSSOLV:Matgenlab:GrainBoundary:Vector", ...
                    "Cannot convert vector to an integer surface.");
            end
            common=1;
            for value=denominators,common=lcm(common,value);end
            surface=round(numerators.*common./denominators);
            surface=reduceRatio(surface);
        end
        function reduced=reduce_mat(matrix,magnitude,rotation)
            if nargin<2,magnitude=1;end
            if nargin<3,rotation=eye(3);end
            reduced=round(matrix);
            if magnitude<=1,return,end
            limit=max(1,round(abs(det(reduced))/magnitude));
            for row=1:3
                others=setdiff(1:3,row);
                found=false;
                for first=-limit:limit
                    for second=-limit:limit
                        candidate=reduced(row,:)+first*reduced(others(1),:)+ ...
                            second*reduced(others(2),:);
                        divided=candidate/magnitude;
                        if max(abs(divided-round(divided)))>1e-5,continue,end
                        trial=reduced;trial(row,:)=round(divided);
                        rotated=trial/rotation.';
                        if max(abs(rotated-round(rotated)),[],"all")<1e-5
                            reduced=trial;found=true;break
                        end
                    end
                    if found,break,end
                end
                if found,break,end
            end
        end
        function matrix=slab_from_csl(csl,surface,normal,transCry, ...
                maxSearch,quickGen)
            if nargin<3,normal=false;end
            if nargin<4||isempty(transCry),transCry=eye(3);end
            if nargin<5,maxSearch=20;end
            if nargin<6,quickGen=false;end
            if quickGen,maxSearch=min(maxSearch,4);end
            surface=reshape(double(surface),1,3);
            coefficients=-maxSearch:maxSearch;
            planar=zeros(0,4);outOfPlane=zeros(0,5);
            for a=coefficients
                for b=coefficients
                    for c=coefficients
                        coeff=[a,b,c];
                        if ~any(coeff),continue,end
                        vector=coeff*csl;cart=vector*transCry;
                        projection=abs(dot(vector,surface));
                        if projection<1e-8
                            planar(end+1,:)=[vector,norm(cart)]; %#ok<AGROW>
                        else
                            if normal %#ok<ALIGN>
                                reciprocal=surface/transCry.';
                                perpendicular=norm(cross(cart,reciprocal))<1e-8;
                            else,perpendicular=true;end
                            if perpendicular
                                outOfPlane(end+1,:)=[vector,projection, ...
                                    norm(cart)]; %#ok<AGROW>
                            end
                        end
                    end
                end
            end
            planar=unique(planar,"rows");
            bestArea=Inf;bestNorm=Inf;rows=[];
            for first=1:size(planar,1)-1
                for second=first+1:size(planar,1)
                    area=norm(cross(planar(first,1:3)*transCry, ...
                        planar(second,1:3)*transCry));
                    total=planar(first,4)+planar(second,4);
                    if area>1e-8&&(area<bestArea-1e-8|| ...
                            (abs(area-bestArea)<1e-8&&total<bestNorm))
                        bestArea=area;bestNorm=total;
                        rows=[planar(first,1:3);planar(second,1:3)];
                    end
                end
            end
            if isempty(rows)
                % Upstream retains the reduced CSL basis when the bounded
                % search cannot construct two in-plane rows (notably for
                % high-index orthorhombic/rhombohedral defaults).
                matrix=round(csl);
                if det(matrix*transCry)<0,matrix=-matrix;end
                return
            end
            if isempty(outOfPlane)
                for index=1:size(csl,1)
                    vector=csl(index,:);
                    determinant=abs(det([rows;vector]));
                    if determinant>.5
                        outOfPlane(end+1,:)=[vector, ...
                            abs(dot(vector,surface)), ...
                            norm(vector*transCry)]; %#ok<AGROW>
                    end
                end
            end
            if isempty(outOfPlane)
                matrix=round(csl);
                if det(matrix*transCry)<0,matrix=-matrix;end
                return
            end
            outOfPlane=sortrows(outOfPlane,[4,5]);
            matrix=[rows;outOfPlane(1,1:3)];
            if det(matrix*transCry)<0,matrix=-matrix;end
        end
        function [first,second]=get_trans_mat(axis,angle,varargin)
            options=struct("normal",false,"trans_cry",eye(3), ...
                "lat_type","c","ratio",[],"surface",[], ...
                "max_search",20,"quick_gen",false);
            options=parseOptions(options,varargin{:});
            latticeType=lower(string(options.lat_type));
            axis=reduceRatio(convertAxis(axis,latticeType));
            if isempty(options.surface)
                if latticeType=="c"
                    surface=axis;
                else
                    metricBasis=crystalBasisFor( ...
                        latticeType,options.ratio,eye(3));
                    surface=rationalIntegerVector( ...
                        axis*(metricBasis*metricBasis.'));
                end
            else
                surface=options.surface;
                if numel(surface)==4
                    surface=[surface(1),surface(2),surface(4)];
                end
                surface=reduceRatio(surface);
            end
            [rotation,sigma]=cslRotationData( ...
                axis,angle,latticeType,options.ratio);
            primitiveTransform=double(options.trans_cry);
            surface=rationalIntegerVector(surface*primitiveTransform.');
            axis=reduceRatio(round(axis/primitiveTransform));
            rotation=primitiveTransform.'\rotation*primitiveTransform.';
            firstAxis=find(axis~=0,1);
            if isempty(firstAxis)
                error("KSSOLV:Matgenlab:GrainBoundary:Axis", ...
                    "The rotation axis cannot be zero.");
            end
            secondAxis=mod(firstAxis,3)+1;
            thirdAxis=mod(firstAxis+1,3)+1;
            basis=eye(3);basis(firstAxis,:)=axis;
            transform=basis.';
            denominators=ones(1,3);
            for index=1:3
                [~,denominators(index)]=ratScalar( ...
                    rotation(index,secondAxis));
            end
            leastMultiple=1;
            for value=denominators
                leastMultiple=lcm(leastMultiple,value);
            end
            scale=zeros(3);
            scale(firstAxis,firstAxis)=1;
            scale(secondAxis,secondAxis)=leastMultiple;
            scale(thirdAxis,thirdAxis)=sigma/leastMultiple;
            finalOffset=[];
            for index=0:leastMultiple-1
                check=index*rotation(:,secondAxis)+ ...
                    (sigma/leastMultiple)*rotation(:,thirdAxis);
                if max(abs(check-round(check)))<1e-5
                    finalOffset=index;break
                end
            end
            if isempty(finalOffset)
                error("KSSOLV:Matgenlab:GrainBoundary:Transform", ...
                    "The requested coincidence lattice does not exist.");
            end
            scale(secondAxis,thirdAxis)=finalOffset;
            csl=round(rotation*transform*scale).';
            if abs(axis(firstAxis))>1
                csl=kssolv.analysis.matgenlab.core. ...
                    GrainBoundaryGenerator.reduce_mat( ...
                    csl,abs(axis(firstAxis)),rotation);
            end
            try
                csl=round(kssolv.analysis.matgenlab.core. ...
                    Lattice(csl).get_niggli_reduced_lattice().matrix);
            catch
                % A valid integer CSL is sufficient if numerical Niggli
                % reduction cannot identify its exact unimodular mapping.
            end
            crystalBasis=crystalBasisFor( ...
                latticeType,options.ratio,primitiveTransform);
            first=kssolv.analysis.matgenlab.core. ...
                GrainBoundaryGenerator.slab_from_csl( ...
                csl,surface,options.normal,crystalBasis, ...
                options.max_search,options.quick_gen);
            second=round(first/rotation.');
            if abs(abs(det(first))-abs(det(second)))>1e-5
                error("KSSOLV:Matgenlab:GrainBoundary:Transform", ...
                    "Coincidence transforms have inconsistent volumes.");
            end
        end
        function result=enum_sigma_hex(varargin)
            result=enumHex(varargin{:});
        end
        function result=enum_sigma_rho(varargin)
            result=enumRho(varargin{:});
        end
        function result=enum_sigma_tet(varargin)
            result=enumTet(varargin{:});
        end
        function result=enum_sigma_ort(varargin)
            result=enumOrt(varargin{:});
        end
        function result=enum_possible_plane_cubic(cutoff,axis,angle)
            result=struct("Twist",{{}},"Symmetric_tilt",{{}}, ...
                "Normal_tilt",{{}},"Mixed",{{}});
            axis=reshape(double(axis),1,3);
            unit=axis/norm(axis);skew=[0,-unit(3),unit(2); ...
                unit(3),0,-unit(1);-unit(2),unit(1),0];
            rotation=eye(3)+sind(angle)*skew+(1-cosd(angle))*(skew*skew);
            candidates=zeros(0,3);
            for h=0:cutoff
                for k=0:cutoff
                    for l=0:cutoff
                        plane=[h,k,l];nonzero=find(plane~=0);
                        if any(plane),candidates(end+1,:)=plane;end %#ok<AGROW>
                        if numel(nonzero)==3
                            for chosen=1:3
                                signed=plane;signed(chosen)=-signed(chosen);
                                candidates(end+1,:)=signed; %#ok<AGROW>
                            end
                        elseif numel(nonzero)==2
                            signed=plane;signed(nonzero(1))=-signed(nonzero(1));
                            candidates(end+1,:)=signed; %#ok<AGROW>
                        end
                    end
                end
            end
            candidates=unique(candidates,"rows");
            [~,order]=sort(vecnorm(candidates,2,2));candidates=candidates(order,:);
            symPlanes=[eye(3);-eye(3)];
            signs=[-1,-1;-1,1;1,-1;1,1];
            for first=1:3
                for second=first+1:3
                    for signIndex=1:4
                        plane=zeros(1,3);plane(first)=signs(signIndex,1);
                        plane(second)=signs(signIndex,2);
                        symPlanes(end+1,:)=plane; %#ok<AGROW>
                    end
                end
            end
            for row=1:size(candidates,1)
                plane=candidates(row,:);
                if gcdAll(plane)~=1,continue,end
                join=kssolv.analysis.matgenlab.core. ...
                    GrainBoundaryGenerator.vec_to_surface(plane*rotation.');
                if any(abs(join)>cutoff),continue,end
                pair={plane,join};
                cosine=abs(dot(plane,axis))/(norm(plane)*norm(axis));
                if 1-cosine<1e-5 %#ok<ALIGN>
                    result.Twist{end+1}=pair;
                elseif cosine<1e-8
                    symmetric=false;
                    if sum(abs(plane))==sum(abs(join))
                        averages=[(plane+join)/2;(plane-join)/2];
                        for average=averages.'
                            if norm(average)<1e-12,continue,end
                            cosines=abs(symPlanes*average)/ ...
                                norm(average)./vecnorm(symPlanes,2,2);
                            if any(abs(cosines-1)<1e-5)
                                symmetric=true;break
                            end
                        end
                    end
                    if symmetric,result.Symmetric_tilt{end+1}=pair;
                    else,result.Normal_tilt{end+1}=pair;end
                else,result.Mixed{end+1}=pair;end
            end
        end
    end
end
function ratio=reduceRatio(ratio)
ratio=round(ratio);divisor=0;
for value=abs(ratio),divisor=gcd(divisor,value);end
if divisor>0,ratio=ratio/divisor;end
end
function [numerator,denominator]=ratScalar(value)
[numerator,denominator]=rat(value,1e-10);
end
function [numerator,denominator]=bestRational(value,maxDenominator)
bestError=Inf;numerator=0;denominator=1;
for candidateDenominator=1:maxDenominator
    candidateNumerator=round(value*candidateDenominator);
    candidateError=abs(value-candidateNumerator/candidateDenominator);
    if candidateError<bestError-10*eps(max(1,abs(value)))
        bestError=candidateError;numerator=candidateNumerator;
        denominator=candidateDenominator;
    end
end
divisor=gcd(abs(numerator),denominator);
if divisor>0
    numerator=numerator/divisor;denominator=denominator/divisor;
end
end
function axis=convertAxis(axis,latType)
axis=reshape(double(axis),1,[]);
if numel(axis)==4
    first=axis(1);second=axis(2);fourth=axis(4);
    switch lower(string(latType))
        case "h"
            axis=[2*first+second,2*second+first,fourth];
        case "r"
            axis=[2*first+second+fourth, ...
                second+fourth-first,fourth-2*second-first];
        otherwise
            axis=[first,second,fourth];
    end
end
if numel(axis)~=3
    error("KSSOLV:Matgenlab:GrainBoundary:Axis", ...
        "Rotation axes require three components.");
end
end
function basis=crystalBasisFor(latType,ratio,transformation)
latType=lower(string(latType));
if nargin>=3&&~isempty(transformation)&& ...
        max(abs(double(transformation)-eye(3)),[],"all")>1e-12
    basis=double(transformation);return
end
switch latType
    case "c"
        basis=eye(3);
    case "t"
        value=ratioValue(ratio,1,2);
        basis=diag([1,1,sqrt(value)]);
    case "o"
        if isempty(ratio)
            error("KSSOLV:Matgenlab:GrainBoundary:Ratio", ...
                "Orthorhombic lattices require an axial ratio.");
        end
        values=double(ratio);
        values(~isfinite(values))=1;
        basis=diag(sqrt([values(3),values(2),values(1)]/values(3)));
    case "h"
        value=ratioValue(ratio,1,2);
        basis=[1,0,0;-.5,sqrt(3)/2,0;0,0,sqrt(value)];
    case "r"
        if isempty(ratio),cosine=.5;
        else,cosine=1/(double(ratio(1))/double(ratio(2))-2);end
        sine=sqrt(max(0,1-cosine^2));
        thirdY=(cosine-cosine^2)/max(sine,eps);
        thirdZ=sqrt(max(0,1-cosine^2-thirdY^2));
        basis=[1,0,0;cosine,sine,0;cosine,thirdY,thirdZ];
    otherwise
        error("KSSOLV:Matgenlab:GrainBoundary:Lattice", ...
            "Lattice type is not implemented.");
end
end
function value=ratioValue(ratio,numeratorIndex,denominatorIndex)
if isempty(ratio),value=1;return,end
values=double(ratio);
if numel(values)<max(numeratorIndex,denominatorIndex)|| ...
        any(~isfinite(values([numeratorIndex,denominatorIndex])))
    value=1;
else
    value=values(numeratorIndex)/values(denominatorIndex);
end
end
function vector=rationalIntegerVector(values)
values=reshape(double(values),1,[]);
numerators=zeros(size(values));denominators=ones(size(values));
for index=1:numel(values)
    [numerators(index),denominators(index)]=rat(values(index),1e-10);
end
common=1;
for denominator=denominators,common=lcm(common,denominator);end
vector=round(numerators.*common./denominators);
vector=reduceRatio(vector);
end
function [rotation,sigma]=cslRotationData(axis,angle,latticeType,ratio)
axis=reduceRatio(round(reshape(axis,1,3)));
u=axis(1);v=axis(2);w=axis(3);
switch lower(string(latticeType))
    case "h"
        [mu,mv]=twoAxisRatio(ratio);
        divisor=gcd(abs(mu),abs(mv));
        mu=mu/divisor;mv=mv/divisor;
        d=(u^2+v^2-u*v)*mv+w^2*mu;
        [n,m]=rotationFraction(angle,d/(3*mu));
        direct=hexMatrix(u,v,w,mu,mv,n,m);
        inverse=hexMatrix(u,v,w,mu,mv,n,-m);
        factor=3*mu*m^2+d*n^2;
    case "r"
        [mu,mv]=twoAxisRatio(ratio);
        divisor=gcd(abs(mu),abs(mv));
        mu=mu/divisor;mv=mv/divisor;
        d=(u^2+v^2+w^2)*(mu-2*mv)+ ...
            2*mv*(v*w+w*u+u*v);
        [n,m]=rotationFraction(angle,d/mu);
        direct=rhoMatrix(u,v,w,mu,mv,n,m);
        inverse=rhoMatrix(u,v,w,mu,mv,n,-m);
        factor=mu*m^2+d*n^2;
    otherwise
        switch lower(string(latticeType))
            case "c"
                mu=1;lambda=1;mv=1;
            case "t"
                [mu,mv]=twoAxisRatio(ratio);
                lambda=mv;
            case "o"
                if isempty(ratio)||numel(ratio)~=3
                    error("KSSOLV:Matgenlab:GrainBoundary:Ratio", ...
                        "Orthorhombic lattices require c^2:b^2:a^2.");
                end
                values=double(ratio);
                values(~isfinite(values))=1;
                mu=values(1);lambda=values(2);mv=values(3);
                if u==0&&v==0,mu=1;end
                if u==0&&w==0,lambda=1;end
                if v==0&&w==0,mv=1;end
            otherwise
                error("KSSOLV:Matgenlab:GrainBoundary:Lattice", ...
                    "Lattice type is not implemented.");
        end
        divisor=gcdAll([mu,lambda,mv]);
        mu=mu/divisor;lambda=lambda/divisor;mv=mv/divisor;
        d=(mv*u^2+lambda*v^2)*mv+w^2*mu*mv;
        [n,m]=rotationFraction(angle,d/(mu*lambda));
        direct=ortMatrix(u,v,w,mu,lambda,mv,n,m);
        inverse=ortMatrix(u,v,w,mu,lambda,mv,n,-m);
        factor=mu*lambda*m^2+d*n^2;
end
common=gcdAll([direct,inverse,factor]);
sigma=round(factor/common);
if sigma>1000
    error("KSSOLV:Matgenlab:GrainBoundary:Sigma", ...
        "Sigma values above 1000 are not supported.");
end
rotation=reshape(double(direct)/(common*sigma),3,3).';
end
function [mu,mv]=twoAxisRatio(ratio)
if isempty(ratio),mu=1;mv=1;
elseif numel(ratio)==2&&all(isfinite(double(ratio)))
    values=round(double(ratio));mu=values(1);mv=values(2);
else
    error("KSSOLV:Matgenlab:GrainBoundary:Ratio", ...
        "The lattice requires a two-integer axial ratio.");
end
end
function [numerator,denominator]=rotationFraction(angle,metric)
if abs(angle-180)<1
    numerator=1;denominator=0;
else
    value=tand(angle/2)/sqrt(metric);
    [numerator,denominator]=rat(value,1e-8);
end
end
function result=enumTet(cutoff,axis,ratio)
axis=reduceRatio(axis);u=axis(1);v=axis(2);w=axis(3);
ratio=reduceRatio(ratio);mu=ratio(1);mv=ratio(2);
d=(u^2+v^2)*mv+w^2*mu;
nMax=floor(sqrt(cutoff*4*mu*mv/d));
result=newMap();
for n=1:nMax
    mMax=floor(sqrt(max(0,(cutoff*4*mu*mv-n^2*d)/mu)));
    for m=0:mMax
        if gcd(m,n)~=1&&m~=0,continue,end
        values=[tetMatrix(u,v,w,mu,mv,n,m), ...
            tetMatrix(u,v,w,mu,mv,n,-m),mu*m^2+d*n^2];
        sigma=round((mu*m^2+d*n^2)/gcdAll(values));
        angle=angleFor(m,n,d/mu);
        result=putSigma(result,sigma,angle,cutoff);
    end
end
end
function values=tetMatrix(u,v,w,mu,mv,n,m)
values=[ ...
 (u^2*mv-v^2*mv-w^2*mu)*n^2+mu*m^2, ...
 2*v*u*mv*n^2-2*w*mu*m*n, ...
 2*u*w*mu*n^2+2*v*mu*m*n, ...
 2*u*v*mv*n^2+2*w*mu*m*n, ...
 (v^2*mv-u^2*mv-w^2*mu)*n^2+mu*m^2, ...
 2*v*w*mu*n^2-2*u*mu*m*n, ...
 2*u*w*mv*n^2-2*v*mv*m*n, ...
 2*v*w*mv*n^2+2*u*mv*m*n, ...
 (w^2*mu-u^2*mv-v^2*mv)*n^2+mu*m^2];
end
function result=enumHex(cutoff,axis,ratio)
axis=reduceRatio(axis);
if numel(axis)==4 %#ok<ALIGN>
    u=2*axis(1)+axis(2);v=2*axis(2)+axis(1);w=axis(4);
else,u=axis(1);v=axis(2);w=axis(3);end
ratio=reduceRatio(ratio);mu=ratio(1);mv=ratio(2);
d=(u^2+v^2-u*v)*mv+w^2*mu;
nMax=floor(sqrt(cutoff*12*mu*mv/abs(d)));result=newMap();
for n=1:nMax
    mMax=floor(sqrt(max(0,(cutoff*12*mu*mv-n^2*d)/(3*mu))));
    for m=0:mMax
        if gcd(m,n)~=1&&m~=0,continue,end
        values=[hexMatrix(u,v,w,mu,mv,n,m), ...
            hexMatrix(u,v,w,mu,mv,n,-m),3*mu*m^2+d*n^2];
        sigma=round((3*mu*m^2+d*n^2)/gcdAll(values));
        angle=angleFor(m,n,d/(3*mu));
        result=putSigma(result,sigma,angle,cutoff);
    end
end
end
function values=hexMatrix(u,v,w,mu,mv,n,m)
values=[ ...
 (u^2*mv-v^2*mv-w^2*mu)*n^2+2*w*mu*m*n+3*mu*m^2, ...
 (2*v-u)*u*mv*n^2-4*w*mu*m*n, ...
 2*u*w*mu*n^2+2*(2*v-u)*mu*m*n, ...
 (2*u-v)*v*mv*n^2+4*w*mu*m*n, ...
 (v^2*mv-u^2*mv-w^2*mu)*n^2-2*w*mu*m*n+3*mu*m^2, ...
 2*v*w*mu*n^2-2*(2*u-v)*mu*m*n, ...
 (2*u-v)*w*mv*n^2-3*v*mv*m*n, ...
 (2*v-u)*w*mv*n^2+3*u*mv*m*n, ...
 (w^2*mu-u^2*mv-v^2*mv+u*v*mv)*n^2+3*mu*m^2];
end
function result=enumOrt(cutoff,axis,ratio)
axis=reduceRatio(axis);u=axis(1);v=axis(2);w=axis(3);
ratio=reduceRatio(ratio);mu=ratio(1);lam=ratio(2);mv=ratio(3);
if u==0&&v==0,mu=1;end
if u==0&&w==0,lam=1;end
if v==0&&w==0,mv=1;end
d=(mv*u^2+lam*v^2)*mv+w^2*mu*mv;
nMax=floor(sqrt(cutoff*4*mu*mv^2*lam/d));result=newMap();
for n=1:nMax
    mMax=floor(sqrt(max(0,(cutoff*4*mu*mv*lam*mv-n^2*d)/(mu*lam))));
    for m=0:mMax
        if gcd(m,n)~=1&&m~=0,continue,end
        values=[ortMatrix(u,v,w,mu,lam,mv,n,m), ...
            ortMatrix(u,v,w,mu,lam,mv,n,-m),mu*lam*m^2+d*n^2];
        sigma=round((mu*lam*m^2+d*n^2)/gcdAll(values));
        angle=angleFor(m,n,d/(mu*lam));
        result=putSigma(result,sigma,angle,cutoff);
    end
end
end
function values=ortMatrix(u,v,w,mu,lam,mv,n,m)
values=[ ...
 (u^2*mv^2-lam*v^2*mv-w^2*mu*mv)*n^2+lam*mu*m^2, ...
 2*lam*(v*u*mv*n^2-w*mu*m*n), ...
 2*mu*(u*w*mv*n^2+v*lam*m*n), ...
 2*mv*(u*v*mv*n^2+w*mu*m*n), ...
 (v^2*mv*lam-u^2*mv^2-w^2*mu*mv)*n^2+lam*mu*m^2, ...
 2*mv*mu*(v*w*n^2-u*m*n), ...
 2*mv*(u*w*mv*n^2-v*lam*m*n), ...
 2*lam*mv*(v*w*n^2+u*m*n), ...
 (w^2*mu*mv-u^2*mv^2-v^2*mv*lam)*n^2+lam*mu*m^2];
end
function result=enumRho(cutoff,axis,ratio)
axis=reduceRatio(axis);
if numel(axis)==4
    u1=axis(1);v1=axis(2);w1=axis(4);
    axis=[2*u1+v1+w1,v1+w1-u1,w1-2*v1-u1];
end
axis=reduceRatio(axis);u=axis(1);v=axis(2);w=axis(3);
ratio=reduceRatio(ratio);mu=ratio(1);mv=ratio(2);
d=(u^2+v^2+w^2)*(mu-2*mv)+2*mv*(v*w+w*u+u*v);
nMax=floor(sqrt(cutoff*abs(4*mu*(mu-3*mv))/abs(d)));
result=newMap();
for n=1:nMax
    mMax=floor(sqrt(max(0,(cutoff*abs(4*mu*(mu-3*mv))-n^2*d)/mu)));
    for m=0:mMax
        if gcd(m,n)~=1&&m~=0,continue,end
        values=[rhoMatrix(u,v,w,mu,mv,n,m), ...
            rhoMatrix(u,v,w,mu,mv,n,-m),mu*m^2+d*n^2];
        sigma=round(abs((mu*m^2+d*n^2)/gcdAll(values)));
        angle=angleFor(m,n,d/mu);
        result=putSigma(result,sigma,angle,cutoff);
    end
end
end
function values=rhoMatrix(u,v,w,mu,mv,n,m)
values=[ ...
 (mu-2*mv)*(u^2-v^2-w^2)*n^2+2*mv*(v-w)*m*n-2*mv*v*w*n^2+mu*m^2, ...
 2*(mv*u*n*(w*n+u*n-m)-(mu-mv)*m*w*n+(mu-2*mv)*u*v*n^2), ...
 2*(mv*u*n*(v*n+u*n+m)+(mu-mv)*m*v*n+(mu-2*mv)*w*u*n^2), ...
 2*(mv*v*n*(w*n+v*n+m)+(mu-mv)*m*w*n+(mu-2*mv)*u*v*n^2), ...
 (mu-2*mv)*(v^2-w^2-u^2)*n^2+2*mv*(w-u)*m*n-2*mv*u*w*n^2+mu*m^2, ...
 2*(mv*v*n*(v*n+u*n-m)-(mu-mv)*m*u*n+(mu-2*mv)*w*v*n^2), ...
 2*(mv*w*n*(w*n+v*n-m)-(mu-mv)*m*v*n+(mu-2*mv)*w*u*n^2), ...
 2*(mv*w*n*(w*n+u*n+m)+(mu-mv)*m*u*n+(mu-2*mv)*w*v*n^2), ...
 (mu-2*mv)*(w^2-u^2-v^2)*n^2+2*mv*(u-v)*m*n-2*mv*u*v*n^2+mu*m^2];
end
function map=newMap()
map=containers.Map("KeyType","double","ValueType","any");
end
function map=putSigma(map,sigma,angle,cutoff)
if sigma<=1||sigma>cutoff,return,end
if isKey(map,sigma) %#ok<ALIGN>
    values=map(sigma);
    if ~any(abs(values-angle)<1e-10),map(sigma)=[values,angle];end
else,map(sigma)=angle;end
end
function angle=angleFor(m,n,ratio)
if m==0,angle=180;else,angle=rad2deg(2*atan(n/m*sqrt(ratio)));end
end
function value=gcdAll(values)
value=0;
for item=round(abs(values)),value=gcd(value,item);end
if value==0,value=1;end
end
function options=parseOptions(options,varargin)
for index=1:2:numel(varargin)
    name=char(string(varargin{index}));
    if isfield(options,name),options.(name)=varargin{index+1};end
end
end
