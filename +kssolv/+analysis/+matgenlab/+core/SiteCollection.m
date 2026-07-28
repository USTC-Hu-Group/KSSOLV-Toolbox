classdef (Abstract) SiteCollection
    %SITECOLLECTION Shared behavior for structures and molecules.

    properties (Access = protected)
        sites_ cell = cell(1, 0)
        explicit_charge_ (1,1) double = NaN
    end

    properties (Dependent, SetAccess = protected)
        sites
    end

    properties (Dependent, SetAccess = private)
        num_sites
        cart_coords
        species
        species_and_occu
        n_elems
        ntypesp
        types_of_species
        types_of_specie
        symbol_set
        atomic_numbers
        site_properties
        labels
        formula
        alphabetical_formula
        reduced_formula
        elements
        composition
        chemical_system
        chemical_system_set
        charge
        is_ordered
        distance_matrix
    end

    methods
        function obj = SiteCollection(sites)
            if nargin > 0
                if ~iscell(sites)
                    error("KSSOLV:Matgenlab:SiteCollection:SitesMustBeCell", ...
                        "Sites must be supplied as a cell array.");
                end
                obj.sites_ = reshape(sites, 1, []);
            end
        end

        function value = get.sites(obj), value = obj.sites_; end
        function obj = set.sites(obj, value), obj.sites_ = reshape(value, 1, []); end
        function value = get.num_sites(obj), value = numel(obj.sites_); end
        function value = length(obj), value = obj.num_sites; end
        function value = get.cart_coords(obj)
            value = zeros(obj.num_sites, 3);
            for index = 1:obj.num_sites
                value(index, :) = obj.sites_{index}.coords;
            end
        end
        function value = get.species(obj)
            value = cell(1, obj.num_sites);
            for index = 1:obj.num_sites
                value{index} = obj.sites_{index}.specie;
            end
        end
        function value = get.species_and_occu(obj)
            value = cellfun(@(site) site.species, obj.sites_, ...
                "UniformOutput", false);
        end
        function value = get.n_elems(obj), value = length(obj.composition); end
        function value = get.ntypesp(obj), value = numel(obj.types_of_species); end
        function value = get.types_of_species(obj)
            value = {};
            identifiers = strings(1, 0);
            for siteIndex = 1:obj.num_sites
                [speciesValues, ~] = ...
                    obj.sites_{siteIndex}.species.items();
                for speciesIndex = 1:numel(speciesValues)
                    identifier = string(speciesValues{speciesIndex});
                    if ~any(identifiers == identifier)
                        identifiers(end + 1) = identifier; %#ok<AGROW>
                        value{end + 1} = ...
                            speciesValues{speciesIndex}; %#ok<AGROW>
                    end
                end
            end
            value = reshape(value, 1, []);
        end
        function value = get.types_of_specie(obj), value = obj.types_of_species; end
        function value = get.symbol_set(obj)
            value = strings(1, 0);
            for index = 1:obj.num_sites
                [speciesValues, ~] = obj.sites_{index}.species.items();
                for speciesIndex = 1:numel(speciesValues)
                    value(end + 1) = ...
                        speciesValues{speciesIndex}.symbol; %#ok<AGROW>
                end
            end
            value = sort(unique(value));
        end
        function value = get.atomic_numbers(obj)
            value = zeros(1, obj.num_sites);
            for index = 1:obj.num_sites
                value(index) = obj.sites_{index}.specie.Z;
            end
        end
        function value = get.site_properties(obj)
            names = strings(1, 0);
            for index = 1:obj.num_sites
                names = [names; string(fieldnames( ...
                    obj.sites_{index}.site_properties))]; %#ok<AGROW>
            end
            names = unique(names);
            value = struct();
            for nameIndex = 1:numel(names)
                name = char(names(nameIndex));
                entries = cell(1, obj.num_sites);
                for siteIndex = 1:obj.num_sites
                    if isfield(obj.sites_{siteIndex}.site_properties, name)
                        entries{siteIndex} = ...
                            obj.sites_{siteIndex}.site_properties.(name);
                    else
                        entries{siteIndex} = [];
                    end
                end
                value.(name) = entries;
            end
        end
        function value = get.labels(obj)
            value = cellfun(@(site) site.label, obj.sites_, ...
                "UniformOutput", false);
        end
        function value = get.formula(obj), value = obj.composition.formula; end
        function value = get.alphabetical_formula(obj)
            value = obj.composition.alphabetical_formula;
        end
        function value = get.reduced_formula(obj)
            value = obj.composition.reduced_formula;
        end
        function value = get.elements(obj), value = obj.composition.elements; end
        function value = get.composition(obj)
            pairs = cell(0, 2);
            for siteIndex = 1:obj.num_sites
                [speciesValues, amounts] = ...
                    obj.sites_{siteIndex}.species.items();
                for speciesIndex = 1:numel(speciesValues)
                    pairs(end + 1, :) = ...
                        {speciesValues{speciesIndex}, ...
                        amounts(speciesIndex)}; %#ok<AGROW>
                end
            end
            value = kssolv.analysis.matgenlab.core.Composition(pairs);
        end
        function value = get.chemical_system(obj)
            value = obj.composition.chemical_system;
        end
        function value = get.chemical_system_set(obj)
            value = obj.composition.chemical_system_set;
        end
        function value = get.charge(obj)
            if isnan(obj.explicit_charge_)
                value = obj.composition.charge;
            else
                value = obj.explicit_charge_;
            end
        end
        function value = get.is_ordered(obj)
            value = all(cellfun(@(site) site.is_ordered, obj.sites_));
        end
        function value = get.distance_matrix(obj)
            value = zeros(obj.num_sites);
            for first = 1:obj.num_sites
                for second = first + 1:obj.num_sites
                    distance = obj.sites_{first}.distance(obj.sites_{second});
                    value(first, second) = distance;
                    value(second, first) = distance;
                end
            end
        end

        function site = get_site(obj, index)
            obj.validateSiteIndex(index);
            site = obj.sites_{index};
        end

        function distance = get_distance(obj, first, second)
            obj.validateSiteIndex(first);
            obj.validateSiteIndex(second);
            distance = obj.sites_{first}.distance(obj.sites_{second});
        end

        function indices = indices_from_symbol(obj, symbol)
            symbol = string(symbol);
            indices = zeros(1, 0);
            for index = 1:obj.num_sites
                [speciesValues, ~] = obj.sites_{index}.species.items();
                if any(cellfun(@(item) item.symbol == symbol, ...
                        speciesValues))
                    indices(end + 1) = index; %#ok<AGROW>
                end
            end
        end

        function value = group_by_types(obj)
            types = obj.types_of_species;
            value = cell(1, 0);
            for typeIndex = 1:numel(types)
                for siteIndex = 1:obj.num_sites
                    if obj.sites_{siteIndex}.species.contains(types{typeIndex})
                        value{end + 1} = obj.sites_{siteIndex}; %#ok<AGROW>
                    end
                end
            end
        end

        function angle = get_angle(obj, first, center, third)
            obj.validateSiteIndex(first);
            obj.validateSiteIndex(center);
            obj.validateSiteIndex(third);
            vector1 = obj.sites_{first}.coords - obj.sites_{center}.coords;
            vector2 = obj.sites_{third}.coords - obj.sites_{center}.coords;
            denominator = norm(vector1) * norm(vector2);
            if denominator == 0
                error("KSSOLV:Matgenlab:SiteCollection:CoincidentSites", ...
                    "Cannot calculate an angle using coincident sites.");
            end
            angle = acosd(max(-1, min(1, dot(vector1, vector2) / denominator)));
        end

        function angle = get_dihedral(obj, first, second, third, fourth)
            indices = [first, second, third, fourth];
            arrayfun(@(index) obj.validateSiteIndex(index), indices);
            p = obj.cart_coords(indices, :);
            b0 = -(p(2, :) - p(1, :));
            b1 = p(3, :) - p(2, :);
            b2 = p(4, :) - p(3, :);
            b1 = b1 / norm(b1);
            v = b0 - dot(b0, b1) * b1;
            w = b2 - dot(b2, b1) * b1;
            angle = atan2d(dot(cross(b1, v), w), dot(v, w));
        end

        function valid = is_valid(obj, tolerance)
            if nargin < 2, tolerance = 0.5; end
            distances = obj.distance_matrix;
            distances(1:obj.num_sites + 1:end) = Inf;
            valid = all(distances >= tolerance, "all");
        end

        function value = to(obj, filename, fmt)
            if nargin < 2, filename = ""; end
            if nargin < 3, fmt = ""; end
            if isa(obj, "kssolv.analysis.matgenlab.core.IStructure")
                structurePropertiesName = "structure_properties";
                concrete = kssolv.analysis.matgenlab.core.Structure. ...
                    from_sites(obj.sites, ...
                    properties = obj.(structurePropertiesName));
                if ~isnan(obj.charge)
                    concrete = concrete.set_charge(obj.charge);
                end
            elseif isa(obj, "kssolv.analysis.matgenlab.core.IMolecule")
                spinMultiplicityName = "spin_multiplicity";
                moleculePropertiesName = "molecule_properties";
                concrete = kssolv.analysis.matgenlab.core.Molecule. ...
                    from_sites(obj.sites, charge = obj.charge, ...
                    spin_multiplicity = obj.(spinMultiplicityName), ...
                    properties = obj.(moleculePropertiesName));
            else
                error("KSSOLV:Matgenlab:SiteCollection:ConcreteType", ...
                    "Unsupported SiteCollection subclass '%s'.", class(obj));
            end
            value = concrete.to(filename, fmt);
        end

        function value = to_file(obj, filename, fmt)
            if nargin < 3, fmt = ""; end
            value = obj.to(filename, fmt);
        end

        function atoms = to_ase_atoms(obj)
            %TO_ASE_ATOMS Language-neutral representation of ASE Atoms data.
            atoms = struct();
            atoms.symbols = cellfun(@(site) char(site.specie.symbol), ...
                obj.sites_, "UniformOutput", false);
            atoms.positions = obj.cart_coords;
            atoms.arrays = obj.site_properties;
            atoms.info = struct("charge", obj.charge);
            atoms.labels = obj.labels;
            if isa(obj, "kssolv.analysis.matgenlab.core.IStructure")
                latticeName = "lattice";
                pbcName = "pbc";
                latticeValue = obj.(latticeName);
                atoms.cell = latticeValue.matrix;
                atoms.pbc = obj.(pbcName);
            else
                atoms.cell = zeros(3);
                atoms.pbc = false(1, 3);
                spinMultiplicityName = "spin_multiplicity";
                atoms.info.spin_multiplicity = ...
                    obj.(spinMultiplicityName);
            end
        end

        function result = calculate(obj, calculator, varargin)
            %CALCULATE Invoke an explicitly supplied MATLAB calculator adapter.
            if nargin < 2 || isempty(calculator)
                error("KSSOLV:Matgenlab:External:CalculatorRequired", ...
                    "A MATLAB function handle or calculator object is " + ...
                    "required; Python ASE calculators are not loaded at runtime.");
            end
            if isa(calculator, "function_handle")
                result = calculator(obj, varargin{:});
            elseif isstruct(calculator) && isfield(calculator, "calculate") && ...
                    isa(calculator.calculate, "function_handle")
                result = calculator.calculate(obj, varargin{:});
            elseif isobject(calculator) && ismethod(calculator, "calculate")
                result = calculator.calculate(obj, varargin{:});
            else
                error("KSSOLV:Matgenlab:External:CalculatorType", ...
                    "calculator must be an explicit MATLAB calculator adapter.");
            end
        end

        function obj = add_site_property(obj, property_name, values)
            property_name = char(string(property_name));
            if numel(values) ~= obj.num_sites
                error("KSSOLV:Matgenlab:SiteCollection:PropertyLength", ...
                    "Site property '%s' requires %d values.", ...
                    property_name, obj.num_sites);
            end
            if ~iscell(values)
                if isvector(values)
                    values = num2cell(reshape(values, 1, []));
                else
                    values = num2cell(values, 2).';
                end
            end
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                site.site_properties.(property_name) = values{index};
                obj.sites_{index} = site;
            end
        end

        function obj = remove_site_property(obj, property_name)
            property_name = char(string(property_name));
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                if isfield(site.site_properties, property_name)
                    site.site_properties = rmfield( ...
                        site.site_properties, property_name);
                    obj.sites_{index} = site;
                end
            end
        end

        function obj = replace_species(obj, species_mapping, in_place)
            if nargin < 3, in_place = true; end
            if ~isscalar(in_place) || ~(islogical(in_place) || isnumeric(in_place))
                error("KSSOLV:Matgenlab:SiteCollection:InPlace", ...
                    "in_place must be a scalar logical value.");
            end
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                site.species = site.species.replace(species_mapping);
                obj.sites_{index} = site;
            end
        end

        function obj = add_oxidation_state_by_element(obj, oxidation_states)
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                [speciesValues, amounts] = site.species.items();
                pairs = cell(numel(speciesValues), 2);
                for speciesIndex = 1:numel(speciesValues)
                    symbol = char(speciesValues{speciesIndex}.symbol);
                    state = mapValue(oxidation_states, symbol);
                    pairs(speciesIndex, :) = { ...
                        kssolv.analysis.matgenlab.core.Species( ...
                            symbol, state), amounts(speciesIndex)};
                end
                site.species = ...
                    kssolv.analysis.matgenlab.core.Composition(pairs);
                obj.sites_{index} = site;
            end
        end

        function obj = add_oxidation_state_by_site(obj, oxidation_states)
            if numel(oxidation_states) ~= obj.num_sites
                error("KSSOLV:Matgenlab:SiteCollection:OxidationLength", ...
                    "One oxidation state is required for every site.");
            end
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                [speciesValues, amounts] = site.species.items();
                pairs = cell(numel(speciesValues), 2);
                for speciesIndex = 1:numel(speciesValues)
                    pairs(speciesIndex, :) = { ...
                        kssolv.analysis.matgenlab.core.Species( ...
                            speciesValues{speciesIndex}.symbol, ...
                            oxidation_states(index)), ...
                        amounts(speciesIndex)};
                end
                site.species = ...
                    kssolv.analysis.matgenlab.core.Composition(pairs);
                obj.sites_{index} = site;
            end
        end

        function obj = remove_oxidation_states(obj)
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                [speciesValues, amounts] = site.species.items();
                pairs = cell(numel(speciesValues), 2);
                for speciesIndex = 1:numel(speciesValues)
                    pairs(speciesIndex, :) = { ...
                        kssolv.analysis.matgenlab.core.Element( ...
                            speciesValues{speciesIndex}.symbol), ...
                        amounts(speciesIndex)};
                end
                site.species = ...
                    kssolv.analysis.matgenlab.core.Composition(pairs);
                obj.sites_{index} = site;
            end
        end

        function obj = add_oxidation_state_by_guess(obj, varargin)
            guesses = obj.composition.oxi_state_guesses(varargin{:});
            if isempty(guesses)
                states = struct();
                for symbol = obj.symbol_set
                    states.(char(symbol)) = 0;
                end
            else
                states = guesses{1};
            end
            obj = obj.add_oxidation_state_by_element(states);
        end

        function obj = add_spin_by_element(obj, spins)
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                [speciesValues, amounts] = site.species.items();
                pairs = cell(numel(speciesValues), 2);
                for speciesIndex = 1:numel(speciesValues)
                    current = speciesValues{speciesIndex};
                    spin = mapValue(spins, char(current.symbol));
                    oxidation = NaN;
                    if isa(current, ...
                            "kssolv.analysis.matgenlab.core.Species")
                        oxidation = current.oxi_state;
                    end
                    pairs(speciesIndex, :) = { ...
                        kssolv.analysis.matgenlab.core.Species( ...
                            current.symbol, oxidation, "spin", spin), ...
                        amounts(speciesIndex)};
                end
                site.species = ...
                    kssolv.analysis.matgenlab.core.Composition(pairs);
                obj.sites_{index} = site;
            end
        end

        function obj = add_spin_by_site(obj, spins)
            if numel(spins) ~= obj.num_sites
                error("KSSOLV:Matgenlab:SiteCollection:SpinLength", ...
                    "One spin value is required for every site.");
            end
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                [speciesValues, amounts] = site.species.items();
                pairs = cell(numel(speciesValues), 2);
                for speciesIndex = 1:numel(speciesValues)
                    current = speciesValues{speciesIndex};
                    oxidation = NaN;
                    if isa(current, ...
                            "kssolv.analysis.matgenlab.core.Species")
                        oxidation = current.oxi_state;
                    end
                    pairs(speciesIndex, :) = { ...
                        kssolv.analysis.matgenlab.core.Species( ...
                            current.symbol, oxidation, ...
                            "spin", spins(index)), amounts(speciesIndex)};
                end
                site.species = ...
                    kssolv.analysis.matgenlab.core.Composition(pairs);
                obj.sites_{index} = site;
            end
        end

        function obj = remove_spin(obj)
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                [speciesValues, amounts] = site.species.items();
                pairs = cell(numel(speciesValues), 2);
                for speciesIndex = 1:numel(speciesValues)
                    current = speciesValues{speciesIndex};
                    if isa(current, ...
                            "kssolv.analysis.matgenlab.core.Species")
                        replacement = ...
                            kssolv.analysis.matgenlab.core.Species( ...
                                current.symbol, current.oxi_state);
                    else
                        replacement = current;
                    end
                    pairs(speciesIndex, :) = ...
                        {replacement, amounts(speciesIndex)};
                end
                site.species = ...
                    kssolv.analysis.matgenlab.core.Composition(pairs);
                obj.sites_{index} = site;
            end
        end

        function cluster = extract_cluster(obj, target_sites, varargin)
            if ~iscell(target_sites), target_sites = num2cell(target_sites); end
            cluster = reshape(target_sites, 1, []);
            others = obj.sites_;
            keep = true(size(others));
            for index = 1:numel(others)
                keep(index) = ~any(cellfun(@(site) ...
                    site == others{index}, cluster));
            end
            others = others(keep);
            previousSize = -1;
            while numel(cluster) > previousSize
                previousSize = numel(cluster);
                unmatched = cell(1, 0);
                for index = 1:numel(others)
                    belongs = false;
                    for clusterIndex = 1:numel(cluster)
                        try
                            belongs = ...
                                kssolv.analysis.matgenlab.core.CovalentBond. ...
                                    is_bonded(others{index}, ...
                                    cluster{clusterIndex}, varargin{:});
                        catch exception
                            if strcmp(exception.identifier, ...
                                    "KSSOLV:Matgenlab:Bonds:MissingData")
                                belongs = false;
                            else
                                rethrow(exception)
                            end
                        end
                        if belongs, break; end
                    end
                    if belongs
                        cluster{end + 1} = others{index}; %#ok<AGROW>
                    else
                        unmatched{end + 1} = others{index}; %#ok<AGROW>
                    end
                end
                others = unmatched;
            end
        end

        function obj = relabel_sites(obj, ignore_uniq)
            if nargin < 2, ignore_uniq = false; end
            counts = containers.Map("KeyType", "char", "ValueType", "double");
            used = strings(1, 0);
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                base = char(site.species_string);
                if ~isKey(counts, base), counts(base) = 0; end
                counts(base) = counts(base) + 1;
                label = string(base) + counts(base);
                if ~ignore_uniq
                    while any(used == label)
                        counts(base) = counts(base) + 1;
                        label = string(base) + counts(base);
                    end
                end
                site.label = label;
                obj.sites_{index} = site;
                used(end + 1) = label; %#ok<AGROW>
            end
        end

        function obj = copy(obj)
            % Value classes already have copy-on-write semantics.
        end
    end

    methods (Static)
        function obj = from_str(inputString, fmt)
            if nargin < 2 || strlength(string(fmt)) == 0
                text = strtrim(string(inputString));
                if startsWith(text, "{")
                    decoded = kssolv.analysis.matgenlab.util.decode(text);
                    if isa(decoded, ...
                            "kssolv.analysis.matgenlab.core.SiteCollection")
                        obj = decoded;
                        return
                    end
                elseif startsWith(lower(text), "data_")
                    fmt = "cif";
                else
                    lines = splitlines(text);
                    if ~isempty(lines) && ...
                            isfinite(str2double(strtrim(lines(1))))
                        fmt = "xyz";
                    else
                        fmt = "poscar";
                    end
                end
            end
            format = lower(string(fmt));
            if ismember(format, ["xyz", "mol", "json-molecule"])
                obj = kssolv.analysis.matgenlab.core.Molecule. ...
                    from_str(inputString, format);
            else
                obj = kssolv.analysis.matgenlab.core.Structure. ...
                    from_str(inputString, format);
            end
        end

        function obj = from_file(filename, fmt)
            if nargin < 2 || strlength(string(fmt)) == 0
                [~, base, extension] = fileparts(string(filename));
                if any(strcmpi(base, ["POSCAR", "CONTCAR"]))
                    fmt = "poscar";
                else
                    fmt = erase(lower(extension), ".");
                end
            end
            format = lower(string(fmt));
            if ismember(format, ["xyz", "mol", "json-molecule"])
                obj = kssolv.analysis.matgenlab.core.Molecule. ...
                    from_file(filename, format);
            else
                obj = kssolv.analysis.matgenlab.core.Structure. ...
                    from_file(filename, format);
            end
        end

        function obj = from_ase_atoms(atoms)
            if ~isstruct(atoms) || ~isfield(atoms, "positions")
                error("KSSOLV:Matgenlab:ASE:Representation", ...
                    "ASE input must use the neutral struct returned by to_ase_atoms.");
            end
            if isfield(atoms, "symbols")
                speciesValues = atoms.symbols;
            elseif isfield(atoms, "numbers")
                speciesValues = arrayfun(@(number) ...
                    kssolv.analysis.matgenlab.core.Element.from_Z(number), ...
                    atoms.numbers, "UniformOutput", false);
            else
                error("KSSOLV:Matgenlab:ASE:Species", ...
                    "ASE representation requires symbols or atomic numbers.");
            end
            properties = struct();
            if isfield(atoms, "arrays"), properties = atoms.arrays; end
            labels = [];
            if isfield(atoms, "labels"), labels = atoms.labels; end
            hasCell = isfield(atoms, "cell") && ...
                any(abs(double(atoms.cell)) > 0, "all");
            hasPbc = isfield(atoms, "pbc") && any(logical(atoms.pbc));
            if hasCell || hasPbc
                pbc = true(1, 3);
                if isfield(atoms, "pbc"), pbc = logical(atoms.pbc); end
                lattice = kssolv.analysis.matgenlab.core.Lattice( ...
                    atoms.cell, pbc);
                obj = kssolv.analysis.matgenlab.core.Structure( ...
                    lattice, speciesValues, atoms.positions, ...
                    coords_are_cartesian = true, ...
                    site_properties = properties, labels = labels);
                if isfield(atoms, "info") && ...
                        isfield(atoms.info, "charge") && ...
                        ~isnan(atoms.info.charge)
                    obj = obj.set_charge(atoms.info.charge);
                end
            else
                charge = 0;
                multiplicity = [];
                if isfield(atoms, "info")
                    if isfield(atoms.info, "charge")
                        charge = atoms.info.charge;
                    end
                    if isfield(atoms.info, "spin_multiplicity")
                        multiplicity = atoms.info.spin_multiplicity;
                    end
                end
                obj = kssolv.analysis.matgenlab.core.Molecule( ...
                    speciesValues, atoms.positions, charge = charge, ...
                    spin_multiplicity = multiplicity, ...
                    site_properties = properties, labels = labels);
            end
        end
    end

    methods (Access = protected)
        function validateSiteIndex(obj, index)
            if ~isscalar(index) || index ~= fix(index) || ...
                    index < 1 || index > obj.num_sites
                error("KSSOLV:Matgenlab:SiteCollection:Index", ...
                    "Site index must be an integer from 1 through %d.", ...
                    obj.num_sites);
            end
        end
    end
end

function value = mapValue(mapping, key)
if isstruct(mapping)
    if ~isfield(mapping, key)
        error("KSSOLV:Matgenlab:SiteCollection:MissingElement", ...
            "No value was supplied for element '%s'.", key);
    end
    value = mapping.(key);
elseif isa(mapping, "containers.Map")
    if ~isKey(mapping, key)
        error("KSSOLV:Matgenlab:SiteCollection:MissingElement", ...
            "No value was supplied for element '%s'.", key);
    end
    value = mapping(key);
else
    error("KSSOLV:Matgenlab:SiteCollection:MappingType", ...
        "Element values must be supplied in a struct or containers.Map.");
end
end
