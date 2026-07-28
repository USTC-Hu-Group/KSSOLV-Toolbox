classdef Spin
    %SPIN Spin-channel enumeration compatible with pymatgen Spin.

    enumeration
        up (1)
        down (-1)
    end

    properties (SetAccess = immutable)
        value (1,1) double
    end

    methods
        function obj = Spin(value)
            obj.value = value;
        end

        function value = double(obj)
            value = obj.value;
        end

        function value = char(obj)
            value = char(string(double(obj)));
        end

        function value = string(obj)
            value = string(double(obj));
        end
    end
end
