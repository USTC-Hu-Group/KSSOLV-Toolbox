classdef ChemicalPotential < kssolv.analysis.matgenlab.util.MSONable
    %CHEMICALPOTENTIAL Mapping from elemental species to chemical potentials.

    properties (SetAccess = private)
        potentials containers.Map
    end

    methods
        function obj = ChemicalPotential(input)
            obj.potentials = containers.Map( ...
                "KeyType", "char", "ValueType", "double");
            if nargin == 0, return; end
            if isa(input, ...
                    "kssolv.analysis.matgenlab.core.ChemicalPotential")
                obj = input;
                return
            end
            if isstruct(input)
                names = fieldnames(input);
                getter = @(name) input.(name);
            elseif isa(input, "containers.Map")
                names = input.keys;
                getter = @(name) input(name);
            elseif iscell(input) && size(input, 2) == 2
                names = input(:, 1);
                getter = @(name) input{find( ...
                    string(input(:, 1)) == string(name), 1), 2};
            else
                error("KSSOLV:Matgenlab:ChemicalPotential:Mapping", ...
                    "Chemical potentials require a mapping or two-column cell array.");
            end
            for index = 1:numel(names)
                element = ...
                    kssolv.analysis.matgenlab.core.get_el_sp(names{index});
                key = char(element.symbol);
                if isKey(obj.potentials, key)
                    error("KSSOLV:Matgenlab:ChemicalPotential:Duplicate", ...
                        "Duplicate potential specified for %s.", key);
                end
                obj.potentials(key) = double(getter(names{index}));
            end
        end

        function energy = get_energy(obj, composition, strict)
            if nargin < 3, strict = true; end
            if ~isa(composition, ...
                    "kssolv.analysis.matgenlab.core.Composition")
                composition = ...
                    kssolv.analysis.matgenlab.core.Composition(composition);
            end
            [species, amounts] = composition.items();
            energy = 0;
            for index = 1:numel(species)
                key = char(species{index}.symbol);
                if isKey(obj.potentials, key)
                    energy = energy + ...
                        obj.potentials(key) * amounts(index);
                elseif strict
                    error("KSSOLV:Matgenlab:ChemicalPotential:Missing", ...
                        "Potential was not specified for %s.", key);
                end
            end
        end

        function out = plus(first, second)
            out = first.combine(second, 1);
        end
        function out = minus(first, second)
            out = first.combine(second, -1);
        end
        function out = times(obj, scalar)
            if ~isnumeric(scalar) || ~isscalar(scalar)
                error("KSSOLV:Matgenlab:ChemicalPotential:Scalar", ...
                    "ChemicalPotential can only be scaled by a number.");
            end
            out = obj.scaled(scalar);
        end
        function out = mtimes(first, second)
            if isa(first, "kssolv.analysis.matgenlab.core.ChemicalPotential")
                out = times(first, second);
            else
                out = times(second, first);
            end
        end
        function out = rdivide(obj, scalar), out = obj.scaled(1 / scalar); end

        function value = as_dict(obj)
            value = struct( ...
                "x_module", "pymatgen.core.composition", ...
                "x_class", "ChemicalPotential", ...
                "potentials", obj.to_struct());
        end
        function value = asDict(obj), value = obj.as_dict(); end

        function value = to_struct(obj)
            value = struct();
            names = obj.potentials.keys;
            for index = 1:numel(names)
                value.(names{index}) = obj.potentials(names{index});
            end
        end
    end

    methods (Static)
        function obj = from_dict(value)
            if isfield(value, "potentials"), value = value.potentials; end
            obj = ...
                kssolv.analysis.matgenlab.core.ChemicalPotential(value);
        end
        function obj = fromDict(value)
            obj = ...
                kssolv.analysis.matgenlab.core.ChemicalPotential.from_dict( ...
                    value);
        end
    end

    methods (Access = private)
        function out = scaled(obj, factor)
            values = obj.to_struct();
            names = fieldnames(values);
            for index = 1:numel(names)
                values.(names{index}) = values.(names{index}) * factor;
            end
            out = ...
                kssolv.analysis.matgenlab.core.ChemicalPotential(values);
        end

        function out = combine(obj, other, signValue)
            if ~isa(other, ...
                    "kssolv.analysis.matgenlab.core.ChemicalPotential")
                error("KSSOLV:Matgenlab:ChemicalPotential:Operand", ...
                    "Both operands must be ChemicalPotential objects.");
            end
            values = obj.to_struct();
            names = other.potentials.keys;
            for index = 1:numel(names)
                name = names{index};
                if ~isfield(values, name), values.(name) = 0; end
                values.(name) = values.(name) + ...
                    signValue * other.potentials(name);
            end
            out = ...
                kssolv.analysis.matgenlab.core.ChemicalPotential(values);
        end
    end
end
