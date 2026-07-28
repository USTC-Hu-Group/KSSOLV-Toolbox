classdef Structure < kssolv.analysis.matgenlab.core.IStructure
    %STRUCTURE Mutable-operation façade using MATLAB copy-on-write values.
    %
    % Methods that mutate in Python return the modified Structure in MATLAB.

    methods
        function obj = Structure(varargin)
            obj@kssolv.analysis.matgenlab.core.IStructure(varargin{:});
        end

        function obj = append(obj, species, coords, options)
            arguments
                obj
                species
                coords
                options.coords_are_cartesian (1,1) logical = false
                options.validate_proximity (1,1) logical = false
                options.properties (1,1) struct = struct()
            end
            site = kssolv.analysis.matgenlab.core.PeriodicSite( ...
                species, coords, obj.lattice, ...
                coords_are_cartesian = options.coords_are_cartesian, ...
                properties = options.properties);
            if options.validate_proximity
                for index = 1:obj.num_sites
                    if site.distance(obj.sites_{index}) < 0.5
                        error("KSSOLV:Matgenlab:Structure:Proximity", ...
                            "New site is too close to an existing site.");
                    end
                end
            end
            obj.sites_{end + 1} = site;
        end

        function obj = insert(obj, index, species, coords, options)
            arguments
                obj
                index (1,1) double {mustBeInteger, mustBePositive}
                species
                coords
                options.coords_are_cartesian (1,1) logical = false
                options.validate_proximity (1,1) logical = false
                options.properties (1,1) struct = struct()
                options.label = missing
            end
            if index > obj.num_sites + 1
                error("KSSOLV:Matgenlab:Structure:Index", ...
                    "Insertion index exceeds the structure length.");
            end
            site = kssolv.analysis.matgenlab.core.PeriodicSite( ...
                species, coords, obj.lattice, ...
                coords_are_cartesian = options.coords_are_cartesian, ...
                properties = options.properties, label = options.label);
            if options.validate_proximity
                for existing = 1:obj.num_sites
                    if site.distance(obj.sites_{existing}) < 0.5
                        error("KSSOLV:Matgenlab:Structure:Proximity", ...
                            "New site is too close to an existing site.");
                    end
                end
            end
            obj.sites_ = [obj.sites_(1:index-1), {site}, obj.sites_(index:end)];
        end

        function obj = replace(obj, index, species, coords, options)
            arguments
                obj
                index (1,1) double
                species = []
                coords = []
                options.coords_are_cartesian (1,1) logical = false
                options.properties = []
                options.label = missing
            end
            obj.validateSiteIndex(index);
            current = obj.sites_{index};
            if isempty(species), species = current.species; end
            if isempty(coords)
                coords = current.frac_coords;
                options.coords_are_cartesian = false;
            end
            if isempty(options.properties)
                options.properties = current.site_properties;
            end
            if ismissing(string(options.label)), options.label = current.label; end
            obj.sites_{index} = ...
                kssolv.analysis.matgenlab.core.PeriodicSite( ...
                    species, coords, obj.lattice, ...
                    coords_are_cartesian = options.coords_are_cartesian, ...
                    properties = options.properties, label = options.label);
        end

        function obj = substitute(obj, index, functionalGroup, bondOrder)
            if nargin < 4, bondOrder = 1; end
            [speciesValues, coordinates, properties, labels] = ...
                kssolv.analysis.matgenlab.core.prepare_functional_group( ...
                obj, index, functionalGroup, bondOrder);
            obj = obj.remove_sites(index);
            for siteIndex = 1:numel(speciesValues)
                obj = obj.append(speciesValues{siteIndex}, ...
                    coordinates(siteIndex, :), ...
                    coords_are_cartesian = true, ...
                    properties = properties{siteIndex});
                site = obj.sites_{end};
                site.label = labels{siteIndex};
                obj.sites_{end} = site;
            end
        end

        function obj = remove_sites(obj, indices)
            indices = unique(reshape(double(indices), 1, []));
            arrayfun(@(index) obj.validateSiteIndex(index), indices);
            keep = true(1, obj.num_sites);
            keep(indices) = false;
            obj.sites_ = obj.sites_(keep);
        end

        function obj = remove_species(obj, species)
            removed = string(species);
            keep = false(1, obj.num_sites);
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                [siteSpecies, amounts] = site.species.items();
                retained = ~cellfun(@(item) ...
                    any(removed == string(item)) || ...
                    any(removed == item.symbol), siteSpecies);
                if any(retained)
                    pairs = [reshape(siteSpecies(retained), [], 1), ...
                        num2cell(reshape(amounts(retained), [], 1))];
                    site.species = ...
                        kssolv.analysis.matgenlab.core.Composition(pairs);
                    obj.sites_{index} = site;
                    keep(index) = true;
                end
            end
            obj.sites_ = obj.sites_(keep);
        end

        function obj = translate_sites(obj, indices, vector, options)
            arguments
                obj
                indices
                vector
                options.frac_coords (1,1) logical = true
                options.to_unit_cell (1,1) logical = true
            end
            indices = reshape(indices, 1, []);
            vector = reshape(double(vector), 1, 3);
            if ~options.frac_coords
                vector = obj.lattice.get_fractional_coords(vector);
            end
            for index = indices
                obj.validateSiteIndex(index);
                site = obj.sites_{index};
                site.frac_coords = site.frac_coords + vector;
                if options.to_unit_cell, site = site.to_unit_cell(true); end
                obj.sites_{index} = site;
            end
        end

        function obj = apply_operation(obj, operation, fractional)
            if nargin < 3, fractional = false; end
            if fractional
                for index = 1:obj.num_sites
                    site = obj.sites_{index};
                    site.frac_coords = operation.operate(site.frac_coords);
                    obj.sites_{index} = site;
                end
            else
                newMatrix = operation.apply_rotation_only(obj.lattice.matrix);
                obj.lattice = kssolv.analysis.matgenlab.core.Lattice( ...
                    newMatrix, obj.lattice.pbc);
                for index = 1:obj.num_sites
                    site = obj.sites_{index};
                    coordinates = operation.operate(site.coords);
                    site.lattice = obj.lattice;
                    site.coords = coordinates;
                    obj.sites_{index} = site;
                end
            end
        end

        function result = mtimes(obj, scaling_matrix)
            if ~isa(obj, "kssolv.analysis.matgenlab.core.Structure")
                % Preserve commutative scaling_matrix * structure syntax.
                temporary = obj;
                obj = scaling_matrix;
                scaling_matrix = temporary;
            end
            if isscalar(scaling_matrix)
                scaling_matrix = eye(3) * scaling_matrix;
            elseif isvector(scaling_matrix) && numel(scaling_matrix) == 3
                scaling_matrix = diag(scaling_matrix);
            end
            if ~isequal(size(scaling_matrix), [3, 3]) || ...
                    any(scaling_matrix ~= fix(scaling_matrix), "all") || ...
                    abs(det(scaling_matrix)) < 1
                error("KSSOLV:Matgenlab:Structure:ScalingMatrix", ...
                    "Supercell scaling matrix must be a nonsingular integer 3-by-3 matrix.");
            end
            scaling_matrix = double(scaling_matrix);
            newLattice = kssolv.analysis.matgenlab.core.Lattice( ...
                scaling_matrix * obj.lattice.matrix, obj.pbc);
            fractionalTranslations = ...
                kssolv.analysis.matgenlab.util.lattice_points_in_supercell( ...
                    scaling_matrix);
            cartesianTranslations = ...
                newLattice.get_cartesian_coords(fractionalTranslations);
            newSites = cell(1, obj.num_sites * size(cartesianTranslations, 1));
            outputIndex = 0;
            for siteIndex = 1:obj.num_sites
                site = obj.sites_{siteIndex};
                for translationIndex = 1:size(cartesianTranslations, 1)
                    outputIndex = outputIndex + 1;
                    newSites{outputIndex} = ...
                        kssolv.analysis.matgenlab.core.PeriodicSite( ...
                            site.species, ...
                            site.coords + ...
                                cartesianTranslations(translationIndex, :), ...
                            newLattice, coords_are_cartesian = true, ...
                            properties = site.site_properties, ...
                            label = site.label);
                end
            end
            result = kssolv.analysis.matgenlab.core.Structure.from_sites( ...
                newSites, properties = obj.structure_properties, ...
                to_unit_cell = true);
            result = result.relabel_sites(true);
        end

        function obj = make_supercell(obj, scaling_matrix, ...
                to_unit_cell, in_place)
            if nargin < 3, to_unit_cell = true; end
            if nargin < 4, in_place = true; end
            if ~in_place, obj = obj.copy(); end
            obj = obj * scaling_matrix;
            if to_unit_cell
                for index = 1:obj.num_sites
                    site = obj.sites_{index};
                    site = site.to_unit_cell(true);
                    obj.sites_{index} = site;
                end
            end
        end

        function obj = rotate_sites(obj, indices, theta, axis, anchor, ...
                toUnitCell)
            if nargin < 2 || isempty(indices), indices = 1:obj.num_sites; end
            if nargin < 3, theta = 0; end
            if nargin < 4 || isempty(axis), axis = [0, 0, 1]; end
            if nargin < 5 || isempty(anchor), anchor = [0, 0, 0]; end
            if nargin < 6, toUnitCell = true; end
            axis = reshape(double(axis), 1, 3);
            if norm(axis) == 0
                error("KSSOLV:Matgenlab:Structure:RotationAxis", ...
                    "Rotation axis cannot be zero.");
            end
            axis = axis / norm(axis);
            anchor = reshape(double(anchor), 1, 3);
            skew = [
                0, -axis(3), axis(2)
                axis(3), 0, -axis(1)
                -axis(2), axis(1), 0
                ];
            rotation = eye(3) + sin(theta) * skew + ...
                (1 - cos(theta)) * (skew * skew);
            for index = reshape(indices, 1, [])
                obj.validateSiteIndex(index);
                site = obj.sites_{index};
                site.coords = (site.coords - anchor) * rotation.' + anchor;
                if toUnitCell, site = site.to_unit_cell(true); end
                obj.sites_{index} = site;
            end
        end

        function obj = apply_strain(obj, strain, inplace)
            if nargin < 3, inplace = true; end
            if ~inplace, obj = obj.copy(); end
            strain = double(strain);
            if isscalar(strain)
                diagonal = repmat(strain, 1, 3);
            elseif isvector(strain) && numel(strain) == 3
                diagonal = reshape(strain, 1, 3);
            elseif isequal(size(strain), [3, 3])
                diagonal = diag(strain).';
            else
                error("KSSOLV:Matgenlab:Structure:StrainShape", ...
                    "strain must be a scalar, three-vector, or 3-by-3 array.");
            end
            matrix = diag(1 + diagonal) * obj.lattice.matrix;
            obj = obj.set_lattice_preserve_fractional( ...
                kssolv.analysis.matgenlab.core.Lattice(matrix, obj.pbc));
        end

        function obj = scale_lattice(obj, volume)
            if ~isscalar(volume) || volume <= 0
                error("KSSOLV:Matgenlab:Structure:Volume", ...
                    "Target volume must be positive.");
            end
            factor = (volume / obj.volume)^(1/3);
            obj = obj.set_lattice_preserve_fractional( ...
                kssolv.analysis.matgenlab.core.Lattice( ...
                    obj.lattice.matrix * factor, obj.pbc));
        end

        function varargout = relax(obj, calculator, varargin)
            if nargin < 2 || isempty(calculator) || ...
                    ischar(calculator) || isstring(calculator)
                error("KSSOLV:Matgenlab:External:StructureRelaxer", ...
                    "Structure relaxation requires an explicit MATLAB " + ...
                    "optimizer adapter.");
            end
            if isa(calculator, "function_handle")
                [varargout{1:nargout}] = calculator(obj, varargin{:});
            elseif isobject(calculator) && ismethod(calculator, "relax")
                [varargout{1:nargout}] = calculator.relax(obj, varargin{:});
            elseif isstruct(calculator) && isfield(calculator, "relax") && ...
                    isa(calculator.relax, "function_handle")
                [varargout{1:nargout}] = ...
                    calculator.relax(obj, varargin{:});
            else
                error("KSSOLV:Matgenlab:Structure:RelaxerType", ...
                    "calculator must expose a MATLAB relaxation adapter.");
            end
        end

        function result = calc_property(obj, propertyName, calculator, varargin)
            if nargin < 3 || isempty(calculator) || ...
                    ischar(calculator) || isstring(calculator)
                error("KSSOLV:Matgenlab:External:PropertyCalculator", ...
                    "Property calculation requires an explicit MATLAB " + ...
                    "calculator adapter.");
            end
            if isa(calculator, "function_handle")
                result = calculator(obj, propertyName, varargin{:});
            elseif isobject(calculator) && ...
                    ismethod(calculator, "calc_property")
                result = calculator.calc_property( ...
                    obj, propertyName, varargin{:});
            elseif isstruct(calculator) && ...
                    isfield(calculator, "calc_property") && ...
                    isa(calculator.calc_property, "function_handle")
                result = calculator.calc_property( ...
                    obj, propertyName, varargin{:});
            else
                error("KSSOLV:Matgenlab:Structure:CalculatorType", ...
                    "calculator must expose a MATLAB property adapter.");
            end
        end

        function obj = set_charge(obj, new_charge)
            if nargin < 2, new_charge = 0; end
            if ~isnumeric(new_charge) || ~isscalar(new_charge) || ...
                    ~isfinite(new_charge)
                error("KSSOLV:Matgenlab:Structure:Charge", ...
                    "Structure charge must be a finite scalar.");
            end
            obj.explicit_charge_ = double(new_charge);
        end

        function obj = merge_sites(obj, tolerance, mode)
            if nargin < 2, tolerance = 0.01; end
            if nargin < 3, mode = "sum"; end
            mode = lower(string(mode));
            if ~ismember(mode, ["sum", "delete", "average"])
                error("KSSOLV:Matgenlab:Structure:MergeMode", ...
                    "mode must be 'sum', 'delete', or 'average'.");
            end
            count = obj.num_sites;
            parent = 1:count;
            for first = 1:count
                for second = first + 1:count
                    if obj.get_distance(first, second) <= tolerance
                        unionRoots(first, second);
                    end
                end
            end
            roots = arrayfun(@findRoot, 1:count);
            uniqueRoots = unique(roots, "stable");
            newSites = cell(1, numel(uniqueRoots));
            for groupIndex = 1:numel(uniqueRoots)
                members = find(roots == uniqueRoots(groupIndex));
                representative = obj.sites_{members(1)};
                mergedProperties = representative.site_properties;
                if mode == "sum" && numel(members) > 1
                    composition = ...
                        kssolv.analysis.matgenlab.core.Composition();
                    for member = members
                        composition = composition + ...
                            obj.sites_{member}.species;
                    end
                    representative = ...
                        kssolv.analysis.matgenlab.core.PeriodicSite( ...
                            composition, representative.frac_coords, ...
                            obj.lattice, ...
                            properties = mergedProperties, ...
                            label = representative.label, ...
                            skip_checks = true);
                end
                % Pymatgen centers every merged cluster, including delete
                % and sum modes; only the species/property policy differs.
                if numel(members) > 1
                    base = representative.frac_coords;
                    coordinates = zeros(numel(members), 3);
                    for memberIndex = 1:numel(members)
                        delta = ...
                            obj.sites_{members(memberIndex)}.frac_coords - ...
                            base;
                        delta(obj.pbc) = ...
                            delta(obj.pbc) - round(delta(obj.pbc));
                        coordinates(memberIndex, :) = base + delta;
                    end
                    representative.frac_coords = mean(coordinates, 1);
                    propertyNames = fieldnames(mergedProperties);
                    for propertyIndex = 1:numel(propertyNames)
                        name = propertyNames{propertyIndex};
                        values = cell(1, numel(members));
                        compatible = true;
                        for memberIndex = 1:numel(members)
                            currentProperties = obj.sites_{ ...
                                members(memberIndex)}.site_properties;
                            if ~isfield(currentProperties, name)
                                compatible = false;
                                break
                            end
                            values{memberIndex} = currentProperties.(name);
                        end
                        if mode == "average" && compatible && ...
                                all(cellfun(@(value) isnumeric(value) && ...
                                isscalar(value), values))
                            mergedProperties.(name) = mean([values{:}]);
                        elseif ~compatible || ...
                                ~all(cellfun(@(value) ...
                                isequal(value, values{1}), values))
                            mergedProperties.(name) = [];
                        end
                    end
                    representative.site_properties = mergedProperties;
                end
                newSites{groupIndex} = representative;
            end
            obj.sites_ = newSites;

            function root = findRoot(index)
                root = index;
                while parent(root) ~= root, root = parent(root); end
                while parent(index) ~= index
                    next = parent(index);
                    parent(index) = root;
                    index = next;
                end
            end

            function unionRoots(first, second)
                firstRoot = findRoot(first);
                secondRoot = findRoot(second);
                if firstRoot ~= secondRoot
                    parent(secondRoot) = firstRoot;
                end
            end
        end

        function obj = sort(obj, key, reverse)
            if nargin < 2, key = []; end
            if nargin < 3, reverse = false; end
            sorted = obj.get_sorted_structure(key, reverse);
            obj.sites_ = sorted.sites;
        end

        function obj = perturb(obj, distance, min_distance, seed)
            if nargin < 3 || isempty(min_distance), min_distance = 0; end
            if nargin < 4 || isempty(seed), seed = "shuffle"; end
            stream = RandStream("mt19937ar", Seed = seedValue(seed));
            for index = 1:obj.num_sites
                direction = randn(stream, 1, 3);
                direction = direction / norm(direction);
                magnitude = min_distance + ...
                    (distance - min_distance) * rand(stream);
                site = obj.sites_{index};
                site.coords = site.coords + direction * magnitude;
                obj.sites_{index} = site;
            end

            function value = seedValue(input)
                if isstring(input) || ischar(input)
                    value = randi(2^31 - 1);
                else
                    value = double(input);
                end
            end
        end

        function obj = set_lattice_preserve_fractional(obj, lattice)
            obj.lattice = lattice;
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                site.lattice = lattice;
                obj.sites_{index} = site;
            end
        end

        function value = to(obj, filename, fmt)
            if nargin < 2, filename = ""; end
            if nargin < 3 || strlength(string(fmt)) == 0
                [~, name, extension] = fileparts(string(filename));
                if any(strcmpi(name, ["POSCAR", "CONTCAR"]))
                    fmt = "poscar";
                elseif strlength(string(filename)) == 0
                    fmt = "json";
                else
                    fmt = erase(lower(extension), ".");
                end
            end
            fmt = lower(string(fmt));
            handler = kssolv.analysis.matgenlab.io. ...
                get_structure_format("name", fmt);
            if ~isempty(handler.write_str)
                value = string(feval(handler.write_str, obj));
                if strlength(string(filename)) > 0
                    if ~isempty(handler.write_file)
                        feval(handler.write_file, obj, filename);
                        return
                    end
                    fid = fopen(filename, "w", "n", "UTF-8");
                    if fid < 0
                        error("KSSOLV:Matgenlab:Structure:Write", ...
                            "Cannot open '%s' for writing.", filename);
                    end
                    cleanup = onCleanup(@() fclose(fid));
                    fwrite(fid, char(value), "char");
                    clear cleanup
                end
                return
            end
            switch fmt
                case {"json", "mson"}
                    value = kssolv.analysis.matgenlab.util.encode(obj);
                case {"poscar", "vasp"}
                    value = string( ...
                        kssolv.analysis.matgenlab.io.vasp.Poscar(obj));
                case "cif"
                    value = string( ...
                        kssolv.analysis.matgenlab.io.cif.CifWriter(obj));
                case "xyz"
                    value = string( ...
                        kssolv.analysis.matgenlab.io.xyz.XYZ(obj));
                otherwise
                    error("KSSOLV:Matgenlab:Structure:UnknownFormat", ...
                        "Unsupported structure format '%s'.", fmt);
            end
            if strlength(string(filename)) > 0
                fid = fopen(filename, "w", "n", "UTF-8");
                if fid < 0
                    error("KSSOLV:Matgenlab:Structure:Write", ...
                        "Cannot open '%s' for writing.", filename);
                end
                cleanup = onCleanup(@() fclose(fid));
                fwrite(fid, char(value), "char");
                clear cleanup
            end
        end

        function value = to_file(obj, filename, fmt)
            if nargin < 3, fmt = ""; end
            value = obj.to(filename, fmt);
        end
    end

    methods (Static)
        function obj = from_prototype(prototype, species, varargin)
            parameters = struct();
            for index = 1:2:numel(varargin)
                if index + 1 > numel(varargin)
                    error("KSSOLV:Matgenlab:Structure:InvalidArguments", ...
                        "Prototype parameters must be name-value pairs.");
                end
                parameters.(char(lower(string(varargin{index})))) = ...
                    varargin{index + 1};
            end
            prototype = lower(string(prototype));
            if ~isfield(parameters, "a")
                error("KSSOLV:Matgenlab:Structure:MissingPrototypeParameter", ...
                    "Required parameter 'a' was not specified.");
            end
            a = parameters.a;
            switch prototype
                case "fcc"
                    obj = kssolv.analysis.matgenlab.core.Structure. ...
                        from_spacegroup("Fm-3m", ...
                            kssolv.analysis.matgenlab.core.Lattice.cubic(a), ...
                            species, [0, 0, 0]);
                case "bcc"
                    obj = kssolv.analysis.matgenlab.core.Structure. ...
                        from_spacegroup("Im-3m", ...
                            kssolv.analysis.matgenlab.core.Lattice.cubic(a), ...
                            species, [0, 0, 0]);
                case "hcp"
                    if ~isfield(parameters, "c")
                        error("KSSOLV:Matgenlab:Structure:MissingPrototypeParameter", ...
                            "Required parameter 'c' was not specified.");
                    end
                    obj = kssolv.analysis.matgenlab.core.Structure. ...
                        from_spacegroup("P6_3/mmc", ...
                            kssolv.analysis.matgenlab.core.Lattice. ...
                            hexagonal(a, parameters.c), ...
                            species, [1/3, 2/3, 1/4]);
                case "diamond"
                    obj = kssolv.analysis.matgenlab.core.Structure. ...
                        from_spacegroup("Fd-3m", ...
                            kssolv.analysis.matgenlab.core.Lattice.cubic(a), ...
                            species, [0, 0, 0]);
                case "rocksalt"
                    obj = kssolv.analysis.matgenlab.core.Structure. ...
                        from_spacegroup("Fm-3m", ...
                            kssolv.analysis.matgenlab.core.Lattice.cubic(a), ...
                            species, [0, 0, 0; 0.5, 0.5, 0]);
                case "perovskite"
                    obj = kssolv.analysis.matgenlab.core.Structure. ...
                        from_spacegroup("Pm-3m", ...
                            kssolv.analysis.matgenlab.core.Lattice.cubic(a), ...
                            species, [0, 0, 0; 0.5, 0.5, 0.5; 0.5, 0.5, 0]);
                case "cscl"
                    obj = kssolv.analysis.matgenlab.core.Structure. ...
                        from_spacegroup("Pm-3m", ...
                            kssolv.analysis.matgenlab.core.Lattice.cubic(a), ...
                            species, [0, 0, 0; 0.5, 0.5, 0.5]);
                case {"fluorite", "caf2"}
                    obj = kssolv.analysis.matgenlab.core.Structure. ...
                        from_spacegroup("Fm-3m", ...
                            kssolv.analysis.matgenlab.core.Lattice.cubic(a), ...
                            species, [0, 0, 0; 0.25, 0.25, 0.25]);
                case "antifluorite"
                    obj = kssolv.analysis.matgenlab.core.Structure. ...
                        from_spacegroup("Fm-3m", ...
                            kssolv.analysis.matgenlab.core.Lattice.cubic(a), ...
                            species, [0.25, 0.25, 0.25; 0, 0, 0]);
                case "zincblende"
                    obj = kssolv.analysis.matgenlab.core.Structure. ...
                        from_spacegroup("F-43m", ...
                            kssolv.analysis.matgenlab.core.Lattice.cubic(a), ...
                            species, [0, 0, 0; 0.25, 0.25, 0.75]);
                otherwise
                    error("KSSOLV:Matgenlab:Structure:UnknownPrototype", ...
                        "Unsupported prototype '%s'.", prototype);
            end
        end

        function obj = from_spacegroup(sg, lattice, species, coords, varargin)
            base = ...
                kssolv.analysis.matgenlab.core.IStructure.from_spacegroup( ...
                    sg, lattice, species, coords, varargin{:});
            obj = kssolv.analysis.matgenlab.core.Structure.from_sites( ...
                base.sites, properties=base.structure_properties);
        end

        function obj = from_sites(sites, options)
            arguments
                sites cell
                options.charge (1,1) double = NaN
                options.properties (1,1) struct = struct()
                options.to_unit_cell (1,1) logical = false
                options.validate_proximity (1,1) logical = false
            end
            base = kssolv.analysis.matgenlab.core.IStructure.from_sites( ...
                sites, properties = options.properties, ...
                charge = options.charge, ...
                to_unit_cell = options.to_unit_cell, ...
                validate_proximity = options.validate_proximity);
            obj = kssolv.analysis.matgenlab.core.Structure( ...
                base.lattice, base.species_and_occu, base.frac_coords, ...
                charge = options.charge, ...
                site_properties = base.site_properties, labels = base.labels, ...
                properties = base.structure_properties);
        end

        function obj = from_dict(value)
            base = ...
                kssolv.analysis.matgenlab.core.IStructure.from_dict(value);
            obj = kssolv.analysis.matgenlab.core.Structure.from_sites( ...
                base.sites, charge = base.charge, ...
                properties = base.structure_properties);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core.Structure.from_dict(value);
        end

        function obj = from_str(input_string, fmt, varargin)
            fmt = lower(string(fmt));
            handler = kssolv.analysis.matgenlab.io. ...
                get_structure_format("name", fmt);
            if ~isempty(handler.read_str)
                value = feval(handler.read_str, input_string);
                if isa(value, ...
                        "kssolv.analysis.matgenlab.core.Structure")
                    obj = value;
                elseif isa(value, ...
                        "kssolv.analysis.matgenlab.core.IStructure")
                    obj = kssolv.analysis.matgenlab.core.Structure. ...
                        from_sites(value.sites, ...
                        properties = value.structure_properties);
                else
                    error("KSSOLV:Matgenlab:Structure:RegistryType", ...
                        "Structure format handler returned '%s'.", ...
                        class(value));
                end
                obj = applyReadOptions(obj, varargin{:});
                return
            end
            switch fmt
                case {"json", "mson"}
                    decoded = kssolv.analysis.matgenlab.util.decode(input_string);
                    if isa(decoded, "kssolv.analysis.matgenlab.core.Structure")
                        obj = decoded;
                    elseif isa(decoded, ...
                            "kssolv.analysis.matgenlab.core.IStructure")
                        obj = ...
                            kssolv.analysis.matgenlab.core.Structure.from_sites( ...
                                decoded.sites, ...
                                properties = decoded.structure_properties);
                    else
                        error("KSSOLV:Matgenlab:Structure:DecodedType", ...
                            "JSON does not contain a Structure.");
                    end
                case {"poscar", "vasp"}
                    parsed = ...
                        kssolv.analysis.matgenlab.io.vasp.Poscar.from_str( ...
                            input_string);
                    obj = parsed.structure;
                case "cif"
                    parser = ...
                        kssolv.analysis.matgenlab.io.cif.CifParser.from_str( ...
                            input_string);
                    structures = parser.parse_structures(on_error = "raise");
                    if isempty(structures)
                        error("KSSOLV:Matgenlab:Structure:CifEmpty", ...
                            "CIF contains no structures.");
                    end
                    obj = structures{1};
                otherwise
                    error("KSSOLV:Matgenlab:Structure:UnknownFormat", ...
                        "Unsupported structure format '%s'.", fmt);
            end
            obj = applyReadOptions(obj, varargin{:});
        end

        function obj = from_file(filename, fmt, varargin)
            if nargin < 2 || strlength(string(fmt)) == 0
                [~, name, extension] = fileparts(string(filename));
                if any(strcmpi(name, ["POSCAR", "CONTCAR"]))
                    fmt = "poscar";
                else
                    fmt = erase(lower(extension), ".");
                end
            end
            if ~isfile(filename)
                error("KSSOLV:Matgenlab:Structure:MissingFile", ...
                    "Structure file '%s' does not exist.", filename);
            end
            if any(lower(string(fmt)) == ["poscar", "vasp"])
                parsed = ...
                    kssolv.analysis.matgenlab.io.vasp.Poscar.from_file( ...
                        filename);
                obj = parsed.structure;
            elseif lower(string(fmt)) == "cif"
                parser = ...
                    kssolv.analysis.matgenlab.io.cif.CifParser(filename);
                structures = parser.parse_structures(on_error = "raise");
                if isempty(structures)
                    error("KSSOLV:Matgenlab:Structure:CifEmpty", ...
                        "CIF contains no structures.");
                end
                obj = structures{1};
            else
                obj = kssolv.analysis.matgenlab.core.Structure.from_str( ...
                    fileread(filename), fmt, varargin{:});
                return
            end
            obj = applyReadOptions(obj, varargin{:});
        end
    end
