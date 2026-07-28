classdef Kpoint < kssolv.analysis.matgenlab.util.MSONable
    %KPOINT Reciprocal-space point tied to a lattice.

    properties (SetAccess = immutable)
        lattice
        frac_coords (1,3) double
        cart_coords (1,3) double
    end

    properties
        label = []
    end

    properties (Dependent, SetAccess = private)
        a
        b
        c
    end

    methods
        function obj = Kpoint(coords, lattice, toUnitCell, ...
                coordsAreCartesian, label)
            if nargin < 3 || isempty(toUnitCell), toUnitCell = false; end
            if nargin < 4 || isempty(coordsAreCartesian)
                coordsAreCartesian = false;
            end
            if nargin < 5, label = []; end
            obj.lattice = lattice;
            if coordsAreCartesian
                fractional = lattice.get_fractional_coords(coords);
            else
                fractional = double(coords);
            end
            fractional = reshape(fractional, 1, 3);
            if toUnitCell
                fractional = fractional - floor(fractional);
            end
            obj.frac_coords = fractional;
            obj.cart_coords = lattice.get_cartesian_coords(fractional);
            obj.label = label;
        end

        function value = get.a(obj), value = obj.frac_coords(1); end
        function value = get.b(obj), value = obj.frac_coords(2); end
        function value = get.c(obj), value = obj.frac_coords(3); end

        function value = eq(obj, other)
            value = isa(other, class(obj)) && ...
                all(abs(obj.frac_coords - other.frac_coords) <= 1e-8) && ...
                obj.lattice == other.lattice && ...
                isequal(obj.label, other.label);
        end

        function value = ne(obj, other), value = ~eq(obj, other); end

        function value = as_dict(obj)
            value = struct( ...
                "lattice", obj.lattice.as_dict(), ...
                "fcoords", obj.frac_coords, ...
                "ccoords", obj.cart_coords, ...
                "label", obj.label, ...
                "x_module", "pymatgen.electronic_structure.bandstructure", ...
                "x_class", "Kpoint");
        end

        function value = asDict(obj), value = obj.as_dict(); end
    end

    methods (Static)
        function obj = from_dict(value)
            lattice = kssolv.analysis.matgenlab.core.Lattice. ...
                from_dict(value.lattice);
            obj = kssolv.analysis.matgenlab.electronic_structure. ...
                Kpoint(value.fcoords, lattice, false, false, value.label);
        end
    end
end
