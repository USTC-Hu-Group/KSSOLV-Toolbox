classdef SymmOp < kssolv.analysis.matgenlab.util.MSONable
    %SYMMOP Affine symmetry operation on points and tensors in three dimensions.
    %
    % The operation follows pymatgen's column-vector convention internally:
    %     p' = R*p + t
    % Public coordinate arrays may be either 1-by-3 or N-by-3.
    %
    % This implementation is based on pymatgen-core v2026.7.24
    % (MIT licensed), pymatgen.core.operations.SymmOp.

    properties (SetAccess = private)
        affineMatrix (4, 4) double
    end

    properties
        tol (1, 1) double {mustBeNonnegative} = 0.01
    end

    properties (Dependent, SetAccess = private)
        affine_matrix
        rotationMatrix
        rotation_matrix
        translationVector
        translation_vector
        inverse
    end

    methods
        function obj = SymmOp(affineTransformationMatrix, tol)
            arguments
                affineTransformationMatrix double
                tol (1, 1) double {mustBeNonnegative} = 0.01
            end
            if ~isequal(size(affineTransformationMatrix), [4, 4])
                error("KSSOLV:Matgenlab:SymmOp:InvalidAffineMatrix", ...
                    "Affine matrix must be a 4-by-4 numeric array.");
            end
            if any(~isfinite(affineTransformationMatrix), "all")
                error("KSSOLV:Matgenlab:SymmOp:NonFiniteAffineMatrix", ...
                    "Affine matrix entries must be finite.");
            end
            obj.affineMatrix = double(affineTransformationMatrix);
            obj.tol = tol;
        end

        function value = get.affine_matrix(obj)
            value = obj.affineMatrix;
        end

        function value = get.rotationMatrix(obj)
            value = obj.affineMatrix(1:3, 1:3);
        end

        function value = get.rotation_matrix(obj)
            value = obj.rotationMatrix;
        end

        function value = get.translationVector(obj)
            value = obj.affineMatrix(1:3, 4).';
        end

        function value = get.translation_vector(obj)
            value = obj.translationVector;
        end

        function value = get.inverse(obj)
            if isa(obj, "kssolv.analysis.matgenlab.core.MagSymmOp")
                value = kssolv.analysis.matgenlab.core.MagSymmOp( ...
                    inv(obj.affineMatrix), obj.timeReversal, obj.tol);
            else
                value = kssolv.analysis.matgenlab.core.SymmOp( ...
                    inv(obj.affineMatrix), obj.tol);
            end
        end

        function tf = eq(obj, other)
            tf = isa(other, "kssolv.analysis.matgenlab.core.SymmOp") && ...
                all(abs(obj.affineMatrix - other.affineMatrix) <= ...
                obj.tol + 1e-5 * abs(other.affineMatrix), "all");
        end

        function tf = ne(obj, other)
            tf = ~eq(obj, other);
        end

        function result = mtimes(obj, other)
            %MTIMES Compose operations: apply other, followed by obj.
            if ~isa(other, "kssolv.analysis.matgenlab.core.SymmOp")
                error("KSSOLV:Matgenlab:SymmOp:InvalidComposition", ...
                    "SymmOp can only be composed with another SymmOp.");
            end
            result = kssolv.analysis.matgenlab.core.SymmOp( ...
                obj.affineMatrix * other.affineMatrix, obj.tol);
        end

        function pointsOut = operate(obj, points)
            arguments
                obj
                points double
            end
            wasVector = isvector(points);
            points = kssolv.analysis.matgenlab.core.SymmOp.requireCoords( ...
                points, "points");
            pointsOut = points * obj.rotationMatrix.' + ...
                obj.translationVector;
            if wasVector
                pointsOut = reshape(pointsOut, 1, 3);
            end
        end

        function pointsOut = operateMulti(obj, points)
            pointsOut = obj.operate(points);
        end

        function pointsOut = operate_multi(obj, points)
            pointsOut = obj.operate(points);
        end

        function vectorsOut = applyRotationOnly(obj, vectors)
            arguments
                obj
                vectors double
            end
            wasColumn = iscolumn(vectors) && numel(vectors) == 3;
            vectors = kssolv.analysis.matgenlab.core.SymmOp.requireCoords( ...
                vectors, "vectors");
            vectorsOut = vectors * obj.rotationMatrix.';
            if wasColumn
                vectorsOut = vectorsOut.';
            end
        end

        function vectorsOut = apply_rotation_only(obj, vectors)
            vectorsOut = obj.applyRotationOnly(vectors);
        end

        function transformed = transformTensor(obj, tensor)
            arguments
                obj
                tensor {mustBeNumeric}
            end
            tensorSize = size(tensor);
            wasRowVector = isrow(tensor) && numel(tensor) == 3;
            if isvector(tensor) && numel(tensor) == 3
                rank = 1;
                tensorSize = [3, 1];
                tensor = tensor(:);
            elseif ismatrix(tensor)
                rank = 2;
                tensorSize = size(tensor);
            else
                rank = ndims(tensor);
            end
            if any(tensorSize(1:rank) ~= 3)
                error("KSSOLV:Matgenlab:SymmOp:InvalidTensor", ...
                    "Every tensor dimension must have length three.");
            end
            transform = 1;
            for idx = 1:rank
                transform = kron(obj.rotationMatrix, transform);
            end
            transformed = reshape(transform * tensor(:), tensorSize);
            if rank == 1 && wasRowVector
                transformed = transformed.';
            end
        end

        function transformed = transform_tensor(obj, tensor)
            transformed = obj.transformTensor(tensor);
        end

        function tf = areSymmetricallyRelated(obj, pointA, pointB, tol)
            arguments
                obj
                pointA double
                pointB double
                tol (1, 1) double {mustBeNonnegative} = 0.001
            end
            pointA = reshape(pointA, 1, []);
            pointB = reshape(pointB, 1, []);
            tf = all(abs(obj.operate(pointA) - pointB) <= tol) || ...
                all(abs(obj.operate(pointB) - pointA) <= tol);
        end

        function tf = are_symmetrically_related(obj, pointA, pointB, tol)
            if nargin < 4
                tol = 0.001;
            end
            tf = obj.areSymmetricallyRelated(pointA, pointB, tol);
        end

        function [related, reversed] = areSymmetricallyRelatedVectors( ...
                obj, fromA, toA, rA, fromB, toB, rB, tol)
            arguments
                obj
                fromA (1, 3) double
                toA (1, 3) double
                rA (1, 3) double
                fromB (1, 3) double
                toB (1, 3) double
                rB (1, 3) double
                tol (1, 1) double {mustBeNonnegative} = 0.001
            end
            fromC = obj.operate(fromA);
            toC = obj.operate(toA);
            vectors = [fromC; toC];
            floored = floor(vectors);
            nearUpperBoundary = abs(vectors - floored) > 1 - tol;
            floored(nearUpperBoundary) = floored(nearUpperBoundary) + 1;
            rC = obj.applyRotationOnly(rA) - floored(1, :) + floored(2, :);
            fromC = mod(fromC, 1);
            toC = mod(toC, 1);

            direct = all(abs(fromB - fromC) <= tol) && ...
                all(abs(toB - toC) <= tol) && all(abs(rB - rC) <= tol);
            reverse = all(abs(toB - fromC) <= tol) && ...
                all(abs(fromB - toC) <= tol) && all(abs(rB + rC) <= tol);
            related = direct || reverse;
            reversed = ~direct && reverse;
        end

        function [related, reversed] = are_symmetrically_related_vectors( ...
                obj, fromA, toA, rA, fromB, toB, rB, tol)
            if nargin < 9
                tol = 0.001;
            end
            [related, reversed] = obj.areSymmetricallyRelatedVectors( ...
                fromA, toA, rA, fromB, toB, rB, tol);
        end

        function data = asDict(obj)
            data = struct( ...
                "x_module", "pymatgen.core.operations", ...
                "x_class", "SymmOp", ...
                "matrix", obj.affineMatrix, ...
                "tolerance", obj.tol);
        end

        function data = as_dict(obj)
            data = obj.asDict();
        end

        function xyz = asXyzString(obj)
            if any(abs(obj.rotationMatrix - round(obj.rotationMatrix)) > ...
                    max(obj.tol, 1e-8), "all")
                warning("KSSOLV:Matgenlab:SymmOp:NonIntegerRotation", ...
                    "Rotation matrix should be integer.");
            end
            variables = ["x", "y", "z"];
            expressions = strings(1, 3);
            for row = 1:3
                expression = "";
                for col = 1:3
                    coefficient = obj.rotationMatrix(row, col);
                    if abs(coefficient) < 1e-12
                        continue
                    end
                    expression = expression + ...
                        kssolv.analysis.matgenlab.core.SymmOp.formatTerm( ...
                        coefficient, variables(col), strlength(expression) > 0);
                end
                translation = obj.translationVector(row);
                if abs(translation) >= 1e-12
                    expression = expression + ...
                        kssolv.analysis.matgenlab.core.SymmOp.formatNumber( ...
                        translation, strlength(expression) > 0);
                end
                if strlength(expression) == 0
                    expression = "0";
                end
                expressions(row) = expression;
            end
            xyz = strjoin(expressions, ", ");
        end

        function xyz = as_xyz_str(obj)
            xyz = obj.asXyzString();
        end

        function text = string(obj)
            text = "Rot:" + newline + string(mat2str(obj.rotationMatrix)) + ...
                newline + "tau" + newline + string(mat2str(obj.translationVector));
        end

        function disp(obj)
            fprintf("%s\n", obj.string());
        end
    end

    methods (Static)
        function obj = fromRotationAndTranslation(rotationMatrix, ...
                translationVector, tol)
            arguments
                rotationMatrix double = eye(3)
                translationVector double = [0, 0, 0]
                tol (1, 1) double {mustBeNonnegative} = 0.1
            end
            if ~isequal(size(rotationMatrix), [3, 3])
                error("KSSOLV:Matgenlab:SymmOp:InvalidRotationMatrix", ...
                    "Rotation matrix must be a 3-by-3 numeric array.");
            end
            if numel(translationVector) ~= 3 || ~isvector(translationVector)
                error("KSSOLV:Matgenlab:SymmOp:InvalidTranslationVector", ...
                    "Translation vector must contain exactly three elements.");
            end
            matrix = eye(4);
            matrix(1:3, 1:3) = rotationMatrix;
            matrix(1:3, 4) = translationVector(:);
            obj = kssolv.analysis.matgenlab.core.SymmOp(matrix, tol);
        end

        function obj = from_rotation_and_translation(rotationMatrix, ...
                translationVector, options)
            arguments
                rotationMatrix double = eye(3)
                translationVector double = [0, 0, 0]
                options.tol (1, 1) double {mustBeNonnegative} = 0.1
            end
            obj = kssolv.analysis.matgenlab.core.SymmOp. ...
                fromRotationAndTranslation(rotationMatrix, translationVector, ...
                options.tol);
        end

        function obj = fromAxisAngleAndTranslation(axis, angle, ...
                angleInRadians, translationVector)
            arguments
                axis double
                angle (1, 1) double
                angleInRadians (1, 1) logical = false
                translationVector double = [0, 0, 0]
            end
            if numel(axis) ~= 3 || norm(axis) <= eps
                error("KSSOLV:Matgenlab:SymmOp:InvalidAxis", ...
                    "Rotation axis must be a nonzero three-element vector.");
            end
            axis = axis(:) / norm(axis);
            if ~angleInRadians
                angle = deg2rad(angle);
            end
            crossMatrix = [0, -axis(3), axis(2); ...
                axis(3), 0, -axis(1); -axis(2), axis(1), 0];
            rotation = cos(angle) * eye(3) + ...
                (1 - cos(angle)) * (axis * axis.') + sin(angle) * crossMatrix;
            obj = kssolv.analysis.matgenlab.core.SymmOp. ...
                fromRotationAndTranslation(rotation, translationVector);
        end

        function obj = from_axis_angle_and_translation(axis, angle, options)
            arguments
                axis double
                angle (1, 1) double
                options.angle_in_radians (1, 1) logical = false
                options.translation_vec double = [0, 0, 0]
            end
            obj = kssolv.analysis.matgenlab.core.SymmOp. ...
                fromAxisAngleAndTranslation(axis, angle, ...
                options.angle_in_radians, options.translation_vec);
        end

        function obj = fromOriginAxisAngle(origin, axis, angle, angleInRadians)
            arguments
                origin double
                axis double
                angle (1, 1) double
                angleInRadians (1, 1) logical = false
            end
            rotationOnly = kssolv.analysis.matgenlab.core.SymmOp. ...
                fromAxisAngleAndTranslation(axis, angle, angleInRadians);
            origin = reshape(origin, 1, []);
            if numel(origin) ~= 3
                error("KSSOLV:Matgenlab:SymmOp:InvalidOrigin", ...
                    "Origin must contain exactly three elements.");
            end
            translation = origin - origin * rotationOnly.rotationMatrix.';
            obj = kssolv.analysis.matgenlab.core.SymmOp. ...
                fromRotationAndTranslation(rotationOnly.rotationMatrix, translation);
        end

        function obj = from_origin_axis_angle(origin, axis, angle, options)
            arguments
                origin double
                axis double
                angle (1, 1) double
                options.angle_in_radians (1, 1) logical = false
            end
            obj = kssolv.analysis.matgenlab.core.SymmOp. ...
                fromOriginAxisAngle(origin, axis, angle, ...
                options.angle_in_radians);
        end

        function obj = reflection(normal, origin)
            arguments
                normal double
                origin double = [0, 0, 0]
            end
            if numel(normal) ~= 3 || norm(normal) <= eps
                error("KSSOLV:Matgenlab:SymmOp:InvalidNormal", ...
                    "Reflection normal must be a nonzero three-element vector.");
            end
            normal = normal(:) / norm(normal);
            rotation = eye(3) - 2 * (normal * normal.');
            origin = reshape(origin, 1, []);
            translation = origin - origin * rotation.';
            obj = kssolv.analysis.matgenlab.core.SymmOp. ...
                fromRotationAndTranslation(rotation, translation, 0.01);
        end

        function obj = inversion(origin)
            arguments
                origin double = [0, 0, 0]
            end
            origin = reshape(origin, 1, []);
            if numel(origin) ~= 3
                error("KSSOLV:Matgenlab:SymmOp:InvalidOrigin", ...
                    "Origin must contain exactly three elements.");
            end
            obj = kssolv.analysis.matgenlab.core.SymmOp. ...
                fromRotationAndTranslation(-eye(3), 2 * origin, 0.01);
        end

        function obj = rotoreflection(axis, angle, origin)
            arguments
                axis double
                angle (1, 1) double
                origin double = [0, 0, 0]
            end
            rotation = kssolv.analysis.matgenlab.core.SymmOp. ...
                fromOriginAxisAngle(origin, axis, angle);
            mirror = kssolv.analysis.matgenlab.core.SymmOp.reflection(axis, origin);
            obj = rotation * mirror;
        end

        function obj = fromXyzString(xyzString)
            arguments
                xyzString (1, 1) string
            end
            tokens = split(lower(erase(xyzString, " ")), ",");
            if numel(tokens) ~= 3
                error("KSSOLV:Matgenlab:SymmOp:InvalidXyzString", ...
                    "XYZ symmetry string must contain three comma-separated expressions.");
            end
            rotation = zeros(3);
            translation = zeros(1, 3);
            for row = 1:3
                [rotation(row, :), translation(row)] = ...
                    kssolv.analysis.matgenlab.core.SymmOp.parseExpression(tokens(row));
            end
            obj = kssolv.analysis.matgenlab.core.SymmOp. ...
                fromRotationAndTranslation(rotation, translation);
        end

        function obj = from_xyz_str(xyzString)
            obj = kssolv.analysis.matgenlab.core.SymmOp.fromXyzString( ...
                string(xyzString));
        end

        function obj = fromDict(data)
            arguments
                data (1, 1) struct
            end
            if isfield(data, "tolerance")
                tolerance = data.tolerance;
            else
                tolerance = 0.01;
            end
            obj = kssolv.analysis.matgenlab.core.SymmOp(data.matrix, tolerance);
        end

        function obj = from_dict(data)
            obj = kssolv.analysis.matgenlab.core.SymmOp.fromDict(data);
        end
    end

    methods (Static, Access = private)
        function coordinates = requireCoords(coordinates, name)
            if isempty(coordinates)
                coordinates = zeros(0, 3);
                return
            end
            if isvector(coordinates) && numel(coordinates) == 3
                coordinates = reshape(coordinates, 1, 3);
            elseif ~ismatrix(coordinates) || size(coordinates, 2) ~= 3
                error("KSSOLV:Matgenlab:SymmOp:InvalidCoordinates", ...
                    "%s must be a three-element vector or N-by-3 array.", name);
            end
            if any(~isfinite(coordinates), "all")
                error("KSSOLV:Matgenlab:SymmOp:NonFiniteCoordinates", ...
                    "%s must contain finite values.", name);
            end
        end

        function text = formatTerm(coefficient, variable, hasPrevious)
            magnitude = abs(coefficient);
            if abs(magnitude - 1) < 1e-10
                body = variable;
            else
                body = kssolv.analysis.matgenlab.core.SymmOp. ...
                    unsignedNumber(magnitude) + variable;
            end
            if coefficient < 0
                text = "-" + body;
            elseif hasPrevious
                text = "+" + body;
            else
                text = body;
            end
        end

        function text = formatNumber(value, hasPrevious)
            body = kssolv.analysis.matgenlab.core.SymmOp. ...
                unsignedNumber(abs(value));
            if value < 0
                text = "-" + body;
            elseif hasPrevious
                text = "+" + body;
            else
                text = body;
            end
        end

        function text = unsignedNumber(value)
            value = round(value, 10);
            [numerator, denominator] = rat(value, 1e-6);
            if denominator <= 1000 && abs(value - numerator / denominator) <= 1e-6
                if denominator == 1
                    text = string(numerator);
                else
                    text = string(numerator) + "/" + string(denominator);
                end
            else
                text = string(sprintf("%.10g", value));
            end
        end

        function [coefficients, translation] = parseExpression(expression)
            expression = char(expression);
            if isempty(expression)
                error("KSSOLV:Matgenlab:SymmOp:InvalidXyzString", ...
                    "Empty coordinate expression.");
            end
            if expression(1) ~= '+' && expression(1) ~= '-'
                expression = ['+', expression];
            end
            pieces = regexp(expression, '([+-])([^+-]+)', 'tokens');
            coefficients = zeros(1, 3);
            translation = 0;
            for idx = 1:numel(pieces)
                signValue = 1;
                if strcmp(pieces{idx}{1}, "-")
                    signValue = -1;
                end
                term = pieces{idx}{2};
                variable = regexp(term, '[xyz]', 'match', 'once');
                if isempty(variable)
                    translation = translation + signValue * ...
                        kssolv.analysis.matgenlab.core.SymmOp.parseNumber(term);
                else
                    coefficientText = erase(term, variable);
                    if isempty(coefficientText)
                        coefficient = 1;
                    else
                        coefficient = ...
                            kssolv.analysis.matgenlab.core.SymmOp. ...
                            parseNumber(coefficientText);
                    end
                    col = double(variable) - double('x') + 1;
                    coefficients(col) = coefficients(col) + ...
                        signValue * coefficient;
                end
            end
        end

        function value = parseNumber(text)
            pieces = split(string(text), "/");
            if isscalar(pieces)
                value = str2double(pieces(1));
            elseif numel(pieces) == 2
                value = str2double(pieces(1)) / str2double(pieces(2));
            else
                value = NaN;
            end
            if ~isfinite(value)
                error("KSSOLV:Matgenlab:SymmOp:InvalidXyzString", ...
                    "Could not parse numeric expression '%s'.", text);
            end
        end
    end
end
