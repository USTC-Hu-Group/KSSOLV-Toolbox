classdef InterfaceCandidateBuilder
    %INTERFACECANDIDATEBUILDER Rank commensurate two-dimensional supercells.

    methods (Static)
        function candidates = enumerate(bottom, top, options)
            arguments
                bottom
                top
                options.maximumRepeat (1,1) double = 6
                options.maximumCandidates (1,1) double = 20
                options.sortMode string = "strain"
                options.maximumRotation (1,1) double = 30
                options.rotationStep (1,1) double {mustBePositive} = 5
            end
            import kssolv.modeling.builders.BuilderUtils
            BuilderUtils.requireTwoDimensional(bottom);
            BuilderUtils.requireTwoDimensional(top);
            maximumRepeat=positiveInteger(options.maximumRepeat, ...
                "Maximum repeat");
            maximumCandidates=positiveInteger(options.maximumCandidates, ...
                "Maximum candidates");
            sortMode=lower(string(options.sortMode));
            if ~any(sortMode == ["strain", "area", "atom_count"])
                error("KSSOLV:Modeling:InterfaceSort", ...
                    "Interface sort mode must be strain, area, or atom_count.");
            end
            maximumRotation=abs(double(options.maximumRotation));
            if ~isscalar(maximumRotation) || ~isfinite(maximumRotation)
                error("KSSOLV:Modeling:InterfaceRotation", ...
                    "Maximum rotation must be a finite scalar.");
            end
            % rotationStep remains in the public schema for recipe
            % compatibility. Matrix matching derives the optimal angle
            % analytically and therefore does not quantize it.

            bottomPlane=bottom.lattice.matrix(1:2,:);
            topPlane=top.lattice.matrix(1:2,:);
            transforms=hermiteTransforms(maximumRepeat);
            prototype=struct("index",0,"bottomRepeat",[1,1,1], ...
                "topRepeat",[1,1,1],"bottomTransform",eye(3), ...
                "topTransform",eye(3),"area",0,"strain",0, ...
                "rotationDegrees",0,"atomCount",0);
            values=repmat(prototype,1,0);
            bottomArea=norm(cross(bottomPlane(1,:),bottomPlane(2,:)));
            for bottomIndex=1:numel(transforms)
                bottomTransform=transforms{bottomIndex};
                bottomDeterminant=round(abs(det(bottomTransform)));
                candidateBottom=bottomTransform(1:2,1:2)*bottomPlane;
                for topIndex=1:numel(transforms)
                    topTransform=transforms{topIndex};
                    topDeterminant=round(abs(det(topTransform)));
                    candidateTop=topTransform(1:2,1:2)*topPlane;
                    [rotation,alignedTop]=optimalAlignment( ...
                        candidateBottom,candidateTop);
                    if abs(rotation)>maximumRotation+1e-10
                        continue
                    end
                    strain=BuilderUtils.inPlanePrincipalStrain( ...
                        candidateBottom,alignedTop);
                    value=prototype;
                    value.bottomRepeat=[bottomDeterminant,1,1];
                    value.topRepeat=[topDeterminant,1,1];
                    value.bottomTransform=bottomTransform;
                    value.topTransform=topTransform;
                    value.area=bottomArea*bottomDeterminant;
                    value.strain=strain;
                    value.rotationDegrees=rotation;
                    value.atomCount=bottom.num_sites*bottomDeterminant + ...
                        top.num_sites*topDeterminant;
                    values(end+1)=value; %#ok<AGROW>
                end
            end
            if isempty(values)
                error("KSSOLV:Modeling:InterfaceCandidates", ...
                    "No interface candidate satisfies the rotation limit.");
            end
            switch sortMode
                case "strain"
                    keys=[[values.strain].',[values.area].', ...
                        abs([values.rotationDegrees].'),[values.atomCount].'];
                case "area"
                    keys=[[values.area].',[values.strain].', ...
                        abs([values.rotationDegrees].'),[values.atomCount].'];
                case "atom_count"
                    keys=[[values.atomCount].',[values.strain].', ...
                        [values.area].',abs([values.rotationDegrees].')];
            end
            [~,order]=sortrows(keys,1:size(keys,2));
            values=values(order);
            values=values(1:min(numel(values),maximumCandidates));
            for index=1:numel(values), values(index).index=index; end
            candidates=values;
        end
    end
end

function transforms=hermiteTransforms(maximumDeterminant)
transforms=cell(1,0);
for determinant=1:maximumDeterminant
    for first=1:determinant
        if mod(determinant,first)~=0, continue, end
        second=determinant/first;
        for shear=0:second-1
            transforms{end+1}=[first,shear,0;0,second,0;0,0,1]; %#ok<AGROW>
        end
    end
end
end

function [angleDegrees,aligned]=optimalAlignment(reference,source)
first=reference(1,:); normal=cross(first,reference(2,:));
if norm(first)<=1e-12 || norm(normal)<=1e-12
    error("KSSOLV:Modeling:DegeneratePlane", ...
        "The interface lattice vectors must be independent.");
end
first=first/norm(first); normal=normal/norm(normal);
second=cross(normal,first);
reference2=[reference*first.',reference*second.'];
source2=[source*first.',source*second.'];
[left,~,right]=svd(source2.'*reference2);
rotation=right*diag([1,sign(det(right*left.'))])*left.';
angleDegrees=atan2d(rotation(2,1),rotation(1,1));
matrix=axisRotation(normal,angleDegrees);
aligned=source*matrix.';
end

function matrix=axisRotation(axis,angleDegrees)
axis=axis/norm(axis); x=axis(1); y=axis(2); z=axis(3);
c=cosd(angleDegrees); s=sind(angleDegrees); t=1-c;
matrix=[t*x*x+c,t*x*y-s*z,t*x*z+s*y; ...
    t*x*y+s*z,t*y*y+c,t*y*z-s*x; ...
    t*x*z-s*y,t*y*z+s*x,t*z*z+c];
end

function value=positiveInteger(value,name)
value=double(value);
if ~isscalar(value) || ~isfinite(value) || value<1 || value~=fix(value)
    error("KSSOLV:Modeling:InterfaceRepeat", ...
        "%s must be a positive integer.",name);
end
end
