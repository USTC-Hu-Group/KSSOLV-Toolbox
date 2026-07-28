classdef BalancedReaction < handle
    %BALANCEDREACTION Explicitly balanced chemical reaction.

    properties (Constant)
        TOLERANCE = 1e-6
    end

    properties (Access = protected)
        coeffs_ (1,:) double = zeros(1,0)
        all_comp_ cell = cell(1,0)
        elements_ cell = cell(1,0)
        reactants_coeffs cell = cell(0,2)
        products_coeffs cell = cell(0,2)
    end

    properties (Dependent, SetAccess = private)
        elements
        coeffs
        all_comp
        reactants
        products
        normalized_repr
    end

    methods
        function obj = BalancedReaction(reactants, products)
            if nargin == 0, return; end
            obj.reactants_coeffs = obj.normalizeMapping(reactants);
            obj.products_coeffs = obj.normalizeMapping(products);
            reactantTotal = kssolv.analysis.matgenlab.core.Composition();
            productTotal = kssolv.analysis.matgenlab.core.Composition();
            for index = 1:size(obj.reactants_coeffs,1)
                reactantTotal = reactantTotal + ...
                    obj.reactants_coeffs{index,1} * ...
                    obj.reactants_coeffs{index,2};
            end
            for index = 1:size(obj.products_coeffs,1)
                productTotal = productTotal + ...
                    obj.products_coeffs{index,1} * ...
                    obj.products_coeffs{index,2};
            end
            if ~reactantTotal.almost_equals(productTotal,0,obj.TOLERANCE)
                throw(kssolv.analysis.matgenlab.analysis.ReactionError( ...
                    "Reaction is unbalanced."));
            end
            combined = [obj.reactants_coeffs(:,1); ...
                obj.products_coeffs(:,1)];
            identifiers = strings(0,1);
            for index = 1:numel(combined)
                composition = combined{index};
                identifier = string(composition);
                if any(identifiers == identifier), continue; end
                identifiers(end+1) = identifier; %#ok<AGROW>
                coefficient = obj.mappingValue( ...
                    obj.products_coeffs, composition) - ...
                    obj.mappingValue(obj.reactants_coeffs, composition);
                if abs(coefficient) > obj.TOLERANCE
                    obj.all_comp_{end+1} = composition;
                    obj.coeffs_(end+1) = coefficient;
                end
            end
            obj.elements_ = reactantTotal.elements;
        end

        function value = get.elements(obj), value = obj.elements_; end
        function value = get.coeffs(obj), value = obj.coeffs_; end
        function value = get.all_comp(obj), value = obj.all_comp_; end
        function value = get.reactants(obj)
            value = obj.all_comp_(obj.coeffs_ < -obj.TOLERANCE);
        end
        function value = get.products(obj)
            value = obj.all_comp_(obj.coeffs_ > obj.TOLERANCE);
        end

        function value = calculate_energy(obj, energies)
            value = 0;
            for index = 1:numel(obj.coeffs_)
                value = value + obj.coeffs_(index) * ...
                    obj.energyValue(energies,obj.all_comp_{index});
            end
        end

        function normalize_to(obj, composition, factor)
            if nargin < 3 || isempty(factor), factor = 1; end
            composition = kssolv.analysis.matgenlab.core. ...
                Composition(composition);
            coefficient = obj.get_coeff(composition);
            obj.coeffs_ = obj.coeffs_ * abs(factor/coefficient);
        end

        function normalize_to_element(obj, element, factor)
            if nargin < 3 || isempty(factor), factor = 1; end
            amount = obj.get_el_amount(element);
            obj.coeffs_ = obj.coeffs_ * factor/amount;
        end

        function value = get_el_amount(obj, element)
            value = 0;
            for index = 1:numel(obj.all_comp_)
                value = value + obj.all_comp_{index}(element) * ...
                    abs(obj.coeffs_(index));
            end
            value = value / 2;
        end

        function value = get_coeff(obj, composition)
            composition = kssolv.analysis.matgenlab.core. ...
                Composition(composition);
            index = find(cellfun(@(item) item == composition, ...
                obj.all_comp_),1);
            if isempty(index)
                error("KSSOLV:Matgenlab:Reaction:CompositionAbsent", ...
                    "Composition is not present in the reaction.");
            end
            value = obj.coeffs_(index);
        end

        function [text, factor] = normalized_repr_and_factor(obj)
            [text,factor] = obj.reactionString(true);
        end

        function value = get.normalized_repr(obj)
            [value,~] = obj.normalized_repr_and_factor();
        end

        function value = char(obj)
            [text,~] = obj.reactionString(false);
            value = char(text);
        end

        function value = string(obj), value = string(char(obj)); end

        function value = eq(obj, other)
            if ~isa(other, class(obj)), value = false; return; end
            value = true;
            for index = 1:numel(obj.all_comp_)
                try
                    second = other.get_coeff(obj.all_comp_{index});
                catch
                    second = 0;
                end
                if abs(obj.coeffs_(index)-second) > obj.TOLERANCE
                    value = false; return
                end
            end
            for index = 1:numel(other.all_comp_)
                try
                    first = obj.get_coeff(other.all_comp_{index});
                catch
                    first = 0;
                end
                if abs(other.coeffs_(index)-first) > obj.TOLERANCE
                    value = false; return
                end
            end
        end

        function value = ne(obj, other), value = ~eq(obj,other); end

        function entry = as_entry(obj, energies)
            total = kssolv.analysis.matgenlab.core.Composition();
            for index = 1:numel(obj.all_comp_)
                total = total + obj.all_comp_{index} * ...
                    abs(obj.coeffs_(index));
            end
            entry = kssolv.analysis.matgenlab.core.ComputedEntry( ...
                total*0.5,obj.calculate_energy(energies));
            entry.name = string(obj);
        end

        function value = as_dict(obj)
            value = struct( ...
                "x_module","pymatgen.analysis.reaction_calculator", ...
                "x_class",classLeafReaction(obj), ...
                "reactants",obj.mappingForWire(obj.reactants_coeffs), ...
                "products",obj.mappingForWire(obj.products_coeffs));
        end

        function value = asDict(obj), value = obj.as_dict(); end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.analysis.BalancedReaction( ...
                value.reactants,value.products);
        end

        function obj = from_str(text)
            pieces = split(string(text),"->");
            if numel(pieces) ~= 2
                error("KSSOLV:Matgenlab:Reaction:InvalidString", ...
                    "Reaction string must contain one ->.");
            end
            reactants = parseReactionSide(pieces(1));
            products = parseReactionSide(pieces(2));
            obj = kssolv.analysis.matgenlab.analysis. ...
                BalancedReaction(reactants,products);
        end
    end

    methods (Access = protected)
        function [text,factor] = reactionString(obj,reduce)
            count = numel(obj.coeffs_);
            coefficients = zeros(1,count);
            formulas = strings(1,count);
            for index = 1:count
                [formulas(index),formulaFactor] = ...
                    obj.all_comp_{index}.get_reduced_formula_and_factor();
                coefficients(index) = obj.coeffs_(index)*formulaFactor;
            end
            factor = 1;
            if reduce && ~isempty(coefficients)
                [numerators,denominators] = rat(abs(coefficients),1e-8);
                commonDenominator = 1;
                for denominator = denominators
                    commonDenominator = lcm(commonDenominator,denominator);
                end
                integers = round(abs(numerators) .* ...
                    commonDenominator ./ denominators);
                divisor = 0;
                for integer = integers
                    divisor = gcd(divisor,integer);
                end
                if divisor == 0, divisor = 1; end
                factor = commonDenominator/divisor;
                coefficients = coefficients*factor;
            end
            left = strings(1,0); right = strings(1,0);
            for index = 1:count
                coefficient = coefficients(index);
                if abs(coefficient) <= obj.TOLERANCE, continue; end
                if abs(abs(coefficient)-1) <= obj.TOLERANCE
                    part = formulas(index);
                else
                    part = string(sprintf("%.4g %s", ...
                        abs(coefficient),formulas(index)));
                end
                if coefficient < 0
                    left(end+1) = part; %#ok<AGROW>
                else
                    right(end+1) = part; %#ok<AGROW>
                end
            end
            text = strjoin(left," + ")+" -> "+strjoin(right," + ");
        end

        function mapping = normalizeMapping(~,input)
            if isa(input,"containers.Map")
                keys=input.keys; mapping=cell(numel(keys),2);
                for index=1:numel(keys)
                    mapping{index,1}= ...
                        kssolv.analysis.matgenlab.core.Composition(keys{index});
                    mapping{index,2}=double(input(keys{index}));
                end
            elseif isstruct(input)
                keys=fieldnames(input); mapping=cell(numel(keys),2);
                for index=1:numel(keys)
                    formula=keys{index};
                    if startsWith(formula,"x") && ...
                            ~isletter(extractBetween(formula,2,2))
                        formula=extractAfter(formula,1);
                    end
                    mapping{index,1}= ...
                        kssolv.analysis.matgenlab.core.Composition(formula);
                    mapping{index,2}=double(input.(keys{index}));
                end
            elseif iscell(input) && size(input,2)==2
                mapping=input;
                for index=1:size(mapping,1)
                    mapping{index,1}= ...
                        kssolv.analysis.matgenlab.core. ...
                        Composition(mapping{index,1});
                    mapping{index,2}=double(mapping{index,2});
                end
            else
                error("KSSOLV:Matgenlab:Reaction:InvalidMapping", ...
                    "Reaction sides require a map, struct, or N-by-2 cell.");
            end
        end

        function value = mappingValue(~,mapping,composition)
            value=0;
            for index=1:size(mapping,1)
                if mapping{index,1}==composition
                    value=mapping{index,2}; return
                end
            end
        end

        function value = energyValue(~,energies,composition)
            if isa(energies,"containers.Map")
                keys={char(string(composition)), ...
                    char(composition.reduced_formula)};
                for index=1:numel(keys)
                    if isKey(energies,keys{index})
                        value=energies(keys{index}); return
                    end
                end
            elseif iscell(energies)
                for index=1:size(energies,1)
                    if kssolv.analysis.matgenlab.core. ...
                            Composition(energies{index,1})==composition
                        value=energies{index,2}; return
                    end
                end
            elseif isstruct(energies)
                candidates={matlab.lang.makeValidName(char(string(composition))), ...
                    matlab.lang.makeValidName(char(composition.reduced_formula))};
                for index=1:numel(candidates)
                    if isfield(energies,candidates{index})
                        value=energies.(candidates{index}); return
                    end
                end
            end
            error("KSSOLV:Matgenlab:Reaction:MissingEnergy", ...
                "No energy was supplied for %s.",composition);
        end

        function value = mappingForWire(~,mapping)
            keys=cell(size(mapping,1),1); values=cell(size(mapping,1),1);
            for index=1:size(mapping,1)
                keys{index}=char(string(mapping{index,1}));
                values{index}=mapping{index,2};
            end
            value=containers.Map(keys,values,"UniformValues",false);
        end
    end
end

function value=classLeafReaction(obj)
parts=split(string(class(obj)),"."); value=parts(end);
end

function mapping=parseReactionSide(text)
parts=split(string(text),"+");
mapping=cell(numel(parts),2);
for index=1:numel(parts)
    token=regexp(char(strtrim(parts(index))), ...
        '^\s*([\d\.]+(?:[eE]-?[\d\.]+)?)?\s*([A-Z][\w\.\(\)]*)\s*$', ...
        'tokens','once');
    if isempty(token)
        error("KSSOLV:Matgenlab:Reaction:InvalidComponent", ...
            "Invalid reaction component '%s'.",parts(index));
    end
    if isscalar(token)
        amount=1; formula=token{1};
    elseif isempty(token{1})
        amount=1; formula=token{2};
    else
        amount=str2double(token{1}); formula=token{2};
    end
    mapping{index,1}=formula;
    mapping{index,2}=amount;
end
end
