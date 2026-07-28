classdef Entry < kssolv.analysis.matgenlab.util.MSONable
    %ENTRY Composition and associated scalar energy.

    properties (Access = protected)
        composition_ (1,1) kssolv.analysis.matgenlab.core.Composition
        energy_ (1,1) double = 0
    end

    properties (Dependent, SetAccess = private)
        is_element
        composition
        formula
        reduced_formula
        energy
        elements
        energy_per_atom
    end

    methods
        function obj = Entry(composition, energy)
            if nargin == 0
                obj.composition_ = ...
                    kssolv.analysis.matgenlab.core.Composition();
                return
            end
            if ~isa(composition, ...
                    "kssolv.analysis.matgenlab.core.Composition")
                composition = ...
                    kssolv.analysis.matgenlab.core.Composition(composition);
            end
            obj.composition_ = composition;
            obj.energy_ = double(energy);
        end

        function value = get.is_element(obj), value = obj.composition_.is_element; end
        function value = get.composition(obj), value = obj.effectiveComposition(); end
        function value = get.formula(obj), value = obj.composition_.formula; end
        function value = get.reduced_formula(obj), value = obj.composition_.reduced_formula; end
        function value = get.energy(obj), value = obj.effectiveEnergy(); end
        function value = get.elements(obj), value = obj.composition_.elements; end
        function value = get.energy_per_atom(obj)
            value = obj.energy / obj.composition.num_atoms;
        end

        function value = effectiveEnergy(obj)
            value = obj.energy_;
            if isa(obj,"kssolv.analysis.matgenlab.core.ComputedEntry")
                value = value + obj.correction;
            end
        end
        function value = effectiveComposition(obj), value = obj.composition_; end

        function value = normalize(obj, mode)
            if nargin < 2, mode = "formula_unit"; end
            factor = obj.normalizationFactor(mode);
            data = obj.as_dict();
            normalizedComposition = obj.composition_ / factor;
            data.composition = normalizedComposition.as_dict();
            data.energy = obj.energy_ / factor;
            value = obj.from_dict(data);
        end

        function data = as_dict(obj)
            data = struct( ...
                x_module="pymatgen.core.entries", ...
                x_class=classLeaf(obj), ...
                energy=obj.energy_, ...
                composition=obj.composition_.as_dict());
            function name = classLeaf(input)
                parts = split(string(class(input)), ".");
                name = parts(end);
            end
        end
        function data = asDict(obj), data = obj.as_dict(); end

        function tf = eq(obj, other)
            tf = isa(other, class(obj)) && ...
                isclose(obj.energy, other.energy) && ...
                obj.composition == other.composition;
            function out = isclose(a, b)
                out = abs(a-b) <= 1e-8 + 1e-5*abs(b);
            end
        end
        function tf = ne(obj, other), tf = ~eq(obj, other); end
        function text = char(obj)
            text = sprintf("%s : %s with energy = %.4f", ...
                classLeaf(obj), char(obj.formula), obj.energy);
            function name = classLeaf(input)
                parts = split(string(class(input)), ".");
                name = char(parts(end));
            end
        end
    end

    methods (Access = protected)
        function factor = normalizationFactor(obj, mode)
            mode = string(mode);
            if mode == "atom"
                factor = obj.composition.num_atoms;
            elseif mode == "formula_unit"
                [~, factor] = ...
                    obj.composition.get_reduced_composition_and_factor();
            else
                error("KSSOLV:Matgenlab:Entry:NormalizationMode", ...
                    "%s is not an allowed option for normalization.", mode);
            end
        end
    end

    methods (Static)
        function obj = from_dict(data)
            obj = kssolv.analysis.matgenlab.core.Entry( ...
                data.composition, data.energy);
        end
        function obj = fromDict(data)
            obj = kssolv.analysis.matgenlab.core.Entry.from_dict(data);
        end
    end
end
