classdef PeriodicNeighbor < kssolv.analysis.matgenlab.core.PeriodicSite
    %PERIODICNEIGHBOR Periodic neighboring site with image and source index.

    properties (SetAccess = private)
        nn_distance (1,1) double = 0
        index (1,1) double = NaN
        image (1,3) double = [0, 0, 0]
    end

    methods
        function obj = PeriodicNeighbor(species, coords, lattice, ...
                nn_distance, index, image, options)
            arguments
                species
                coords
                lattice
                nn_distance (1,1) double {mustBeNonnegative}
                index (1,1) double = NaN
                image = [0, 0, 0]
                options.properties (1,1) struct = struct()
                options.label = missing
                options.coords_are_cartesian (1,1) logical = false
            end
            obj@kssolv.analysis.matgenlab.core.PeriodicSite( ...
                species, coords, lattice, properties = options.properties, ...
                label = options.label, ...
                coords_are_cartesian = options.coords_are_cartesian);
            obj.nn_distance = nn_distance;
            obj.index = index;
            obj.image = reshape(double(image), 1, 3);
        end

        function value = as_dict(obj, verbosity)
            if nargin < 2, verbosity = 0; end
            base = as_dict@kssolv.analysis.matgenlab.core.PeriodicSite( ...
                obj, verbosity);
            serializedIndex = obj.index;
            if ~isnan(serializedIndex), serializedIndex = serializedIndex - 1; end
            value = struct( ...
                "species", {base.species}, ...
                "coords", obj.coords, ...
                "lattice", obj.lattice.as_dict(verbosity), ...
                "x_module", "pymatgen.core.structure", ...
                "x_class", "PeriodicNeighbor", ...
                "properties", obj.site_properties, ...
                "nn_distance", obj.nn_distance, ...
                "index", serializedIndex, ...
                "image", obj.image, ...
                "label", obj.label);
        end
    end

    methods (Static)
        function obj = from_dict(value, lattice)
            if nargin < 2 || isempty(lattice)
                lattice = ...
                    kssolv.analysis.matgenlab.core.Lattice.from_dict( ...
                        value.lattice);
            end
            if isfield(value, "coords")
                species = ...
                    kssolv.analysis.matgenlab.core.Site.speciesFromDict( ...
                        value.species);
                coords = value.coords;
                cartesian = true;
                properties = value.properties;
                label = value.label;
            else
                site = ...
                    kssolv.analysis.matgenlab.core.PeriodicSite.from_dict( ...
                        value, lattice);
                species = site.species;
                coords = site.frac_coords;
                cartesian = false;
                properties = site.site_properties;
                label = site.label;
            end
            restoredIndex = value.index;
            if ~isnan(restoredIndex), restoredIndex = restoredIndex + 1; end
            obj = kssolv.analysis.matgenlab.core.PeriodicNeighbor( ...
                species, coords, lattice, ...
                value.nn_distance, restoredIndex, value.image, ...
                properties = properties, label = label, ...
                coords_are_cartesian = cartesian);
        end
        function obj = fromDict(value, varargin)
            obj = ...
                kssolv.analysis.matgenlab.core.PeriodicNeighbor.from_dict( ...
                    value, varargin{:});
        end
    end
end
