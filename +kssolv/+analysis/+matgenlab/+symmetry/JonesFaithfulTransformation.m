classdef JonesFaithfulTransformation
    %JONESFAITHFULTRANSFORMATION Change of crystallographic setting.
    properties (Access=private)
        matrixP (3,3) double = eye(3)
        originP (1,3) double = [0,0,0]
    end
    properties (Dependent)
        P
        p
        inverse
        transformation_string
    end
    methods
        function obj=JonesFaithfulTransformation(P,p)
            if nargin<1,P=eye(3);end
            if nargin<2,p=[0,0,0];end
            if ~isequal(size(P),[3,3])||numel(p)~=3|| ...
                    any(~isfinite(P),"all")||any(~isfinite(p),"all")
                error("KSSOLV:Matgenlab:JonesFaithful:Size", ...
                    "P must be finite 3-by-3 and p must have 3 elements.");
            end
            if abs(det(P))<1e-14
                error("KSSOLV:Matgenlab:JonesFaithful:Singular", ...
                    "The setting transformation matrix is singular.");
            end
            obj.matrixP=double(P);
            obj.originP=reshape(double(p),1,3);
        end

        function value=get.P(obj),value=obj.matrixP;end
        function value=get.p(obj),value=obj.originP;end
        function value=get.inverse(obj)
            inverseP=obj.matrixP\eye(3);
            value=kssolv.analysis.matgenlab.symmetry. ...
                JonesFaithfulTransformation(inverseP, ...
                -(inverseP*obj.originP.').');
        end
        function value=get.transformation_string(obj)
            value=kssolv.analysis.matgenlab.util. ...
                transformation_to_string(obj.matrixP.',[0,0,0], ...
                ["a","b","c"])+...
                ";"+kssolv.analysis.matgenlab.util. ...
                transformation_to_string(zeros(3),obj.originP);
        end
        function transformed=transform_symmop(obj,symmetryOperation)
            rotation=obj.matrixP\( ...
                symmetryOperation.rotation_matrix*obj.matrixP);
            translation=(obj.matrixP\( ...
                symmetryOperation.translation_vector.'+ ...
                (symmetryOperation.rotation_matrix-eye(3))* ...
                obj.originP.')).';
            translation=mod(translation,1);
            if isa(symmetryOperation, ...
                    "kssolv.analysis.matgenlab.core.MagSymmOp")
                transformed=kssolv.analysis.matgenlab.core.MagSymmOp. ...
                    fromRotationAndTranslationAndTimeReversal( ...
                    rotation,translation, ...
                    symmetryOperation.time_reversal, ...
                    symmetryOperation.tol);
            elseif isa(symmetryOperation, ...
                    "kssolv.analysis.matgenlab.core.SymmOp")
                transformed=kssolv.analysis.matgenlab.core.SymmOp. ...
                    fromRotationAndTranslation(rotation,translation, ...
                    symmetryOperation.tol);
            else
                error("KSSOLV:Matgenlab:JonesFaithful:OperationType", ...
                    "Expected a SymmOp or MagSymmOp.");
            end
        end
        function transformed=transformSymmop(obj,symmetryOperation)
            transformed=obj.transform_symmop(symmetryOperation);
        end
        function transformed=transform_coords(obj,coordinates)
            coordinates=double(coordinates);
            if isvector(coordinates),coordinates=reshape(coordinates,1,[]);end
            if size(coordinates,2)~=3
                error("KSSOLV:Matgenlab:JonesFaithful:Coordinates", ...
                    "Coordinates must be N-by-3.");
            end
            transformed=(obj.matrixP\(coordinates-obj.originP).').';
        end
        function transformed=transformCoords(obj,coordinates)
            transformed=obj.transform_coords(coordinates);
        end
        function transformed=transform_lattice(obj,lattice)
            transformed=kssolv.analysis.matgenlab.core.Lattice( ...
                lattice.matrix*obj.matrixP);
        end
        function transformed=transformLattice(obj,lattice)
            transformed=obj.transform_lattice(lattice);
        end
        function equal=eq(obj,other)
            equal=isa(other,class(obj))&& ...
                all(abs(obj.matrixP-other.matrixP)<1e-8,"all")&& ...
                all(abs(obj.originP-other.originP)<1e-8,"all");
        end
        function equal=ne(obj,other),equal=~(obj==other);end
        function text=char(obj),text=char(obj.transformation_string);end
    end
    methods (Static)
        function obj=from_transformation_str(transformationString)
            if nargin<1,transformationString="a,b,c;0,0,0";end
            [matrix,origin]=kssolv.analysis.matgenlab.symmetry. ...
                JonesFaithfulTransformation. ...
                parse_transformation_string(transformationString);
            obj=kssolv.analysis.matgenlab.symmetry. ...
                JonesFaithfulTransformation(matrix,origin);
        end
        function obj=fromTransformationStr(transformationString)
            if nargin<1,transformationString="a,b,c;0,0,0";end
            obj=kssolv.analysis.matgenlab.symmetry. ...
                JonesFaithfulTransformation. ...
                from_transformation_str(transformationString);
        end
        function obj=from_origin_shift(originShift)
            if nargin<1,originShift="0,0,0";end
            pieces=split(string(originShift),",");
            if numel(pieces)~=3
                error("KSSOLV:Matgenlab:JonesFaithful:Parse", ...
                    "Origin shift must contain three components.");
            end
            origin=arrayfun(@parseScalar,pieces);
            obj=kssolv.analysis.matgenlab.symmetry. ...
                JonesFaithfulTransformation(eye(3),origin);
        end
        function obj=fromOriginShift(originShift)
            if nargin<1,originShift="0,0,0";end
            obj=kssolv.analysis.matgenlab.symmetry. ...
                JonesFaithfulTransformation.from_origin_shift(originShift);
        end
        function [matrix,origin]= ...
                parse_transformation_string(transformationString)
            try
                sections=split(string(transformationString),";");
                if numel(sections)~=2
                    error("KSSOLV:Matgenlab:JonesFaithful:Sections", ...
                        "Expected exactly one semicolon.");
                end
                basis=split(sections(1),",");
                shifts=split(sections(2),",");
                if numel(basis)~=3||numel(shifts)~=3
                    error("KSSOLV:Matgenlab:JonesFaithful:Components", ...
                        "Basis and origin must each contain 3 components.");
                end
                matrix=zeros(3);
                for column=1:3
                    matrix(:,column)=parseLinear(basis(column)).';
                end
                origin=arrayfun(@parseScalar,shifts);
                origin=reshape(origin,1,3);
            catch exception
                wrapped=MException( ...
                    "KSSOLV:Matgenlab:JonesFaithful:Parse", ...
                    "Failed to parse transformation string: %s", ...
                    exception.message);
                wrapped=addCause(wrapped,exception);
                throw(wrapped);
            end
        end
        function [matrix,origin]= ...
                parseTransformationString(transformationString)
            if nargin<1,transformationString="a,b,c;0,0,0";end
            [matrix,origin]=kssolv.analysis.matgenlab.symmetry. ...
                JonesFaithfulTransformation. ...
                parse_transformation_string(transformationString);
        end
    end
end

function coefficients=parseLinear(expression)
expression=lower(regexprep(char(expression),"\s+",""));
if isempty(expression)||~isempty(regexp(expression,"[^0-9abc+\-*/.()]","once"))
    error("KSSOLV:Matgenlab:JonesFaithful:Characters", ...
        "Basis expression contains invalid characters.");
end
expanded='';
for index=1:numel(expression)
    if index>1
        previous=expression(index-1);current=expression(index);
        leftToken=isstrprop(previous,"digit")|| ...
            ismember(previous,'abc')||previous==')';
        rightToken=ismember(current,'abc')||current=='('|| ...
            (previous==')'&&isstrprop(current,"digit"));
        if leftToken&&rightToken,expanded(end+1)='*';end %#ok<AGROW>
    end
    expanded(end+1)=expression(index); %#ok<AGROW>
end
expression=expanded;
evaluator=str2func("@(a,b,c)"+string(expression));
constant=evaluator(0,0,0);
coefficients=[evaluator(1,0,0),evaluator(0,1,0), ...
    evaluator(0,0,1)]-constant;
probe=[0.37,-0.21,0.43];
if abs(evaluator(probe(1),probe(2),probe(3))- ...
        (constant+dot(coefficients,probe)))>1e-10|| ...
        abs(constant)>1e-12||any(~isfinite(coefficients))
    error("KSSOLV:Matgenlab:JonesFaithful:Nonlinear", ...
        "Basis expressions must be finite and linear in a, b and c.");
end
end

function value=parseScalar(expression)
expression=regexprep(char(expression),"\s+","");
if isempty(expression)||~isempty(regexp(expression,"[^0-9+\-*/.()]","once"))
    error("KSSOLV:Matgenlab:JonesFaithful:OriginCharacters", ...
        "Origin expression contains invalid characters.");
end
evaluator=str2func("@()"+string(expression));
value=evaluator();
if ~isscalar(value)||~isfinite(value)
    error("KSSOLV:Matgenlab:JonesFaithful:OriginValue", ...
        "Origin components must be finite scalars.");
end
end
