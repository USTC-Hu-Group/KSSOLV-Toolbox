classdef Orbital
    %ORBITAL Parsed POTCAR atomic-configuration row.
    properties
        n (1,1) double
        l (1,1) double
        j (1,1) double
        E (1,1) double
        occ (1,1) double
    end
    methods
        function obj = Orbital(n, l, j, E, occ)
            if nargin == 0, return; end
            obj.n = n; obj.l = l; obj.j = j; obj.E = E; obj.occ = occ;
        end
        function value = double(obj)
            value = [obj.n, obj.l, obj.j, obj.E, obj.occ];
        end
    end
end
