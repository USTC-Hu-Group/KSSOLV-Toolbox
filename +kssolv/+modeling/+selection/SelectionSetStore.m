classdef SelectionSetStore
    %SELECTIONSETSTORE Persistent named selections backed by stable site IDs.

    properties (Constant, Access = private)
        SiteIdProperty = "kssolv_site_id"
        IdentityProperty = "kssolv_selection_identity"
        SetsProperty = "kssolv_selection_sets"
    end

    methods (Static)
        function [model, set] = save(model, name, indices)
            name = strip(string(name));
            if ~isscalar(name) || name == ""
                error("KSSOLV:Modeling:SelectionSetName", ...
                    "A nonempty scalar selection-set name is required.");
            end
            indices = kssolv.modeling.ParameterUtils.indices( ...
                struct("indices", indices), model.num_sites, []);
            [model, siteIds] = ...
                kssolv.modeling.selection.SelectionSetStore. ...
                ensureSiteIds(model);
            sets = kssolv.modeling.selection.SelectionSetStore.readSets(model);
            set = struct("schemaVersion", 1, "name", name, ...
                "siteIds", reshape(siteIds(indices), 1, []));
            existing = find(string({sets.name}) == name, 1);
            if isempty(existing)
                sets(end + 1) = set;
            else
                sets(existing) = set;
            end
            model.properties.( ...
                kssolv.modeling.selection.SelectionSetStore.SetsProperty) = sets;
        end

        function [indices, missingIds] = resolve(model, name)
            name = strip(string(name));
            sets = kssolv.modeling.selection.SelectionSetStore.readSets(model);
            position = find(string({sets.name}) == name, 1);
            if isempty(position)
                error("KSSOLV:Modeling:SelectionSetMissing", ...
                    "Selection set '%s' does not exist.", name);
            end
            [~, currentIds] = ...
                kssolv.modeling.selection.SelectionSetStore. ...
                ensureSiteIds(model);
            requested = reshape(string(sets(position).siteIds), 1, []);
            indices = zeros(1, 0);
            missingIds = strings(1, 0);
            for id = requested
                index = find(currentIds == id, 1);
                if isempty(index)
                    missingIds(end + 1) = id; %#ok<AGROW>
                else
                    indices(end + 1) = index; %#ok<AGROW>
                end
            end
        end

        function values = list(model)
            sets = kssolv.modeling.selection.SelectionSetStore.readSets(model);
            template = struct("name", "", "siteCount", 0, ...
                "resolvedCount", 0, "missingCount", 0);
            values = repmat(template, 1, numel(sets));
            for index = 1:numel(sets)
                [resolved, missing] = ...
                    kssolv.modeling.selection.SelectionSetStore.resolve( ...
                    model, sets(index).name);
                values(index) = struct( ...
                    "name", string(sets(index).name), ...
                    "siteCount", numel(sets(index).siteIds), ...
                    "resolvedCount", numel(resolved), ...
                    "missingCount", numel(missing));
            end
        end

        function model = remove(model, name)
            name = strip(string(name));
            sets = kssolv.modeling.selection.SelectionSetStore.readSets(model);
            position = find(string({sets.name}) == name, 1);
            if isempty(position)
                error("KSSOLV:Modeling:SelectionSetMissing", ...
                    "Selection set '%s' does not exist.", name);
            end
            sets(position) = [];
            model.properties.( ...
                kssolv.modeling.selection.SelectionSetStore.SetsProperty) = sets;
        end

        function [model, ids] = ensureSiteIds(model)
            properties = model.properties;
            identity = struct("schemaVersion", 1, "nextId", 1);
            identityName = ...
                kssolv.modeling.selection.SelectionSetStore.IdentityProperty;
            if isfield(properties, identityName) && ...
                    isstruct(properties.(identityName)) && ...
                    isscalar(properties.(identityName))
                stored = properties.(identityName);
                if isfield(stored, "nextId") && ...
                        isnumeric(stored.nextId) && isscalar(stored.nextId) && ...
                        isfinite(stored.nextId) && stored.nextId >= 1
                    identity.nextId = max(1, fix(double(stored.nextId)));
                end
            end

            ids = strings(1, model.num_sites);
            used = strings(1, 0);
            for index = 1:model.num_sites
                siteProperties = model.get_site(index).site_properties;
                candidate = "";
                propertyName = ...
                    kssolv.modeling.selection.SelectionSetStore.SiteIdProperty;
                if isfield(siteProperties, propertyName)
                    candidate = string(siteProperties.(propertyName));
                end
                if ~isscalar(candidate) || candidate == "" || ...
                        any(used == candidate)
                    candidate = nextId();
                end
                ids(index) = candidate;
                used(end + 1) = candidate; %#ok<AGROW>
            end
            if model.num_sites > 0
                model = model.add_site_property( ...
                    kssolv.modeling.selection.SelectionSetStore.SiteIdProperty, ...
                    cellstr(ids));
            end
            properties = model.properties;
            properties.(identityName) = identity;
            model.properties = properties;

            function value = nextId()
                while true
                    value = "site-" + compose("%08d", identity.nextId);
                    identity.nextId = identity.nextId + 1;
                    if ~any(used == value), return, end
                end
            end
        end
    end

    methods (Static, Access = private)
        function sets = readSets(model)
            sets = struct("schemaVersion", {}, "name", {}, "siteIds", {});
            properties = model.properties;
            propertyName = ...
                kssolv.modeling.selection.SelectionSetStore.SetsProperty;
            if ~isfield(properties, propertyName) || ...
                    isempty(properties.(propertyName))
                return
            end
            candidate = properties.(propertyName);
            if ~isstruct(candidate)
                error("KSSOLV:Modeling:SelectionSetSchema", ...
                    "Stored selection sets use an invalid schema.");
            end
            required = ["schemaVersion", "name", "siteIds"];
            for fieldName = required
                if ~isfield(candidate, fieldName)
                    error("KSSOLV:Modeling:SelectionSetSchema", ...
                        "Stored selection sets use an invalid schema.");
                end
            end
            sets = reshape(candidate, 1, []);
        end
    end
end
