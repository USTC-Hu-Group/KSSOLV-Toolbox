classdef RotationTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess = private)
        axis (1,3) double
        angle (1,1) double
        angle_in_radians (1,1) logical
    end
    methods
        function obj = RotationTransformation(axis, angle, angleInRadians)
            if nargin < 3, angleInRadians = false; end
            axis = reshape(double(axis), 1, 3);
            if norm(axis) == 0
                error("KSSOLV:Matgenlab:RotationTransformation:Axis", ...
                    "Rotation axis must be nonzero.");
            end
            obj.axis = axis;
            obj.angle = double(angle);
            obj.angle_in_radians = logical(angleInRadians);
        end
        function result = apply_transformation(obj, structure, varargin)
            operation = kssolv.analysis.matgenlab.core.SymmOp. ...
                from_axis_angle_and_translation(obj.axis, obj.angle, ...
                angle_in_radians = obj.angle_in_radians);
            result = structure.copy();
            result = result.apply_operation(operation);
        end
    end
    methods (Access = protected)
        function value = inverseTransformation(obj)
            value = kssolv.analysis.matgenlab.transformations. ...
                RotationTransformation(obj.axis, -obj.angle, ...
                obj.angle_in_radians);
        end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.transformations. ...
                RotationTransformation(value.axis, value.angle, ...
                value.angle_in_radians);
        end
        function obj = fromDict(value), obj = ...
                kssolv.analysis.matgenlab.transformations. ...
                RotationTransformation.from_dict(value); end
    end
end
