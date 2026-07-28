classdef ResCELL
    %RESCELL Unit-cell parameters stored in a RES CELL record.

    properties (SetAccess = private)
        unknown_field_1 (1,1) double = 1
        a (1,1) double = 1
        b (1,1) double = 1
        c (1,1) double = 1
        alpha (1,1) double = 90
        beta (1,1) double = 90
        gamma (1,1) double = 90
    end

    methods
        function obj = ResCELL(field1, a, b, c, alpha, beta, gamma)
            if nargin == 0, return; end
            values = double([field1, a, b, c, alpha, beta, gamma]);
            if any(~isfinite(values))
                error("KSSOLV:Matgenlab:Res:CELL", ...
                    "CELL values must be finite.");
            end
            obj.unknown_field_1 = values(1);
            obj.a = values(2); obj.b = values(3); obj.c = values(4);
            obj.alpha = values(5); obj.beta = values(6);
            obj.gamma = values(7);
        end

        function value = string(obj)
            value = sprintf( ...
                "CELL %.5f %.5f %.5f %.5f %.5f %.5f %.5f", ...
                obj.unknown_field_1, obj.a, obj.b, obj.c, ...
                obj.alpha, obj.beta, obj.gamma);
        end

        function value = char(obj), value = char(string(obj)); end

        function value = as_dict(obj)
            value = struct("unknown_field_1", obj.unknown_field_1, ...
                "a", obj.a, "b", obj.b, "c", obj.c, ...
                "alpha", obj.alpha, "beta", obj.beta, ...
                "gamma", obj.gamma);
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.res.ResCELL( ...
                value.unknown_field_1, value.a, value.b, value.c, ...
                value.alpha, value.beta, value.gamma);
        end
    end
end
