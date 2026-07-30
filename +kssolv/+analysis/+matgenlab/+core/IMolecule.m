classdef IMolecule < kssolv.analysis.matgenlab.core.SiteCollection & ...
        kssolv.analysis.matgenlab.util.MSONable
    %IMOLECULE Non-periodic molecular site collection.

    properties (SetAccess = protected)
        spin_multiplicity (1,1) double = 1
        molecule_properties (1,1) struct = struct()
        charge_spin_check_ (1,1) logical = true
    end

    properties (Dependent, SetAccess = private)
        nelectrons
        center_of_mass
    end

    methods
        function obj = IMolecule(species, coords, options)
            arguments
                species
                coords
                options.charge (1,1) double = 0
                options.spin_multiplicity = []
                options.validate_proximity (1,1) logical = false
                options.site_properties (1,1) struct = struct()
                options.labels = []
                options.charge_spin_check (1,1) logical = true
                options.properties (1,1) struct = struct()
            end
            obj@kssolv.analysis.matgenlab.core.SiteCollection();
            species = obj.normalizeSequence(species);
            if ~isnumeric(coords) || size(coords, 2) ~= 3 || ...
                    size(coords, 1) ~= numel(species)
                error("KSSOLV:Matgenlab:Molecule:Shape", ...
                    "Species and coordinates must contain the same number of sites.");
            end
            obj.explicit_charge_ = options.charge;
            obj.molecule_properties = options.properties;
            obj.charge_spin_check_ = options.charge_spin_check;
            labels = options.labels;
            if isempty(labels), labels = repmat(missing, numel(species), 1);
            else, labels = reshape(string(labels), [], 1);
            end
            if numel(labels) ~= numel(species)
                error("KSSOLV:Matgenlab:Molecule:LabelLength", ...
                    "labels must contain one value per site.");
            end
            propertyNames = fieldnames(options.site_properties);
            obj.sites_ = cell(1, numel(species));
            for index = 1:numel(species)
                siteProperties = struct();
                for propertyIndex = 1:numel(propertyNames)
                    name = propertyNames{propertyIndex};
                    values = options.site_properties.(name);
                    if numel(values) ~= numel(species)
                        error("KSSOLV:Matgenlab:Molecule:PropertyLength", ...
                            "Site property '%s' requires one value per site.", name);
                    end
                    if iscell(values), siteProperties.(name) = values{index};
                    elseif isvector(values), siteProperties.(name) = values(index);
                    else, siteProperties.(name) = values(index, :);
                    end
                end
                obj.sites_{index} = kssolv.analysis.matgenlab.core.Site( ...
                    species{index}, coords(index, :), ...
                    properties = siteProperties, label = labels(index));
            end
            if options.validate_proximity && ~obj.is_valid(0.5)
                error("KSSOLV:Matgenlab:Molecule:Proximity", ...
                    "Molecule contains sites less than 0.5 angstrom apart.");
            end

            electrons = 0;
            for siteIndex = 1:numel(obj.sites_)
                [siteSpecies, amounts] = obj.sites_{siteIndex}.species.items();
                electrons = electrons + sum(cellfun(@(item) ...
                    item.Z, siteSpecies) .* amounts);
            end
            electrons = electrons - options.charge;
            if isempty(options.spin_multiplicity)
                obj.spin_multiplicity = mod(round(electrons), 2) + 1;
            else
                obj.spin_multiplicity = double(options.spin_multiplicity);
            end
            if options.charge_spin_check && ...
                    mod(round(electrons), 2) == mod(round(obj.spin_multiplicity), 2)
                error("KSSOLV:Matgenlab:Molecule:ChargeSpin", ...
                    "Charge and spin multiplicity are not possible for this molecule.");
            end
        end

        function value = get.nelectrons(obj)
            value = 0;
            for siteIndex = 1:obj.num_sites
                [siteSpecies, amounts] = obj.sites_{siteIndex}.species.items();
                value = value + sum(cellfun(@(item) ...
                    item.Z, siteSpecies) .* amounts);
            end
            value = value - obj.charge;
        end

        function value = get.center_of_mass(obj)
            masses = zeros(obj.num_sites, 1);
            for index = 1:obj.num_sites
                masses(index) = obj.sites_{index}.species.weight;
            end
            value = sum(obj.cart_coords .* masses, 1) / sum(masses);
        end

        function neighbors = get_sites_in_sphere(obj, point, radius)
            point = reshape(double(point), 1, 3);
            neighbors = cell(1, 0);
            for index = 1:obj.num_sites
                distance = norm(obj.sites_{index}.coords - point);
                if distance <= radius
                    neighbors{end + 1} = ...
                        kssolv.analysis.matgenlab.core.Neighbor( ...
                            obj.sites_{index}.species, ...
                            obj.sites_{index}.coords, distance, index, ...
                            properties = obj.sites_{index}.site_properties, ...
                            label = obj.sites_{index}.label); %#ok<AGROW>
                end
            end
            if ~isempty(neighbors)
                [~, order] = sort(cellfun(@(item) item.nn_distance, neighbors));
                neighbors = neighbors(order);
            end
        end

        function neighbors = get_neighbors(obj, site, radius)
            neighbors = obj.get_sites_in_sphere(site.coords, radius);
            neighbors = neighbors(cellfun(@(item) ...
                item.nn_distance > 1e-12, neighbors));
        end

        function neighbors = get_neighbors_in_shell(obj, origin, radius, width)
            values = obj.get_sites_in_sphere(origin, radius + width);
            neighbors = values(cellfun(@(item) ...
                item.nn_distance >= radius - width, values));
        end

        function result = get_centered_molecule(obj)
            shift = -obj.center_of_mass;
            result = kssolv.analysis.matgenlab.core.Molecule.from_sites(obj.sites_);
            result = result.translate_sites(1:result.num_sites, shift);
        end

        function structure = get_boxed_structure(obj, a, b, c, options)
            arguments
                obj
                a (1,1) double {mustBePositive}
                b (1,1) double {mustBePositive}
                c (1,1) double {mustBePositive}
                options.images = [1, 1, 1]
                options.random_rotation (1,1) logical = false
                options.min_dist (1,1) double {mustBeNonnegative} = 1
                options.cls = []
                options.offset = [0, 0, 0]
                options.no_cross (1,1) logical = false
                options.reorder (1,1) logical = true
            end
            images = reshape(double(options.images), 1, 3);
            if any(images < 1) || any(images ~= fix(images))
                error("KSSOLV:Matgenlab:Molecule:Images", ...
                    "images must contain three positive integers.");
            end
            lattice = kssolv.analysis.matgenlab.core.Lattice. ...
                orthorhombic(a * images(1), b * images(2), c * images(3));
            speciesValues = cell(1, 0);
            coordinates = zeros(0, 3);
            sourceIndices = zeros(1, 0);
            offset = reshape(double(options.offset), 1, 3);
            moleculeCoordinates = obj.cart_coords - obj.center_of_mass;
            extent = max(obj.cart_coords, [], 1) - ...
                min(obj.cart_coords, [], 1);
            if any(extent >= [a, b, c])
                error("KSSOLV:Matgenlab:Molecule:BoxTooSmall", ...
                    "Molecule does not fit inside the requested box.");
            end
            for ix = 0:images(1)-1
                for iy = 0:images(2)-1
                    for iz = 0:images(3)-1
                        boxCenter = ([ix, iy, iz] + 0.5) .* ...
                            [a, b, c] + offset;
                        candidate = moleculeCoordinates + boxCenter;
                        if options.random_rotation
                            accepted = false;
                            for attempt = 1:1000
                                axis = rand(1, 3);
                                axis = axis / norm(axis);
                                theta = deg2rad(-180 + 360 * rand());
                                skew = [ ...
                                    0, -axis(3), axis(2); ...
                                    axis(3), 0, -axis(1); ...
                                    -axis(2), axis(1), 0];
                                rotation = eye(3) + sin(theta) * skew + ...
                                    (1 - cos(theta)) * (skew * skew);
                                trial = moleculeCoordinates * rotation.' + ...
                                    boxCenter;
                                if options.no_cross && ...
                                        any(trial < 0, "all") || ...
                                        options.no_cross && ...
                                        any(trial > lattice.lengths, "all")
                                    error("KSSOLV:Matgenlab:Molecule:BoxCrossing", ...
                                        "Molecule crosses the boundary of the box.");
                                end
                                if isempty(coordinates)
                                    accepted = true;
                                else
                                    distances = lattice.get_all_distances( ...
                                        lattice.get_fractional_coords(trial), ...
                                        lattice.get_fractional_coords(coordinates));
                                    accepted = min(distances, [], "all") > ...
                                        options.min_dist;
                                end
                                if accepted
                                    candidate = trial;
                                    break
                                end
                            end
                            if ~accepted
                                error("KSSOLV:Matgenlab:Molecule:BoxPacking", ...
                                    "Unable to place a non-overlapping rotated image.");
                            end
                        elseif options.no_cross && ...
                                (any(candidate < 0, "all") || ...
                                any(candidate > lattice.lengths, "all"))
                            error("KSSOLV:Matgenlab:Molecule:BoxCrossing", ...
                                "Molecule crosses the boundary of the box.");
                        end
                        for siteIndex = 1:obj.num_sites
                            speciesValues{end + 1} = ...
                                obj.sites_{siteIndex}.species; %#ok<AGROW>
                            coordinates(end + 1, :) = ...
                                candidate(siteIndex, :); %#ok<AGROW>
                            sourceIndices(end + 1) = siteIndex; %#ok<AGROW>
                        end
                    end
                end
            end
            siteProperties = struct();
            propertyNames = fieldnames(obj.site_properties);
            for propertyIndex = 1:numel(propertyNames)
                name = propertyNames{propertyIndex};
                values = obj.site_properties.(name);
                siteProperties.(name) = values(sourceIndices);
            end
            labels = obj.labels(sourceIndices);
            constructor = options.cls;
            if isempty(constructor)
                constructor = @kssolv.analysis.matgenlab.core.Structure;
            elseif ischar(constructor) || isstring(constructor)
                constructor = str2func(char(constructor));
            end
            if ~isa(constructor, "function_handle")
                error("KSSOLV:Matgenlab:Molecule:BoxClass", ...
                    "cls must be a structure constructor or function handle.");
            end
            structure = constructor(lattice, speciesValues, coordinates, ...
                coords_are_cartesian = true, ...
                site_properties = siteProperties, labels = labels);
            if options.reorder
                structure = structure.get_sorted_structure();
            end
        end

        function result = copy(obj)
            if isa(obj, "kssolv.analysis.matgenlab.core.Molecule")
                result = kssolv.analysis.matgenlab.core.Molecule.from_sites( ...
                    obj.sites_, charge = obj.charge, ...
                    spin_multiplicity = obj.spin_multiplicity, ...
                    charge_spin_check = obj.charge_spin_check_, ...
                    properties = obj.molecule_properties);
            else
                result = kssolv.analysis.matgenlab.core.IMolecule.from_sites( ...
                    obj.sites_, charge = obj.charge, ...
                    spin_multiplicity = obj.spin_multiplicity, ...
                    charge_spin_check = obj.charge_spin_check_, ...
                    properties = obj.molecule_properties);
            end
        end

        function bonds = get_covalent_bonds(obj, tol)
            if nargin < 2, tol = 0.2; end
            pairs = obj.get_covalent_bond_pairs(tol);
            bonds = cell(1, size(pairs, 1));
            for index = 1:size(pairs, 1)
                bonds{index} = kssolv.analysis.matgenlab.core. ...
                    CovalentBond(obj.sites_{pairs(index, 1)}, ...
                    obj.sites_{pairs(index, 2)});
            end
        end

        function pairs = get_covalent_bond_pairs(obj, tol)
            %GET_COVALENT_BOND_PAIRS Return one-based bonded site pairs.
            %
            % A spatial hash limits exact CovalentBond checks to nearby
            % atoms. The result remains lexicographically ordered like the
            % former all-pairs implementation.
            if nargin < 2, tol = 0.2; end
            if obj.num_sites < 2
                pairs = zeros(0, 2);
                return
            end
            [candidates, bondData, coordinates, symbols] = ...
                covalentCandidates(obj, tol);
            if isempty(candidates)
                pairs = zeros(0, 2);
                return
            end
            thresholds = zeros(size(candidates, 1), 1);
            uniqueSymbols = unique(symbols);
            for first = 1:numel(uniqueSymbols)
                for second = first:numel(uniqueSymbols)
                    firstSymbol = uniqueSymbols(first);
                    secondSymbol = uniqueSymbols(second);
                    mask = (symbols(candidates(:, 1)) == firstSymbol & ...
                        symbols(candidates(:, 2)) == secondSymbol) | ...
                        (symbols(candidates(:, 1)) == secondSymbol & ...
                        symbols(candidates(:, 2)) == firstSymbol);
                    key = char(strjoin(sort( ...
                        [firstSymbol, secondSymbol]), "|"));
                    lengths = cell2mat(bondData(key).values);
                    thresholds(mask) = (1 + tol) * max(lengths);
                end
            end
            distances = vecnorm( ...
                coordinates(candidates(:, 1), :) - ...
                coordinates(candidates(:, 2), :), 2, 2);
            pairs = candidates(distances < thresholds, :);
        end

        function [firstMolecule, secondMolecule] = ...
                break_bond(obj, firstIndex, secondIndex, tol)
            if nargin < 4, tol = 0.2; end
            obj.validateSiteIndex(firstIndex);
            obj.validateSiteIndex(secondIndex);
            if firstIndex == secondIndex
                error("KSSOLV:Matgenlab:Molecule:BondIndices", ...
                    "Bond endpoints must be different sites.");
            end
            clusters = cell(1, 2);
            clusters{1} = obj.sites_(firstIndex);
            clusters{2} = obj.sites_(secondIndex);
            remaining = setdiff(1:obj.num_sites, ...
                [firstIndex, secondIndex], "stable");
            while ~isempty(remaining)
                unmatched = zeros(1, numel(remaining));
                unmatchedCount = 0;
                for siteIndex = remaining
                    placed = false;
                    for clusterIndex = 1:2
                        cluster = clusters{clusterIndex};
                        if any(cellfun(@(site) ...
                                localBonded(obj.sites_{siteIndex}, ...
                                site, tol), cluster))
                            clusters{clusterIndex}{end + 1} = ...
                                obj.sites_{siteIndex};
                            placed = true;
                            break
                        end
                    end
                    if ~placed
                        unmatchedCount = unmatchedCount + 1;
                        unmatched(unmatchedCount) = siteIndex;
                    end
                end
                unmatched = unmatched(1:unmatchedCount);
                if numel(unmatched) == numel(remaining)
                    error("KSSOLV:Matgenlab:Molecule:UnmatchedSites", ...
                        "Not all sites are matched after breaking the bond.");
                end
                remaining = unmatched;
            end
            if isa(obj, "kssolv.analysis.matgenlab.core.Molecule")
                firstMolecule = ...
                    kssolv.analysis.matgenlab.core.Molecule.from_sites( ...
                        clusters{1});
                secondMolecule = ...
                    kssolv.analysis.matgenlab.core.Molecule.from_sites( ...
                        clusters{2});
            else
                firstMolecule = ...
                    kssolv.analysis.matgenlab.core.IMolecule.from_sites( ...
                        clusters{1});
                secondMolecule = ...
                    kssolv.analysis.matgenlab.core.IMolecule.from_sites( ...
                        clusters{2});
            end

            function value = localBonded(first, second, tolerance)
                try
                    value = ...
                        kssolv.analysis.matgenlab.core.CovalentBond. ...
                            is_bonded(first, second, tolerance);
                catch exception
                    if strcmp(exception.identifier, ...
                            "KSSOLV:Matgenlab:Bonds:MissingData")
                        value = false;
                    else
                        rethrow(exception)
                    end
                end
            end
        end

        function output = get_zmatrix(obj)
            lines = strings(obj.num_sites, 1);
            variables = strings(0, 1);
            for index = 1:obj.num_sites
                symbol = string(obj.sites_{index}.specie);
                if index == 1
                    lines(index) = symbol;
                    continue
                end
                previous = 1:index-1;
                distances = arrayfun(@(other) ...
                    obj.get_distance(index, other), previous);
                [~, order] = sort(distances);
                nearest = previous(order);
                variableIndex = index - 1;
                bondLength = obj.get_distance(index, nearest(1));
                if index == 2
                    lines(index) = sprintf("%s %d B%d", ...
                        symbol, nearest(1), variableIndex);
                    variables(end + 1) = sprintf("B%d=%.6f", ...
                        variableIndex, bondLength); %#ok<AGROW>
                elseif index == 3
                    angle = obj.get_angle(index, nearest(1), nearest(2));
                    lines(index) = sprintf("%s %d B%d %d A%d", ...
                        symbol, nearest(1), variableIndex, ...
                        nearest(2), variableIndex);
                    variables(end + 1) = sprintf("B%d=%.6f", ...
                        variableIndex, bondLength); %#ok<AGROW>
                    variables(end + 1) = sprintf("A%d=%.6f", ...
                        variableIndex, angle); %#ok<AGROW>
                else
                    angle = obj.get_angle(index, nearest(1), nearest(2));
                    dihedral = obj.get_dihedral(index, nearest(1), ...
                        nearest(2), nearest(3));
                    lines(index) = sprintf( ...
                        "%s %d B%d %d A%d %d D%d", ...
                        symbol, nearest(1), variableIndex, ...
                        nearest(2), variableIndex, nearest(3), ...
                        variableIndex);
                    variables(end + 1) = sprintf("B%d=%.6f", ...
                        variableIndex, bondLength); %#ok<AGROW>
                    variables(end + 1) = sprintf("A%d=%.6f", ...
                        variableIndex, angle); %#ok<AGROW>
                    variables(end + 1) = sprintf("D%d=%.6f", ...
                        variableIndex, dihedral); %#ok<AGROW>
                end
            end
            output = strjoin(lines, newline) + newline + newline + ...
                strjoin(variables, newline);
        end

        function value = as_dict(obj)
            siteData = cellfun(@(site) site.as_dict(), obj.sites_, ...
                "UniformOutput", false);
            value = struct( ...
                "x_module", "pymatgen.core.structure", ...
                "x_class", className(obj), ...
                "charge", obj.charge, ...
                "spin_multiplicity", obj.spin_multiplicity, ...
                "properties", obj.molecule_properties, ...
                "sites", {siteData});

            function value = className(input)
                names = split(string(class(input)), ".");
                value = names(end);
            end
        end

        function value = asDict(obj), value = obj.as_dict(); end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") && ...
                    isscalar(reference(1).subs)
                indices = reference(1).subs{1};
                if isscalar(indices), value = obj.get_site(indices);
                else, value = obj.sites_(indices);
                end
                if numel(reference) > 1
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
            elseif strcmp(reference(1).type, ".") && ...
                    strcmp(reference(1).subs, "properties")
                value = obj.molecule_properties;
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
                properties = obj.molecule_properties;
                if isscalar(reference)
                    properties = value;
                else
                    properties = builtin( ...
                        "subsasgn", properties, reference(2:end), value);
                end
                if ~isstruct(properties) || ~isscalar(properties)
                    error("KSSOLV:Matgenlab:Molecule:PropertiesType", ...
                        "properties must be a scalar struct.");
                end
                obj.molecule_properties = properties;
            else
                obj = builtin("subsasgn", obj, reference, value);
            end
        end

        function tf = eq(obj, other)
            if ~isa(other, class(obj)) || obj.num_sites ~= other.num_sites || ...
                    obj.charge ~= other.charge || ...
                    obj.spin_multiplicity ~= other.spin_multiplicity
                tf = false;
                return
            end
            tf = true;
            for index = 1:obj.num_sites
                if obj.sites_{index} ~= other.sites_{index}
                    tf = false; return
                end
            end
        end

        function tf = ne(obj, other), tf = ~eq(obj, other); end
    end

    methods (Static)
        function obj = from_sites(sites, options)
            arguments
                sites cell
                options.charge (1,1) double = 0
                options.spin_multiplicity = []
                options.validate_proximity (1,1) logical = false
                options.charge_spin_check (1,1) logical = true
                options.properties (1,1) struct = struct()
            end
            sites=reshape(sites,1,[]);
            species = cellfun(@(site) site.species, sites, ...
                "UniformOutput", false);
            coordinates = cell2mat(cellfun(@(site) site.coords, sites, ...
                "UniformOutput", false).');
            labels = cellfun(@(site) site.label, sites, "UniformOutput", false);
            names = strings(1, 0);
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
            obj = kssolv.analysis.matgenlab.core.IMolecule( ...
                species, coordinates, charge = options.charge, ...
                spin_multiplicity = options.spin_multiplicity, ...
                validate_proximity = options.validate_proximity, ...
                charge_spin_check = options.charge_spin_check, ...
                site_properties = siteProperties, labels = labels, ...
                properties = options.properties);
        end

        function obj = from_dict(value)
            sites = value.sites;
            if isstruct(sites), sites = num2cell(sites); end
            if ~iscell(sites),sites={sites};end
            sites=reshape(sites,1,[]);
            siteObjects=cell(size(sites));
            for index=1:numel(sites)
                if isa(sites{index},"kssolv.analysis.matgenlab.core.Site")
                    siteObjects{index}=sites{index};
                else
                    siteObjects{index}= ...
                        kssolv.analysis.matgenlab.core.Site.from_dict( ...
                        sites{index});
                end
            end
            properties = struct();
            if isfield(value, "properties") && ~isempty(value.properties)
                properties = value.properties;
            end
            obj = kssolv.analysis.matgenlab.core.IMolecule.from_sites( ...
                siteObjects, charge = value.charge, ...
                spin_multiplicity = value.spin_multiplicity, ...
                properties = properties);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core.IMolecule.from_dict(value);
        end
    end

    methods (Static, Access = protected)
        function value = normalizeSequence(input)
            if isempty(input), value = cell(1, 0);
            elseif iscell(input), value = reshape(input, 1, []);
            elseif isstring(input), value = num2cell(reshape(input, 1, []));
            elseif ischar(input), value = {input};
            elseif isobject(input) && ~isscalar(input), value = num2cell(input);
            else, value = {input};
            end
        end
    end
end

function [pairs, data, coordinates, symbols] = ...
        covalentCandidates(molecule, tol)
data = kssolv.analysis.matgenlab.core.bond_lengths_data();
symbols = reshape(string(molecule.species), 1, []);
uniqueSymbols = unique(symbols);
maximumLength = 0;
for first = 1:numel(uniqueSymbols)
    for second = first:numel(uniqueSymbols)
        key = char(strjoin(sort( ...
            [uniqueSymbols(first), uniqueSymbols(second)]), "|"));
        if ~isKey(data, key)
            error("KSSOLV:Matgenlab:Bonds:MissingData", ...
                "No bond data for elements %s - %s", ...
                uniqueSymbols(first), uniqueSymbols(second));
        end
        lengths = cell2mat(data(key).values);
        maximumLength = max(maximumLength, max(lengths));
    end
end
bucketWidth = max((1 + tol) * maximumLength, eps);
coordinates = molecule.cart_coords;
origin = min(coordinates, [], 1);
cells = floor((coordinates - origin) ./ bucketWidth);
dimensions = max(cells, [], 1) + 1;
linearKeys = cells(:, 1) + dimensions(1) .* ...
    (cells(:, 2) + dimensions(2) .* cells(:, 3));
[uniqueKeys, firstIndices, groups] = unique(linearKeys, "sorted");
uniqueCells = cells(firstIndices, :);
members = accumarray(groups, (1:molecule.num_sites).', [], @(value) {value});
groupCounts = accumarray(groups, 1);
offsets = halfCellOffsets();
chunks = cell(size(offsets, 1), 1);
for offsetIndex = 1:size(offsets, 1)
    offset = offsets(offsetIndex, :);
    targetCells = uniqueCells + offset;
    valid = all(targetCells >= 0 & targetCells < dimensions, 2);
    targetKeys = targetCells(:, 1) + dimensions(1) .* ...
        (targetCells(:, 2) + dimensions(2) .* targetCells(:, 3));
    [found, targetGroups] = ismember(targetKeys, uniqueKeys);
    found = found & valid;
    sourceGroups = find(found);
    targets = targetGroups(sourceGroups);
    rows = cell(1, 0);
    if any(offset ~= 0)
        simple = groupCounts(sourceGroups) == 1 & ...
            groupCounts(targets) == 1;
        if any(simple)
            rows{end + 1} = [ ...
                firstIndices(sourceGroups(simple)), ...
                firstIndices(targets(simple))]; %#ok<AGROW>
        end
        sourceGroups = sourceGroups(~simple);
        targets = targets(~simple);
    else
        keep = groupCounts(sourceGroups) > 1;
        sourceGroups = sourceGroups(keep);
        targets = targets(keep);
    end
    for groupIndex = 1:numel(sourceGroups)
        sourceGroup = sourceGroups(groupIndex);
        targetGroup = targets(groupIndex);
        first = members{sourceGroup};
        second = members{targetGroup};
        if all(offset == 0)
            [a, b] = find(triu( ...
                true(numel(first), numel(first)), 1));
            rows{end + 1} = [first(a), first(b)]; %#ok<AGROW>
        else
            [a, b] = ndgrid(first, second);
            rows{end + 1} = [a(:), b(:)]; %#ok<AGROW>
        end
    end
    if ~isempty(rows), chunks{offsetIndex} = vertcat(rows{:}); end
end
chunks = chunks(~cellfun("isempty", chunks));
if isempty(chunks)
    pairs = zeros(0, 2);
else
    pairs = vertcat(chunks{:});
    pairs = sort(pairs, 2);
    pairs = sortrows(unique(pairs, "rows"), [1, 2]);
end
end

function offsets = halfCellOffsets()
persistent value
if isempty(value)
    [x, y, z] = ndgrid(-1:1, -1:1, -1:1);
    candidates = [x(:), y(:), z(:)];
    keep = false(size(candidates, 1), 1);
    for index = 1:size(candidates, 1)
        row = candidates(index, :);
        first = find(row ~= 0, 1);
        keep(index) = isempty(first) || row(first) > 0;
    end
    value = candidates(keep, :);
end
offsets = value;
end
