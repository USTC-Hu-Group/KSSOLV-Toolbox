classdef Trajectory < kssolv.analysis.matgenlab.util.MSONable
    %TRAJECTORY Molecular or periodic simulation trajectory.

    properties
        species cell = cell(1, 0)
        coords double = zeros(0, 0, 3)
        charge = []
        spin_multiplicity = []
        lattice double = []
        site_properties = []
        frame_properties = []
        constant_lattice = []
        time_step = []
        coords_are_displacement (1,1) logical = false
        base_positions double = []
    end

    methods
        function obj = Trajectory(species, coords, options)
            arguments
                species
                coords
                options.charge = []
                options.spin_multiplicity = []
                options.lattice = []
                options.site_properties = []
                options.frame_properties = []
                options.constant_lattice = true
                options.time_step = []
                options.coords_are_displacement (1,1) logical = false
                options.base_positions = []
            end
            if ndims(coords) ~= 3 || size(coords, 3) ~= 3
                error("KSSOLV:Matgenlab:Trajectory:CoordinateShape", ...
                    "coords must have shape M-by-N-by-3.");
            end
            obj.species = obj.normalizeSpecies(species);
            if numel(obj.species) ~= size(coords, 2)
                error("KSSOLV:Matgenlab:Trajectory:SpeciesLength", ...
                    "Species count must equal the second coords dimension.");
            end
            obj.coords = double(coords);
            obj.charge = options.charge;
            obj.spin_multiplicity = options.spin_multiplicity;
            obj.site_properties = options.site_properties;
            obj.frame_properties = options.frame_properties;
            obj.constant_lattice = options.constant_lattice;
            obj.time_step = options.time_step;
            obj.coords_are_displacement = options.coords_are_displacement;
            if isempty(options.lattice)
                if isempty(options.charge)
                    error("KSSOLV:Matgenlab:Trajectory:ChargeRequired", ...
                        "charge must be provided for a Molecule trajectory.");
                end
            else
                obj.lattice = obj.normalizeLattice(options.lattice);
                if ~options.constant_lattice && isequal(size(obj.lattice), [3, 3])
                    obj.lattice = repmat(obj.lattice, 1, 1, size(coords, 1));
                    obj.lattice = permute(obj.lattice, [3, 1, 2]);
                end
                if ndims(obj.lattice) == 3 && ...
                        size(obj.lattice, 1) ~= size(coords, 1)
                    error("KSSOLV:Matgenlab:Trajectory:LatticeLength", ...
                        "A variable lattice requires one matrix per frame.");
                end
            end
            if options.coords_are_displacement
                obj.base_positions = double(options.base_positions);
            else
                obj.base_positions = squeeze(obj.coords(1, :, :));
            end
            obj.validateProperties();
        end

        function value = length(obj), value = size(obj.coords, 1); end

        function value = get_frame(obj, frames)
            obj = obj.to_positions();
            if isscalar(frames)
                if frames < 1 || frames > length(obj) || frames ~= fix(frames)
                    error("KSSOLV:Matgenlab:Trajectory:Index", ...
                        "Trajectory frame index is out of range.");
                end
                coordinates = reshape(obj.coords(frames, :, :), ...
                    size(obj.coords, 2), 3);
                siteProps = obj.getSiteProperties(frames);
                frameProps = obj.getFrameProperties(frames);
                if isempty(obj.lattice)
                    chargeValue = obj.charge;
                    if isempty(chargeValue), chargeValue = 0; end
                    value = kssolv.analysis.matgenlab.core.Molecule( ...
                        obj.species, coordinates, charge = chargeValue, ...
                        spin_multiplicity = obj.spin_multiplicity, ...
                        site_properties = siteProps, properties = frameProps);
                else
                    latticeValue = obj.lattice;
                    if ~obj.constant_lattice
                        latticeValue = squeeze(obj.lattice(frames, :, :));
                    end
                    value = kssolv.analysis.matgenlab.core.Structure( ...
                        kssolv.analysis.matgenlab.core.Lattice(latticeValue), ...
                        obj.species, coordinates, ...
                        to_unit_cell = true, site_properties = siteProps, ...
                        properties = frameProps);
                end
                return
            end

            frames = reshape(double(frames), 1, []);
            if any(frames < 1 | frames > length(obj) | frames ~= fix(frames))
                error("KSSOLV:Matgenlab:Trajectory:Index", ...
                    "Trajectory frame indices are out of range.");
            end
            latticeValue = obj.lattice;
            if ~isempty(latticeValue) && ~obj.constant_lattice
                latticeValue = latticeValue(frames, :, :);
            end
            value = kssolv.analysis.matgenlab.core.Trajectory( ...
                obj.species, obj.coords(frames, :, :), ...
                charge = obj.charge, ...
                spin_multiplicity = obj.spin_multiplicity, ...
                lattice = latticeValue, ...
                site_properties = obj.getSiteProperties(frames), ...
                frame_properties = obj.getFrameProperties(frames), ...
                constant_lattice = obj.constant_lattice, ...
                time_step = obj.time_step, ...
                base_positions = obj.base_positions);
        end

        function value = get_structure(obj, index)
            value = obj.get_frame(index);
            if ~isa(value, "kssolv.analysis.matgenlab.core.Structure")
                error("KSSOLV:Matgenlab:Trajectory:NotStructure", ...
                    "Cannot return Structure for a Molecule trajectory.");
            end
        end

        function value = get_molecule(obj, index)
            value = obj.get_frame(index);
            if ~isa(value, "kssolv.analysis.matgenlab.core.Molecule")
                error("KSSOLV:Matgenlab:Trajectory:NotMolecule", ...
                    "Cannot return Molecule for a Structure trajectory.");
            end
        end

        function obj = to_positions(obj)
            if ~obj.coords_are_displacement, return; end
            if isempty(obj.base_positions)
                error("KSSOLV:Matgenlab:Trajectory:MissingBasePositions", ...
                    "Cannot reconstruct positions without base_positions.");
            end
            obj.coords = cumsum(obj.coords, 1) + ...
                reshape(obj.base_positions, 1, size(obj.coords, 2), 3);
            obj.coords_are_displacement = false;
        end

        function obj = to_displacements(obj)
            if obj.coords_are_displacement, return; end
            shifted = circshift(obj.coords, 1, 1);
            displacements = obj.coords - shifted;
            displacements(1, :, :) = 0;
            if ~isempty(obj.lattice)
                displacements = displacements - round(displacements);
            end
            obj.coords = displacements;
            obj.coords_are_displacement = true;
        end

        function obj = extend(obj, other)
            if isempty(obj.lattice) ~= isempty(other.lattice)
                error("KSSOLV:Matgenlab:Trajectory:IncompatibleType", ...
                    "Cannot combine Molecule and Structure trajectories.");
            end
            if ~isequal(obj.time_step, other.time_step)
                error("KSSOLV:Matgenlab:Trajectory:TimeStep", ...
                    "Trajectory time steps are incompatible.");
            end
            if numel(obj.species) ~= numel(other.species) || ...
                    any(~cellfun(@(a,b) string(a) == string(b), ...
                    obj.species, other.species))
                error("KSSOLV:Matgenlab:Trajectory:Species", ...
                    "Trajectory species are incompatible.");
            end
            obj = obj.to_positions();
            other = other.to_positions();
            firstLength = length(obj);
            secondLength = length(other);
            obj.site_properties = combineProperties( ...
                obj.site_properties, other.site_properties, ...
                firstLength, secondLength);
            obj.frame_properties = combineProperties( ...
                obj.frame_properties, other.frame_properties, ...
                firstLength, secondLength);
            if ~isempty(obj.lattice)
                [obj.lattice, obj.constant_lattice] = combineLattice( ...
                    obj.lattice, other.lattice, firstLength, secondLength);
            end
            obj.coords = cat(1, obj.coords, other.coords);

            function result = combineProperties(first, second, nFirst, nSecond)
                if isempty(first) && isempty(second), result = []; return; end
                if ~iscell(first), first = repmat({first}, 1, nFirst); end
                if ~iscell(second), second = repmat({second}, 1, nSecond); end
                result = [reshape(first, 1, []), reshape(second, 1, [])];
            end

            function [result, constant] = combineLattice(first, second, nFirst, nSecond)
                if isequal(size(first), [3, 3]) && ...
                        isequal(size(second), [3, 3]) && ...
                        all(abs(first - second) < 1e-12, "all")
                    result = first; constant = true; return
                end
                if isequal(size(first), [3, 3])
                    first = repmat(reshape(first, 1, 3, 3), nFirst, 1, 1);
                end
                if isequal(size(second), [3, 3])
                    second = repmat(reshape(second, 1, 3, 3), nSecond, 1, 1);
                end
                result = cat(1, first, second);
                constant = false;
            end
        end

        function atomsTrajectory = to_ase(obj, property_map, ase_traj_file)
            if nargin < 2 || isempty(property_map)
                property_map = struct("energy", "energy", ...
                    "forces", "forces", "stress", "stress");
            end
            if nargin < 3, ase_traj_file = ""; end
            obj = obj.to_positions();
            atomsTrajectory = cell(1, length(obj));
            for index = 1:length(obj)
                frame = obj.get_frame(index);
                atoms = frame.to_ase_atoms();
                if isfield(atoms.arrays, "velocities") && ...
                        iscell(atoms.arrays.velocities)
                    atoms.arrays.velocities = ...
                        vertcat(atoms.arrays.velocities{:});
                end
                frameProperties = obj.getFrameProperties(index);
                results = struct();
                names = string(fieldnames(property_map));
                for nameIndex = 1:numel(names)
                    aseName = char(names(nameIndex));
                    trajectoryName = char(string( ...
                        property_map.(aseName)));
                    if isfield(frameProperties, trajectoryName)
                        results.(aseName) = ...
                            frameProperties.(trajectoryName);
                    end
                end
                atoms.calc = struct("results", results);
                atomsTrajectory{index} = atoms;
            end
            if strlength(string(ase_traj_file)) > 0
                transport = aseTransportStore("get");
                if isempty(transport)
                    error("KSSOLV:Matgenlab:Trajectory:AseRequired", ...
                        "Writing ASE .traj files requires an explicit MATLAB ASE transport.");
                end
                transport("write", string(ase_traj_file), atomsTrajectory);
            end
        end

        function write_Xdatcar(obj, filename, systemName, significant_figures)
            if nargin < 2, filename = "XDATCAR"; end
            if nargin < 3 || strlength(string(systemName)) == 0
                systemName = obj.get_structure(1).reduced_formula;
            end
            if nargin < 4, significant_figures = 6; end
            if isempty(obj.lattice)
                error("KSSOLV:Matgenlab:Trajectory:NotPeriodic", ...
                    "XDATCAR requires a Structure trajectory.");
            end
            obj = obj.to_positions();
            first = obj.get_structure(1);
            symbols = cellfun(@(item) string(item.symbol), first.species);
            [uniqueSymbols, counts] = groupedSymbols(string(symbols));
            lines = strings(0, 1);
            format = sprintf("%%.%df %%.%df %%.%df", ...
                significant_figures, significant_figures, significant_figures);
            for frame = 1:length(obj)
                if frame == 1 || ~obj.constant_lattice
                    latticeValue = obj.lattice;
                    if ~obj.constant_lattice
                        latticeValue = squeeze(obj.lattice(frame, :, :));
                    end
                    lines(end + 1) = string(systemName); %#ok<AGROW>
                    lines(end + 1) = "1.0"; %#ok<AGROW>
                    for row = 1:3
                        lines(end + 1) = strjoin(string(latticeValue(row, :)), " "); %#ok<AGROW>
                    end
                    lines(end + 1) = strjoin(uniqueSymbols, " "); %#ok<AGROW>
                    lines(end + 1) = strjoin(string(counts), " "); %#ok<AGROW>
                end
                lines(end + 1) = sprintf("Direct configuration=     %d", frame); %#ok<AGROW>
                coordinates = reshape(obj.coords(frame, :, :), ...
                    size(obj.coords, 2), 3);
                for siteIndex = 1:size(coordinates, 1)
                    lines(end + 1) = sprintf(format, coordinates(siteIndex, :)); %#ok<AGROW>
                end
            end
            fid = fopen(filename, "w", "n", "UTF-8");
            if fid < 0
                error("KSSOLV:Matgenlab:Trajectory:Write", ...
                    "Cannot open '%s' for writing.", filename);
            end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, char(strjoin(lines, newline) + newline), "char");
            clear cleanup

            function [uniqueValues, counts] = groupedSymbols(values)
                uniqueValues = values(1);
                counts = 1;
                for valueIndex = 2:numel(values)
                    if values(valueIndex) == uniqueValues(end)
                        counts(end) = counts(end) + 1;
                    else
                        uniqueValues(end + 1) = values(valueIndex); %#ok<AGROW>
                        counts(end + 1) = 1; %#ok<AGROW>
                    end
                end
            end
        end

        function value = as_dict(obj)
            value = struct( ...
                "x_module", "pymatgen.core.trajectory", ...
                "x_class", "Trajectory", ...
                "species", {cellfun(@(item) string(item), obj.species, ...
                    "UniformOutput", false)}, ...
                "coords", obj.coords, ...
                "charge", obj.charge, ...
                "spin_multiplicity", obj.spin_multiplicity, ...
                "lattice", obj.lattice, ...
                "site_properties", obj.site_properties, ...
                "frame_properties", obj.frame_properties, ...
                "constant_lattice", obj.constant_lattice, ...
                "time_step", obj.time_step, ...
                "coords_are_displacement", obj.coords_are_displacement, ...
                "base_positions", obj.base_positions);
        end

        function value = asDict(obj), value = obj.as_dict(); end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") && ...
                    isscalar(reference(1).subs)
                value = obj.get_frame(reference(1).subs{1});
                if numel(reference) > 1
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
            else
                [varargout{1:nargout}] = builtin("subsref", obj, reference);
            end
        end
    end

    methods (Static)
        function obj = from_ase(trajectory, constant_lattice, ...
                store_frame_properties, property_map, ...
                lattice_match_tol, additional_fields)
            if nargin < 2, constant_lattice = []; end
            if nargin < 3 || isempty(store_frame_properties)
                store_frame_properties = true;
            end
            if nargin < 4 || isempty(property_map)
                property_map = struct("energy", "energy", ...
                    "forces", "forces", "stress", "stress");
            end
            if nargin < 5 || isempty(lattice_match_tol)
                lattice_match_tol = 1e-6;
            end
            if nargin < 6 || isempty(additional_fields)
                additional_fields = ["temperature", "velocities"];
            end
            if ischar(trajectory) || ...
                    (isstring(trajectory) && isscalar(trajectory))
                transport = aseTransportStore("get");
                if isempty(transport)
                    error("KSSOLV:Matgenlab:Trajectory:AseRequired", ...
                        "Reading ASE .traj files requires an explicit MATLAB ASE transport.");
                end
                trajectory = transport("read", string(trajectory), {});
            end
            if isstruct(trajectory)
                trajectory = num2cell(reshape(trajectory, 1, []));
            end
            if ~iscell(trajectory) || isempty(trajectory)
                error("KSSOLV:Matgenlab:Trajectory:AseRepresentation", ...
                    "ASE trajectory must be a nonempty cell or struct array.");
            end
            structures = cell(1, numel(trajectory));
            frameProperties = cell(1, numel(trajectory));
            for index = 1:numel(trajectory)
                atoms = trajectory{index};
                if any(additional_fields == "velocities") && ...
                        isfield(atoms, "velocities")
                    if ~isfield(atoms, "arrays"), atoms.arrays = struct(); end
                    atoms.arrays.velocities = ...
                        reshape(num2cell(atoms.velocities, 2), 1, []);
                end
                structures{index} = ...
                    kssolv.analysis.matgenlab.core.SiteCollection. ...
                    from_ase_atoms(atoms);
                properties = struct();
                if store_frame_properties && isfield(atoms, "calc")
                    results = atoms.calc;
                    if isfield(results, "results"), results = results.results; end
                    names = string(fieldnames(property_map));
                    for nameIndex = 1:numel(names)
                        aseName = char(names(nameIndex));
                        if isfield(results, aseName)
                            target = char(string(property_map.(aseName)));
                            properties.(target) = results.(aseName);
                        end
                    end
                end
                if any(additional_fields == "temperature")
                    if isfield(atoms, "temperature")
                        properties.temperature = atoms.temperature;
                    elseif isfield(atoms, "info") && ...
                            isfield(atoms.info, "temperature")
                        properties.temperature = atoms.info.temperature;
                    end
                end
                frameProperties{index} = properties;
            end
            periodic = isa(structures{1}, ...
                "kssolv.analysis.matgenlab.core.IStructure");
            if isempty(constant_lattice)
                constant_lattice = true;
                if periodic
                    reference = structures{1}.lattice.matrix;
                    for index = 2:numel(structures)
                        if any(abs(structures{index}.lattice.matrix - ...
                                reference) >= lattice_match_tol, "all")
                            constant_lattice = false;
                            break
                        end
                    end
                end
            end
            if periodic
                obj = kssolv.analysis.matgenlab.core.Trajectory. ...
                    from_structures(structures, logical(constant_lattice), ...
                    frame_properties = frameProperties);
            else
                obj = kssolv.analysis.matgenlab.core.Trajectory. ...
                    from_molecules(structures, ...
                    frame_properties = frameProperties);
            end
        end

        function set_ase_transport(transport)
            if nargin == 0, transport = []; end
            aseTransportStore("set", transport);
        end

        function obj = from_structures(structures, constant_lattice, options)
            arguments
                structures cell
                constant_lattice (1,1) logical = true
                options.time_step = []
                options.frame_properties = []
            end
            if isempty(structures)
                error("KSSOLV:Matgenlab:Trajectory:Empty", ...
                    "At least one structure is required.");
            end
            if constant_lattice
                lattice = structures{1}.lattice.matrix;
            else
                lattice = zeros(numel(structures), 3, 3);
                for index = 1:numel(structures)
                    lattice(index, :, :) = structures{index}.lattice.matrix;
                end
            end
            coordinates = zeros(numel(structures), ...
                structures{1}.num_sites, 3);
            properties = cell(1, numel(structures));
            for index = 1:numel(structures)
                coordinates(index, :, :) = structures{index}.frac_coords;
                properties{index} = structures{index}.site_properties;
            end
            obj = kssolv.analysis.matgenlab.core.Trajectory( ...
                structures{1}.species_and_occu, coordinates, ...
                lattice = lattice, site_properties = properties, ...
                frame_properties = options.frame_properties, ...
                constant_lattice = constant_lattice, ...
                time_step = options.time_step);
        end

        function obj = from_molecules(molecules, options)
            arguments
                molecules cell
                options.time_step = []
                options.frame_properties = []
            end
            if isempty(molecules)
                error("KSSOLV:Matgenlab:Trajectory:Empty", ...
                    "At least one molecule is required.");
            end
            coordinates = zeros(numel(molecules), molecules{1}.num_sites, 3);
            properties = cell(1, numel(molecules));
            for index = 1:numel(molecules)
                coordinates(index, :, :) = molecules{index}.cart_coords;
                properties{index} = molecules{index}.site_properties;
            end
            obj = kssolv.analysis.matgenlab.core.Trajectory( ...
                molecules{1}.species_and_occu, coordinates, ...
                charge = molecules{1}.charge, ...
                spin_multiplicity = molecules{1}.spin_multiplicity, ...
                site_properties = properties, ...
                frame_properties = options.frame_properties, ...
                time_step = options.time_step);
        end

        function obj = from_file(filename, constant_lattice, options)
            arguments
                filename
                constant_lattice (1,1) logical = true
                options.time_step = []
            end
            filename = string(filename);
            if ~isfile(filename)
                error("KSSOLV:Matgenlab:Trajectory:MissingFile", ...
                    "Trajectory file '%s' does not exist.", filename);
            end
            [~, base, extension] = fileparts(filename);
            if contains(upper(base + extension), "XDATCAR")
                [species, coordinates, lattices] = parseXdatcar(filename);
                if constant_lattice
                    latticeValue = squeeze(lattices(1, :, :));
                    for index = 2:size(lattices, 1)
                        if any(abs(squeeze(lattices(index, :, :)) - ...
                                latticeValue) > 1e-10, "all")
                            error("KSSOLV:Matgenlab:Trajectory:LatticeChanged", ...
                                "XDATCAR contains changing lattices but " + ...
                                "constant_lattice is true.");
                        end
                    end
                else
                    latticeValue = lattices;
                end
                obj = kssolv.analysis.matgenlab.core.Trajectory( ...
                    species, coordinates, lattice = latticeValue, ...
                    constant_lattice = constant_lattice, ...
                    time_step = options.time_step);
            elseif startsWith(lower(extension), ".json")
                decoded = kssolv.analysis.matgenlab.util.decode( ...
                    fileread(filename));
                if isa(decoded, ...
                        "kssolv.analysis.matgenlab.core.Trajectory")
                    obj = decoded;
                elseif isstruct(decoded)
                    obj = ...
                        kssolv.analysis.matgenlab.core.Trajectory.from_dict( ...
                            decoded);
                else
                    error("KSSOLV:Matgenlab:Trajectory:DecodedType", ...
                        "JSON file does not contain a Trajectory.");
                end
            elseif endsWith(lower(filename), ".traj")
                error("KSSOLV:Matgenlab:Trajectory:AseRequired", ...
                    "ASE .traj support requires an installed MATLAB ASE adaptor.");
            elseif startsWith(lower(base + extension), "vasprun") && ...
                    contains(lower(extension), ".xml")
                error("KSSOLV:Matgenlab:Trajectory:VasprunRequired", ...
                    "vasprun.xml support requires matgenlab VASP outputs.");
            else
                error("KSSOLV:Matgenlab:Trajectory:UnsupportedFile", ...
                    "Expected XDATCAR, vasprun.xml, .traj, or .json.");
            end

            function [species, frames, latticeFrames] = parseXdatcar(path)
                lines = splitlines(string(fileread(path)));
                lines = lines(strlength(strtrim(lines)) > 0);
                configurationLines = find(startsWith( ...
                    strtrim(lines), "Direct configuration", ...
                    IgnoreCase = true));
                if isempty(configurationLines)
                    error("KSSOLV:Matgenlab:Trajectory:Xdatcar", ...
                        "XDATCAR has no Direct configuration blocks.");
                end
                [symbols, counts, firstLattice] = ...
                    parseHeader(lines, configurationLines(1));
                siteCount = sum(counts);
                species = cell(1, siteCount);
                cursor = 1;
                for symbolIndex = 1:numel(symbols)
                    for siteIndex = ...
                            cursor:cursor + counts(symbolIndex) - 1
                        species{siteIndex} = ...
                            kssolv.analysis.matgenlab.core.Composition( ...
                                {symbols(symbolIndex), 1});
                    end
                    cursor = cursor + counts(symbolIndex);
                end
                frames = zeros(numel(configurationLines), siteCount, 3);
                latticeFrames = zeros(numel(configurationLines), 3, 3);
                for frameIndex = 1:numel(configurationLines)
                    lineIndex = configurationLines(frameIndex);
                    if frameIndex == 1 || ...
                            lineIndex - configurationLines(frameIndex - 1) > ...
                            siteCount + 1
                        [frameSymbols, frameCounts, latticeValue] = ...
                            parseHeader(lines, lineIndex);
                        if ~isequal(frameSymbols, symbols) || ...
                                ~isequal(frameCounts, counts)
                            error("KSSOLV:Matgenlab:Trajectory:XdatcarSpecies", ...
                                "XDATCAR species change between frames.");
                        end
                    else
                        latticeValue = firstLattice;
                    end
                    latticeFrames(frameIndex, :, :) = latticeValue;
                    if lineIndex + siteCount > numel(lines)
                        error("KSSOLV:Matgenlab:Trajectory:XdatcarTruncated", ...
                            "XDATCAR coordinate block is truncated.");
                    end
                    for siteIndex = 1:siteCount
                        values = sscanf(lines(lineIndex + siteIndex), ...
                            "%f %f %f");
                        if numel(values) ~= 3
                            error("KSSOLV:Matgenlab:Trajectory:XdatcarCoordinate", ...
                                "Invalid XDATCAR coordinate line.");
                        end
                        frames(frameIndex, siteIndex, :) = values;
                    end
                end
            end

            function [symbols, counts, latticeValue] = ...
                    parseHeader(lines, configurationLine)
                headerStart = configurationLine - 7;
                if headerStart < 1
                    error("KSSOLV:Matgenlab:Trajectory:XdatcarHeader", ...
                        "XDATCAR header is incomplete.");
                end
                scale = str2double(strtrim(lines(headerStart + 1)));
                latticeValue = zeros(3);
                for row = 1:3
                    values = sscanf(lines(headerStart + 1 + row), ...
                        "%f %f %f");
                    if numel(values) ~= 3
                        error("KSSOLV:Matgenlab:Trajectory:XdatcarLattice", ...
                            "Invalid XDATCAR lattice line.");
                    end
                    latticeValue(row, :) = values;
                end
                latticeValue = latticeValue * scale;
                symbols = split(strtrim(lines(headerStart + 5))).';
                counts = sscanf(lines(headerStart + 6), "%d").';
                if numel(symbols) ~= numel(counts)
                    error("KSSOLV:Matgenlab:Trajectory:XdatcarSpecies", ...
                        "XDATCAR symbol and count lines disagree.");
                end
            end
        end

        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.core.Trajectory( ...
                value.species, value.coords, ...
                charge = field(value, "charge", []), ...
                spin_multiplicity = field(value, "spin_multiplicity", []), ...
                lattice = field(value, "lattice", []), ...
                site_properties = field(value, "site_properties", []), ...
                frame_properties = field(value, "frame_properties", []), ...
                constant_lattice = field(value, "constant_lattice", true), ...
                time_step = field(value, "time_step", []), ...
                coords_are_displacement = ...
                    field(value, "coords_are_displacement", false), ...
                base_positions = field(value, "base_positions", []));

            function output = field(input, name, defaultValue)
                if isfield(input, name), output = input.(name);
                else, output = defaultValue;
                end
            end
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core.Trajectory.from_dict(value);
        end
    end

    methods (Access = private)
        function validateProperties(obj)
            if iscell(obj.site_properties) && ...
                    numel(obj.site_properties) ~= length(obj)
                error("KSSOLV:Matgenlab:Trajectory:SitePropertiesLength", ...
                    "Frame-varying site_properties require one entry per frame.");
            end
            if iscell(obj.frame_properties) && ...
                    numel(obj.frame_properties) ~= length(obj)
                error("KSSOLV:Matgenlab:Trajectory:FramePropertiesLength", ...
                    "frame_properties require one entry per frame.");
            end
        end

        function value = getSiteProperties(obj, frames)
            if isempty(obj.site_properties), value = struct();
            elseif iscell(obj.site_properties)
                selected = obj.site_properties(frames);
                if isscalar(frames), value = selected{1}; else, value = selected; end
            else, value = obj.site_properties;
            end
        end

        function value = getFrameProperties(obj, frames)
            if isempty(obj.frame_properties), value = struct();
            elseif iscell(obj.frame_properties)
                selected = obj.frame_properties(frames);
                if isscalar(frames), value = selected{1}; else, value = selected; end
            else, value = obj.frame_properties;
            end
        end
    end

    methods (Static, Access = private)
        function value = normalizeSpecies(input)
            if iscell(input), value = reshape(input, 1, []);
            elseif isstring(input), value = num2cell(reshape(input, 1, []));
            elseif ischar(input), value = {input};
            else, value = num2cell(input);
            end
        end

        function value = normalizeLattice(input)
            if isa(input, "kssolv.analysis.matgenlab.core.Lattice")
                value = input.matrix;
            elseif iscell(input)
                value = zeros(numel(input), 3, 3);
                for index = 1:numel(input)
                    if isa(input{index}, ...
                            "kssolv.analysis.matgenlab.core.Lattice")
                        value(index, :, :) = input{index}.matrix;
                    else
                        value(index, :, :) = input{index};
                    end
                end
            else
                value = double(input);
            end
            if ~(isequal(size(value), [3, 3]) || ...
                    (ndims(value) == 3 && ...
                    isequal(size(value, 2), 3) && isequal(size(value, 3), 3)))
                error("KSSOLV:Matgenlab:Trajectory:LatticeShape", ...
                    "lattice must have shape 3-by-3 or M-by-3-by-3.");
            end
        end
    end
end

function value = aseTransportStore(action, replacement)
persistent transport
if nargin > 1 && action == "set", transport = replacement; end
value = transport;
end
