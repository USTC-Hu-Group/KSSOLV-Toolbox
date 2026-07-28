classdef Composition
    %COMPOSITION Immutable mapping from elements/species to amounts.

    properties (Constant)
        amount_tolerance = 1e-8
        charge_balanced_tolerance = 1e-8
    end

    properties (SetAccess = protected)
        allow_negative (1,1) logical = false
    end

    properties (Access = protected)
        species_ cell = cell(1, 0)
        amounts_ (1,:) double = zeros(1, 0)
    end

    properties (Dependent)
        elements
        num_atoms
        average_electroneg
        total_electrons
        is_element
        formula
        alphabetical_formula
        iupac_formula
        element_composition
        fractional_composition
        reduced_composition
        reduced_formula
        hill_formula
        anonymized_formula
        valid
        weight
        chemical_system
        chemical_system_set
        charge
        charge_balanced
    end

    methods
        function obj = Composition(input, varargin)
            if nargin == 0, return; end
            options = struct(allow_negative=false, strict=false);
            for idx = 1:2:numel(varargin)
                if idx + 1 > numel(varargin)
                    error("KSSOLV:Matgenlab:Composition:InvalidArguments", ...
                        "Name-value arguments must occur in pairs.");
                end
                name = char(lower(string(varargin{idx})));
                if ~isfield(options, name)
                    error("KSSOLV:Matgenlab:Composition:InvalidOption", ...
                        "Unknown Composition option '%s'.", name);
                end
                options.(name) = logical(varargin{idx + 1});
            end
            obj.allow_negative = options.allow_negative;

            if isa(input, "kssolv.analysis.matgenlab.core.Composition")
                species = input.species_;
                amounts = input.amounts_;
            elseif ischar(input) || (isstring(input) && isscalar(input))
                [keys_, amounts] = kssolv.analysis.matgenlab.core.Composition. ...
                    parseFormula(string(input));
                species = cellfun(@(x) kssolv.analysis.matgenlab.core.getElSp(x), ...
                    cellstr(keys_), "UniformOutput", false);
            else
                [species, amounts] = kssolv.analysis.matgenlab.core.Composition. ...
                    unpackMapping(input);
            end

            for idx = 1:numel(species)
                amount = double(amounts(idx));
                if ~isscalar(amount) || ~isfinite(amount)
                    error("KSSOLV:Matgenlab:Composition:InvalidAmount", ...
                        "Composition amounts must be finite scalar numbers.");
                end
                if amount < -obj.amount_tolerance && ~obj.allow_negative
                    error("KSSOLV:Matgenlab:Composition:NegativeAmount", ...
                        "Amounts in Composition cannot be negative.");
                end
                if abs(amount) >= obj.amount_tolerance
                    obj = obj.addExact(kssolv.analysis.matgenlab.core.getElSp(species{idx}), amount);
                end
            end
            if options.strict && ~obj.valid
                error("KSSOLV:Matgenlab:Composition:InvalidSpecies", ...
                    "Strict Composition cannot contain dummy species.");
            end
        end

        function out = get.elements(obj), out = obj.species_; end
        function out = get.num_atoms(obj), out = sum(abs(obj.amounts_)); end
        function out = get.average_electroneg(obj)
            if obj.num_atoms == 0, out = NaN; return; end
            values = zeros(size(obj.amounts_));
            for idx = 1:numel(values), values(idx) = obj.species_{idx}.X; end
            out = sum(values .* abs(obj.amounts_)) / obj.num_atoms;
        end
        function out = get.total_electrons(obj)
            values = zeros(size(obj.amounts_));
            for idx = 1:numel(values), values(idx) = obj.species_{idx}.Z; end
            out = sum(values .* abs(obj.amounts_));
        end
        function out = get.is_element(obj), out = isscalar(obj.species_); end
        function out = get.formula(obj)
            if isa(obj, "kssolv.analysis.matgenlab.core.Ion")
                out = obj.ionFormula(); %#ok<MCNPN>
                return
            end
            [symbols, amounts] = obj.elementAmounts();
            order = kssolv.analysis.matgenlab.core.Composition.sortSymbols(symbols, false);
            pieces = strings(1, numel(order));
            for idx = 1:numel(order)
                loc = find(symbols == order(idx), 1);
                pieces(idx) = order(idx) + ...
                    kssolv.analysis.matgenlab.core.Composition.formatAmount(amounts(loc), false);
            end
            out = strjoin(pieces, " ");
        end
        function out = get.alphabetical_formula(obj)
            if isa(obj, "kssolv.analysis.matgenlab.core.Ion")
                out = obj.ionAlphabeticalFormula(); %#ok<MCNPN>
                return
            end
            [symbols, amounts] = obj.elementAmounts();
            [symbols, order] = sort(symbols);
            amounts = amounts(order);
            pieces = symbols + arrayfun(@(x) ...
                kssolv.analysis.matgenlab.core.Composition.formatAmount(x, false), ...
                amounts);
            out = strjoin(pieces, " ");
        end
        function out = get.iupac_formula(obj)
            [symbols, amounts] = obj.elementAmounts();
            ranks = zeros(size(symbols));
            for idx = 1:numel(symbols)
                ranks(idx) = kssolv.analysis.matgenlab.core.getElSp( ...
                    symbols(idx)).iupac_ordering;
            end
            [~, order] = sortrows([ranks(:), (1:numel(ranks)).']);
            pieces = strings(1, numel(order));
            for idx = 1:numel(order)
                loc = order(idx);
                pieces(idx) = symbols(loc) + ...
                    kssolv.analysis.matgenlab.core.Composition.formatAmount(amounts(loc), false);
            end
            out = strjoin(pieces, " ");
        end
        function out = get.element_composition(obj)
            [symbols, amounts] = obj.elementAmounts();
            out = kssolv.analysis.matgenlab.core.Composition( ...
                [cellstr(symbols(:)), num2cell(amounts(:))], ...
                "allow_negative", obj.allow_negative);
        end
        function out = get.fractional_composition(obj)
            if obj.num_atoms == 0, out = obj; else, out = obj / obj.num_atoms; end
        end
        function out = get.reduced_composition(obj)
            [out, ~] = obj.get_reduced_composition_and_factor();
        end
        function out = get.reduced_formula(obj)
            if isa(obj, "kssolv.analysis.matgenlab.core.Ion")
                out = obj.ionReducedFormula(); %#ok<MCNPN>
                return
            end
            [out, ~] = obj.get_reduced_formula_and_factor();
        end
        function out = get.hill_formula(obj)
            [symbols, amounts] = obj.elementAmounts();
            if any(symbols == "C")
                ordered = ["C", symbols(symbols ~= "C" & symbols == "H"), ...
                    sort(symbols(symbols ~= "C" & symbols ~= "H"))];
            else
                ordered = sort(symbols);
            end
            pieces = strings(1, numel(ordered));
            for idx = 1:numel(ordered)
                loc = find(symbols == ordered(idx), 1);
                pieces(idx) = ordered(idx) + ...
                    kssolv.analysis.matgenlab.core.Composition.formatAmount(amounts(loc), true);
            end
            out = strjoin(pieces, " ");
        end
        function out = get.anonymized_formula(obj)
            if isa(obj, "kssolv.analysis.matgenlab.core.Ion")
                out = obj.ionAnonymizedFormula(); %#ok<MCNPN>
                return
            end
            reduced = obj.element_composition;
            if ~isempty(reduced.amounts_) && ...
                    all(abs(reduced.amounts_ - round(reduced.amounts_)) < obj.amount_tolerance)
                divisor = abs(round(reduced.amounts_(1)));
                for idx = 2:numel(reduced.amounts_)
                    divisor = gcd(divisor, abs(round(reduced.amounts_(idx))));
                end
                if divisor > 1, reduced = reduced / divisor; end
            end
            vals = sort(reduced.amounts_);
            letters = char('A' + (0:numel(vals)-1));
            pieces = strings(1, numel(vals));
            for idx = 1:numel(vals)
                pieces(idx) = string(letters(idx)) + ...
                    kssolv.analysis.matgenlab.core.Composition.formatAmount(vals(idx), true);
            end
            out = strjoin(pieces, "");
        end
        function out = get.valid(obj)
            out = true;
            for idx = 1:numel(obj.species_)
                if isa(obj.species_{idx}, "kssolv.analysis.matgenlab.core.DummySpecies")
                    out = false; return
                end
            end
        end
        function out = get.weight(obj)
            out = 0;
            for idx = 1:numel(obj.species_)
                out = out + obj.species_{idx}.atomic_mass * obj.amounts_(idx);
            end
        end
        function out = get.chemical_system_set(obj)
            [symbols, ~] = obj.elementAmounts();
            out = sort(unique(symbols));
        end
        function out = get.chemical_system(obj), out = strjoin(obj.chemical_system_set, "-"); end
        function out = get.charge(obj)
            if isa(obj, "kssolv.analysis.matgenlab.core.Ion")
                out = obj.explicitCharge(); %#ok<MCNPN>
                return
            end
            states = zeros(size(obj.amounts_));
            assigned = false(size(obj.amounts_));
            for idx = 1:numel(states)
                if isa(obj.species_{idx}, "kssolv.analysis.matgenlab.core.Species") && ...
                        ~isnan(obj.species_{idx}.oxi_state)
                    states(idx) = obj.species_{idx}.oxi_state;
                    assigned(idx) = true;
                end
            end
            if ~any(assigned & states ~= 0), out = NaN;
            elseif ~all(assigned), out = NaN;
            else, out = sum(states .* obj.amounts_);
            end
        end
        function out = get.charge_balanced(obj)
            if isa(obj, "kssolv.analysis.matgenlab.core.Ion")
                out = abs(obj.explicitCharge()) <= obj.charge_balanced_tolerance; %#ok<MCNPN>
                return
            end
            value = obj.charge;
            if isnan(value)
                allZeroSpecies = ~isempty(obj.species_);
                for idx = 1:numel(obj.species_)
                    allZeroSpecies = allZeroSpecies && ...
                        isa(obj.species_{idx}, "kssolv.analysis.matgenlab.core.Species") && ...
                        ~isnan(obj.species_{idx}.oxi_state) && ...
                        obj.species_{idx}.oxi_state == 0;
                end
                if allZeroSpecies, out = false; else, out = NaN; end
            else, out = abs(value) <= obj.charge_balanced_tolerance;
            end
        end

        function amount = amountOf(obj, key)
            query = kssolv.analysis.matgenlab.core.getElSp(key);
            amount = 0;
            exact = isa(query, "kssolv.analysis.matgenlab.core.Species");
            for idx = 1:numel(obj.species_)
                if exact
                    if obj.sameSpecies(obj.species_{idx}, query), amount = amount + obj.amounts_(idx); end
                elseif obj.species_{idx}.symbol == query.symbol
                    amount = amount + obj.amounts_(idx);
                end
            end
        end
        function tf = contains(obj, key)
            query = kssolv.analysis.matgenlab.core.getElSp(key);
            if isa(query, "kssolv.analysis.matgenlab.core.Species")
                tf = any(cellfun(@(x) obj.sameSpecies(x, query), obj.species_));
            else
                tf = any(cellfun(@(x) x.symbol == query.symbol, obj.species_));
            end
        end
        function tf = isKey(obj, key), tf = obj.contains(key); end

        function varargout = subsref(obj, s)
            if strcmp(s(1).type, "()") && isscalar(s(1).subs)
                value = obj.amountOf(s(1).subs{1});
                if numel(s) > 1, value = builtin("subsref", value, s(2:end)); end
                varargout{1} = value;
            else
                [varargout{1:nargout}] = builtin("subsref", obj, s);
            end
        end

        function count = length(obj), count = numel(obj.species_); end
        function [species, amounts] = items(obj)
            species = obj.species_;
            amounts = obj.amounts_;
        end
        function out = values(obj), out = obj.amounts_; end

        function tf = eq(a, b)
            if ~isa(b, "kssolv.analysis.matgenlab.core.Composition")
                tf = false; return
            end
            if length(a) ~= length(b), tf = false; return; end
            tf = true;
            for idx = 1:numel(a.species_)
                query = a.species_{idx};
                if isa(query, "kssolv.analysis.matgenlab.core.Species")
                    loc = find(cellfun(@(x) a.sameSpecies(query, x), b.species_), 1);
                    if isempty(loc), tf = false; return; end
                    otherAmount = b.amounts_(loc);
                else
                    otherAmount = b.amountOf(query);
                end
                if abs(a.amounts_(idx) - otherAmount) > a.amount_tolerance
                    tf = false; return
                end
            end
        end
        function tf = ne(a, b), tf = ~eq(a, b); end
        function tf = almost_equals(a, b, rtol, atol)
            if nargin < 3, rtol = 0.1; end
            if nargin < 4, atol = 1e-8; end
            allKeys = [a.species_, b.species_];
            tf = true;
            for idx = 1:numel(allKeys)
                av = a.amountOf(allKeys{idx}); bv = b.amountOf(allKeys{idx});
                if abs(bv - av) > atol + rtol * (abs(av) + abs(bv)) / 2
                    tf = false; return
                end
            end
        end

        function out = plus(a, b)
            if ~isa(b, "kssolv.analysis.matgenlab.core.Composition")
                b = kssolv.analysis.matgenlab.core.Composition(b);
            end
            out = a;
            for idx = 1:numel(b.species_), out = out.addExact(b.species_{idx}, b.amounts_(idx)); end
            out = out.prune();
        end
        function out = minus(a, b)
            if ~isa(b, "kssolv.analysis.matgenlab.core.Composition")
                b = kssolv.analysis.matgenlab.core.Composition(b);
            end
            out = a;
            for idx = 1:numel(b.species_), out = out.addExact(b.species_{idx}, -b.amounts_(idx)); end
            if ~out.allow_negative && any(out.amounts_ < -out.amount_tolerance)
                error("KSSOLV:Matgenlab:Composition:NegativeAmount", ...
                    "Amounts in Composition cannot be negative.");
            end
            out = out.prune();
        end
        function out = mtimes(a, b)
            if isnumeric(a) && isscalar(a), out = b.scale(a);
            elseif isnumeric(b) && isscalar(b), out = a.scale(b);
            else
                error("KSSOLV:Matgenlab:Composition:Multiply", ...
                    "A Composition can only be multiplied by a scalar.");
            end
        end
        function out = times(a, b), out = mtimes(a, b); end
        function out = mrdivide(a, b)
            if ~isnumeric(b) || ~isscalar(b) || b == 0
                error("KSSOLV:Matgenlab:Composition:Divide", ...
                    "A Composition can only be divided by a nonzero scalar.");
            end
            out = a.scale(1 / b);
        end
        function out = rdivide(a, b), out = mrdivide(a, b); end
        function out = copy(obj), out = obj; end

        function [out, factor] = get_reduced_composition_and_factor(obj)
            [~, factor] = obj.get_reduced_formula_and_factor();
            out = obj / factor;
        end
        function [formula_, factor] = get_reduced_formula_and_factor(obj, iupacOrdering)
            if nargin < 2, iupacOrdering = false; end
            if any(abs(obj.amounts_ - round(obj.amounts_)) >= obj.amount_tolerance)
                formula_ = erase(obj.formula, " ");
                factor = 1;
                return
            end
            [symbols, amounts] = obj.elementAmounts();
            [formula_, factor] = kssolv.analysis.matgenlab.core.Composition. ...
                reduceFormula(symbols, round(amounts), iupacOrdering);
            [formula_, factor] = kssolv.analysis.matgenlab.core.Composition. ...
                applySpecialFormula(formula_, factor);
        end
        function [formula_, factor] = get_integer_formula_and_factor(obj, maxDenominator, iupacOrdering)
            if nargin < 2, maxDenominator = 10000; end
            if nargin < 3, iupacOrdering = false; end
            [symbols, amounts] = obj.elementAmounts();
            scale = kssolv.analysis.matgenlab.core.Composition.gcdFloat(amounts, 1 / maxDenominator);
            ints = round(amounts / scale);
            [formula_, baseFactor] = kssolv.analysis.matgenlab.core.Composition. ...
                reduceFormula(symbols, ints, iupacOrdering);
            [formula_, baseFactor] = kssolv.analysis.matgenlab.core.Composition. ...
                applySpecialFormula(formula_, baseFactor);
            factor = baseFactor * scale;
        end

        function fraction = get_atomic_fraction(obj, species)
            fraction = abs(obj.amountOf(species)) / obj.num_atoms;
        end
        function fraction = get_wt_fraction(obj, species)
            query = kssolv.analysis.matgenlab.core.getElSp(species);
            fraction = query.atomic_mass * abs(obj.amountOf(query)) / obj.weight;
        end
        function tf = contains_element_type(obj, category)
            category = string(category);
            if endsWith(category, "-block")
                block_ = extractBefore(category, 2);
                tf = any(cellfun(@(x) x.block == block_, obj.species_));
                return
            end
            aliases = struct(rare_earth_metal="is_rare_earth");
            field = "is_" + category;
            validCategories = ["noble_gas","transition_metal", ...
                "post_transition_metal", ...
                "rare_earth_metal","metal","metalloid","alkali","alkaline", ...
                "halogen","chalcogen","lanthanoid","actinoid","radioactive","quadrupolar"];
            if ~ismember(category, validCategories)
                error("KSSOLV:Matgenlab:Composition:InvalidElementType", ...
                    "Invalid element category '%s'.", category);
            end
            if isfield(aliases, char(category)), field = aliases.(char(category)); end
            tf = false;
            for idx = 1:numel(obj.species_)
                el = kssolv.analysis.matgenlab.core.Element(obj.species_{idx}.symbol);
                if el.(field), tf = true; return; end
            end
        end

        function map = get_el_amt_dict(obj)
            [symbols, amounts] = obj.elementAmounts();
            map = struct();
            for idx = 1:numel(symbols), map.(symbols(idx)) = amounts(idx); end
        end
        function map = asDict(obj)
            map = containers.Map("KeyType", "char", "ValueType", "double");
            for idx = 1:numel(obj.species_)
                key = char(obj.species_{idx});
                if isKey(map, key), map(key) = map(key) + obj.amounts_(idx);
                else, map(key) = obj.amounts_(idx);
                end
            end
        end
        function map = as_dict(obj), map = obj.asDict(); end
        function map = as_reduced_dict(obj), map = obj.reduced_composition.asDict(); end
        function map = to_reduced_dict(obj), map = obj.as_reduced_dict(); end
        function map = as_weight_dict(obj)
            map = containers.Map("KeyType", "char", "ValueType", "double");
            for idx = 1:numel(obj.species_)
                map(char(obj.species_{idx})) = obj.get_wt_fraction(obj.species_{idx});
            end
        end
        function map = to_weight_dict(obj), map = obj.as_weight_dict(); end
        function data = as_data_dict(obj)
            data = struct(reduced_cell_composition=obj.reduced_composition, ...
                unit_cell_composition=obj.asDict(), ...
                reduced_cell_formula=obj.reduced_formula, ...
                elements={cellfun(@char, obj.species_, "UniformOutput", false)}, ...
                nelements=length(obj));
        end
        function data = to_data_dict(obj), data = obj.as_data_dict(); end

        function out = replace(obj, elementMap)
            if ~isstruct(elementMap) && ~isa(elementMap, "containers.Map")
                error("KSSOLV:Matgenlab:Composition:InvalidReplacement", ...
                    "Replacement map must be a struct or containers.Map.");
            end
            out = kssolv.analysis.matgenlab.core.Composition();
            if isstruct(elementMap), names = fieldnames(elementMap);
            else, names = keys(elementMap);
            end
            for sourceIndex = 1:numel(obj.species_)
                source = obj.species_{sourceIndex};
                amount = obj.amounts_(sourceIndex);
                keyIndex = find(string(names) == source.symbol, 1);
                if isempty(keyIndex)
                    out = out.addExact(source, amount);
                else
                    key = names{keyIndex};
                    if isstruct(elementMap), replacement = elementMap.(key);
                    else, replacement = elementMap(key);
                    end
                    if ischar(replacement) || isstring(replacement) || ...
                            isa(replacement, "kssolv.analysis.matgenlab.core.Element") || ...
                            isa(replacement, "kssolv.analysis.matgenlab.core.Species")
                        out = out.addExact( ...
                            kssolv.analysis.matgenlab.core.getElSp(replacement), amount);
                    else
                        replacementComp = ...
                            kssolv.analysis.matgenlab.core.Composition(replacement);
                        for replacementIndex = 1:numel(replacementComp.species_)
                            out = out.addExact( ...
                                replacementComp.species_{replacementIndex}, ...
                                replacementComp.amounts_(replacementIndex) * amount);
                        end
                    end
                end
            end
            out = out.prune();
        end

        function guesses = oxi_state_guesses(obj, oxiStatesOverride, ...
                targetCharge, allOxidationStates, maxSites)
            if nargin < 2, oxiStatesOverride = []; end
            if nargin < 3, targetCharge = 0; end
            if nargin < 4, allOxidationStates = false; end
            if nargin < 5, maxSites = []; end
            if isscalar(obj.element_composition.species_)
                symbol = obj.element_composition.species_{1}.symbol;
                guesses = {struct(char(symbol), 0)};
                return
            end
            [guesses, ~] = kssolv.analysis.matgenlab.core.Composition. ...
                oxidationGuessDetails(obj, oxiStatesOverride, targetCharge, ...
                    allOxidationStates, maxSites);
        end
        function out = add_charges_from_oxi_state_guesses(obj, ...
                oxiStatesOverride, targetCharge, allOxidationStates, maxSites)
            if nargin < 2, oxiStatesOverride = []; end
            if nargin < 3, targetCharge = 0; end
            if nargin < 4, allOxidationStates = false; end
            if nargin < 5, maxSites = []; end
            [~, combinations] = ...
                kssolv.analysis.matgenlab.core.Composition. ...
                oxidationGuessDetails(obj, oxiStatesOverride, targetCharge, ...
                    allOxidationStates, maxSites);
            if isempty(combinations)
                [symbols, amounts] = obj.elementAmounts();
                pairs = cell(numel(symbols), 2);
                for idx = 1:numel(symbols)
                    pairs{idx, 1} = ...
                        kssolv.analysis.matgenlab.core.Species(symbols(idx), 0);
                    pairs{idx, 2} = amounts(idx);
                end
            else
                pairs = cell(0, 2);
                chosen = combinations{1};
                symbols = string(fieldnames(chosen));
                for idx = 1:numel(symbols)
                    selected = chosen.(symbols(idx));
                    uniqueStates = unique(selected, "stable");
                    for state = reshape(uniqueStates, 1, [])
                        pairs(end + 1, :) = { ...
                            kssolv.analysis.matgenlab.core.Species(symbols(idx), state), ...
                            sum(selected == state)}; %#ok<AGROW>
                    end
                end
            end
            out = kssolv.analysis.matgenlab.core.Composition(pairs);
        end
        function out = remove_charges(obj), out = obj.element_composition; end

        function out = char(obj)
            pieces = strings(1, numel(obj.species_));
            for idx = 1:numel(obj.species_)
                pieces(idx) = string(obj.species_{idx}) + ...
                    kssolv.analysis.matgenlab.core.Composition. ...
                    formatAmount(obj.amounts_(idx), false);
            end
            out = char(strjoin(pieces, " "));
        end
        function out = string(obj), out = string(char(obj)); end
        function out = toPrettyString(obj), out = erase(string(obj), " "); end
        function out = to_pretty_string(obj), out = obj.toPrettyString(); end
        function out = to_latex_string(obj)
            out = regexprep(char(obj.reduced_formula), '([0-9.]+)', '$_{$1}$');
        end
        function out = to_html_string(obj)
            out = regexprep(char(obj.reduced_formula), '([0-9.]+)', '<sub>$1</sub>');
        end
    end

    methods (Static)
        function obj = fromDict(dct), obj = kssolv.analysis.matgenlab.core.Composition(dct); end
        function obj = from_dict(dct), obj = kssolv.analysis.matgenlab.core.Composition.fromDict(dct); end
        function obj = from_weight_dict(dct)
            [species, weights] = kssolv.analysis.matgenlab.core.Composition.unpackMapping(dct);
            mols = zeros(size(weights));
            for idx = 1:numel(species)
                el = kssolv.analysis.matgenlab.core.getElSp(species{idx});
                mols(idx) = weights(idx) / el.atomic_mass;
            end
            mols = mols / sum(mols);
            obj = kssolv.analysis.matgenlab.core.Composition( ...
                [species(:), num2cell(mols(:))], "strict", true);
        end
        function obj = from_weights(input)
            if ischar(input) || isstring(input)
                [symbols, weights] = kssolv.analysis.matgenlab.core.Composition.parseFormula(input);
                input = [cellstr(symbols(:)), num2cell(weights(:))];
            end
            obj = kssolv.analysis.matgenlab.core.Composition.from_weight_dict(input);
        end

        function compositions = ranked_compositions_from_indeterminate_formula( ...
                fuzzyFormula, lockIfStrict)
            if nargin < 2, lockIfStrict = true; end
            if lockIfStrict
                try
                    compositions = {kssolv.analysis.matgenlab.core. ...
                        Composition(fuzzyFormula)};
                    return
                catch
                    % Continue with fuzzy, case-insensitive parsing.
                end
            end
            candidates = kssolv.analysis.matgenlab.core.Composition. ...
                fuzzyParse(erase(string(fuzzyFormula), " "));
            if isempty(candidates), compositions = {}; return; end

            formulas = strings(1, numel(candidates));
            scores = zeros(1, numel(candidates));
            comps = cell(1, numel(candidates));
            for idx = 1:numel(candidates)
                map = candidates{idx}.map;
                pairs = [keys(map).', values(map).'];
                comps{idx} = kssolv.analysis.matgenlab.core.Composition(pairs);
                formulas(idx) = comps{idx}.formula;
                scores(idx) = candidates{idx}.score;
            end
            [uniqueFormulas, first] = unique(formulas, "stable"); %#ok<ASGLU>
            bestComps = cell(1, numel(first));
            bestScores = zeros(1, numel(first));
            for idx = 1:numel(first)
                members = find(formulas == formulas(first(idx)));
                [bestScores(idx), local] = max(scores(members));
                bestComps{idx} = comps{members(local)};
            end
            lexical = strings(1, numel(bestComps));
            for idx = 1:numel(bestComps), lexical(idx) = bestComps{idx}.formula; end
            ranking = table(-bestScores(:), lexical(:), (1:numel(bestComps)).', ...
                VariableNames=["negativeScore", "formula", "index"]);
            ranking = sortrows(ranking, ["negativeScore", "formula"]);
            compositions = bestComps(ranking.index);
        end
    end

    methods (Access = protected)
        function obj = addExact(obj, species, amount)
            for idx = 1:numel(obj.species_)
                if obj.sameSpecies(obj.species_{idx}, species)
                    obj.amounts_(idx) = obj.amounts_(idx) + amount;
                    return
                end
            end
            obj.species_{end + 1} = species;
            obj.amounts_(end + 1) = amount;
        end
        function obj = prune(obj)
            keep = abs(obj.amounts_) >= obj.amount_tolerance;
            obj.species_ = obj.species_(keep);
            obj.amounts_ = obj.amounts_(keep);
        end
        function out = scale(obj, factor)
            if ~isscalar(factor) || ~isfinite(factor)
                error("KSSOLV:Matgenlab:Composition:InvalidScale", ...
                    "Scale factor must be a finite scalar.");
            end
            if factor < 0 && ~obj.allow_negative
                error("KSSOLV:Matgenlab:Composition:NegativeAmount", ...
                    "Amounts in Composition cannot be negative.");
            end
            out = obj;
            out.amounts_ = out.amounts_ * factor;
            out = out.prune();
        end
    end

    methods (Access = private)
        function [symbols, amounts] = elementAmounts(obj)
            symbols = strings(1, 0); amounts = zeros(1, 0);
            for idx = 1:numel(obj.species_)
                symbol = obj.species_{idx}.symbol;
                loc = find(symbols == symbol, 1);
                if isempty(loc)
                    symbols(end + 1) = symbol; %#ok<AGROW>
                    amounts(end + 1) = obj.amounts_(idx); %#ok<AGROW>
                else
                    amounts(loc) = amounts(loc) + obj.amounts_(idx);
                end
            end
        end
    end

    methods (Static, Access = private)
        function tf = sameSpecies(a, b)
            if isa(a, "kssolv.analysis.matgenlab.core.Species") ~= ...
                    isa(b, "kssolv.analysis.matgenlab.core.Species")
                tf = false;
            else
                tf = a == b;
            end
        end

        function [species, amounts] = unpackMapping(input)
            if isstruct(input)
                names = fieldnames(input);
                species = names.';
                amounts = cellfun(@(n) input.(n), names).';
            elseif isa(input, "containers.Map")
                species = keys(input);
                amounts = cell2mat(values(input));
            elseif isa(input, "dictionary")
                keys_ = keys(input);
                values_ = values(input);
                species = num2cell(keys_);
                amounts = double(values_);
            elseif iscell(input) && size(input, 2) == 2
                species = input(:, 1).';
                amounts = cell2mat(input(:, 2)).';
            else
                error("KSSOLV:Matgenlab:Composition:InvalidInput", ...
                    "Composition input must be a formula or key/value mapping.");
            end
            species = reshape(species, 1, []);
            amounts = reshape(double(amounts), 1, []);
        end

        function [symbols, amounts] = parseFormula(formula_)
            formula_ = char(string(formula_));
            if isempty(strtrim(formula_)) || ~isempty(regexp(formula_, '^[\s\d.*/]*$', 'once'))
                error("KSSOLV:Matgenlab:Composition:InvalidFormula", ...
                    "Invalid formula='%s'.", formula_);
            end
            formula_ = strrep(formula_, "@", "");
            formula_ = replace(string(formula_), ["[","]","{","}"], ["(",")","(",")"]);
            [symbols, amounts, pos] = kssolv.analysis.matgenlab.core.Composition. ...
                parseSequence(char(formula_), 1, char(0));
            while pos <= strlength(formula_) && isspace(char(extractBetween(formula_, pos, pos)))
                pos = pos + 1;
            end
            if pos <= strlength(formula_)
                error("KSSOLV:Matgenlab:Composition:InvalidFormula", ...
                    "'%s' is an invalid formula.", formula_);
            end
        end

        function [symbols, amounts, pos] = parseSequence(text, pos, closing)
            symbols = strings(1, 0); amounts = zeros(1, 0);
            n = length(text);
            while pos <= n
                if isspace(text(pos)), pos = pos + 1; continue; end
                if closing ~= char(0) && text(pos) == closing
                    pos = pos + 1;
                    return
                end
                if text(pos) == '('
                    [subSymbols, subAmounts, pos] = ...
                        kssolv.analysis.matgenlab.core.Composition. ...
                        parseSequence(text, pos + 1, ')');
                    [factor, pos] = kssolv.analysis.matgenlab.core.Composition. ...
                        parseNumber(text, pos);
                    [symbols, amounts] = kssolv.analysis.matgenlab.core.Composition. ...
                        mergeAmounts(symbols, amounts, subSymbols, subAmounts * factor);
                elseif isstrprop(text(pos), "upper")
                    start = pos; pos = pos + 1;
                    if pos <= n && isstrprop(text(pos), "lower"), pos = pos + 1; end
                    symbol = string(text(start:pos-1));
                    if ~kssolv.analysis.matgenlab.core.Element.isValidSymbol(symbol)
                        try
                            kssolv.analysis.matgenlab.core.DummySpecies(symbol);
                        catch
                            error("KSSOLV:Matgenlab:Composition:InvalidFormula", ...
                                "%s is an invalid element or dummy symbol.", symbol);
                        end
                    end
                    [amount, pos] = kssolv.analysis.matgenlab.core.Composition. ...
                        parseNumber(text, pos);
                    [symbols, amounts] = kssolv.analysis.matgenlab.core.Composition. ...
                        mergeAmounts(symbols, amounts, symbol, amount);
                else
                    error("KSSOLV:Matgenlab:Composition:InvalidFormula", ...
                        "'%s' is an invalid formula.", text(pos:end));
                end
            end
            if closing ~= char(0)
                error("KSSOLV:Matgenlab:Composition:InvalidFormula", ...
                    "Unclosed group in formula.");
            end
        end

        function [value, pos] = parseNumber(text, pos)
            n = length(text);
            while pos <= n && isspace(text(pos)), pos = pos + 1; end
            match = regexp(text(pos:end), ...
                '^([-+]?(?:\d*\.?\d+)(?:[eE][-+]?\d+)?)', 'tokens', 'once');
            if isempty(match)
                value = 1;
            else
                value = str2double(match{1});
                pos = pos + length(match{1});
            end
        end

        function [symbols, amounts] = mergeAmounts(symbols, amounts, newSymbols, newAmounts)
            newSymbols = reshape(string(newSymbols), 1, []);
            newAmounts = reshape(double(newAmounts), 1, []);
            for idx = 1:numel(newSymbols)
                loc = find(symbols == newSymbols(idx), 1);
                if isempty(loc)
                    symbols(end + 1) = newSymbols(idx); %#ok<AGROW>
                    amounts(end + 1) = newAmounts(idx); %#ok<AGROW>
                else
                    amounts(loc) = amounts(loc) + newAmounts(idx);
                end
            end
        end

        function order = sortSymbols(symbols, iupac)
            ranks = zeros(numel(symbols), 2);
            for idx = 1:numel(symbols)
                el = kssolv.analysis.matgenlab.core.getElSp(symbols(idx));
                if iupac, ranks(idx, 1) = el.iupac_ordering;
                else
                    ranks(idx, 1) = el.X;
                    if isnan(ranks(idx, 1)), ranks(idx, 1) = Inf; end
                end
                ranks(idx, 2) = idx;
            end
            [~, idx] = sortrows(ranks, [1, 2]);
            % Alphabetical fallback for exactly equal ranks.
            groups = unique(ranks(idx, 1), "stable");
            final = zeros(size(idx)); cursor = 1;
            for value = reshape(groups, 1, [])
                members = find(ranks(:, 1) == value);
                [~, local] = sort(symbols(members));
                final(cursor:cursor+numel(members)-1) = members(local);
                cursor = cursor + numel(members);
            end
            order = symbols(final);
        end

        function [formula_, factor] = reduceFormula(symbols, amounts, iupac)
            keep = abs(amounts) > kssolv.analysis.matgenlab.core.Composition.amount_tolerance;
            symbols = symbols(keep); amounts = amounts(keep);
            ordered = kssolv.analysis.matgenlab.core.Composition.sortSymbols(symbols, false);
            [~, positions] = ismember(ordered, symbols);
            amounts = amounts(positions); symbols = ordered;
            if isempty(amounts), formula_ = ""; factor = 1; return; end
            factor = abs(round(amounts(1)));
            for idx = 2:numel(amounts), factor = gcd(factor, abs(round(amounts(idx)))); end
            if factor == 0, factor = 1; end

            poly = "";
            if numel(symbols) >= 3
                x1 = kssolv.analysis.matgenlab.core.getElSp(symbols(end)).X;
                x2 = kssolv.analysis.matgenlab.core.getElSp(symbols(end-1)).X;
                if x1 - x2 < 1.65
                    [polyFormula, polyFactor] = ...
                        kssolv.analysis.matgenlab.core.Composition.reduceFormula( ...
                        symbols(end-1:end), amounts(end-1:end) / factor, iupac);
                    if polyFactor ~= 1
                        poly = "(" + polyFormula + ")" + ...
                            kssolv.analysis.matgenlab.core.Composition.formatAmount(polyFactor, true);
                        symbols = symbols(1:end-2);
                        amounts = amounts(1:end-2);
                    end
                end
            end
            if iupac
                ordered = kssolv.analysis.matgenlab.core.Composition.sortSymbols(symbols, true);
                [~, positions] = ismember(ordered, symbols);
                amounts = amounts(positions); symbols = ordered;
            end
            pieces = strings(1, numel(symbols));
            for idx = 1:numel(symbols)
                pieces(idx) = symbols(idx) + ...
                    kssolv.analysis.matgenlab.core.Composition. ...
                    formatAmount(amounts(idx) / factor, true);
            end
            formula_ = strjoin(pieces, "") + poly;
        end

        function [formula_, factor] = applySpecialFormula(formula_, factor)
            from = ["LiO","NaO","KO","HO","CsO","RbO","O","N","F","Cl","H"];
            to = ["Li2O2","Na2O2","K2O2","H2O2","Cs2O2","Rb2O2", ...
                "O2","N2","F2","Cl2","H2"];
            idx = find(from == formula_, 1);
            if ~isempty(idx), formula_ = to(idx); factor = factor / 2; end
        end

        function out = formatAmount(value, omitOne)
            if omitOne && abs(value - 1) < 1e-12
                out = "";
            elseif abs(value - round(value)) < 1e-12
                out = string(sprintf("%d", round(value)));
            else
                out = string(sprintf("%.12g", value));
            end
        end

        function value = gcdFloat(values_, tolerance)
            scale = 1 / tolerance;
            ints = round(values_ * scale);
            g = abs(ints(1));
            for idx = 2:numel(ints), g = gcd(g, abs(ints(idx))); end
            value = g / scale;
        end

        function [guesses, combinations] = oxidationGuessDetails( ...
                obj, overrides, targetCharge, allOxidationStates, maxSites)
            elemental = obj.element_composition;
            if any(abs(elemental.amounts_ - round(elemental.amounts_)) > ...
                    obj.amount_tolerance)
                error("KSSOLV:Matgenlab:Composition:NonIntegerOxidationGuess", ...
                    "Charge balance analysis requires integer values in Composition.");
            end
            [symbols, amounts] = elemental.elementAmounts();
            divisor = abs(round(amounts(1)));
            for index = 2:numel(amounts)
                divisor = gcd(divisor, abs(round(amounts(index))));
            end
            if divisor < 1, divisor = 1; end

            if ~isempty(maxSites) && maxSites < 0
                amounts = amounts / divisor;
                if maxSites < -1 && sum(amounts) > abs(maxSites)
                    error("KSSOLV:Matgenlab:Composition:MaxSites", ...
                        "Composition cannot accommodate max_sites=%g.", maxSites);
                end
            elseif ~isempty(maxSites) && maxSites > 0 && sum(amounts) > maxSites
                if divisor > 1
                    amounts = amounts / divisor;
                    amounts = amounts * max(1, floor(maxSites / sum(amounts)));
                end
                if sum(amounts) > maxSites
                    error("KSSOLV:Matgenlab:Composition:MaxSites", ...
                        "Composition cannot accommodate max_sites=%g.", maxSites);
                end
            end

            options = cell(1, numel(symbols));
            for index = 1:numel(symbols)
                element = ...
                    kssolv.analysis.matgenlab.core.Element(symbols(index));
                states = localOverride(symbols(index), overrides);
                if isempty(states) && allOxidationStates
                    states = element.oxidation_states;
                elseif isempty(states)
                    states = element.icsd_oxidation_states;
                    if isempty(states)
                        states = element.common_oxidation_states;
                    end
                end
                if isempty(states), states = 0; end
                options{index} = ...
                    kssolv.analysis.matgenlab.core.Composition. ...
                    oxidationOptions(states, round(amounts(index)), ...
                        symbols(index));
            end

            guesses = cell(1, 0);
            combinations = cell(1, 0);
            scores = zeros(1, 0);
            recurse(1, zeros(1, numel(symbols)), 0);
            if ~isempty(scores)
                [~, order] = sort(scores, "descend");
                guesses = guesses(order);
                combinations = combinations(order);
            end

            function recurse(position, selectedSums, score)
                if position > numel(options)
                    if abs(sum(selectedSums) - targetCharge) > 1e-12
                        return
                    end
                    guess = struct();
                    combination = struct();
                    for item = 1:numel(symbols)
                        guess.(symbols(item)) = ...
                            selectedSums(item) / amounts(item);
                        location = find(abs(options{item}.sums - ...
                            selectedSums(item)) < 1e-12, 1);
                        combination.(symbols(item)) = ...
                            options{item}.combos{location};
                    end
                    guesses{end + 1} = guess;
                    combinations{end + 1} = combination;
                    scores(end + 1) = score;
                    return
                end
                for location = 1:numel(options{position}.sums)
                    selectedSums(position) = options{position}.sums(location);
                    recurse(position + 1, selectedSums, ...
                        score + options{position}.scores(location));
                end
            end

            function states = localOverride(symbol, values)
                states = [];
                if isempty(values), return; end
                name = char(symbol);
                if isstruct(values) && isfield(values, name)
                    states = double(values.(name));
                elseif isa(values, "containers.Map") && isKey(values, name)
                    states = double(values(name));
                end
            end
        end

        function options = oxidationOptions(states, count, symbol)
            if nargin < 3, symbol = ""; end
            states = reshape(unique(states, "stable"), 1, []);
            sums = zeros(1, 0);
            combos = cell(1, 0);
            scores = zeros(1, 0);
            priors = ...
                kssolv.analysis.matgenlab.core.Composition.oxidationPriors();
            recurse(1, 1, zeros(1, count));
            options = struct(sums=sums, combos={combos}, scores=scores);

            function recurse(position, firstState, selected)
                if position > count
                    value = sum(selected);
                    score = 0;
                    if strlength(symbol) > 0
                        for state = reshape(selected, 1, [])
                            species = kssolv.analysis.matgenlab.core. ...
                                Species(symbol, state);
                            key = char(string(species));
                            if isKey(priors, key), score = score + priors(key); end
                        end
                    end
                    location = find(abs(sums - value) < 1e-12, 1);
                    if isempty(location)
                        sums(end + 1) = value;
                        combos{end + 1} = selected;
                        scores(end + 1) = score;
                    elseif score > scores(location)
                        combos{location} = selected;
                        scores(location) = score;
                    end
                    return
                end
                for stateIndex = firstState:numel(states)
                    selected(position) = states(stateIndex);
                    recurse(position + 1, stateIndex, selected);
                end
            end
        end

        function priors = oxidationPriors()
            persistent cached
            if isempty(cached)
                here = fileparts(mfilename("fullpath"));
                rows = jsondecode(fileread(fullfile( ...
                    here, "+data", "oxidation_state_occurrence.json")));
                cached = containers.Map("KeyType", "char", ...
                    "ValueType", "double");
                for index = 1:numel(rows)
                    row = rows{index};
                    cached(char(string(row{1}))) = double(row{2});
                end
            end
            priors = cached;
        end

        function enumerateGuesses(options, symbols, amounts, idx, chosen, target, callback)
            if idx > numel(options)
                if abs(sum(chosen) - target) <= 1e-12
                    result = struct();
                    for pos = 1:numel(symbols)
                        result.(symbols(pos)) = chosen(pos) / amounts(pos);
                    end
                    callback(result);
                end
                return
            end
            for value = reshape(options{idx}, 1, [])
                chosen(idx) = value;
                kssolv.analysis.matgenlab.core.Composition.enumerateGuesses( ...
                    options, symbols, amounts, idx + 1, chosen, target, callback);
            end
        end

        function results = fuzzyParse(text)
            text = char(text);
            results = {};
            emptyMap = containers.Map("KeyType", "char", "ValueType", "double");
            parseAt(1, emptyMap, 0);

            function parseAt(position, current, score)
                if position > length(text)
                    results{end + 1} = struct(map=current, score=score);
                    return
                end
                if text(position) == '('
                    depth = 1; closePos = position + 1;
                    while closePos <= length(text) && depth > 0
                        if text(closePos) == '(', depth = depth + 1;
                        elseif text(closePos) == ')', depth = depth - 1;
                        end
                        closePos = closePos + 1;
                    end
                    if depth ~= 0, return; end
                    closePos = closePos - 1;
                    [factor, nextPos] = kssolv.analysis.matgenlab.core. ...
                        Composition.parseNumber(text, closePos + 1);
                    inside = kssolv.analysis.matgenlab.core.Composition. ...
                        fuzzyParse(text(position + 1:closePos - 1));
                    for altIndex = 1:numel(inside)
                        merged = kssolv.analysis.matgenlab.core.Composition. ...
                            copyMap(current);
                        altKeys = keys(inside{altIndex}.map);
                        for keyIndex = 1:numel(altKeys)
                            key = altKeys{keyIndex};
                            value = inside{altIndex}.map(key) * factor;
                            if isKey(merged, key), merged(key) = merged(key) + value;
                            else, merged(key) = value;
                            end
                        end
                        parseAt(nextPos, merged, score + inside{altIndex}.score);
                    end
                    return
                end
                if ~isletter(text(position)), return; end
                for tokenLength = 1:min(2, length(text) - position + 1)
                    raw = text(position:position + tokenLength - 1);
                    if ~all(isletter(raw)), continue; end
                    symbol = upper(string(raw(1)));
                    points = double(isstrprop(raw(1), "upper")) * 100;
                    if tokenLength == 2
                        symbol = symbol + lower(string(raw(2)));
                        points = points + double(isstrprop(raw(2), "lower")) * 100;
                    end
                    if ~kssolv.analysis.matgenlab.core.Element.isValidSymbol(symbol)
                        continue
                    end
                    [amount, nextPos] = kssolv.analysis.matgenlab.core. ...
                        Composition.parseNumber(text, position + tokenLength);
                    updated = kssolv.analysis.matgenlab.core.Composition.copyMap(current);
                    key = char(symbol);
                    if isKey(updated, key), updated(key) = updated(key) + amount;
                    else, updated(key) = amount;
                    end
                    parseAt(nextPos, updated, score + points);
                end
            end
        end

        function result = copyMap(source)
            if source.Count == 0
                result = containers.Map("KeyType", "char", "ValueType", "double");
            else
                result = containers.Map(keys(source), values(source));
            end
        end
    end
end
