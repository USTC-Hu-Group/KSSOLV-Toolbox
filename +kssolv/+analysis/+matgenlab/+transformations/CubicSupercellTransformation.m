classdef CubicSupercellTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        min_atoms (1,1) double
        max_atoms (1,1) double
        min_length (1,1) double
        max_length
        force_diagonal (1,1) logical
        force_90_degrees (1,1) logical
        allow_orthorhombic (1,1) logical
        angle_tolerance (1,1) double
        step_size (1,1) double
    end
    properties (Dependent,SetAccess=private)
        transformation_matrix
    end
    properties (Hidden,Access=private)
        state
    end
    methods
        function obj=CubicSupercellTransformation(minAtoms,maxAtoms, ...
                minLength,maxLength,forceDiagonal,force90,allowOrtho, ...
                angleTolerance,stepSize)
            if nargin<1||isempty(minAtoms),minAtoms=-Inf;end
            if nargin<2||isempty(maxAtoms),maxAtoms=Inf;end
            if nargin<3,minLength=15;end
            if nargin<4,maxLength=[];end
            if nargin<5,forceDiagonal=false;end
            if nargin<6,force90=false;end
            if nargin<7,allowOrtho=false;end
            if nargin<8,angleTolerance=1e-3;end
            if nargin<9,stepSize=.1;end
            obj.min_atoms=minAtoms;obj.max_atoms=maxAtoms;
            obj.min_length=minLength;obj.max_length=maxLength;
            obj.force_diagonal=forceDiagonal;
            obj.force_90_degrees=force90;
            obj.allow_orthorhombic=allowOrtho;
            obj.angle_tolerance=angleTolerance;obj.step_size=stepSize;
            obj.state=kssolv.analysis.matgenlab.transformations.internal.State();
        end
        function value=get.transformation_matrix(obj)
            if isempty(obj.state),value=[];else,value=obj.state.data;end
        end
        function result=apply_transformation(obj,structure)
            lattice=structure.lattice.matrix;
            if obj.allow_orthorhombic&&isempty(obj.max_length)
                error("KSSOLV:Matgenlab:CubicSupercell:MaxLength", ...
                    "max_length is required for orthorhombic cells.");
            end
            if obj.force_diagonal
                matrix=diag(ceil(obj.min_length./ ...
                    structure.lattice.lengths));
                obj.state.data=matrix;result=structure*matrix;return
            end
            if ~obj.allow_orthorhombic
                target=obj.min_length;
                for iteration=1:10000
                    [vectors,atoms,candidate,matrix]=obj. ...
                        get_possible_supercell(lattice,structure,eye(3)*target);
                    if obj.check_constraints(vectors,atoms,candidate)
                        obj.state.data=matrix;result=candidate;return
                    end
                    obj.check_exceptions(vectors,atoms);
                    target=target+obj.step_size;
                end
            else
                step=obj.step_size;
                if obj.force_90_degrees,step=step*5;end
                sizes=obj.min_length:step:(obj.max_length-step/2);
                [a,b,c]=ndgrid(sizes,sizes,sizes);
                combinations=[a(:),b(:),c(:)];
                [~,order]=sort(sum(combinations,2));
                for row=order.'
                    target=diag(combinations(row,:));
                    [vectors,atoms,candidate,matrix]=obj. ...
                        get_possible_supercell(lattice,structure,target);
                    if obj.check_constraints(vectors,atoms,candidate)
                        obj.state.data=matrix;result=candidate;return
                    end
                    obj.check_exceptions(vectors,atoms);
                end
            end
            error("KSSOLV:Matgenlab:CubicSupercell:NotFound", ...
                "Unable to find a supercell satisfying the constraints.");
        end
        function check_exceptions(obj,vectors,atoms)
            if atoms>obj.max_atoms
                error("KSSOLV:Matgenlab:CubicSupercell:MaxAtoms", ...
                    "Maximum number of atoms was exceeded.");
            end
            if ~isempty(obj.max_length)&& ...
                    max(vecnorm(vectors,2,2))>=obj.max_length
                error("KSSOLV:Matgenlab:CubicSupercell:MaxLength", ...
                    "Maximum supercell length was exceeded.");
            end
        end
        function value=check_constraints(obj,vectors,atoms,structure)
            value=min(vecnorm(vectors,2,2))>=obj.min_length&& ...
                atoms>=obj.min_atoms&&atoms<=obj.max_atoms&& ...
                (~obj.force_90_degrees||all(abs( ...
                structure.lattice.angles-90)<obj.angle_tolerance));
        end
        function [vectors,atoms,superstructure,matrix]= ...
                get_possible_supercell(~,lattice,structure,target)
            unrounded=target/lattice;
            matrix=kssolv.analysis.matgenlab.transformations. ...
                CubicSupercellTransformation.roundNonsingular(unrounded);
            proposed=matrix*lattice;
            a=proposed(1,:);b=proposed(2,:);c=proposed(3,:);
            project=@(left,right)dot(left,right)/dot(right,right)*right;
            vectors=[c-project(c,a);a-project(a,c); ...
                b-project(b,a);a-project(a,b); ...
                b-project(b,c);c-project(c,b)];
            superstructure=structure*matrix;
            atoms=superstructure.num_sites;
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                CubicSupercellTransformation(value.min_atoms, ...
                value.max_atoms,value.min_length,value.max_length, ...
                value.force_diagonal,value.force_90_degrees, ...
                value.allow_orthorhombic,value.angle_tolerance, ...
                value.step_size);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                CubicSupercellTransformation.from_dict(value);end
    end
    methods (Static,Access=private)
        function rounded=roundNonsingular(values)
            rounded=round(values);
            zeroRows=find(~any(rounded,2));
            for row=zeroRows.'
                [~,column]=max(abs(values(row,:)));
                rounded(row,column)=sign(values(row,column))* ...
                    ceil(abs(values(row,column)));
            end
            zeroColumns=find(~any(rounded,1));
            for column=zeroColumns
                rows=find(abs(values(:,column))== ...
                    max(abs(values(:,column))));
                for row=rows.'
                    rounded(row,column)=sign(values(row,column))* ...
                        ceil(abs(values(row,column)));
                end
            end
            if abs(det(rounded))<1e-12
                % Search adjacent integer matrices deterministically.
                best=[];bestError=Inf;
                for delta=-1:1
                    for row=1:3
                        for column=1:3
                            candidate=rounded;
                            candidate(row,column)=candidate(row,column)+delta;
                            if abs(det(candidate))>=1&& ...
                                    norm(candidate-values,"fro")<bestError
                                best=candidate;
                                bestError=norm(candidate-values,"fro");
                            end
                        end
                    end
                end
                if ~isempty(best),rounded=best;end
            end
            rounded=double(rounded);
        end
    end
end
