classdef Element
    %ELEMENT Immutable chemical element compatible with pymatgen Element.
    %
    % Numeric physical properties are returned in the units documented by
    % pymatgen's periodic_table.json (atomic mass in amu, radii in angstrom,
    % temperatures in kelvin). Unit-wrapped values can be layered on by the
    % matgenlab units package without changing this object's data model.

    properties (SetAccess = private)
        symbol (1,1) string
        Z (1,1) double
        A (1,1) double = NaN
        long_name (1,1) string
    end

    properties (Access = private)
        source_symbol (1,1) string
        record (1,1) struct
    end

    properties (Dependent)
        name
        number
        X
        atomic_radius
        atomic_mass
        atomic_mass_number
        atomic_orbitals
        atomic_orbitals_eV
        data
        ionization_energy
        electron_affinity
        electronic_structure
        average_ionic_radius
        average_cationic_radius
        average_anionic_radius
        ionic_radii
        max_oxidation_state
        min_oxidation_state
        oxidation_states
        common_oxidation_states
        icsd_oxidation_states
        full_electronic_structure
        n_electrons
        valence
        term_symbols
        row
        group
        block
        is_noble_gas
        is_transition_metal
        is_post_transition_metal
        is_rare_earth
        is_metal
        is_metalloid
        is_alkali
        is_alkaline
        is_halogen
        is_chalcogen
        is_lanthanoid
        is_actinoid
        is_radioactive
        is_quadrupolar
        nmr_quadrupole_moment
        iupac_ordering
        ground_state_term_symbol
        metallic_radius
        atomic_radius_calculated
        van_der_waals_radius
        mendeleev_no
        ionization_energies
        electrical_resistivity
        velocity_of_sound
        reflectivity
        refractive_index
        poissons_ratio
        molar_volume
        thermal_conductivity
        boiling_point
        melting_point
        critical_temperature
        superconduction_temperature
        liquid_range
        bulk_modulus
        youngs_modulus
        brinell_hardness
        rigidity_modulus
        mineral_hardness
        vickers_hardness
        density_of_solid
        coefficient_of_linear_thermal_expansion
        ground_level
    end

    methods
        function obj = Element(symbol)
            if nargin == 0
                symbol = "H";
            elseif isa(symbol, "kssolv.analysis.matgenlab.core.Element")
                obj = symbol;
                return
            end
            symbol = string(symbol);
            if ~isscalar(symbol) || strlength(symbol) == 0
                error("KSSOLV:Matgenlab:Element:InvalidSymbol", ...
                    "Element symbol must be a nonempty scalar string.");
            end
            obj.source_symbol = symbol;
            obj.record = kssolv.analysis.matgenlab.core.PeriodicTableData. ...
                element(symbol);
            obj.Z = obj.raw("Atomic no");
            obj.A = obj.raw("Atomic mass no", NaN);
            obj.long_name = string(obj.raw("Name"));
            if obj.raw("Is named isotope", false)
                syms = kssolv.analysis.matgenlab.core.PeriodicTableData.symbols(false);
                obj.symbol = "";
                for idx = 1:numel(syms)
                    rec = kssolv.analysis.matgenlab.core.PeriodicTableData. ...
                        element(syms(idx));
                    if kssolv.analysis.matgenlab.core.PeriodicTableData. ...
                            rawField(rec, "Atomic no", NaN) == obj.Z
                        obj.symbol = syms(idx);
                        break
                    end
                end
            else
                obj.symbol = symbol;
            end
        end

        function out = get.name(obj), out = obj.source_symbol; end
        function out = get.number(obj), out = obj.Z; end
        function out = get.X(obj)
            out = obj.raw("X", NaN);
            if isempty(out), out = NaN; end
        end
        function out = get.atomic_radius(obj), out = obj.raw("Atomic radius", NaN); end
        function out = get.atomic_mass(obj), out = obj.raw("Atomic mass"); end
        function out = get.atomic_mass_number(obj), out = obj.A; end
        function out = get.atomic_orbitals(obj)
            rawValue = obj.raw("Atomic orbitals", struct());
            out = containers.Map("KeyType", "char", "ValueType", "double");
            names = fieldnames(rawValue);
            for idx = 1:numel(names)
                orbitalName = names{idx};
                if ~isempty(regexp(orbitalName, '^x\d', 'once'))
                    orbitalName = orbitalName(2:end);
                end
                out(orbitalName) = double(rawValue.(names{idx}));
            end
        end
        function out = get.atomic_orbitals_eV(obj)
            out = obj.atomic_orbitals;
            names = out.keys;
            for idx = 1:numel(names)
                out(names{idx}) = out(names{idx}) * 27.211386245988;
            end
        end
        function out = get.data(obj), out = obj.record; end
        function out = get.ionization_energies(obj), out = obj.raw("Ionization energies", []); end
        function out = get.ionization_energy(obj)
            values = obj.ionization_energies;
            if isempty(values), out = NaN; else, out = values(1); end
        end
        function out = get.electron_affinity(obj), out = obj.raw("Electron affinity", NaN); end
        function out = get.electronic_structure(obj)
            configs = obj.raw("Electronic structure", struct());
            out = string(kssolv.analysis.matgenlab.core.PeriodicTableData. ...
                numericField(configs, 0, ""));
        end
        function out = get.ionic_radii(obj)
            rawRadii = obj.raw("Ionic radii", struct());
            names = fieldnames(rawRadii);
            out = containers.Map("KeyType", "double", "ValueType", "double");
            for idx = 1:numel(names)
                key = kssolv.analysis.matgenlab.core.Element.decodeNumericField(names{idx});
                out(key) = rawRadii.(names{idx});
            end
        end
        function out = get.average_ionic_radius(obj)
            radii = obj.ionic_radii;
            if radii.Count == 0, out = 0; else, out = mean(cell2mat(values(radii))); end
        end
        function out = get.average_cationic_radius(obj)
            radii = obj.ionic_radii;
            keys_ = cell2mat(keys(radii));
            vals = cell2mat(values(radii));
            vals = vals(keys_ > 0);
            if isempty(vals), out = 0; else, out = mean(vals); end
        end
        function out = get.average_anionic_radius(obj)
            radii = obj.ionic_radii;
            keys_ = cell2mat(keys(radii));
            vals = cell2mat(values(radii));
            vals = vals(keys_ < 0);
            if isempty(vals), out = 0; else, out = mean(vals); end
        end
        function out = get.oxidation_states(obj), out = reshape(double(obj.raw("Oxidation states", [])), 1, []); end
        function out = get.common_oxidation_states(obj), out = reshape(double(obj.raw("Common oxidation states", [])), 1, []); end
        function out = get.icsd_oxidation_states(obj), out = reshape(double(obj.raw("ICSD oxidation states", [])), 1, []); end
        function out = get.max_oxidation_state(obj)
            vals = obj.oxidation_states;
            if isempty(vals), out = 0; else, out = max(vals); end
        end
        function out = get.min_oxidation_state(obj)
            vals = obj.oxidation_states;
            if isempty(vals), out = 0; else, out = min(vals); end
        end
        function out = get.full_electronic_structure(obj)
            out = kssolv.analysis.matgenlab.core.Element. ...
                parseElectronicStructure(obj.electronic_structure);
        end
        function out = get.n_electrons(obj)
            config = obj.full_electronic_structure;
            out = sum(cell2mat(config(:, 3)));
        end
        function out = get.valence(obj)
            if obj.group == 18
                out = [NaN, 0];
                return
            end
            config = obj.full_electronic_structure;
            angular = "spdfghiklmnoqrtuvwxyz";
            candidates = zeros(0, 2);
            for idx = 1:size(config, 1)
                l = strfind(angular, string(config{idx, 2})) - 1;
                ne = config{idx, 3};
                isLast = idx == size(config, 1);
                if ne < 2 * (2 * l + 1) || (isLast && isempty(candidates))
                    candidates(end + 1, :) = [l, ne]; %#ok<AGROW>
                end
            end
            if size(candidates, 1) ~= 1
                error("KSSOLV:Matgenlab:Element:AmbiguousValence", ...
                    "%s has ambiguous valence", obj.symbol);
            end
            out = candidates(1, :);
        end
        function out = get.term_symbols(obj)
            if obj.is_noble_gas
                out = {"1S0"};
                return
            end
            val = obj.valence;
            L = val(1); ne = val(2);
            ml = -L:L;
            mlValues = repelem(ml, 2);
            ms2Values = repmat([1, -1], 1, numel(ml));
            combos = nchoosek(1:numel(mlValues), ne);
            counts = containers.Map("KeyType", "char", "ValueType", "double");
            for idx = 1:size(combos, 1)
                key = sprintf("%d,%d", sum(mlValues(combos(idx, :))), ...
                    sum(ms2Values(combos(idx, :))));
                if isKey(counts, key), counts(key) = counts(key) + 1;
                else, counts(key) = 1;
                end
            end
            labels = "SPDFGHIKLMNOQRTUVWXYZ";
            out = {};
            while counts.Count > 0
                names = keys(counts);
                pairs = zeros(numel(names), 2);
                for idx = 1:numel(names)
                    pairs(idx, :) = sscanf(names{idx}, "%d,%d").';
                end
                [~, order] = sortrows(pairs, [1, 2]);
                ML0 = pairs(order(1), 1);
                MS20 = pairs(order(1), 2);
                termL = abs(ML0);
                termS = abs(MS20) / 2;
                jValues = abs(termL - termS):(termL + termS);
                terms = strings(1, numel(jValues));
                for idx = 1:numel(jValues)
                    terms(idx) = string(2 * termS + 1) + ...
                        extractBetween(labels, termL + 1, termL + 1) + ...
                        compose("%.1f", jValues(idx));
                end
                out{end + 1} = terms; %#ok<AGROW>
                for mlValue = -termL:termL
                    for ms2Value = (2 * termS):-2:(-2 * termS)
                        key = sprintf("%d,%d", mlValue, ms2Value);
                        if isKey(counts, key)
                            counts(key) = counts(key) - 1;
                            if counts(key) == 0, remove(counts, key); end
                        end
                    end
                end
            end
        end
        function out = get.row(obj)
            if obj.Z >= 57 && obj.Z <= 71, out = 6; return; end
            if obj.Z >= 89 && obj.Z <= 103, out = 7; return; end
            cumulative = cumsum([2, 8, 8, 18, 18, 32, 32]);
            idx = find(cumulative >= obj.Z, 1);
            if isempty(idx), out = 8; else, out = idx; end
        end
        function out = get.group(obj)
            z = obj.Z;
            if z == 1, out = 1; return; end
            if z == 2, out = 18; return; end
            if z <= 18
                rem8 = mod(z - 2, 8);
                if rem8 == 0, out = 18;
                elseif rem8 <= 2, out = rem8;
                else, out = 10 + rem8;
                end
                return
            end
            if z <= 54
                rem18 = mod(z - 18, 18);
                if rem18 == 0, out = 18; else, out = rem18; end
                return
            end
            if (z >= 57 && z <= 71) || (z >= 89 && z <= 103)
                out = 3; return
            end
            rem32 = mod(z - 54, 32);
            if rem32 == 0, out = 18;
            elseif rem32 >= 18, out = rem32 - 14;
            else, out = rem32;
            end
        end
        function out = get.block(obj)
            if (obj.is_actinoid || obj.is_lanthanoid) && ~ismember(obj.Z, [71, 103])
                out = "f";
            elseif obj.is_actinoid || obj.is_lanthanoid || ismember(obj.group, 3:12)
                out = "d";
            elseif ismember(obj.group, [1, 2])
                out = "s";
            else
                out = "p";
            end
        end
        function out = get.is_noble_gas(obj), out = ismember(obj.Z, [2,10,18,36,54,86,118]); end
        function out = get.is_transition_metal(obj)
            out = ismember(obj.Z, [21:30,39:48,57,72:80,89,104:112]);
        end
        function out = get.is_post_transition_metal(obj), out = ismember(obj.symbol, ["Al","Ga","In","Tl","Sn","Pb","Bi"]); end
        function out = get.is_rare_earth(obj), out = obj.is_lanthanoid || obj.is_actinoid || ismember(obj.symbol, ["Sc","Y"]); end
        function out = get.is_metal(obj)
            out = obj.is_alkali || obj.is_alkaline || obj.is_post_transition_metal || ...
                obj.is_transition_metal || obj.is_lanthanoid || obj.is_actinoid;
        end
        function out = get.is_metalloid(obj), out = ismember(obj.symbol, ["B","Si","Ge","As","Sb","Te","Po"]); end
        function out = get.is_alkali(obj), out = ismember(obj.Z, [3,11,19,37,55,87]); end
        function out = get.is_alkaline(obj), out = ismember(obj.Z, [4,12,20,38,56,88]); end
        function out = get.is_halogen(obj), out = ismember(obj.Z, [9,17,35,53,85]); end
        function out = get.is_chalcogen(obj), out = ismember(obj.Z, [8,16,34,52,84]); end
        function out = get.is_lanthanoid(obj), out = obj.Z > 56 && obj.Z < 72; end
        function out = get.is_actinoid(obj), out = obj.Z > 88 && obj.Z < 104; end
        function out = get.is_radioactive(obj), out = ismember(obj.Z, [43,61]) || obj.Z >= 84; end
        function out = get.nmr_quadrupole_moment(obj), out = obj.raw("NMR Quadrupole Moment", struct()); end
        function out = get.is_quadrupolar(obj), out = ~isempty(fieldnames(obj.nmr_quadrupole_moment)); end
        function out = get.iupac_ordering(obj), out = obj.raw("IUPAC ordering", NaN); end
        function out = get.ground_state_term_symbol(obj)
            if obj.is_noble_gas, out = "1S0"; return; end
            groups = obj.term_symbols;
            flat = [groups{:}];
            labels = "SPDFGHIKLMNOQRTUVWXYZ";
            multiplicity = zeros(size(flat));
            lValues = zeros(size(flat));
            jValues = zeros(size(flat));
            for idx = 1:numel(flat)
                token = regexp(char(flat(idx)), '^(\d+)([A-Z])([0-9.]+)$', ...
                    'tokens', 'once');
                multiplicity(idx) = str2double(token{1});
                lValues(idx) = strfind(labels, string(token{2})) - 1;
                jValues(idx) = str2double(token{3});
            end
            keep = multiplicity == max(multiplicity);
            keep = keep & lValues == max(lValues(keep));
            candidates = find(keep);
            val = obj.valence;
            if val(2) <= 2 * val(1) + 1
                [~, loc] = min(jValues(candidates));
            else
                [~, loc] = max(jValues(candidates));
            end
            out = flat(candidates(loc));
        end
        function out = get.metallic_radius(obj), out = obj.raw("Metallic radius", NaN); end
        function out = get.atomic_radius_calculated(obj), out = obj.raw("Atomic radius calculated", NaN); end
        function out = get.van_der_waals_radius(obj), out = obj.raw("Van der waals radius", NaN); end
        function out = get.mendeleev_no(obj), out = obj.raw("Mendeleev no", NaN); end
        function out = get.electrical_resistivity(obj), out = obj.raw("Electrical resistivity", NaN); end
        function out = get.velocity_of_sound(obj), out = obj.raw("Velocity of sound", NaN); end
        function out = get.reflectivity(obj), out = obj.raw("Reflectivity", NaN); end
        function out = get.refractive_index(obj), out = obj.raw("Refractive index", NaN); end
        function out = get.poissons_ratio(obj), out = obj.raw("Poissons ratio", NaN); end
        function out = get.molar_volume(obj), out = obj.raw("Molar volume", NaN); end
        function out = get.thermal_conductivity(obj), out = obj.raw("Thermal conductivity", NaN); end
        function out = get.boiling_point(obj), out = obj.raw("Boiling point", NaN); end
        function out = get.melting_point(obj), out = obj.raw("Melting point", NaN); end
        function out = get.critical_temperature(obj), out = obj.raw("Critical temperature", NaN); end
        function out = get.superconduction_temperature(obj), out = obj.raw("Superconduction temperature", NaN); end
        function out = get.liquid_range(obj), out = obj.raw("Liquid range", NaN); end
        function out = get.bulk_modulus(obj), out = obj.raw("Bulk modulus", NaN); end
        function out = get.youngs_modulus(obj), out = obj.raw("Youngs modulus", NaN); end
        function out = get.brinell_hardness(obj), out = obj.raw("Brinell hardness", NaN); end
        function out = get.rigidity_modulus(obj), out = obj.raw("Rigidity modulus", NaN); end
        function out = get.mineral_hardness(obj), out = obj.raw("Mineral hardness", NaN); end
        function out = get.vickers_hardness(obj), out = obj.raw("Vickers hardness", NaN); end
        function out = get.density_of_solid(obj), out = obj.raw("Density of solid", NaN); end
        function out = get.coefficient_of_linear_thermal_expansion(obj)
            out = obj.raw("Coefficient of linear thermal expansion", NaN);
        end
        function out = get.ground_level(obj), out = string(obj.raw("Ground level", "")); end

        function value = getData(obj, key, default)
            if nargin < 3, default = []; end
            value = obj.raw(key, default);
        end

        function tf = eq(a, b)
            if ~isa(a, "kssolv.analysis.matgenlab.core.Element") || ...
                    ~isa(b, "kssolv.analysis.matgenlab.core.Element")
                tf = false;
                return
            end
            tf = reshape([a.Z], size(a)) == reshape([b.Z], size(b)) & ...
                kssolv.analysis.matgenlab.core.Element.nanEqual( ...
                reshape([a.A], size(a)), reshape([b.A], size(b)));
        end

        function tf = ne(a, b), tf = ~eq(a, b); end
        function tf = lt(a, b)
            ax = a.X; bx = b.X;
            if isnan(ax), ax = Inf; end
            if isnan(bx), bx = Inf; end
            tf = ax < bx || (ax == bx && a.symbol < b.symbol);
        end
        function out = char(obj), out = char(obj.symbol); end
        function out = string(obj), out = obj.symbol; end
        function out = toPrettyString(obj), out = obj.symbol; end

        function result = asDict(obj)
            result = struct();
            result.("x_module") = "pymatgen.core.periodic_table";
            result.("x_class") = "Element";
            result.element = obj.source_symbol;
        end
        function result = as_dict(obj), result = obj.asDict(); end
    end

    methods (Static)
        function obj = fromZ(z, massNumber)
            arguments
                z (1,1) double {mustBeInteger, mustBePositive}
                massNumber (1,1) double = NaN
            end
            syms = kssolv.analysis.matgenlab.core.PeriodicTableData.symbols(true);
            for idx = 1:numel(syms)
                candidate = kssolv.analysis.matgenlab.core.Element(syms(idx));
                if candidate.Z == z && ...
                        (isnan(massNumber) || candidate.A == massNumber)
                    obj = candidate;
                    return
                end
            end
            error("KSSOLV:Matgenlab:Element:InvalidAtomicNumber", ...
                "Unexpected atomic number Z=%g", z);
        end
        function obj = from_Z(z, massNumber)
            if nargin < 2, obj = kssolv.analysis.matgenlab.core.Element.fromZ(z);
            else, obj = kssolv.analysis.matgenlab.core.Element.fromZ(z, massNumber);
            end
        end
        function obj = fromName(name)
            name = lower(string(name));
            if name == "aluminium", name = "aluminum"; end
            if name == "caesium", name = "cesium"; end
            syms = kssolv.analysis.matgenlab.core.PeriodicTableData.symbols(false);
            for idx = 1:numel(syms)
                candidate = kssolv.analysis.matgenlab.core.Element(syms(idx));
                if lower(candidate.long_name) == name
                    obj = candidate;
                    return
                end
            end
            error("KSSOLV:Matgenlab:Element:InvalidName", "No element with name='%s'", name);
        end
        function obj = from_name(name), obj = kssolv.analysis.matgenlab.core.Element.fromName(name); end
        function obj = fromRowAndGroup(row, group)
            syms = kssolv.analysis.matgenlab.core.PeriodicTableData.symbols(false);
            for idx = 1:numel(syms)
                candidate = kssolv.analysis.matgenlab.core.Element(syms(idx));
                if candidate.Z >= 57 && candidate.Z <= 71
                    r = 8; g = mod(candidate.Z - 54, 32);
                elseif candidate.Z >= 89 && candidate.Z <= 103
                    r = 9; g = mod(candidate.Z - 54, 32);
                else
                    r = candidate.row; g = candidate.group;
                end
                if r == row && g == group, obj = candidate; return; end
            end
            error("KSSOLV:Matgenlab:Element:InvalidRowGroup", ...
                "No element with row=%g and group=%g.", row, group);
        end
        function obj = from_row_and_group(row, group)
            obj = kssolv.analysis.matgenlab.core.Element.fromRowAndGroup(row, group);
        end
        function tf = isValidSymbol(symbol)
            tf = kssolv.analysis.matgenlab.core.PeriodicTableData.isValidSymbol(symbol);
        end
        function tf = is_valid_symbol(symbol)
            tf = kssolv.analysis.matgenlab.core.Element.isValidSymbol(symbol);
        end
        function obj = fromDict(dct)
            obj = kssolv.analysis.matgenlab.core.Element(dct.element);
        end
        function obj = from_dict(dct), obj = kssolv.analysis.matgenlab.core.Element.fromDict(dct); end
        function values = all()
            syms = kssolv.analysis.matgenlab.core.PeriodicTableData.symbols(false);
            values = cellfun(@(s) kssolv.analysis.matgenlab.core.Element(s), ...
                cellstr(syms), "UniformOutput", false);
        end
        function text = print_periodic_table(filterFunction)
            %PRINT_PERIODIC_TABLE Render the same nine-by-eighteen table as pymatgen.
            if nargin < 1, filterFunction = []; end
            rows = strings(9, 1);
            for row = 1:9
                cells = repmat("   ", 1, 18);
                for group = 1:18
                    try
                        element = kssolv.analysis.matgenlab.core.Element. ...
                            fromRowAndGroup(row, group);
                    catch
                        continue
                    end
                    if isempty(filterFunction) || filterFunction(element)
                        cells(group) = pad(element.symbol, 3, "right");
                    end
                end
                rows(row) = strjoin(cells, " ");
            end
            text = strjoin(rows, newline) + newline;
            if nargout == 0
                fprintf("%s", text);
            end
        end
        function config = parse_electronic_structure(text)
            config = kssolv.analysis.matgenlab.core.Element. ...
                parseElectronicStructure(text);
        end
    end

    methods (Access = private)
        function value = raw(obj, key, default)
            if nargin < 3, default = []; end
            value = kssolv.analysis.matgenlab.core.PeriodicTableData. ...
                rawField(obj.record, key, default);
        end
    end

    methods (Static, Access = private)
        function config = parseElectronicStructure(text)
            text = char(text);
            pieces = split(string(text), ".");
            config = cell(0, 3);
            first = regexp(char(pieces(1)), '^\[([A-Z][a-z]?)\]$', 'tokens', 'once');
            start = 1;
            if ~isempty(first)
                core = kssolv.analysis.matgenlab.core.Element(first{1});
                config = core.full_electronic_structure;
                start = 2;
            end
            for idx = start:numel(pieces)
                token = regexp(char(pieces(idx)), '^(\d+)([spdfg])(\d+)$', 'tokens', 'once');
                if isempty(token), continue; end
                config(end + 1, :) = {str2double(token{1}), string(token{2}), str2double(token{3})}; %#ok<AGROW>
            end
            madelung = ["1s","2s","2p","3s","3p","4s","3d","4p","5s", ...
                "4d","5p","6s","4f","5d","6p","7s","5f","6d","7p"];
            ranks = zeros(size(config, 1), 1);
            for idx = 1:size(config, 1)
                label = string(config{idx, 1}) + string(config{idx, 2});
                ranks(idx) = find(madelung == label, 1);
            end
            [~, order] = sort(ranks);
            config = config(order, :);
        end

        function number = decodeNumericField(field)
            % makeValidName("-2") commonly yields x_2 and ("0") x0.
            raw = regexprep(field, '^x', '');
            if startsWith(raw, "_"), raw = "-" + extractAfter(string(raw), 1); end
            number = str2double(raw);
            if isnan(number)
                error("KSSOLV:Matgenlab:PeriodicTableData:NumericKey", ...
                    "Cannot decode numeric JSON field '%s'.", field);
            end
        end

        function tf = nanEqual(a, b)
            tf = (a == b) | (isnan(a) & isnan(b));
        end
    end
end
