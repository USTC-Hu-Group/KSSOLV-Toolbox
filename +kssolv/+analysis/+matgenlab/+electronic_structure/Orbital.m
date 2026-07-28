classdef Orbital
    %ORBITAL VASP orbital-order enumeration compatible with pymatgen.

    enumeration
        s (0)
        py (1)
        pz (2)
        px (3)
        dxy (4)
        dyz (5)
        dz2 (6)
        dxz (7)
        dx2 (8)
        f_3 (9)
        f_2 (10)
        f_1 (11)
        f0 (12)
        f1 (13)
        f2 (14)
        f3 (15)
    end

    properties (SetAccess = immutable)
        value (1,1) double
        orbital_type
    end

    methods
        function obj = Orbital(value)
            obj.value = value;
            if value == 0
                obj.orbital_type = ...
                    kssolv.analysis.matgenlab.electronic_structure. ...
                    OrbitalType.s;
            elseif value <= 3
                obj.orbital_type = ...
                    kssolv.analysis.matgenlab.electronic_structure. ...
                    OrbitalType.p;
            elseif value <= 8
                obj.orbital_type = ...
                    kssolv.analysis.matgenlab.electronic_structure. ...
                    OrbitalType.d;
            else
                obj.orbital_type = ...
                    kssolv.analysis.matgenlab.electronic_structure. ...
                    OrbitalType.f;
            end
        end

        function value = double(obj)
            value = obj.value;
        end

        function value = char(obj)
            names = ["s", "py", "pz", "px", "dxy", "dyz", "dz2", ...
                "dxz", "dx2", "f_3", "f_2", "f_1", "f0", "f1", ...
                "f2", "f3"];
            value = char(names(double(obj) + 1));
        end

        function value = string(obj)
            value = string(char(obj));
        end
    end
end
