classdef OrbitalDescription
    %ORBITALDESCRIPTION Parsed POTCAR projector-description row.
    properties
        l (1,1) double
        E (1,1) double
        Type (1,1) double
        Rcut (1,1) double
        Type2 (1,1) double = NaN
        Rcut2 (1,1) double = NaN
    end
    methods
        function obj = OrbitalDescription(l, E, Type, Rcut, Type2, Rcut2)
            if nargin == 0, return; end
            obj.l = l; obj.E = E; obj.Type = Type; obj.Rcut = Rcut;
            if nargin >= 5 && ~isempty(Type2), obj.Type2 = Type2; end
            if nargin >= 6 && ~isempty(Rcut2), obj.Rcut2 = Rcut2; end
        end
        function value = double(obj)
            value = [obj.l, obj.E, obj.Type, obj.Rcut, obj.Type2, obj.Rcut2];
        end
    end
end
