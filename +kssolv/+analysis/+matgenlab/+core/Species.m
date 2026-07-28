classdef Species
    %SPECIES Element carrying an optional oxidation state and spin.

    properties (SetAccess = protected)
        symbol (1,1) string = "H"
        oxi_state (1,1) double = NaN
        spin (1,1) double = NaN
        element (1,1) kssolv.analysis.matgenlab.core.Element = ...
            kssolv.analysis.matgenlab.core.Element("H")
        Z (1,1) double = 1
        A (1,1) double = NaN
    end

    properties (Access = protected)
        is_dummy (1,1) logical = false
    end

    properties (Dependent)
        name
        X
        atomic_mass
        atomic_radius
        electronic_structure
        full_electronic_structure
        n_electrons
        valence
        ionic_radius
        row
        group
        block
        iupac_ordering
        oxidation_states
        common_oxidation_states
        is_metal
        is_transition_metal
        is_noble_gas
        is_post_transition_metal
        is_rare_earth
        is_metalloid
        is_alkali
        is_alkaline
        is_halogen
        is_chalcogen
        is_lanthanoid
        is_actinoid
        is_radioactive
        is_quadrupolar
        data
    end

    methods
        function obj = Species(symbol, oxidationState, varargin)
            if nargin == 0, return; end
            if isa(symbol, "kssolv.analysis.matgenlab.core.Species")
                obj = symbol;
                return
            end
            symbol = string(symbol);
            explicitOxi = nargin >= 2 && ~isempty(oxidationState);
            parsed = regexp(char(symbol), ...
                '^([A-Z][a-z]*)([0-9]*\.?[0-9]*)([+-])$', 'tokens', 'once');
            if ~isempty(parsed)
                if explicitOxi
                    error("KSSOLV:Matgenlab:Species:DuplicateOxidationState", ...
                        "Oxidation state must be specified either in symbol or as an argument, not both.");
                end
                symbol = string(parsed{1});
                magnitude = str2double(parsed{2});
                if isnan(magnitude), magnitude = 1; end
                if parsed{3} == '-', magnitude = -magnitude; end
                oxidationState = magnitude;
            elseif ~explicitOxi
                oxidationState = NaN;
            end

            spinValue = NaN;
            if ~isempty(varargin)
                if isscalar(varargin) && isnumeric(varargin{1})
                    spinValue = varargin{1};
                else
                    for idx = 1:2:numel(varargin)
                        if idx + 1 > numel(varargin)
                            error("KSSOLV:Matgenlab:Species:InvalidArguments", ...
                                "Name-value arguments must occur in pairs.");
                        end
                        if strcmpi(string(varargin{idx}), "spin")
                            spinValue = varargin{idx + 1};
                        else
                            error("KSSOLV:Matgenlab:Species:InvalidOption", ...
                                "Unknown Species option '%s'.", string(varargin{idx}));
                        end
                    end
                end
            end

            obj.element = kssolv.analysis.matgenlab.core.Element(symbol);
            obj.symbol = obj.element.symbol;
            obj.Z = obj.element.Z;
            obj.A = obj.element.A;
            obj.oxi_state = double(oxidationState);
            obj.spin = double(spinValue);
        end

        function out = get.name(obj), out = obj.symbol; end
        function out = get.X(obj)
            if obj.is_dummy, out = 0; else, out = obj.element.X; end
        end
        function out = get.atomic_mass(obj)
            if obj.is_dummy, out = 0; else, out = obj.element.atomic_mass; end
        end
        function out = get.atomic_radius(obj)
            if obj.is_dummy, out = NaN; else, out = obj.element.atomic_radius; end
        end
        function out = get.row(obj)
            if obj.is_dummy, out = NaN; else, out = obj.element.row; end
        end
        function out = get.group(obj)
            if obj.is_dummy, out = NaN; else, out = obj.element.group; end
        end
        function out = get.block(obj)
            if obj.is_dummy, out = ""; else, out = obj.element.block; end
        end
        function out = get.iupac_ordering(obj)
            if obj.is_dummy, out = 0; else, out = obj.element.iupac_ordering; end
        end
        function out = get.oxidation_states(obj)
            if obj.is_dummy, out = []; else, out = obj.element.oxidation_states; end
        end
        function out = get.common_oxidation_states(obj)
            if obj.is_dummy, out = []; else, out = obj.element.common_oxidation_states; end
        end
        function out = get.is_metal(obj), out = ~obj.is_dummy && obj.element.is_metal; end
        function out = get.is_transition_metal(obj), out = ~obj.is_dummy && obj.element.is_transition_metal; end
        function out = get.is_noble_gas(obj), out = ~obj.is_dummy && obj.element.is_noble_gas; end
        function out = get.is_post_transition_metal(obj), out = ~obj.is_dummy && obj.element.is_post_transition_metal; end
        function out = get.is_rare_earth(obj), out = ~obj.is_dummy && obj.element.is_rare_earth; end
        function out = get.is_metalloid(obj), out = ~obj.is_dummy && obj.element.is_metalloid; end
        function out = get.is_alkali(obj), out = ~obj.is_dummy && obj.element.is_alkali; end
        function out = get.is_alkaline(obj), out = ~obj.is_dummy && obj.element.is_alkaline; end
        function out = get.is_halogen(obj), out = ~obj.is_dummy && obj.element.is_halogen; end
        function out = get.is_chalcogen(obj), out = ~obj.is_dummy && obj.element.is_chalcogen; end
        function out = get.is_lanthanoid(obj), out = ~obj.is_dummy && obj.element.is_lanthanoid; end
        function out = get.is_actinoid(obj), out = ~obj.is_dummy && obj.element.is_actinoid; end
        function out = get.is_radioactive(obj), out = ~obj.is_dummy && obj.element.is_radioactive; end
        function out = get.is_quadrupolar(obj), out = ~obj.is_dummy && obj.element.is_quadrupolar; end
        function out = get.data(obj)
            if obj.is_dummy, out = struct(); else, out = obj.element.data; end
        end

        function out = get.electronic_structure(obj)
            if obj.is_dummy
                error("KSSOLV:Matgenlab:Species:NoElectronicStructure", ...
                    "Dummy species have no electronic structure.");
            end
            configs = obj.element.getData("Electronic structure", struct());
            key = obj.oxi_state;
            if isnan(key), key = 0; end
            out = kssolv.analysis.matgenlab.core.PeriodicTableData. ...
                numericField(configs, key, "");
            if strlength(string(out)) == 0
                error("KSSOLV:Matgenlab:Species:NoElectronicStructure", ...
                    "No electronic structure data for oxidation state %g.", obj.oxi_state);
            end
            out = string(out);
        end
        function out = get.full_electronic_structure(obj)
            out = kssolv.analysis.matgenlab.core.Element. ...
                parse_electronic_structure(obj.electronic_structure);
        end
        function out = get.n_electrons(obj)
            config = obj.full_electronic_structure;
            out = sum(cell2mat(config(:, 3)));
        end
        function out = get.valence(obj)
            if isnan(obj.oxi_state) || obj.oxi_state == 0
                out = obj.element.valence;
                return
            end
            config = obj.full_electronic_structure;
            if obj.group == 18, out = [NaN, 0]; return; end
            angular = "spdfghiklmnoqrtuvwxyz";
            candidates = zeros(0, 2);
            for idx = 1:size(config, 1)
                l = strfind(angular, string(config{idx, 2})) - 1;
                ne = config{idx, 3};
                if ne < 2 * (2 * l + 1) || (idx == size(config, 1) && isempty(candidates))
                    candidates(end + 1, :) = [l, ne]; %#ok<AGROW>
                end
            end
            if size(candidates, 1) ~= 1
                error("KSSOLV:Matgenlab:Species:AmbiguousValence", ...
                    "%s has ambiguous valence.", char(obj));
            end
            out = candidates(1, :);
        end
        function out = get.ionic_radius(obj)
            if obj.is_dummy || isnan(obj.oxi_state), out = NaN; return; end
            radii = obj.element.ionic_radii;
            if isKey(radii, obj.oxi_state)
                out = radii(obj.oxi_state);
                return
            end
            out = NaN;
            for key = ["Ionic radii hs", "Ionic radii ls"]
                candidate = kssolv.analysis.matgenlab.core. ...
                    PeriodicTableData.numericField(obj.element.getData(key, struct()), ...
                    obj.oxi_state, NaN);
                if ~isnan(candidate), out = candidate; return; end
            end
        end

        function value = get_nmr_quadrupole_moment(obj, isotope)
            if nargin < 2, isotope = ""; end
            moments = obj.element.nmr_quadrupole_moment;
            names = fieldnames(moments);
            if isempty(names), value = 0; return; end
            if strlength(string(isotope)) == 0
                masses = zeros(numel(names), 1);
                for idx = 1:numel(names)
                    match = regexp(names{idx}, '(\d+)$', 'tokens', 'once');
                    if isempty(match), masses(idx) = Inf; else, masses(idx) = str2double(match{1}); end
                end
                [~, idx] = min(masses);
                value = moments.(names{idx});
                return
            end
            field = matlab.lang.makeValidName(char(string(isotope)));
            if ~isfield(moments, field)
                error("KSSOLV:Matgenlab:Species:UnknownIsotope", ...
                    "No quadrupole moment for isotope '%s'.", string(isotope));
            end
            value = moments.(field);
        end

        function value = get_shannon_radius(obj, cn, spinMode, radiusType)
            if nargin < 3, spinMode = ""; end
            if nargin < 4, radiusType = "ionic"; end
            if obj.is_dummy || isnan(obj.oxi_state)
                error("KSSOLV:Matgenlab:Species:MissingOxidationState", ...
                    "A Shannon radius requires an oxidation state.");
            end
            radii = obj.element.getData("Shannon radii", struct());
            oxiData = kssolv.analysis.matgenlab.core.PeriodicTableData. ...
                numericField(radii, obj.oxi_state, []);
            cnField = matlab.lang.makeValidName(char(string(cn)));
            if isempty(oxiData) || ~isfield(oxiData, cnField)
                error("KSSOLV:Matgenlab:Species:MissingShannonRadius", ...
                    "No Shannon radius for %s at coordination %s.", char(obj), string(cn));
            end
            spins = oxiData.(cnField);
            names = fieldnames(spins);
            if isscalar(names)
                selected = spins.(names{1});
            else
                spinField = matlab.lang.makeValidName(char(string(spinMode)));
                if ~isfield(spins, spinField)
                    error("KSSOLV:Matgenlab:Species:MissingShannonRadius", ...
                        "No Shannon radius for spin mode '%s'.", string(spinMode));
                end
                selected = spins.(spinField);
            end
            field = matlab.lang.makeValidName(char(string(radiusType) + "_radius"));
            value = selected.(field);
        end

        function value = get_crystal_field_spin(obj, coordination, spinConfig)
            if nargin < 2, coordination = "oct"; end
            if nargin < 3, spinConfig = "high"; end
            coordination = string(coordination);
            spinConfig = string(spinConfig);
            if ~ismember(coordination, ["oct", "tet"]) || ~ismember(spinConfig, ["low", "high"])
                error("KSSOLV:Matgenlab:Species:CrystalField", ...
                    "Invalid coordination or spin configuration.");
            end
            config = obj.element.full_electronic_structure;
            if size(config, 1) < 2 || config{end - 1, 2} ~= "s" || config{end, 2} ~= "d"
                error("KSSOLV:Matgenlab:Species:CrystalField", ...
                    "Invalid element %s for crystal-field calculation.", obj.symbol);
            end
            if isnan(obj.oxi_state)
                error("KSSOLV:Matgenlab:Species:MissingOxidationState", ...
                    "A crystal-field calculation requires an oxidation state.");
            end
            ne = config{end, 3} + config{end - 1, 3} - obj.oxi_state;
            if ne < 0 || ne > 10
                error("KSSOLV:Matgenlab:Species:CrystalField", ...
                    "Invalid oxidation state for crystal-field calculation.");
            end
            if spinConfig == "high"
                value = min(ne, 10 - ne);
            elseif coordination == "oct"
                if ne <= 3, value = ne;
                elseif ne <= 6, value = 6 - ne;
                elseif ne <= 8, value = ne - 6;
                else, value = 10 - ne;
                end
            else
                if ne <= 2, value = ne;
                elseif ne <= 4, value = 4 - ne;
                elseif ne <= 7, value = ne - 4;
                else, value = 10 - ne;
                end
            end
        end

        function tf = eq(a, b)
            if ~isa(b, "kssolv.analysis.matgenlab.core.Species")
                tf = false; return
            end
            tf = a.symbol == b.symbol && ...
                kssolv.analysis.matgenlab.core.Species.nanEqual(a.oxi_state, b.oxi_state) && ...
                kssolv.analysis.matgenlab.core.Species.nanEqual(a.spin, b.spin) && ...
                kssolv.analysis.matgenlab.core.Species.nanEqual(a.A, b.A);
        end
        function tf = ne(a, b), tf = ~eq(a, b); end
        function tf = lt(a, b)
            ax = a.X; bx = b.X;
            if isnan(ax), ax = Inf; end
            if isnan(bx), bx = Inf; end
            if ax ~= bx, tf = ax < bx; return; end
            if a.symbol ~= b.symbol, tf = a.symbol < b.symbol; return; end
            ao = a.oxi_state; bo = b.oxi_state;
            if isnan(ao), ao = 0; end
            if isnan(bo), bo = 0; end
            if ao ~= bo, tf = ao < bo; return; end
            as = a.spin; bs = b.spin;
            if isnan(as), as = Inf; end
            if isnan(bs), bs = Inf; end
            tf = as < bs;
        end

        function out = char(obj)
            out = char(obj.toPrettyString());
            if ~isnan(obj.spin)
                out = sprintf("%s,spin=%s", out, ...
                    kssolv.analysis.matgenlab.core.Species.formatNumber(obj.spin, false));
            end
        end
        function out = string(obj), out = string(char(obj)); end
        function out = toPrettyString(obj)
            out = obj.symbol;
            if ~isnan(obj.oxi_state)
                magnitude = kssolv.analysis.matgenlab.core.Species. ...
                    formatNumber(abs(obj.oxi_state), true);
                if obj.oxi_state >= 0, sign_ = "+"; else, sign_ = "-"; end
                out = out + magnitude + sign_;
            end
        end
        function out = to_pretty_string(obj), out = obj.toPrettyString(); end

        function result = asDict(obj)
            result = struct(x_module="pymatgen.core.periodic_table", ...
                x_class="Species", element=obj.symbol, ...
                oxidation_state=obj.oxi_state, spin=obj.spin);
        end
        function result = as_dict(obj), result = obj.asDict(); end
    end

    methods (Static)
        function obj = fromStr(text)
            text = string(text);
            spinMatch = regexp(char(text), ',?spin=([-+]?\d*\.?\d+)$', ...
                'tokens', 'once');
            if isempty(spinMatch)
                spinValue = NaN;
                base = char(text);
            else
                spinValue = str2double(spinMatch{1});
                base = regexprep(char(text), ',?spin=([-+]?\d*\.?\d+)$', '');
            end
            parsed = regexp(base, ...
                '^([A-Z][a-z]*)([0-9]*\.?[0-9]*)([+-]?)$', ...
                'tokens', 'once');
            if isempty(parsed)
                error("KSSOLV:Matgenlab:Species:Parse", ...
                    "Invalid species string '%s'.", text);
            end
            hasOxi = ~isempty(parsed{2}) || ~isempty(parsed{3});
            hasSpin = ~isnan(spinValue);
            if ~hasOxi && ~hasSpin
                error("KSSOLV:Matgenlab:Species:Parse", ...
                    "Invalid species string '%s'.", text);
            end
            if hasOxi
                magnitude = str2double(parsed{2});
                if isnan(magnitude), magnitude = 1; end
                if strcmp(parsed{3}, "-"), magnitude = -magnitude; end
            else
                magnitude = 0;
            end
            if hasSpin
                obj = kssolv.analysis.matgenlab.core.Species(parsed{1}, magnitude, ...
                    "spin", spinValue);
            else
                obj = kssolv.analysis.matgenlab.core.Species(parsed{1}, magnitude);
            end
        end
        function obj = from_str(text), obj = kssolv.analysis.matgenlab.core.Species.fromStr(text); end
        function obj = fromDict(dct)
            spinValue = NaN;
            if isfield(dct, "spin") && ~isempty(dct.spin), spinValue = dct.spin; end
            obj = kssolv.analysis.matgenlab.core.Species( ...
                dct.element, dct.oxidation_state, "spin", spinValue);
        end
        function obj = from_dict(dct), obj = kssolv.analysis.matgenlab.core.Species.fromDict(dct); end
    end

    methods (Static, Access = protected)
        function out = formatNumber(value, omitOne)
            if nargin < 2, omitOne = false; end
            if omitOne && abs(value - 1) < 1e-12
                out = "";
            elseif abs(value - round(value)) < 1e-12
                out = string(sprintf("%d", round(value)));
            else
                out = string(sprintf("%.8g", value));
            end
        end
        function tf = nanEqual(a, b), tf = a == b || (isnan(a) && isnan(b)); end
    end
end
