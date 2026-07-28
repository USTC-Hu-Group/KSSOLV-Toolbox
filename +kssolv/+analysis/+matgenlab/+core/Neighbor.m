classdef Neighbor < kssolv.analysis.matgenlab.core.Site
    %NEIGHBOR Non-periodic neighboring site with distance and source index.

    properties (SetAccess = private)
        nn_distance (1,1) double = 0
        index (1,1) double = NaN
    end

    methods
        function obj = Neighbor(species, coords, nn_distance, index, options)
            arguments
                species
                coords
                nn_distance (1,1) double {mustBeNonnegative}
                index (1,1) double = NaN
                options.properties (1,1) struct = struct()
                options.label = missing
            end
            obj@kssolv.analysis.matgenlab.core.Site( ...
                species, coords, properties = options.properties, ...
                label = options.label);
            obj.nn_distance = nn_distance;
            obj.index = index;
        end

        function value = as_dict(obj)
            base = as_dict@kssolv.analysis.matgenlab.core.Site(obj);
            serializedIndex = obj.index;
            if ~isnan(serializedIndex), serializedIndex = serializedIndex - 1; end
            value = struct( ...
                "species", {base.species}, ...
                "coords", obj.coords, ...
                "properties", obj.site_properties, ...
                "nn_distance", obj.nn_distance, ...
                "index", serializedIndex, ...
                "x_module", "pymatgen.core.structure", ...
                "x_class", "Neighbor", ...
                "label", obj.label);
        end
    end

    methods (Static)
        function obj = from_dict(value)
            if isfield(value, "coords")
                species = ...
                    kssolv.analysis.matgenlab.core.Site.speciesFromDict( ...
                        value.species);
                coords = value.coords;
                properties = value.properties;
                label = value.label;
            else
                site = kssolv.analysis.matgenlab.core.Site.from_dict(value);
                species = site.species;
                coords = site.coords;
                properties = site.site_properties;
                label = site.label;
            end
            restoredIndex = value.index;
            if ~isnan(restoredIndex), restoredIndex = restoredIndex + 1; end
            obj = kssolv.analysis.matgenlab.core.Neighbor( ...
                species, coords, value.nn_distance, restoredIndex, ...
                properties = properties, label = label);
        end
        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core.Neighbor.from_dict(value);
        end
    end
end
