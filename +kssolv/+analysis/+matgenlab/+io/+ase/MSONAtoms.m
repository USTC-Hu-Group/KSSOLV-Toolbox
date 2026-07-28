classdef MSONAtoms
    %MSONATOMS Language-neutral ASE Atoms representation with MSON support.

    properties
        symbols cell = cell(1, 0)
        positions double = zeros(0, 3)
        pbc (1, 3) logical = [false, false, false]
        cell double = zeros(3)
        arrays (1, 1) struct = struct()
        info (1, 1) struct = struct()
        labels = []
        constraints cell = cell(1, 0)
        calc = []
        charge = []
        spin_multiplicity = []
    end

    methods
        function obj = MSONAtoms(input, varargin)
            if nargin == 0, return; end
            if isa(input, class(obj))
                obj = input;
                return
            end
            if isstruct(input)
                names = string(fieldnames(input));
                known = string(properties(obj));
                for name = reshape(names, 1, [])
                    if any(known == name)
                        obj.(char(name)) = input.(char(name));
                    end
                end
            else
                obj.symbols = cellstr(string(input));
            end
            for index = 1:2:numel(varargin)
                obj.(char(string(varargin{index}))) = varargin{index + 1};
            end
            obj.symbols = reshape(cellstr(string(obj.symbols)), 1, []);
            obj.pbc = reshape(logical(obj.pbc), 1, 3);
            if iscell(obj.labels), obj.labels = reshape(obj.labels, 1, []); end
            arrayNames = fieldnames(obj.arrays);
            for index = 1:numel(arrayNames)
                name = arrayNames{index};
                if isvector(obj.arrays.(name))
                    obj.arrays.(name) = reshape(obj.arrays.(name), 1, []);
                end
            end
        end

        function value = as_dict(obj)
            base = obj.to_struct();
            base.info = struct();
            value = struct("x_module", "pymatgen.io.ase", ...
                "x_class", "MSONAtoms", ...
                "atoms_json", jsonencode(base), ...
                "atoms_info", ...
                kssolv.analysis.matgenlab.util.toDict(obj.info));
        end

        function value = asDict(obj), value = obj.as_dict(); end

        function value = to_struct(obj)
            names = string(properties(obj));
            value = struct();
            for name = reshape(names, 1, [])
                value.(char(name)) = obj.(char(name));
            end
        end

        function value = copy(obj), value = obj; end

        function tf = eq(left, right)
            tf = isa(right, class(left)) && ...
                isequaln(left.to_struct(), right.to_struct());
        end
    end

    methods (Static)
        function obj = from_dict(value)
            decoded = jsondecode(value.atoms_json);
            obj = kssolv.analysis.matgenlab.io.ase.MSONAtoms(decoded);
            if isfield(value, "atoms_info")
                obj.info = kssolv.analysis.matgenlab.util.fromDict( ...
                    value.atoms_info, Strict = false);
            end
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.io.ase.MSONAtoms.from_dict(value);
        end
    end
end
