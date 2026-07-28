classdef CriticalPoint < handle
    %CRITICALPOINT Field data at a non-equivalent Critic2 critical point.

    properties
        index (1,1) double
        coords = []
        frac_coords (1,3) double
        point_group (1,1) string
        multiplicity (1,1) double
        field (1,1) double
        field_gradient
        field_hessian = []
    end

    properties (Access = private)
        type_ (1,1) string
    end

    properties (Dependent, SetAccess = private)
        type
        laplacian
        ellipticity
    end

    methods
        function obj = CriticalPoint(index, type, fracCoords, pointGroup, ...
                multiplicity, field, fieldGradient, coords, fieldHessian)
            if nargin == 0, return; end
            if nargin < 8, coords = []; end
            if nargin < 9, fieldHessian = []; end
            obj.index = double(index);
            obj.type_ = lower(string(type));
            obj.frac_coords = reshape(double(fracCoords), 1, 3);
            obj.point_group = string(pointGroup);
            obj.multiplicity = double(multiplicity);
            obj.field = double(field);
            obj.field_gradient = double(fieldGradient);
            obj.coords = double(coords);
            obj.field_hessian = double(fieldHessian);
            % Validate eagerly, matching Python Enum construction behavior.
            validatedType = kssolv.analysis.matgenlab.command_line. ...
                critic2_caller.CriticalPointType.from_value(obj.type_);
            obj.type_ = string(validatedType);
        end

        function value = get.type(obj)
            value = kssolv.analysis.matgenlab.command_line. ...
                critic2_caller.CriticalPointType.from_value(obj.type_);
        end

        function value = get.laplacian(obj)
            if isempty(obj.field_hessian), value = NaN;
            else, value = trace(obj.field_hessian);
            end
        end

        function value = get.ellipticity(obj)
            if isempty(obj.field_hessian)
                value = NaN;
                return
            end
            eigenvalues = sort(real(eig(obj.field_hessian)));
            value = eigenvalues(1) / eigenvalues(2) - 1;
        end

        function value = char(obj)
            value = sprintf("Critical Point: %s (%s)", string(obj.type), ...
                strjoin(compose("%.8g", obj.frac_coords), " "));
        end

        function value = string(obj)
            value = string(char(obj));
        end

        function value = as_dict(obj)
            value = struct( ...
                "x_module", "pymatgen.command_line.critic2_caller", ...
                "x_class", "CriticalPoint", ...
                "index", obj.index, ...
                "type", obj.type_, ...
                "coords", obj.coords, ...
                "frac_coords", obj.frac_coords, ...
                "point_group", obj.point_group, ...
                "multiplicity", obj.multiplicity, ...
                "field", obj.field, ...
                "field_gradient", obj.field_gradient, ...
                "field_hessian", obj.field_hessian);
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.command_line.critic2_caller. ...
                CriticalPoint(value.index, value.type, value.frac_coords, ...
                value.point_group, value.multiplicity, value.field, ...
                value.field_gradient, value.coords, value.field_hessian);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.command_line. ...
                critic2_caller.CriticalPoint.from_dict(value);
        end
    end
end