end

function structure = applyReadOptions(structure, varargin)
options = struct("primitive", false, "sort", false, "merge_tol", 0);
if ~isempty(varargin) && ...
        ~(ischar(varargin{1}) || isstring(varargin{1}))
    names = ["primitive", "sort", "merge_tol"];
    for index = 1:min(numel(varargin), numel(names))
        options.(char(names(index))) = varargin{index};
    end
else
    for index = 1:2:numel(varargin)
        if index == numel(varargin)
            error("KSSOLV:Matgenlab:Structure:InvalidArguments", ...
                "Structure read options must be name-value pairs.");
        end
        name = char(lower(string(varargin{index})));
        if ~isfield(options, name)
            error("KSSOLV:Matgenlab:Structure:InvalidOption", ...
                "Unknown structure read option '%s'.", name);
        end
        options.(name) = varargin{index + 1};
    end
end
if logical(options.primitive)
    structure = structure.get_primitive_structure();
    if ~isa(structure, "kssolv.analysis.matgenlab.core.Structure")
        structure = kssolv.analysis.matgenlab.core.Structure.from_sites( ...
            structure.sites, charge = structure.charge, ...
            properties = structure.structure_properties);
    end
end
if logical(options.sort), structure = structure.sort(); end
if double(options.merge_tol) > 0
    structure = structure.merge_sites(double(options.merge_tol));
end
end
