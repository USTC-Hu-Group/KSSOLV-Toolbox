classdef SquareTensor < kssolv.analysis.matgenlab.core.Tensor
    %SQUARETENSOR Rank-two 3-by-3 Tensor convenience class.

    properties (Dependent, SetAccess = private)
        trans
        inv
        det
        principal_invariants
    end

    methods
        function obj = SquareTensor(input_array, vscale)
            arguments
                input_array {mustBeNumeric}
                vscale double = []
            end
            if isempty(vscale)
                args = {input_array, [], 2};
            else
                args = {input_array, vscale, 2};
            end
            obj@kssolv.analysis.matgenlab.core.Tensor(args{:});
        end

        function value = get.trans(obj)
            value = kssolv.analysis.matgenlab.core.SquareTensor( ...
                double(obj).', obj.vscale);
        end

        function value = get.inv(obj)
            if obj.det == 0
                error("KSSOLV:Matgenlab:SquareTensor:NonInvertible", ...
                    "SquareTensor is non-invertible");
            end
            value = kssolv.analysis.matgenlab.core.SquareTensor( ...
                builtin("inv", double(obj)), obj.vscale);
        end

        function value = get.det(obj)
            value = builtin("det", double(obj));
        end

        function tf = is_rotation(obj, tol, include_improper)
            arguments
                obj
                tol (1,1) double {mustBeNonnegative} = 0.001
                include_improper (1,1) logical = true
            end
            determinant = builtin("det", double(obj));
            if abs(determinant) <= eps(max(1,norm(double(obj),"fro")))
                tf = false;
                return
            end
            if include_improper
                determinant = abs(determinant);
            end
            tf = all(abs(double(obj.inv)-double(obj.trans)) <= tol, "all") && ...
                abs(determinant - 1) <= tol;
        end

        function result = refine_rotation(obj)
            values = double(obj);
            newX = kssolv.analysis.matgenlab.core.get_uvec(values(1,:));
            y = kssolv.analysis.matgenlab.core.get_uvec(values(2,:));
            newY = y - dot(newX,y)*newX;
            newZ = cross(newX,newY);
            result = kssolv.analysis.matgenlab.core.SquareTensor( ...
                [newX;newY;newZ], obj.vscale);
        end

        function result = get_scaled(obj, scale_factor)
            arguments
                obj
                scale_factor (1,1) double
            end
            result = kssolv.analysis.matgenlab.core.SquareTensor( ...
                double(obj)*scale_factor, obj.vscale);
        end

        function values = get.principal_invariants(obj)
            matrix = double(obj);
            first = trace(matrix);
            second = 0.5 * (first^2 - trace(matrix*matrix));
            third = builtin("det", matrix);
            values = [first,second,third];
        end

        function [unitary, positive] = polar_decomposition(obj, side)
            arguments
                obj
                side (1,1) string {mustBeMember(side,["right","left"])} = "right"
            end
            [left,singular,right] = svd(double(obj));
            unitary = left * right.';
            if side == "right"
                positive = right * singular * right.';
            else
                positive = left * singular * left.';
            end
        end
    end

    methods (Static)
        function obj = from_voigt(voigt_input)
            obj = kssolv.analysis.matgenlab.core.Tensor. ...
                fromVoigtForClass(voigt_input, ...
                "kssolv.analysis.matgenlab.core.SquareTensor");
        end

        function obj = from_dict(data)
            if isfield(data, "voigt") && data.voigt
                obj = ...
                    kssolv.analysis.matgenlab.core.SquareTensor. ...
                    from_voigt(data.input_array);
            else
                obj = ...
                    kssolv.analysis.matgenlab.core.SquareTensor( ...
                    data.input_array);
            end
        end
    end
end
