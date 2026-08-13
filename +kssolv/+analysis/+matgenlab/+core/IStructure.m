classdef IStructure < kssolv.analysis.matgenlab.core.SiteCollection & ...
        kssolv.analysis.matgenlab.util.MSONable
    %ISTRUCTURE Periodic collection of sites.

    properties (SetAccess = protected)
        lattice (1,1) kssolv.analysis.matgenlab.core.Lattice = ...
            kssolv.analysis.matgenlab.core.Lattice(eye(3))
        structure_properties (1,1) struct = struct()
    end

    properties (Dependent, SetAccess = private)
        frac_coords
        volume
        density
        pbc
        is_3d_periodic
    end

    methods
        function obj = IStructure(lattice, species, coords, options)
            arguments
                lattice
                species
                coords
                options.charge = NaN
                options.validate_proximity (1,1) logical = false
                options.to_unit_cell (1,1) logical = false
                options.coords_are_cartesian (1,1) logical = false
                options.site_properties (1,1) struct = struct()
                options.labels = []
                options.properties (1,1) struct = struct()
                options.skip_checks (1,1) logical = false
            end
            obj@kssolv.analysis.matgenlab.core.SiteCollection();
            if ~isa(lattice, "kssolv.analysis.matgenlab.core.Lattice")
                lattice = kssolv.analysis.matgenlab.core.Lattice(lattice);
            end
            obj.lattice = lattice;
            obj.structure_properties = options.properties;

            species = obj.normalizeSequence(species);
            if ~isnumeric(coords) || size(coords, 2) ~= 3 || ...
                    size(coords, 1) ~= numel(species)
                error("KSSOLV:Matgenlab:Structure:Shape", ...
                    "Species and coordinates must contain the same number of sites.");
            end
            labels = options.labels;
            if isempty(labels)
                labels = repmat(missing, numel(species), 1);
            else
                labels = reshape(string(labels), [], 1);
                if numel(labels) ~= numel(species)
                    error("KSSOLV:Matgenlab:Structure:LabelLength", ...
                        "labels must contain one value per site.");
                end
            end

            propertyNames = fieldnames(options.site_properties);
            for propertyIndex = 1:numel(propertyNames)
                values = options.site_properties.(propertyNames{propertyIndex});
                if numel(values) ~= numel(species)
                    error("KSSOLV:Matgenlab:Structure:PropertyLength", ...
                        "Site property '%s' must contain one value per site.", ...
                        propertyNames{propertyIndex});
                end
            end

            obj.sites_ = cell(1, numel(species));
            for index = 1:numel(species)
                siteProperties = struct();
                for propertyIndex = 1:numel(propertyNames)
                    name = propertyNames{propertyIndex};
                    values = options.site_properties.(name);
                    if iscell(values)
                        siteProperties.(name) = values{index};
                    elseif isvector(values)
                        siteProperties.(name) = values(index);
                    else
                        siteProperties.(name) = values(index, :);
                    end
                end
                obj.sites_{index} = ...
                    kssolv.analysis.matgenlab.core.PeriodicSite( ...
                        species{index}, coords(index, :), lattice, ...
                        to_unit_cell = options.to_unit_cell, ...
                        coords_are_cartesian = options.coords_are_cartesian, ...
                        properties = siteProperties, label = labels(index), ...
                        skip_checks = options.skip_checks);
            end
            if options.validate_proximity && ~obj.is_valid(0.5)
                error("KSSOLV:Matgenlab:Structure:Proximity", ...
                    "Structure contains sites less than 0.5 angstrom apart.");
            end
            obj.explicit_charge_ = double(options.charge);
        end

        function value = get.frac_coords(obj)
            value = zeros(obj.num_sites, 3);
            for index = 1:obj.num_sites
                value(index, :) = obj.sites_{index}.frac_coords;
            end
        end
        function value = get.volume(obj), value = obj.lattice.volume; end
        function value = get.density(obj)
            % CODATA value used by the frozen scipy.constants dependency.
            value = obj.composition.weight * 1.66053906892 / obj.volume;
        end
        function value = get.pbc(obj), value = obj.lattice.pbc; end
        function value = get.is_3d_periodic(obj), value = all(obj.pbc); end

        function info = get_space_group_info(obj, symprec, angleTolerance)
            if nargin < 2, symprec = 0.01; end
            if nargin < 3, angleTolerance = 5; end
            analyzer = ...
                kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj, symprec, angleTolerance);
            info = {analyzer.get_space_group_symbol(), ...
                analyzer.get_space_group_number()};
        end

        function tf = matches(obj, other, anonymous, varargin)
            if nargin < 3, anonymous = false; end
            if ~isempty(varargin) && ...
                    (ischar(varargin{1}) || isstring(varargin{1}))
                matcher = structureMatcherFromOptions(varargin{:});
            else
                matcher = kssolv.analysis.matgenlab.core.StructureMatcher( ...
                    varargin{:});
            end
            if anonymous
                tf = matcher.fit_anonymous(obj, other);
            else
                tf = matcher.fit(obj, other);
            end
        end

        function structure = get_primitive_structure( ...
                obj, tolerance, useSiteProperties, varargin)
            if nargin < 2, tolerance = 0.25; end
            if nargin < 3, useSiteProperties = false; end
            if tolerance <= 0
                error("KSSOLV:Matgenlab:Structure:PrimitiveTolerance", ...
                    "tolerance must be positive.");
            end
            constrainLattice = [];
            reduce = true;
            for optionIndex = 1:2:numel(varargin)
                if optionIndex == numel(varargin)
                    error("KSSOLV:Matgenlab:Structure:InvalidArguments", ...
                        "Primitive-structure options must be name-value pairs.");
                end
                name = lower(string(varargin{optionIndex}));
                if name == "constrain_latt"
                    constrainLattice = varargin{optionIndex + 1};
                elseif name == "reduce"
                    reduce = logical(varargin{optionIndex + 1});
                else
                    error("KSSOLV:Matgenlab:Structure:InvalidOption", ...
                        "Unknown primitive-structure option '%s'.", name);
                end
            end
            analyzer = ...
                kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj, tolerance);
            structure = analyzer.find_primitive(useSiteProperties);
            if isa(obj, "kssolv.analysis.matgenlab.core.Structure") && ...
                    ~isa(structure, "kssolv.analysis.matgenlab.core.Structure")
                structure = kssolv.analysis.matgenlab.core.Structure.from_sites( ...
                    structure.sites, properties=structure.structure_properties);
            end
            if reduce
                structure = structure.get_reduced_structure();
            end
            if ~isempty(constrainLattice) && ...
                    ~latticeConstraintsSatisfied( ...
                    structure.lattice, obj.lattice, constrainLattice)
                structure = obj.copy();
            end
        end

        function structure = to_cell(obj, cellType, varargin)
            options = struct("symprec", 0.01, "angle_tolerance", 5, ...
                "keep_site_properties", false);
            for index = 1:2:numel(varargin)
                if index + 1 > numel(varargin)
                    error("KSSOLV:Matgenlab:Structure:InvalidArguments", ...
                        "Name-value arguments must occur in pairs.");
                end
                name = char(lower(string(varargin{index})));
                if isfield(options, name)
                    options.(name) = varargin{index + 1};
                end
            end
            analyzer = ...
                kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj, options.symprec, ...
                    options.angle_tolerance);
            switch lower(string(cellType))
                case "primitive"
                    structure = analyzer.get_primitive_standard_structure( ...
                        true, options.keep_site_properties);
                case "conventional"
                    structure = analyzer.get_conventional_standard_structure( ...
                        true, options.keep_site_properties);
                otherwise
                    error("KSSOLV:Matgenlab:Structure:CellType", ...
                        "cell_type must be 'primitive' or 'conventional'.");
            end
        end

        function structure = to_primitive(obj, varargin)
            structure = obj.to_cell("primitive", varargin{:});
        end

        function structure = to_conventional(obj, varargin)
            structure = obj.to_cell("conventional", varargin{:});
        end

        function dataset = get_symmetry_dataset( ...
                obj, backend, returnRawDataset, symprec, varargin)
            if nargin < 2 || isempty(backend), backend = "spglib"; end
            if nargin < 3 || isempty(returnRawDataset)
                returnRawDataset = false;
            end
            if nargin < 4 || isempty(symprec), symprec = 0.01; end
            if lower(string(backend)) ~= "spglib"
                error("KSSOLV:Matgenlab:Structure:MissingMoyopy", ...
                    "The moyopy backend is not available in matgenlab.");
            end
            angleTolerance = 5;
            for index = 1:2:numel(varargin)
                if lower(string(varargin{index})) == "angle_tolerance"
                    angleTolerance = varargin{index + 1};
                end
            end
            analyzer = ...
                kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj, symprec, angleTolerance);
            raw = analyzer.get_symmetry_dataset();
            if returnRawDataset
                dataset = raw;
            else
                dataset = struct( ...
                    "hall_number", raw.hall_number, ...
                    "number", raw.number, ...
                    "site_symmetry_symbols", raw.site_symmetry_symbols, ...
                    "wyckoffs", raw.wyckoffs, ...
                    "international", raw.international, ...
                    "orbits", raw.crystallographic_orbits, ...
                    "std_origin_shift", raw.origin_shift);
            end
        end

        function distance = get_distance(obj, first, second, image)
            obj.validateSiteIndex(first);
            obj.validateSiteIndex(second);
            if nargin < 4
                distance = obj.sites_{first}.distance(obj.sites_{second});
            else
                distance = obj.sites_{first}.distance( ...
                    obj.sites_{second}, image);
            end
        end

        function neighbors = get_sites_in_sphere(obj, point, radius, options)
            arguments
                obj
                point
                radius (1,1) double {mustBeNonnegative}
                options.include_index (1,1) logical = true
                options.include_image (1,1) logical = true
            end
            point = reshape(double(point), 1, 3);
            fractionalPoint = obj.lattice.get_fractional_coords(point);
            imageRange = ceil(radius ./ obj.lattice.lengths) + 1;
            periodic = obj.pbc;
            imageRange(~periodic) = 0;
            [imageC, imageB, imageA] = ndgrid( ...
                -imageRange(3):imageRange(3), ...
                -imageRange(2):imageRange(2), ...
                -imageRange(1):imageRange(1));
            images = [imageA(:), imageB(:), imageC(:)];
            lattice = obj.lattice;
            latticeMatrix = lattice.matrix;
            neighbors = cell(1, 0);
            for siteIndex = 1:obj.num_sites
                site = obj.sites_{siteIndex};
                fractional = site.frac_coords;
                species = site.species;
                siteProperties = site.site_properties;
                label = site.label;
                deltas = fractional + images - fractionalPoint;
                cartesian = deltas * latticeMatrix;
                distances = sqrt(sum(cartesian .* cartesian, 2));
                matches = find(distances <= radius + 1e-12);
                for matchIndex = reshape(matches, 1, [])
                    image = images(matchIndex, :);
                    neighborIndex = siteIndex + ...
                        0 * double(options.include_index);
                    neighborImage = image + ...
                        0 * double(options.include_image);
                    neighbor = ...
                        kssolv.analysis.matgenlab.core.PeriodicNeighbor( ...
                            species, fractional + image, lattice, ...
                            distances(matchIndex), neighborIndex, ...
                            neighborImage, properties = siteProperties, ...
                            label = label);
                    neighbors{end + 1} = neighbor; %#ok<AGROW>
                end
            end
            if ~isempty(neighbors)
                distances = cellfun(@(item) item.nn_distance, neighbors);
                [~, order] = sort(distances);
                neighbors = neighbors(order);
            end
        end

        function neighbors = get_neighbors(obj, site, radius)
            neighbors = obj.get_sites_in_sphere(site.coords, radius);
            keep = true(size(neighbors));
            for index = 1:numel(neighbors)
                keep(index) = neighbors{index}.nn_distance > 1e-12;
            end
            neighbors = neighbors(keep);
        end

        function neighbors = get_neighbors_in_shell(obj, origin, radius, ...
                width, include_index, include_image)
            if nargin < 5, include_index = false; end
            if nargin < 6, include_image = false; end
            values = obj.get_sites_in_sphere(origin, radius + width, ...
                include_index = include_index, ...
                include_image = include_image);
            neighbors = values(cellfun(@(neighbor) ...
                neighbor.nn_distance >= radius - width, values));
        end

        function neighbors = get_all_neighbors(obj, radius, options)
            arguments
                obj
                radius (1,1) double {mustBeNonnegative}
                options.include_index (1,1) logical = true
                options.include_image (1,1) logical = true
                options.numerical_tol (1,1) double {mustBeNonnegative} = 1e-8
                options.sites = {}
            end
            centerSites = options.sites;
            if isempty(centerSites), centerSites = obj.sites_; end
            if ~iscell(centerSites), centerSites = num2cell(centerSites); end
            centerSites = reshape(centerSites, 1, []);
            neighbors = cell(1, numel(centerSites));
            for index = 1:numel(centerSites)
                values = obj.get_sites_in_sphere( ...
                    centerSites{index}.coords, radius, ...
                    include_index = options.include_index, ...
                    include_image = options.include_image);
                values = values(cellfun(@(item) ...
                    item.nn_distance > options.numerical_tol, values));
                neighbors{index} = values;
            end
        end

        function neighbors = get_all_neighbors_py(obj, radius, varargin)
            neighbors = obj.get_all_neighbors(radius, varargin{:});
        end

        function neighbors = get_all_neighbors_old(obj, radius, varargin)
            neighbors = obj.get_all_neighbors(radius, varargin{:});
        end

        function neighbors = get_neighbors_old(obj, site, radius, varargin)
            if ~isempty(varargin)
                % include_index/include_image only change Python tuple shape;
                % PeriodicNeighbor always retains both values in MATLAB.
            end
            neighbors = obj.get_neighbors(site, radius);
        end

        function [center_indices, point_indices, offset_vectors, distances] = ...
                get_neighbor_list(obj, radius, options)
            arguments
                obj
                radius (1,1) double {mustBeNonnegative}
                options.numerical_tol (1,1) double {mustBeNonnegative} = 1e-8
                options.exclude_self (1,1) logical = true
                options.sites = {}
            end
            allNeighbors = obj.get_all_neighbors(radius, ...
                numerical_tol = options.numerical_tol, ...
                sites = options.sites);
            center_indices = zeros(0, 1);
            point_indices = zeros(0, 1);
            offset_vectors = zeros(0, 3);
            distances = zeros(0, 1);
            for center = 1:numel(allNeighbors)
                values = allNeighbors{center};
                for index = 1:numel(values)
                    item = values{index};
                    if options.exclude_self && item.nn_distance <= ...
                            options.numerical_tol
                        continue
                    end
                    center_indices(end + 1, 1) = center; %#ok<AGROW>
                    point_indices(end + 1, 1) = item.index; %#ok<AGROW>
                    offset_vectors(end + 1, :) = item.image; %#ok<AGROW>
                    distances(end + 1, 1) = item.nn_distance; %#ok<AGROW>
                end
            end
        end

        function [centerIndices, pointIndices, offsetVectors, distances, ...
                symmetryIndices, symmetryOperations] = ...
                get_symmetric_neighbor_list(obj, radius, spaceGroup, ...
                uniqueOnly, numericalTolerance, excludeSelf)
            if nargin < 3 || isempty(spaceGroup)
                information = obj.get_space_group_info();
                spaceGroup = information{1};
            end
            if nargin < 4, uniqueOnly = false; end
            if nargin < 5, numericalTolerance = 1e-8; end
            if nargin < 6, excludeSelf = true; end
            if isa(spaceGroup, ...
                    "kssolv.analysis.matgenlab.symmetry.groups.SpaceGroup")
                group = spaceGroup;
            elseif isnumeric(spaceGroup)
                group = kssolv.analysis.matgenlab.symmetry.groups. ...
                    SpaceGroup.from_int_number(spaceGroup);
            else
                group = kssolv.analysis.matgenlab.symmetry.groups. ...
                    SpaceGroup(string(spaceGroup));
            end
            if ~group.is_compatible(obj.lattice)
                error("KSSOLV:Matgenlab:Structure:IncompatibleSpaceGroup", ...
                    "The lattice is incompatible with space group %s.", ...
                    group.symbol);
            end
            [centerIndices, pointIndices, offsetVectors, distances] = ...
                obj.get_neighbor_list(radius, ...
                numerical_tol = numericalTolerance, ...
                exclude_self = excludeSelf);
            if uniqueOnly
                keep = true(numel(centerIndices), 1);
                for first = 1:numel(centerIndices)
                    if ~keep(first), continue; end
                    for second = first + 1:numel(centerIndices)
                        if keep(second) && ...
                                centerIndices(first) == pointIndices(second) && ...
                                pointIndices(first) == centerIndices(second) && ...
                                all(offsetVectors(first, :) == ...
                                -offsetVectors(second, :)) && ...
                                abs(distances(first) - distances(second)) <= ...
                                numericalTolerance
                            keep(second) = false;
                            break
                        end
                    end
                end
                centerIndices = centerIndices(keep);
                pointIndices = pointIndices(keep);
                offsetVectors = offsetVectors(keep, :);
                distances = distances(keep);
                [distances, order] = sort(distances);
                centerIndices = centerIndices(order);
                pointIndices = pointIndices(order);
                offsetVectors = offsetVectors(order, :);
            end
            count = numel(centerIndices);
            symmetryIndices = nan(count, 1);
            symmetryOperations = cell(count, 1);
            identity = kssolv.analysis.matgenlab.core.SymmOp. ...
                from_rotation_and_translation(eye(3), zeros(1, 3));
            symmetryIndex = 0;
            for first = 1:count
                if ~isnan(symmetryIndices(first)), continue; end
                symmetryIndices(first) = symmetryIndex;
                symmetryOperations{first} = identity;
                for second = first + 1:count
                    if ~isnan(symmetryIndices(second)) || ...
                            abs(distances(first) - distances(second)) > ...
                            numericalTolerance
                        continue
                    end
                    for operationIndex = 1:numel(group.symmetry_ops)
                        operation = group.symmetry_ops{operationIndex};
                        [related, reversed] = ...
                            operation.are_symmetrically_related_vectors( ...
                            obj.sites_{centerIndices(first)}.frac_coords, ...
                            obj.sites_{pointIndices(first)}.frac_coords, ...
                            offsetVectors(first, :), ...
                            obj.sites_{centerIndices(second)}.frac_coords, ...
                            obj.sites_{pointIndices(second)}.frac_coords, ...
                            offsetVectors(second, :), 0.001);
                        if related
                            symmetryIndices(second) = symmetryIndex;
                            symmetryOperations{second} = operation;
                            if reversed
                                temporary = centerIndices(second);
                                centerIndices(second) = pointIndices(second);
                                pointIndices(second) = temporary;
                                offsetVectors(second, :) = ...
                                    -offsetVectors(second, :);
                            end
                            break
                        end
                    end
                end
                symmetryIndex = symmetryIndex + 1;
            end
            [symmetryIndices, order] = sort(symmetryIndices);
            centerIndices = centerIndices(order);
            pointIndices = pointIndices(order);
            offsetVectors = offsetVectors(order, :);
            distances = distances(order);
            symmetryOperations = symmetryOperations(order);
            for groupIndex = unique(symmetryIndices).'
                positions = find(symmetryIndices == groupIndex);
                identityPosition = positions(find(cellfun(@(operation) ...
                    operation == identity, ...
                    symmetryOperations(positions)), 1));
                if ~isempty(identityPosition) && ...
                        identityPosition ~= positions(1)
                    swap = [positions(1), identityPosition];
                    centerIndices(swap) = centerIndices(fliplr(swap));
                    pointIndices(swap) = pointIndices(fliplr(swap));
                    offsetVectors(swap, :) = ...
                        offsetVectors(fliplr(swap), :);
                    distances(swap) = distances(fliplr(swap));
                    symmetryOperations(swap) = ...
                        symmetryOperations(fliplr(swap));
                end
            end
        end

        function result = get_sorted_structure(obj, key, reverse)
            if nargin < 2 || isempty(key)
                electroneg = zeros(obj.num_sites, 1);
                names = strings(obj.num_sites, 1);
                for index = 1:obj.num_sites
                    electroneg(index) = obj.sites_{index}.species.average_electroneg;
                    names(index) = obj.sites_{index}.species_string;
                end
                [~, order] = sortrows(table(electroneg, names), ...
                    ["electroneg", "names"]);
            else
                values = cellfun(key, obj.sites_, "UniformOutput", false);
                [~, order] = sort([values{:}]);
            end
            if nargin >= 3 && reverse, order = flip(order); end
            result = kssolv.analysis.matgenlab.core.Structure.from_sites( ...
                obj.sites_(order), charge = obj.explicit_charge_, ...
                properties = obj.structure_properties);
        end

        function result = copy(obj, site_properties, sanitize, properties)
            mergedSiteProperties = obj.site_properties;
            if nargin >= 2 && ~isempty(site_properties)
                names = fieldnames(site_properties);
                for nameIndex = 1:numel(names)
                    mergedSiteProperties.(names{nameIndex}) = ...
                        site_properties.(names{nameIndex});
                end
            end
            if nargin < 3, sanitize = false; end
            if nargin < 4 || isempty(properties)
                properties = obj.structure_properties;
            end
            latticeValue = obj.lattice;
            coordinates = obj.frac_coords;
            if sanitize
                latticeValue = obj.lattice.get_lll_reduced_lattice();
                coordinates = latticeValue.get_fractional_coords( ...
                    obj.cart_coords);
            end
            constructor = @kssolv.analysis.matgenlab.core.IStructure;
            if isa(obj, "kssolv.analysis.matgenlab.core.Structure")
                constructor = @kssolv.analysis.matgenlab.core.Structure;
            end
            result = constructor(latticeValue, obj.species_and_occu, ...
                coordinates, to_unit_cell = sanitize, ...
                site_properties = mergedSiteProperties, labels = obj.labels, ...
                properties = properties, skip_checks = true);
            result.explicit_charge_ = obj.explicit_charge_;
            if sanitize && ...
                    isa(result, "kssolv.analysis.matgenlab.core.Structure")
                result = result.sort();
            end
        end

        function images = interpolate(obj, ending, nimages, ...
                interpolate_lattices, pbc, autosort_tol, end_amplitude)
            if nargin < 3 || isempty(nimages), nimages = 10; end
            if nargin < 4, interpolate_lattices = false; end
            if nargin < 5, pbc = true; end
            if nargin < 6, autosort_tol = 0; end
            if nargin < 7, end_amplitude = 1; end
            if obj.num_sites ~= ending.num_sites || ...
                    ~all(cellfun(@(first, second) first == second, ...
                    obj.species_and_occu, ending.species_and_occu))
                error("KSSOLV:Matgenlab:Structure:InterpolationSpecies", ...
                    "Structures have different species or site counts.");
            end
            if isscalar(nimages)
                fractions = linspace(0, 1, nimages + 1);
            else
                fractions = reshape(double(nimages), 1, []);
            end
            startCoordinates = obj.frac_coords;
            endCoordinates = ending.frac_coords;
            if autosort_tol > 0
                distances = obj.lattice.get_all_distances( ...
                    startCoordinates, endCoordinates);
                mapping = zeros(1, obj.num_sites);
                ambiguous = zeros(1, 0);
                for siteIndex = 1:obj.num_sites
                    candidates = find( ...
                        distances(siteIndex, :) < autosort_tol);
                    if isscalar(candidates)
                        mapping(siteIndex) = candidates;
                    else
                        ambiguous(end + 1) = siteIndex; %#ok<AGROW>
                    end
                end
                if numel(ambiguous) > 1 || ...
                        numel(unique(mapping(mapping > 0))) ~= nnz(mapping)
                    error("KSSOLV:Matgenlab:Structure:InterpolationAutosort", ...
                        "Unable to reliably match structures with autosort_tol=%g.", ...
                        autosort_tol);
                end
                if isscalar(ambiguous)
                    remaining = setdiff(1:obj.num_sites, mapping(mapping > 0));
                    if ~isscalar(remaining)
                        error("KSSOLV:Matgenlab:Structure:InterpolationAutosort", ...
                            "Unable to determine the unmatched endpoint site.");
                    end
                    mapping(ambiguous) = remaining;
                end
                endCoordinates = endCoordinates(mapping, :);
            end
            delta = endCoordinates - startCoordinates;
            if pbc, delta = delta - round(delta); end
            images = cell(1, numel(fractions));
            for index = 1:numel(fractions)
                fraction = fractions(index);
                latticeValue = obj.lattice;
                if interpolate_lattices
                    deformation = ending.lattice.matrix.' / ...
                        obj.lattice.matrix.';
                    [~, singularValues, right] = svd(deformation);
                    stretch = right * singularValues * right.';
                    latticeMatrix = ((eye(3) + fraction * end_amplitude * ...
                        (stretch - eye(3))) * obj.lattice.matrix.').';
                    latticeValue = kssolv.analysis.matgenlab.core.Lattice( ...
                        latticeMatrix, obj.lattice.pbc);
                elseif obj.lattice ~= ending.lattice
                    error("KSSOLV:Matgenlab:Structure:InterpolationLattice", ...
                        "Lattices differ and interpolate_lattices is false.");
                end
                images{index} = ...
                    kssolv.analysis.matgenlab.core.Structure( ...
                        latticeValue, obj.species_and_occu, ...
                            startCoordinates + ...
                        fraction * end_amplitude * delta, ...
                        site_properties = obj.site_properties, ...
                        labels = obj.labels, ...
                        properties = obj.structure_properties, ...
                        skip_checks = true);
                images{index}.explicit_charge_ = obj.explicit_charge_;
            end
        end

        function result = get_reduced_structure(obj, algorithm)
            if nargin < 2, algorithm = "niggli"; end
            switch lower(string(algorithm))
                case "niggli"
                    reducedLattice = ...
                        obj.lattice.get_niggli_reduced_lattice();
                case "lll"
                    reducedLattice = ...
                        obj.lattice.get_lll_reduced_lattice();
                otherwise
                    error("KSSOLV:Matgenlab:Structure:ReductionAlgorithm", ...
                        "Unknown reduction algorithm '%s'.", algorithm);
            end
            coordinates = ...
                reducedLattice.get_fractional_coords(obj.cart_coords);
            result = kssolv.analysis.matgenlab.core.Structure( ...
                reducedLattice, obj.species_and_occu, coordinates, ...
                to_unit_cell = true, ...
                site_properties = obj.site_properties, ...
                labels = obj.labels, properties = obj.structure_properties, ...
                skip_checks = true);
            result.explicit_charge_ = obj.explicit_charge_;
        end

        function structures = get_orderings(obj, mode, varargin)
            if nargin < 2 || strlength(string(mode)) == 0, mode = "enum"; end
            if obj.is_ordered
                structures = {kssolv.analysis.matgenlab.core.Structure. ...
                    from_sites(obj.sites, charge = obj.explicit_charge_, ...
                    properties = obj.structure_properties)};
                return
            end
            options = struct("runner", [], "deduplicate", true);
            passthrough = {};
            for index = 1:2:numel(varargin)
                if index == numel(varargin)
                    error("KSSOLV:Matgenlab:Structure:InvalidArguments", ...
                        "Ordering options must be name-value pairs.");
                end
                name = char(lower(string(varargin{index})));
                if isfield(options, name)
                    options.(name) = varargin{index + 1};
                else
                    passthrough(end + 1:end + 2) = ...
                        varargin(index:index + 1);
                end
            end
            if ~isempty(options.runner)
                if ~isa(options.runner, "function_handle")
                    error("KSSOLV:Matgenlab:Structure:OrderingRunner", ...
                        "runner must be a MATLAB function handle.");
                end
                structures = options.runner(obj, mode, passthrough{:});
                return
            end
            if ~startsWith(lower(string(mode)), "enum")
                error("KSSOLV:Matgenlab:External:McsqsRequired", ...
                    "SQS generation requires an explicit mcsqs adapter " + ...
                    "through the runner option.");
            end
            structures = nativeSameCellOrderings(obj);
            if isempty(structures)
                error("KSSOLV:Matgenlab:External:EnumlibRequired", ...
                    "The occupancies require a supercell; supply an " + ...
                    "enumlib-compatible MATLAB runner.");
            end
            if options.deduplicate && numel(structures) > 1
                matcher = kssolv.analysis.matgenlab.core.StructureMatcher();
                groups = matcher.group_structures(structures);
                structures = cellfun(@(group) group{1}, groups, ...
                    "UniformOutput", false);
            end
        end

        function obj = unset_charge(obj)
            obj.explicit_charge_ = NaN;
        end

        function miller = get_miller_index_from_site_indexes(obj, ...
                site_ids, round_dp, verbose)
            if nargin < 3, round_dp = 4; end
            if nargin < 4, verbose = true; end
            site_ids = reshape(double(site_ids), 1, []);
            arrayfun(@(index) obj.validateSiteIndex(index), site_ids);
            miller = obj.lattice.get_miller_index_from_coords( ...
                obj.frac_coords(site_ids, :), ...
                coords_are_cartesian = false, round_dp = round_dp, ...
                verbose = verbose);
        end

        function value = as_dataframe(obj)
            species = cell(obj.num_sites, 1);
            for index = 1:obj.num_sites
                species{index} = obj.sites_{index}.species;
            end
            fractional = obj.frac_coords;
            cartesian = obj.cart_coords;
            value = table(species, fractional(:, 1), fractional(:, 2), ...
                fractional(:, 3), cartesian(:, 1), cartesian(:, 2), ...
                cartesian(:, 3), VariableNames = ...
                ["Species", "a", "b", "c", "x", "y", "z"]);
            propertyNames = fieldnames(obj.site_properties);
            for propertyIndex = 1:numel(propertyNames)
                name = propertyNames{propertyIndex};
                entries = obj.site_properties.(name);
                value.(name) = reshape(entries, [], 1);
            end
            value.Properties.Description = ...
                "Reduced Formula: " + obj.reduced_formula;
            value.Properties.UserData = struct("Lattice", obj.lattice);
        end

        function value = as_dict(obj, verbosity, format)
            if nargin < 2, verbosity = 1; end
            if nargin < 3, format = ""; end
            if lower(string(format)) == "abivars"
                value = kssolv.analysis.matgenlab.io.abinit. ...
                    structure_to_abivars(obj);
                return
            end
            siteData = cellfun(@(site) site.as_dict(verbosity), obj.sites_, ...
                "UniformOutput", false);
            value = struct( ...
                "x_module", "pymatgen.core.structure", ...
                "x_class", className(obj), ...
                "charge", obj.charge, ...
                "lattice", obj.lattice.as_dict(verbosity), ...
                "properties", obj.structure_properties, ...
                "sites", {siteData});

            function value = className(input)
                parts = split(string(class(input)), ".");
                value = parts(end);
            end
        end

        function value = asDict(obj, varargin), value = obj.as_dict(varargin{:}); end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") && ...
                    isscalar(reference(1).subs)
                indices = reference(1).subs{1};
                if isscalar(indices)
                    value = obj.get_site(indices);
                else
                    value = obj.sites_(indices);
                end
                if numel(reference) > 1
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
            elseif strcmp(reference(1).type, ".") && ...
                    strcmp(reference(1).subs, "properties")
                value = obj.structure_properties;
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
                properties = obj.structure_properties;
                if isscalar(reference)
                    properties = value;
                else
                    properties = builtin( ...
                        "subsasgn", properties, reference(2:end), value);
                end
                if ~isstruct(properties) || ~isscalar(properties)
                    error("KSSOLV:Matgenlab:Structure:PropertiesType", ...
                        "properties must be a scalar struct.");
                end
                obj.structure_properties = properties;
            elseif isa(obj, "kssolv.analysis.matgenlab.core.Structure") && ...
                    strcmp(reference(1).type, ".") && ...
                    strcmp(reference(1).subs, "lattice")
                if ~isscalar(reference)
                    error("KSSOLV:Matgenlab:Structure:LatticeAssignment", ...
                        "Assign a complete Lattice or 3-by-3 matrix.");
                end
                if ~isa(value, "kssolv.analysis.matgenlab.core.Lattice")
                    value = kssolv.analysis.matgenlab.core.Lattice(value);
                end
                obj = builtin("subsasgn", obj, reference, value);
                for siteIndex = 1:obj.num_sites
                    site = obj.sites_{siteIndex};
                    site.lattice = value;
                    obj.sites_{siteIndex} = site;
                end
            else
                obj = builtin("subsasgn", obj, reference, value);
            end
        end

        function tf = eq(obj, other)
            if ~isa(other, class(obj)) || obj.lattice ~= other.lattice || ...
                    obj.num_sites ~= other.num_sites
                tf = false;
                return
            end
            tf = true;
            for index = 1:obj.num_sites
                if obj.sites_{index} ~= other.sites_{index}
                    tf = false;
                    return
                end
            end
        end

        function tf = ne(obj, other), tf = ~eq(obj, other); end
    end

    methods (Static)
        function obj = from_magnetic_spacegroup(msg, lattice, species, ...
                coords, siteProperties, varargin)
            options = struct("coords_are_cartesian", false, ...
                "tol", 1e-5, "labels", []);
            for index = 1:2:numel(varargin)
                if index == numel(varargin)
                    error("KSSOLV:Matgenlab:Structure:InvalidArguments", ...
                        "Name-value arguments must occur in pairs.");
                end
                name = char(lower(string(varargin{index})));
                if ~isfield(options, name)
                    error("KSSOLV:Matgenlab:Structure:InvalidOption", ...
                        "Unknown magnetic space-group option '%s'.", name);
                end
                options.(name) = varargin{index + 1};
            end
            if ~isfield(siteProperties, "magmom")
                error("KSSOLV:Matgenlab:Structure:MissingMagmom", ...
                    "Magnetic moments have to be defined.");
            end
            if ischar(msg) || isstring(msg) || isnumeric(msg)
                error("KSSOLV:Matgenlab:External:MagneticSpaceGroup", ...
                    "Pass a MagneticSpaceGroup-compatible MATLAB object; " + ...
                    "the magnetic database adapter is not available.");
            end
            if ~isa(lattice, "kssolv.analysis.matgenlab.core.Lattice")
                lattice = kssolv.analysis.matgenlab.core.Lattice(lattice);
            end
            if ismethod(msg, "is_compatible") && ...
                    ~msg.is_compatible(lattice)
                error("KSSOLV:Matgenlab:Structure:IncompatibleSpaceGroup", ...
                    "The supplied lattice is incompatible with the magnetic group.");
            end
            species = kssolv.analysis.matgenlab.core.IStructure. ...
                normalizeSequence(species);
            coords = double(coords);
            if options.coords_are_cartesian
                coords = lattice.get_fractional_coords(coords);
            end
            moments = siteProperties.magmom;
            if numel(species) ~= size(coords, 1) || ...
                    numel(moments) ~= numel(species)
                error("KSSOLV:Matgenlab:Structure:Shape", ...
                    "species, coordinates, and magnetic moments must match.");
            end
            labels = options.labels;
            if isempty(labels), labels = repmat(missing, numel(species), 1); end
            labels = reshape(string(labels), [], 1);
            propertyNames = fieldnames(siteProperties);
            allSpecies = cell(1, 0);
            allCoordinates = zeros(0, 3);
            allLabels = strings(0, 1);
            allProperties = struct();
            for propertyIndex = 1:numel(propertyNames)
                allProperties.(propertyNames{propertyIndex}) = cell(1, 0);
            end
            for siteIndex = 1:numel(species)
                moment = kssolv.analysis.matgenlab.electronic_structure. ...
                    Magmom(valueAt(moments, siteIndex));
                if isa(msg, ...
                        "kssolv.analysis.matgenlab.symmetry.groups.SpaceGroup")
                    orbit = msg.get_orbit( ...
                        coords(siteIndex, :), options.tol);
                    orbitMoments = repmat({moment}, size(orbit, 1), 1);
                else
                    try
                    [orbit, orbitMoments] = msg.get_orbit( ...
                        coords(siteIndex, :), moment, options.tol);
                    catch exception
                        rethrow(exception)
                    end
                end
                count = size(orbit, 1);
                allSpecies = [allSpecies, ...
                    repmat(species(siteIndex), 1, count)]; %#ok<AGROW>
                allCoordinates = [allCoordinates; orbit]; %#ok<AGROW>
                allLabels = [allLabels; ...
                    repmat(labels(siteIndex), count, 1)]; %#ok<AGROW>
                for propertyIndex = 1:numel(propertyNames)
                    name = propertyNames{propertyIndex};
                    if strcmp(name, "magmom")
                        if ~iscell(orbitMoments)
                            orbitMoments = num2cell(orbitMoments);
                        end
                        allProperties.(name) = [allProperties.(name), ...
                            reshape(orbitMoments, 1, [])];
                    else
                        value = valueAt(siteProperties.(name), siteIndex);
                        allProperties.(name) = [allProperties.(name), ...
                            repmat({value}, 1, count)];
                    end
                end
            end
            obj = kssolv.analysis.matgenlab.core.IStructure( ...
                lattice, allSpecies, allCoordinates, ...
                site_properties = allProperties, labels = allLabels);
        end

        function obj = from_id(identifier, source, varargin)
            if nargin < 2 || strlength(string(source)) == 0
                source = "Materials Project";
            end
            fetcher = [];
            for index = 1:2:numel(varargin)
                if index == numel(varargin)
                    error("KSSOLV:Matgenlab:Structure:InvalidArguments", ...
                        "from_id options must be name-value pairs.");
                end
                if lower(string(varargin{index})) == "fetcher"
                    fetcher = varargin{index + 1};
                end
            end
            if isempty(fetcher)
                error("KSSOLV:Matgenlab:External:StructureFetcher", ...
                    "Fetching '%s' from %s requires an explicit authenticated " + ...
                    "MATLAB fetcher function.", string(identifier), string(source));
            end
            if ~isa(fetcher, "function_handle")
                error("KSSOLV:Matgenlab:Structure:FetcherType", ...
                    "fetcher must be a MATLAB function handle.");
            end
            obj = fetcher(identifier, source);
            if ~isa(obj, "kssolv.analysis.matgenlab.core.IStructure")
                error("KSSOLV:Matgenlab:Structure:FetcherResult", ...
                    "fetcher must return an IStructure or Structure.");
            end
        end

        function obj = from_spacegroup(sg, lattice, species, coords, varargin)
            options = struct("site_properties", struct(), ...
                "coords_are_cartesian", false, "tol", 1e-5, "labels", []);
            for index = 1:2:numel(varargin)
                if index + 1 > numel(varargin)
                    error("KSSOLV:Matgenlab:Structure:InvalidArguments", ...
                        "Name-value arguments must occur in pairs.");
                end
                name = char(lower(string(varargin{index})));
                if ~isfield(options, name)
                    error("KSSOLV:Matgenlab:Structure:InvalidOption", ...
                        "Unknown from_spacegroup option '%s'.", name);
                end
                options.(name) = varargin{index + 1};
            end
            if ~isa(lattice, "kssolv.analysis.matgenlab.core.Lattice")
                lattice = kssolv.analysis.matgenlab.core.Lattice(lattice);
            end
            if isnumeric(sg)
                group = ...
                    kssolv.analysis.matgenlab.symmetry.groups. ...
                    SpaceGroup.from_int_number(sg);
            else
                group = ...
                    kssolv.analysis.matgenlab.symmetry.groups. ...
                    SpaceGroup(string(sg));
            end
            if ~group.is_compatible(lattice)
                error("KSSOLV:Matgenlab:Structure:IncompatibleSpaceGroup", ...
                    "The supplied lattice is incompatible with space group %s.", ...
                    group.symbol);
            end
            species = ...
                kssolv.analysis.matgenlab.core.IStructure. ...
                normalizeSequence(species);
            coords = double(coords);
            if numel(species) ~= size(coords, 1)
                error("KSSOLV:Matgenlab:Structure:Shape", ...
                    "Supplied species and coords lengths are different.");
            end
            if options.coords_are_cartesian
                coords = lattice.get_fractional_coords(coords);
            end
            labels = options.labels;
            if isempty(labels), labels = repmat(missing, numel(species), 1);
            else, labels = reshape(string(labels), [], 1);
            end
            propertyNames = fieldnames(options.site_properties);
            allSpecies = cell(1, 0);
            allCoordinates = zeros(0, 3);
            allLabels = strings(0, 1);
            allProperties = struct();
            for propertyIndex = 1:numel(propertyNames)
                allProperties.(propertyNames{propertyIndex}) = cell(1, 0);
            end
            for siteIndex = 1:numel(species)
                orbit = group.get_orbit(coords(siteIndex, :), options.tol);
                count = size(orbit, 1);
                allSpecies = [allSpecies, ...
                    repmat(species(siteIndex), 1, count)]; %#ok<AGROW>
                allCoordinates = [allCoordinates; orbit]; %#ok<AGROW>
                allLabels = [allLabels; ...
                    repmat(labels(siteIndex), count, 1)]; %#ok<AGROW>
                for propertyIndex = 1:numel(propertyNames)
                    name = propertyNames{propertyIndex};
                    values = options.site_properties.(name);
                    if iscell(values), value = values{siteIndex};
                    elseif isvector(values), value = values(siteIndex);
                    else, value = values(siteIndex, :);
                    end
                    allProperties.(name) = [allProperties.(name), ...
                        repmat({value}, 1, count)];
                end
            end
            obj = kssolv.analysis.matgenlab.core.IStructure( ...
                lattice, allSpecies, allCoordinates, ...
                site_properties=allProperties, labels=allLabels);
        end

        function obj = from_sites(sites, options)
            arguments
                sites cell
                options.charge (1,1) double = NaN
                options.properties (1,1) struct = struct()
                options.to_unit_cell (1,1) logical = false
                options.validate_proximity (1,1) logical = false
            end
            sites=reshape(sites,1,[]);
            if isempty(sites)
                error("KSSOLV:Matgenlab:Structure:EmptySites", ...
                    "You need at least one site to construct a Structure.");
            end
            lattice = sites{1}.lattice;
            species = cellfun(@(site) site.species, sites, ...
                "UniformOutput", false);
            coordinates = cell2mat(cellfun(@(site) site.frac_coords, sites, ...
                "UniformOutput", false).');
            labels = cellfun(@(site) site.label, sites, "UniformOutput", false);
            names = strings(0, 1);
            for index = 1:numel(sites)
                names = [names; string(fieldnames(sites{index}.site_properties))]; %#ok<AGROW>
            end
            names = unique(names);
            siteProperties = struct();
            for nameIndex = 1:numel(names)
                name = char(names(nameIndex));
                values = cell(1, numel(sites));
                for index = 1:numel(sites)
                    if isfield(sites{index}.site_properties, name)
                        values{index} = sites{index}.site_properties.(name);
                    else
                        values{index} = [];
                    end
                end
                siteProperties.(name) = values;
            end
            obj = kssolv.analysis.matgenlab.core.IStructure( ...
                lattice, species, coordinates, ...
                to_unit_cell = options.to_unit_cell, ...
                validate_proximity = options.validate_proximity, ...
                site_properties = siteProperties, labels = labels, ...
                properties = options.properties, charge = options.charge);
        end

        function obj = from_dict(value, format)
            if nargin >= 2 && lower(string(format)) == "abivars"
                obj = kssolv.analysis.matgenlab.io.abinit. ...
                    structure_from_abivars(value);
                return
            end
            if isa(value.lattice,"kssolv.analysis.matgenlab.core.Lattice")
                lattice=value.lattice;
            else
                lattice = ...
                    kssolv.analysis.matgenlab.core.Lattice.from_dict(value.lattice);
            end
            sites = value.sites;
            if isstruct(sites), sites = reshape(num2cell(sites), 1, []); end
            if ~iscell(sites),sites={sites};end
            sites=reshape(sites,1,[]);
            siteObjects=cell(size(sites));
            for index=1:numel(sites)
                if isa(sites{index}, ...
                        "kssolv.analysis.matgenlab.core.PeriodicSite")
                    siteObjects{index}=sites{index};
                else
                    siteObjects{index}= ...
                        kssolv.analysis.matgenlab.core.PeriodicSite. ...
                        from_dict(sites{index},lattice);
                end
            end
            properties = struct();
            if isfield(value, "properties") && ~isempty(value.properties)
                properties = value.properties;
            end
            charge = fieldValue(value, "charge", NaN);
            if isempty(charge), charge = NaN; end
            obj = kssolv.analysis.matgenlab.core.IStructure.from_sites( ...
                siteObjects, charge = charge, ...
                properties = properties);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core.IStructure.from_dict(value);
        end
    end

    methods (Static, Access = protected)
        function value = normalizeSequence(input)
            if iscell(input)
                value = reshape(input, 1, []);
            elseif isstring(input)
                value = num2cell(reshape(input, 1, []));
            elseif ischar(input)
                value = {input};
            elseif isobject(input) && ~isscalar(input)
                value = num2cell(input);
            else
                value = {input};
            end
        end
    end
end

function structures = nativeSameCellOrderings(structure)
choices = cell(1, structure.num_sites);
targetKeys = strings(1, 0);
targetCounts = zeros(1, 0);
for siteIndex = 1:structure.num_sites
    [siteSpecies, occupancies] = structure.sites{siteIndex}.species.items();
    choices{siteIndex} = siteSpecies(occupancies > 0);
    for speciesIndex = 1:numel(siteSpecies)
        key = string(siteSpecies{speciesIndex});
        position = find(targetKeys == key, 1);
        if isempty(position)
            targetKeys(end + 1) = key; %#ok<AGROW>
            targetCounts(end + 1) = occupancies(speciesIndex); %#ok<AGROW>
        else
            targetCounts(position) = targetCounts(position) + ...
                occupancies(speciesIndex);
        end
    end
end
roundedTargets = round(targetCounts);
if any(abs(targetCounts - roundedTargets) > 1e-8)
    structures = cell(1, 0);
    return
end
selected = cell(1, structure.num_sites);
running = zeros(size(targetKeys));
structures = cell(1, 0);
enumerate(1);

    function enumerate(siteIndex)
        if siteIndex > structure.num_sites
            if any(running ~= roundedTargets), return; end
            candidate = kssolv.analysis.matgenlab.core.Structure( ...
                structure.lattice, selected, structure.frac_coords, ...
                charge = structure.charge, ...
                site_properties = structure.site_properties, ...
                labels = structure.labels, ...
                properties = structure.structure_properties);
            structures{end + 1} = candidate;
            return
        end
        for choiceIndex = 1:numel(choices{siteIndex})
            specie = choices{siteIndex}{choiceIndex};
            position = find(targetKeys == string(specie), 1);
            if running(position) >= roundedTargets(position), continue; end
            selected{siteIndex} = specie;
            running(position) = running(position) + 1;
            enumerate(siteIndex + 1);
            running(position) = running(position) - 1;
        end
    end
end

function value = valueAt(values, index)
if iscell(values)
    value = values{index};
elseif isvector(values)
    value = values(index);
else
    value = values(index, :);
end
end

function tf = latticeConstraintsSatisfied(candidate, original, constraints)
if isstruct(constraints)
    names = fieldnames(constraints);
    expected = zeros(1, numel(names));
    for index = 1:numel(names)
        expected(index) = constraints.(names{index});
    end
else
    names = cellstr(string(constraints));
    expected = zeros(1, numel(names));
    for index = 1:numel(names)
        expected(index) = latticeParameter(original, names{index});
    end
end
actual = zeros(size(expected));
for index = 1:numel(names)
    actual(index) = latticeParameter(candidate, names{index});
end
tf = all(abs(actual - expected) <= ...
    1e-8 + 1e-5 * abs(expected));
end

function value = latticeParameter(lattice, name)
name = lower(string(name));
switch name
    case "a", value = lattice.lengths(1);
    case "b", value = lattice.lengths(2);
    case "c", value = lattice.lengths(3);
    case "alpha", value = lattice.angles(1);
    case "beta", value = lattice.angles(2);
    case "gamma", value = lattice.angles(3);
    case "volume", value = lattice.volume;
    otherwise
        error("KSSOLV:Matgenlab:Structure:LatticeConstraint", ...
            "Unknown lattice constraint '%s'.", name);
end
end

function value = fieldValue(data, name, defaultValue)
if isfield(data, name)
    value = data.(name);
else
    value = defaultValue;
end
end

function matcher = structureMatcherFromOptions(varargin)
options = struct( ...
    "ltol", 0.2, "stol", 0.3, "angle_tol", 5, ...
    "primitive_cell", true, "scale", true, ...
    "attempt_supercell", false, "allow_subset", false, ...
    "comparator", [], "supercell_size", "num_sites", ...
    "ignored_species", strings(1, 0));
for index = 1:2:numel(varargin)
    if index == numel(varargin)
        error("KSSOLV:Matgenlab:Structure:InvalidArguments", ...
            "Structure matcher options must be name-value pairs.");
    end
    name = char(lower(string(varargin{index})));
    if ~isfield(options, name)
        error("KSSOLV:Matgenlab:Structure:InvalidOption", ...
            "Unknown structure matcher option '%s'.", name);
    end
    options.(name) = varargin{index + 1};
end
matcher = kssolv.analysis.matgenlab.core.StructureMatcher( ...
    options.ltol, options.stol, options.angle_tol, ...
    options.primitive_cell, options.scale, options.attempt_supercell, ...
    options.allow_subset, options.comparator, options.supercell_size, ...
    options.ignored_species);
end
