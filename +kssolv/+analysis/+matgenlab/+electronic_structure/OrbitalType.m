classdef OrbitalType
    %ORBITALTYPE Azimuthal orbital type compatible with pymatgen.

    enumeration
        s (0)
        p (1)
        d (2)
        f (3)
    end

    properties (SetAccess = immutable)
        value (1,1) double
    end

    methods
        function obj = OrbitalType(value)
            obj.value = value;
        end

        function value = double(obj)
            value = obj.value;
        end

        function value = char(obj)
            names = ["s", "p", "d", "f"];
            value = char(names(double(obj) + 1));
        end

        function value = string(obj)
            value = string(char(obj));
        end
    end
end
