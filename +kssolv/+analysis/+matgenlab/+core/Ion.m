classdef Ion < kssolv.analysis.matgenlab.core.Composition
    %ION Composition with an explicitly stored net charge.

    properties (Access = private)
        charge_ (1,1) double = 0
    end

    properties (Dependent)
        composition
    end

    methods
        function obj = Ion(composition, charge, varargin)
            if nargin < 1, composition = kssolv.analysis.matgenlab.core.Composition(); end
            if nargin < 2, charge = 0; end
            obj@kssolv.analysis.matgenlab.core.Composition(composition, varargin{:});
            if ~isscalar(charge) || ~isfinite(charge)
                error("KSSOLV:Matgenlab:Ion:InvalidCharge", ...
                    "Ion charge must be a finite scalar.");
            end
            obj.charge_ = double(charge);
        end

        function out = get.composition(obj)
            pairs = [obj.species_.', num2cell(obj.amounts_.')];
            out = kssolv.analysis.matgenlab.core.Composition(pairs, ...
                "allow_negative", obj.allow_negative);
        end
        function out = ionFormula(obj)
            out = obj.composition.formula + " " + ...
                kssolv.analysis.matgenlab.core.Ion.chargeString(obj.charge_, false);
        end
        function out = ionAlphabeticalFormula(obj)
            out = obj.composition.alphabetical_formula + " " + ...
                kssolv.analysis.matgenlab.core.Ion.chargeString(obj.charge_, false);
        end
        function out = ionAnonymizedFormula(obj)
            out = obj.composition.anonymized_formula + ...
                kssolv.analysis.matgenlab.core.Ion.chargeString(obj.charge_, false);
        end
        function out = ionReducedFormula(obj)
            [formula_, factor] = obj.get_reduced_formula_and_factor();
            out = formula_ + kssolv.analysis.matgenlab.core.Ion. ...
                chargeString(obj.charge_ / factor, true);
        end
        function out = explicitCharge(obj), out = obj.charge_; end

        function tf = eq(a, b)
            tf = isa(b, "kssolv.analysis.matgenlab.core.Ion") && ...
                a.composition == b.composition && a.charge_ == b.charge_;
        end
        function tf = ne(a, b), tf = ~eq(a, b); end
        function out = plus(a, b)
            if ~isa(b, "kssolv.analysis.matgenlab.core.Ion")
                error("KSSOLV:Matgenlab:Ion:Add", "Ions can only be added to Ions.");
            end
            out = kssolv.analysis.matgenlab.core.Ion( ...
                a.composition + b.composition, a.charge_ + b.charge_);
        end
        function out = minus(a, b)
            if ~isa(b, "kssolv.analysis.matgenlab.core.Ion")
                error("KSSOLV:Matgenlab:Ion:Subtract", "Ions can only be subtracted from Ions.");
            end
            out = kssolv.analysis.matgenlab.core.Ion( ...
                a.composition - b.composition, a.charge_ - b.charge_);
        end
        function out = mtimes(a, b)
            if isnumeric(a) && isscalar(a)
                out = kssolv.analysis.matgenlab.core.Ion( ...
                    b.composition * a, b.charge_ * a);
            elseif isnumeric(b) && isscalar(b)
                out = kssolv.analysis.matgenlab.core.Ion( ...
                    a.composition * b, a.charge_ * b);
            else
                error("KSSOLV:Matgenlab:Ion:Multiply", ...
                    "An Ion can only be multiplied by a scalar.");
            end
        end
        function out = times(a, b), out = mtimes(a, b); end

        function [formula_, factor] = get_reduced_formula_and_factor(obj, iupacOrdering, hydrates)
            if nargin < 2, iupacOrdering = false; end
            if nargin < 3, hydrates = false; end
            comp = obj.composition;
            if any(abs(comp.values() - round(comp.values())) >= comp.amount_tolerance)
                formula_ = erase(obj.formula, " "); factor = 1; return
            end

            nWater = 0;
            if hydrates
                nH = comp.amountOf("H"); nO = comp.amountOf("O");
                containsMetal = false;
                for idx = 1:numel(comp.elements)
                    containsMetal = containsMetal || comp.elements{idx}.is_metal;
                end
                if nO > 0 && containsMetal
                    if nH >= 2 * nO, nWater = floor(nO);
                    else, nWater = floor(nH / 2);
                    end
                    comp = comp - kssolv.analysis.matgenlab.core.Composition("H2O") * nWater;
                end
            end

            % Composition's reducer supplies the pymatgen polyanion logic;
            % undo solid-only peroxide/diatomic special cases below.
            [formula_, factor] = comp.get_reduced_formula_and_factor(iupacOrdering);
            [formula_, factor] = kssolv.analysis.matgenlab.core.Ion. ...
                undoSolidFormula(formula_, factor);
            if obj.composition.amountOf("H") == obj.composition.amountOf("O")
                formula_ = replace(formula_, "HO", "OH");
            end
            if nWater > 0
                formula_ = formula_ + "." + string(nWater) + "H2O";
            end

            % Ion-specific canonical aqueous formulas, matching pymatgen.
            switch formula_
                case "OH"
                    if obj.charge_ == 0, formula_ = "H2O2"; factor = factor / 2; end
                case "H2CO"
                    formula_ = "CH3COOH"; factor = factor / 2;
                case "PH3O4"
                    formula_ = "H3PO4";
                case "PHO4"
                    formula_ = "HPO4";
                case "P(HO2)2"
                    formula_ = "H2PO4";
                case "H3(CO)2"
                    formula_ = "CH3COO";
                case "H4CO"
                    formula_ = "CH3OH";
                case "H6C2O"
                    formula_ = "C2H5OH";
                case "H8C3O"
                    formula_ = "C3H7OH";
                case "H10C4O"
                    formula_ = "C4H9OH";
                case "H4N"
                    formula_ = "NH4";
                case "H3N"
                    formula_ = "NH3";
                case "H4C"
                    formula_ = "CH4";
                case "CSN"
                    formula_ = "SCN";
                case "HCOO"
                    formula_ = "HCO2";
                case "CO2"
                    if obj.charge_ == -2, formula_ = "C2O4"; factor = factor / 2; end
            end
            if formula_ == "O" && mod(factor, 3) == 0
                formula_ = "O3"; factor = factor / 3;
            elseif ismember(formula_, ["N", "P"]) && obj.charge_ == -1
                formula_ = formula_ + "3"; factor = factor / 3;
            elseif formula_ == "I" && abs(obj.charge_ - 1/3) < 1e-12
                formula_ = "I3"; factor = factor / 3;
            elseif ismember(formula_, ["O", "N", "F", "Cl", "H"]) && mod(factor, 2) == 0
                formula_ = formula_ + "2"; factor = factor / 2;
            end
        end

        function guesses = oxi_state_guesses(obj, allOxidationStates)
            if nargin < 2, allOxidationStates = false; end
            guesses = obj.composition.oxi_state_guesses( ...
                [], obj.charge_, allOxidationStates);
        end

        function map = asDict(obj)
            map = obj.composition.asDict();
            map("charge") = obj.charge_;
        end
        function map = as_dict(obj), map = obj.asDict(); end
        function map = as_reduced_dict(obj)
            unreduced = obj.composition.asDict();
            map = obj.composition.reduced_composition.asDict();
            factor = 1;
            ks = keys(map);
            for idx = 1:numel(ks)
                if isKey(unreduced, ks{idx})
                    factor = unreduced(ks{idx}) / map(ks{idx});
                    break
                end
            end
            map("charge") = obj.charge_ / factor;
        end
        function map = to_reduced_dict(obj), map = obj.as_reduced_dict(); end

        function out = char(obj), out = char(obj.formula); end
        function out = string(obj), out = obj.formula; end
        function out = toPrettyString(obj)
            base = obj.composition.reduced_formula;
            if obj.charge_ == 0, out = base;
            else, out = base + "^" + compose("%+g", obj.charge_);
            end
        end
        function out = to_pretty_string(obj), out = obj.toPrettyString(); end
        function out = to_latex_string(obj)
            base = obj.composition.to_latex_string();
            base = string(base);
            if obj.charge_ ~= 0
                base = base + "$^{" + compose("%+g", obj.charge_) + "}$";
            end
            out = base;
        end
    end

    methods (Static)
        function obj = fromFormula(formula_)
            formula_ = char(string(formula_));
            formula_ = regexprep(formula_, '\s*\(aq\)\s*', '', 'once');
            charge = 0;

            bracket = regexp(formula_, '\[([^\[\]]+)\]', 'tokens', 'once');
            if ~isempty(bracket)
                charge = kssolv.analysis.matgenlab.core.Ion.parseCharge(bracket{1});
                formula_ = regexprep(formula_, '\[[^\[\]]+\]', '', 'once');
            else
                % Only a trailing charge belongs to the ion. This preserves
                % stoichiometric digits in cases such as Ca2+ and SO42-.
                signs = regexp(formula_, '([+-]{2,})$', 'tokens', 'once');
                if ~isempty(signs)
                    charge = sum(char(signs{1}) == '+') - sum(char(signs{1}) == '-');
                    formula_ = regexprep(formula_, '([+-]{2,})$', '', 'once');
                else
                    match = regexp(formula_, '([+-])([.\d]*)$', 'tokens', 'once');
                    if ~isempty(match)
                        if isempty(match{2}), magnitude = 1; else, magnitude = str2double(match{2}); end
                        if strcmp(match{1}, "-"), magnitude = -magnitude; end
                        charge = magnitude;
                        formula_ = regexprep(formula_, '([+-])([.\d]*)$', '', 'once');
                    end
                end
            end
            obj = kssolv.analysis.matgenlab.core.Ion( ...
                kssolv.analysis.matgenlab.core.Composition(formula_), charge);
        end
        function obj = from_formula(formula_), obj = kssolv.analysis.matgenlab.core.Ion.fromFormula(formula_); end

        function obj = fromDict(dct)
            if isa(dct, "containers.Map")
                copy = containers.Map(keys(dct), values(dct));
                if ~isKey(copy, "charge")
                    error("KSSOLV:Matgenlab:Ion:MissingCharge", ...
                        "Serialized Ion is missing its charge.");
                end
                charge = copy("charge"); remove(copy, "charge");
                comp = kssolv.analysis.matgenlab.core.Composition(copy);
            else
                charge = dct.charge;
                dct = rmfield(dct, "charge");
                comp = kssolv.analysis.matgenlab.core.Composition(dct);
            end
            obj = kssolv.analysis.matgenlab.core.Ion(comp, charge);
        end
        function obj = from_dict(dct), obj = kssolv.analysis.matgenlab.core.Ion.fromDict(dct); end
    end

    methods (Static, Access = private)
        function charge = parseCharge(text)
            text = char(string(text));
            if isempty(regexp(text, '^(?:[.\d]*[+-]+|[+-]+[.\d]*)$', 'once'))
                error("KSSOLV:Matgenlab:Ion:InvalidFormula", "Invalid ion charge.");
            end
            signs = text(text == '+' | text == '-');
            prefix = regexp(text, '^[.\d]+', 'match', 'once');
            suffix = regexp(text, '[.\d]+$', 'match', 'once');
            if ~isempty(prefix) && ~isempty(suffix)
                error("KSSOLV:Matgenlab:Ion:InvalidFormula", "Invalid ion charge.");
            elseif ~isempty(prefix)
                magnitude = str2double(prefix);
                charge = magnitude * (sum(signs == '+') - sum(signs == '-'));
            elseif ~isempty(suffix)
                magnitude = str2double(suffix);
                charge = magnitude * (sum(signs == '+') - sum(signs == '-'));
            else
                charge = sum(signs == '+') - sum(signs == '-');
            end
        end
        function out = chargeString(charge, brackets)
            if charge == 0, out = "(aq)"; return; end
            if charge > 0, sign_ = "+"; else, sign_ = "-"; end
            value = abs(charge);
            if abs(value - round(value)) < 1e-12
                magnitude = string(sprintf("%d", round(value)));
            else
                magnitude = string(sprintf("%.12g", value));
            end
            if brackets, out = "[" + sign_ + magnitude + "]";
            else, out = sign_ + magnitude;
            end
        end
        function [formula_, factor] = undoSolidFormula(formula_, factor)
            from = ["Li2O2","Na2O2","K2O2","H2O2","Cs2O2","Rb2O2", ...
                "O2","N2","F2","Cl2","H2"];
            to = ["LiO","NaO","KO","HO","CsO","RbO","O","N","F","Cl","H"];
            idx = find(from == formula_, 1);
            if ~isempty(idx)
                formula_ = to(idx);
                factor = factor * 2;
            end
        end
    end
end
