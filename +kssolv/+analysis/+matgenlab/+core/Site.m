classdef Site < kssolv.analysis.matgenlab.util.MSONable
    %SITE A composition at a non-periodic Cartesian point.

    properties (Constant)
        position_atol double = 1e-5
    end

    properties
        % "properties" is a MATLAB keyword and cannot be declared as a
        % class property. subsref/subsasgn below expose the upstream name.
        site_properties (1,1) struct = struct()
    end

    properties (Access = protected)
        species_ (1,1) kssolv.analysis.matgenlab.core.Composition
        coords_ (1,3) double = [0, 0, 0]
        label_ (1,1) string = missing
    end

    properties (Dependent)
        species
        coords
        label
        x
        y
        z
    end

    properties (Dependent, SetAccess = private)
        species_string
        specie
        is_ordered
    end

    methods
        function obj = Site(species, coords, options)
            arguments
                species
                coords
                options.properties (1,1) struct = struct()
                options.label = missing
                options.skip_checks (1,1) logical = false
            end

            obj.species_ = obj.normalizeSpecies(species);
            if ~options.skip_checks && ...
                    obj.species_.num_atoms > 1 + ...
                    kssolv.analysis.matgenlab.core.Composition.amount_tolerance
                error("KSSOLV:Matgenlab:Site:Occupancy", ...
                    "Species occupancies sum to more than 1.");
            end
            obj.coords_ = obj.validateCoordinates(coords, "Cartesian");
            obj.site_properties = options.properties;
            if ~ismissing(string(options.label))
                obj.label_ = string(options.label);
            end
        end

        function value = get.species(obj), value = obj.species_; end
        function obj = set.species(obj, value)
            value = obj.normalizeSpecies(value);
            if value.num_atoms > 1 + ...
                    kssolv.analysis.matgenlab.core.Composition.amount_tolerance
                error("KSSOLV:Matgenlab:Site:Occupancy", ...
                    "Species occupancies sum to more than 1.");
            end
            obj.species_ = value;
        end

        function value = get.coords(obj), value = obj.getCoords(); end
        function obj = set.coords(obj, value), obj = obj.setCoords(value); end

        function value = get.label(obj)
            if ismissing(obj.label_)
                value = obj.species_string;
            else
                value = obj.label_;
            end
        end
        function obj = set.label(obj, value)
            if isempty(value) || ismissing(string(value))
                obj.label_ = missing;
            else
                obj.label_ = string(value);
            end
        end

        function value = get.x(obj), value = obj.coords(1); end
        function value = get.y(obj), value = obj.coords(2); end
        function value = get.z(obj), value = obj.coords(3); end
        function obj = set.x(obj, value)
            coordinates = obj.coords; coordinates(1) = value; obj.coords = coordinates;
        end
        function obj = set.y(obj, value)
            coordinates = obj.coords; coordinates(2) = value; obj.coords = coordinates;
        end
        function obj = set.z(obj, value)
            coordinates = obj.coords; coordinates(3) = value; obj.coords = coordinates;
        end

        function value = get.is_ordered(obj)
            value = obj.species_.is_element && ...
                abs(obj.species_.num_atoms - 1) <= ...
                kssolv.analysis.matgenlab.core.Composition.amount_tolerance;
        end

        function value = get.specie(obj)
            if ~obj.is_ordered
                error("KSSOLV:Matgenlab:Site:DisorderedSpecie", ...
                    "specie property only works for ordered sites.");
            end
            speciesValues = obj.species_.items();
            value = speciesValues{1};
        end

        function value = get.species_string(obj)
            [speciesValues, occupancies] = obj.species_.items();
            if obj.is_ordered
                value = string(speciesValues{1});
                return
            end

            ranking = zeros(numel(speciesValues), 1);
            names = strings(numel(speciesValues), 1);
            for index = 1:numel(speciesValues)
                ranking(index) = speciesValues{index}.X;
                names(index) = string(speciesValues{index});
            end
            ranking(isnan(ranking)) = Inf;
            [~, order] = sortrows(table(ranking, names), ["ranking", "names"]);
            pieces = strings(1, numel(order));
            for index = 1:numel(order)
                location = order(index);
                pieces(index) = sprintf("%s:%.3g", ...
                    names(location), occupancies(location));
            end
            value = strjoin(pieces, ", ");
        end

        function value = occupancy(obj, element)
            value = obj.species_(element);
        end

        function value = distance(obj, other)
            value = norm(other.coords - obj.coords);
        end

        function value = distance_from_point(obj, point)
            point = obj.validateCoordinates(point, "Cartesian");
            value = norm(point - obj.coords);
        end

        function tf = eq(obj, other)
            tf = isa(other, class(obj)) && obj.species == other.species && ...
                all(abs(obj.coords - other.coords) <= obj.position_atol) && ...
                kssolv.analysis.matgenlab.util.is_np_dict_equal( ...
                    obj.site_properties, other.site_properties);
        end

        function tf = ne(obj, other), tf = ~eq(obj, other); end

        function tf = lt(obj, other)
            if obj.species.average_electroneg ~= other.species.average_electroneg
                tf = obj.species.average_electroneg < ...
                    other.species.average_electroneg;
            else
                tf = obj.species_string < other.species_string;
            end
        end

        function value = hash(obj)
            [speciesValues, ~] = obj.species.items();
            value = sum(cellfun(@(item) item.Z, speciesValues));
        end

        function value = char(obj)
            value = sprintf("%s %s", mat2str(obj.coords), obj.species_string);
        end

        function value = string(obj), value = string(char(obj)); end

        function value = as_dict(obj)
            [speciesValues, occupancies] = obj.species.items();
            entries = cell(1, numel(speciesValues));
            for index = 1:numel(speciesValues)
                entry = speciesValues{index}.as_dict();
                metadata = fieldnames(entry);
                metadata = metadata(ismember(metadata, ...
                    {'x_module', 'x_class'}));
                if ~isempty(metadata)
                    entry = rmfield(entry, metadata);
                end
                entry.occu = occupancies(index);
                entries{index} = entry;
            end
            value = struct( ...
                "name", obj.species_string, ...
                "species", {entries}, ...
                "xyz", obj.coords, ...
                "properties", obj.site_properties, ...
                "x_module", "pymatgen.core.sites", ...
                "x_class", "Site", ...
                "label", obj.label);
        end

        function value = asDict(obj), value = obj.as_dict(); end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, ".") && ...
                    strcmp(reference(1).subs, "properties")
                value = obj.site_properties;
                if numel(reference) > 1
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
            else
                [varargout{1:nargout}] = builtin("subsref", obj, reference);
            end
        end

        function obj = subsasgn(obj, reference, value)
            if strcmp(reference(1).type, ".") && ...
                    strcmp(reference(1).subs, "properties")
                if isscalar(reference)
                    obj.site_properties = value;
                else
                    current = obj.site_properties;
                    current = builtin("subsasgn", current, reference(2:end), value);
                    obj.site_properties = current;
                end
            else
                obj = builtin("subsasgn", obj, reference, value);
            end
        end
    end

    methods (Static)
        function obj = from_dict(value)
            species = ...
                kssolv.analysis.matgenlab.core.Site.speciesFromDict(value.species);
            properties = struct();
            if isfield(value, "properties") && ~isempty(value.properties)
                properties = value.properties;
            end
            label = missing;
            if isfield(value, "label") && ~isempty(value.label)
                label = string(value.label);
            end
            obj = kssolv.analysis.matgenlab.core.Site( ...
                species, value.xyz, properties = properties, label = label);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core.Site.from_dict(value);
        end
    end

    methods (Access = protected)
        function value = getCoords(obj), value = obj.coords_; end

        function obj = setCoords(obj, value)
            obj.coords_ = obj.validateCoordinates(value, "Cartesian");
        end
    end

    methods (Static, Access = protected)
        function composition = normalizeSpecies(value)
            if isa(value, "kssolv.analysis.matgenlab.core.Composition")
                composition = value;
            elseif isstruct(value) || iscell(value) || ...
                    isa(value, "containers.Map") || isa(value, "dictionary")
                composition = kssolv.analysis.matgenlab.core.Composition(value);
            else
                composition = kssolv.analysis.matgenlab.core.Composition({value, 1});
            end
        end

        function coordinates = validateCoordinates(value, kind)
            if ~isnumeric(value) || numel(value) ~= 3 || any(~isfinite(value))
                error("KSSOLV:Matgenlab:Site:InvalidCoordinates", ...
                    "%s coordinates must contain three finite numbers.", kind);
            end
            coordinates = reshape(double(value), 1, 3);
        end

        function composition = speciesFromDict(entries)
            if isstruct(entries)
                entries = num2cell(entries);
            end
            pairs = cell(numel(entries), 2);
            for index = 1:numel(entries)
                entry = entries{index};
                if isfield(entry, "oxidation_state")
                    if kssolv.analysis.matgenlab.core.Element.is_valid_symbol( ...
                            string(entry.element))
                        item = kssolv.analysis.matgenlab.core.Species.from_dict(entry);
                    else
                        item = ...
                            kssolv.analysis.matgenlab.core.DummySpecies.from_dict(entry);
                    end
                else
                    item = kssolv.analysis.matgenlab.core.Element(entry.element);
                end
                pairs{index, 1} = item;
                pairs{index, 2} = entry.occu;
            end
            composition = kssolv.analysis.matgenlab.core.Composition(pairs);
        end
    end
end
