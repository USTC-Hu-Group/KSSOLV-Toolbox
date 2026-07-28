classdef PeriodicSite < kssolv.analysis.matgenlab.core.Site
    %PERIODICSITE Site represented by fractional coordinates and a lattice.

    properties (Access = protected)
        lattice_ (1,1) kssolv.analysis.matgenlab.core.Lattice = ...
            kssolv.analysis.matgenlab.core.Lattice(eye(3))
        frac_coords_ (1,3) double = [0, 0, 0]
    end

    properties (Dependent)
        lattice
        frac_coords
        a
        b
        c
    end

    methods
        function obj = PeriodicSite(species, coords, lattice, options)
            arguments
                species
                coords
                lattice
                options.to_unit_cell (1,1) logical = false
                options.coords_are_cartesian (1,1) logical = false
                options.properties (1,1) struct = struct()
                options.label = missing
                options.skip_checks (1,1) logical = false
            end

            if ~isa(lattice, "kssolv.analysis.matgenlab.core.Lattice")
                lattice = kssolv.analysis.matgenlab.core.Lattice(lattice);
            end
            obj@kssolv.analysis.matgenlab.core.Site( ...
                species, [0, 0, 0], properties = options.properties, ...
                label = options.label, skip_checks = options.skip_checks);
            obj.lattice_ = lattice;
            if options.coords_are_cartesian
                coords = lattice.get_fractional_coords(coords);
            end
            coords = obj.validateCoordinates(coords, "Fractional");
            if options.to_unit_cell
                periodic = lattice.pbc;
                coords(periodic) = mod(coords(periodic), 1);
            end
            obj.frac_coords_ = coords;
            obj.coords_ = lattice.get_cartesian_coords(coords);
        end

        function value = get.lattice(obj), value = obj.lattice_; end
        function obj = set.lattice(obj, value)
            if ~isa(value, "kssolv.analysis.matgenlab.core.Lattice")
                value = kssolv.analysis.matgenlab.core.Lattice(value);
            end
            obj.lattice_ = value;
            obj.coords_ = value.get_cartesian_coords(obj.frac_coords_);
        end

        function value = get.frac_coords(obj), value = obj.frac_coords_; end
        function obj = set.frac_coords(obj, value)
            obj.frac_coords_ = obj.validateCoordinates(value, "Fractional");
            obj.coords_ = obj.lattice_.get_cartesian_coords(obj.frac_coords_);
        end

        function value = get.a(obj), value = obj.frac_coords_(1); end
        function value = get.b(obj), value = obj.frac_coords_(2); end
        function value = get.c(obj), value = obj.frac_coords_(3); end
        function obj = set.a(obj, value)
            coordinates = obj.frac_coords_; coordinates(1) = value;
            obj.frac_coords = coordinates;
        end
        function obj = set.b(obj, value)
            coordinates = obj.frac_coords_; coordinates(2) = value;
            obj.frac_coords = coordinates;
        end
        function obj = set.c(obj, value)
            coordinates = obj.frac_coords_; coordinates(3) = value;
            obj.frac_coords = coordinates;
        end

        function obj = to_unit_cell(obj, in_place)
            if nargin < 2, in_place = false; end
            if ~isscalar(in_place) || ~(islogical(in_place) || isnumeric(in_place))
                error("KSSOLV:Matgenlab:PeriodicSite:InPlace", ...
                    "in_place must be a scalar logical value.");
            end
            coordinates = obj.frac_coords_;
            periodic = obj.lattice_.pbc;
            coordinates(periodic) = mod(coordinates(periodic), 1);
            obj.frac_coords = coordinates;
        end

        function tf = is_periodic_image(obj, other, tolerance, check_lattice)
            if nargin < 3, tolerance = 1e-8; end
            if nargin < 4, check_lattice = true; end
            if check_lattice && obj.lattice ~= other.lattice
                tf = false;
                return
            end
            if obj.species ~= other.species
                tf = false;
                return
            end
            difference = obj.frac_coords - other.frac_coords;
            periodic = obj.lattice.pbc;
            difference(periodic) = ...
                difference(periodic) - round(difference(periodic));
            tf = all(abs(difference) <= tolerance);
        end

        function [distance, image] = distance_and_image_from_frac_coords( ...
                obj, coordinates, image)
            if nargin < 3
                [distance, image] = obj.lattice.get_distance_and_image( ...
                    obj.frac_coords, coordinates);
            else
                [distance, image] = obj.lattice.get_distance_and_image( ...
                    obj.frac_coords, coordinates, image);
            end
        end

        function [distance, image] = distance_and_image(obj, other, image)
            if nargin < 3
                [distance, image] = ...
                    obj.distance_and_image_from_frac_coords(other.frac_coords);
            else
                [distance, image] = ...
                    obj.distance_and_image_from_frac_coords( ...
                        other.frac_coords, image);
            end
        end

        function value = distance(obj, other, image)
            if nargin < 3
                value = obj.distance_and_image(other);
            else
                value = obj.distance_and_image(other, image);
            end
        end

        function tf = eq(obj, other)
            tf = isa(other, class(obj)) && obj.species == other.species && ...
                obj.lattice == other.lattice && ...
                all(abs(obj.coords - other.coords) <= obj.position_atol) && ...
                kssolv.analysis.matgenlab.util.is_np_dict_equal( ...
                    obj.site_properties, other.site_properties);
        end

        function value = as_dict(obj, verbosity)
            if nargin < 2, verbosity = 0; end
            [species, occupancies] = obj.species.items();
            entries = cell(1, numel(species));
            for index = 1:numel(species)
                entry = species{index}.as_dict();
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
                "species", {entries}, ...
                "abc", obj.frac_coords, ...
                "lattice", obj.lattice.as_dict(verbosity), ...
                "x_module", "pymatgen.core.sites", ...
                "x_class", "PeriodicSite", ...
                "properties", obj.site_properties, ...
                "label", obj.label);
            if verbosity > 0
                value.xyz = obj.coords;
            end
        end

        function value = asDict(obj, varargin), value = obj.as_dict(varargin{:}); end
    end

    methods (Static)
        function obj = from_dict(value, lattice)
            if nargin < 2 || isempty(lattice)
                if isa(value.lattice, ...
                        "kssolv.analysis.matgenlab.core.Lattice")
                    lattice=value.lattice;
                else
                    lattice = ...
                        kssolv.analysis.matgenlab.core.Lattice. ...
                        from_dict(value.lattice);
                end
            end
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
            obj = kssolv.analysis.matgenlab.core.PeriodicSite( ...
                species, value.abc, lattice, ...
                properties = properties, label = label);
        end

        function obj = fromDict(value, varargin)
            obj = ...
                kssolv.analysis.matgenlab.core.PeriodicSite.from_dict( ...
                    value, varargin{:});
        end
    end

    methods (Access = protected)
        function value = getCoords(obj)
            value = obj.lattice_.get_cartesian_coords(obj.frac_coords_);
        end

        function obj = setCoords(obj, value)
            obj.coords_ = obj.validateCoordinates(value, "Cartesian");
            obj.frac_coords_ = ...
                obj.lattice_.get_fractional_coords(obj.coords_);
        end
    end
end
