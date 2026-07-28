classdef Poscar
    %POSCAR Read and write VASP POSCAR and CONTCAR files.
    %
    % This is a native MATLAB implementation of pymatgen-core v2026.7.24
    % pymatgen.io.vasp.inputs.Poscar. Production code does not invoke Python.

    properties (SetAccess = private)
        structure
        comment (1,1) string = ""
        true_names (1,1) logical = true
        temperature (1,1) double = -1
    end

    properties (Dependent)
        selective_dynamics
        velocities
        predictor_corrector
        predictor_corrector_preamble
        lattice_velocities
    end

    properties (Dependent, SetAccess = private)
        site_symbols
        natoms
    end

    properties (Access = private)
        selectiveDynamics_ = []
        velocities_ = []
        predictorCorrector_ = []
        predictorCorrectorPreamble_ (1,1) string = ""
        latticeVelocities_ = []
    end

    methods
        function obj = Poscar(structure, varargin)
            if nargin == 0
                return
            end
            if ~isa(structure, "kssolv.analysis.matgenlab.core.IStructure")
                error("KSSOLV:Matgenlab:Poscar:StructureType", ...
                    "structure must be a matgenlab Structure or IStructure.");
            end
            if ~structure.is_ordered
                error("KSSOLV:Matgenlab:Poscar:DisorderedStructure", ...
                    "Disordered structure with partial occupancies cannot be converted into POSCAR.");
            end

            options = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                parseConstructorOptions(varargin);
            numberSites = structure.num_sites;
            selective = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                validateSiteMatrix( ...
                options.selective_dynamics, numberSites, ...
                "selective_dynamics", true);
            velocities = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                validateSiteMatrix( ...
                options.velocities, numberSites, "velocities", false);
            predictor = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                validatePredictorCorrector( ...
                options.predictor_corrector, numberSites);
            latticeVelocity = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                validateLatticeVelocities( ...
                options.lattice_velocities);

            if ~isempty(selective) && all(selective, "all")
                selective = [];
            end
            if ~isempty(velocities) && ~any(velocities, "all")
                velocities = [];
            end
            if ~isempty(predictor) && ~any(predictor, "all")
                predictor = [];
            end
            if ~isempty(latticeVelocity) && ~any(latticeVelocity, "all")
                latticeVelocity = [];
            end

            siteProperties = struct();
            if ~isempty(selective)
                siteProperties.selective_dynamics = ...
                    kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    rowsToCells(selective);
            end
            if ~isempty(velocities)
                siteProperties.velocities = ...
                    kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    rowsToCells(velocities);
            end
            if ~isempty(predictor)
                values = cell(1, numberSites);
                for siteIndex = 1:numberSites
                    values{siteIndex} = ...
                        reshape(predictor(siteIndex, :, :), 3, 3);
                end
                siteProperties.predictor_corrector = values;
            end

            copied = kssolv.analysis.matgenlab.core.Structure( ...
                structure.lattice, structure.species_and_occu, ...
                structure.frac_coords, ...
                site_properties = siteProperties, labels = structure.labels, ...
                properties = structure.structure_properties);
            if options.sort_structure
                copied = copied.get_sorted_structure();
            end

            obj.structure = copied;
            obj.selectiveDynamics_ = ...
                kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                siteMatrixFromStructure( ...
                copied, "selective_dynamics", true);
            obj.velocities_ = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                siteMatrixFromStructure( ...
                copied, "velocities", false);
            obj.predictorCorrector_ = ...
                kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                predictorFromStructure(copied);
            obj.predictorCorrectorPreamble_ = ...
                kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                validatePreamble(options.predictor_corrector_preamble);
            obj.latticeVelocities_ = latticeVelocity;
            obj.true_names = logical(options.true_names);
            if isempty(options.comment)
                obj.comment = string(structure.formula);
            else
                obj.comment = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    validateComment(options.comment);
            end
        end

        function value = get.selective_dynamics(obj)
            value = obj.selectiveDynamics_;
        end

        function obj = set.selective_dynamics(obj, value)
            value = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                validateSiteMatrix( ...
                value, obj.structure.num_sites, ...
                "selective_dynamics", true);
            obj.selectiveDynamics_ = value;
            obj = obj.syncSiteProperty("selective_dynamics", value);
        end

        function value = get.velocities(obj)
            value = obj.velocities_;
        end

        function obj = set.velocities(obj, value)
            value = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                validateSiteMatrix( ...
                value, obj.structure.num_sites, "velocities", false);
            obj.velocities_ = value;
            obj = obj.syncSiteProperty("velocities", value);
        end

        function value = get.predictor_corrector(obj)
            value = obj.predictorCorrector_;
        end

        function obj = set.predictor_corrector(obj, value)
            value = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                validatePredictorCorrector( ...
                value, obj.structure.num_sites);
            obj.predictorCorrector_ = value;
            obj = obj.syncPredictorProperty(value);
        end

        function value = get.predictor_corrector_preamble(obj)
            if obj.predictorCorrectorPreamble_ == ""
                value = [];
            else
                value = obj.predictorCorrectorPreamble_;
            end
        end

        function obj = set.predictor_corrector_preamble(obj, value)
            obj.predictorCorrectorPreamble_ = ...
                kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                validatePreamble(value);
        end

        function value = get.lattice_velocities(obj)
            value = obj.latticeVelocities_;
        end

        function obj = set.lattice_velocities(obj, value)
            obj.latticeVelocities_ = ...
                kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                validateLatticeVelocities(value);
        end

        function value = get.site_symbols(obj)
            symbols = strings(1, obj.structure.num_sites);
            for index = 1:obj.structure.num_sites
                symbols(index) = obj.structure(index).specie.symbol;
            end
            if isempty(symbols)
                value = strings(1, 0);
                return
            end
            value = symbols([true, symbols(2:end) ~= symbols(1:end-1)]);
        end

        function value = get.natoms(obj)
            symbols = strings(1, obj.structure.num_sites);
            for index = 1:obj.structure.num_sites
                symbols(index) = obj.structure(index).specie.symbol;
            end
            if isempty(symbols)
                value = zeros(1, 0);
                return
            end
            starts = find([true, symbols(2:end) ~= symbols(1:end-1)]);
            value = diff([starts, numel(symbols) + 1]);
        end

        function value = get_str(obj, varargin)
            options = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                parseGetStrOptions(varargin);
            significantFigures = options.significant_figures;
            format = sprintf("%%%d.%df", ...
                significantFigures + 5, significantFigures);

            lattice = obj.structure.lattice.matrix;
            if det(lattice) < 0
                lattice = -lattice;
            end

            lines = strings(0, 1);
            lines(end + 1) = obj.comment;
            lines(end + 1) = "1.0";
            for row = 1:3
                formatted = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    formatRow(lattice(row, :), format);
                lines(end + 1) = formatted; %#ok<AGROW>
            end
            if obj.true_names && ~options.vasp4_compatible
                lines(end + 1) = strjoin(obj.site_symbols, " ");
            end
            lines(end + 1) = strjoin(string(obj.natoms), " ");
            if ~isempty(obj.selectiveDynamics_)
                lines(end + 1) = "Selective dynamics";
            end
            if options.direct
                lines(end + 1) = "direct";
                coordinates = obj.structure.frac_coords;
            else
                lines(end + 1) = "cartesian";
                coordinates = obj.structure.cart_coords;
            end

            for siteIndex = 1:obj.structure.num_sites
                line = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    formatRow(coordinates(siteIndex, :), format);
                if ~isempty(obj.selectiveDynamics_)
                    flags = repmat("F", 1, 3);
                    flags(obj.selectiveDynamics_(siteIndex, :)) = "T";
                    line = line + " " + strjoin(flags, " ");
                end
                line = line + " " + ...
                    obj.structure(siteIndex).species_string;
                lines(end + 1) = line; %#ok<AGROW>
            end

            if ~isempty(obj.latticeVelocities_)
                lines(end + 1) = "Lattice velocities and vectors";
                lines(end + 1) = "  1";
                for row = 1:6
                    tokens = strings(1, 3);
                    for column = 1:3
                        tokens(column) = sprintf(" % .7E", ...
                            obj.latticeVelocities_(row, column));
                    end
                    lines(end + 1) = strjoin(tokens, " "); %#ok<AGROW>
                end
            end

            if ~isempty(obj.velocities_)
                lines(end + 1) = "";
                for row = 1:size(obj.velocities_, 1)
                    formatted = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                        formatRow(obj.velocities_(row, :), format);
                    lines(end + 1) = formatted; %#ok<AGROW>
                end
            end

            if ~isempty(obj.predictorCorrector_)
                if obj.predictorCorrectorPreamble_ == ""
                    warning("KSSOLV:Matgenlab:Poscar:MissingPredictorPreamble", ...
                        "Preamble information missing or corrupt. Writing " + ...
                        "Poscar with no predictor corrector data.");
                else
                    lines(end + 1) = "";
                    preambleLines = splitlines( ...
                        obj.predictorCorrectorPreamble_);
                    for preambleIndex = 1:numel(preambleLines)
                        lines(end + 1) = preambleLines(preambleIndex); %#ok<AGROW>
                    end
                    for derivative = 1:3
                        for siteIndex = 1:obj.structure.num_sites
                            row = reshape(obj.predictorCorrector_( ...
                                siteIndex, derivative, :), 1, 3);
                            formatted = ...
                                kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                                formatRow(row, format);
                            lines(end + 1) = formatted; %#ok<AGROW>
                        end
                    end
                end
            end
            value = strjoin(lines, newline) + newline;
        end

        function value = get_string(obj, varargin)
            value = obj.get_str(varargin{:});
        end

        function value = char(obj)
            value = char(obj.get_str());
        end

        function value = string(obj)
            value = obj.get_str();
        end

        function write_file(obj, filename, varargin)
            text = obj.get_str(varargin{:});
            fid = fopen(filename, "w", "n", "UTF-8");
            if fid < 0
                error("KSSOLV:Matgenlab:Poscar:Open", ...
                    "Cannot open '%s' for writing.", filename);
            end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, char(text), "char");
            clear cleanup
        end

        function value = as_dict(obj)
            value = struct( ...
                "x_module", "pymatgen.io.vasp.inputs", ...
                "x_class", "Poscar", ...
                "structure", obj.structure.as_dict(), ...
                "true_names", obj.true_names, ...
                "selective_dynamics", obj.selectiveDynamics_, ...
                "velocities", obj.velocities_, ...
                "predictor_corrector", obj.predictorCorrector_, ...
                "comment", obj.comment);
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end

        function obj = set_temperature(obj, temperature, seed)
            if nargin < 3
                stream = RandStream.getGlobalStream();
            else
                if ~isscalar(seed) || ~isnumeric(seed) || ~isfinite(seed)
                    error("KSSOLV:Matgenlab:Poscar:RandomSeed", ...
                        "seed must be a finite numeric scalar.");
                end
                stream = RandStream("mt19937ar", Seed = double(seed));
            end
            if ~isscalar(temperature) || ~isnumeric(temperature) || ...
                    ~isfinite(temperature) || temperature < 0
                error("KSSOLV:Matgenlab:Poscar:Temperature", ...
                    "temperature must be a finite nonnegative scalar in kelvin.");
            end
            numberSites = obj.structure.num_sites;
            if numberSites < 2
                error("KSSOLV:Matgenlab:Poscar:TemperatureDegreesOfFreedom", ...
                    "At least two sites are required to initialize velocities.");
            end

            velocities = randn(stream, numberSites, 3);
            masses = zeros(numberSites, 1);
            atomicMassUnit = 1.66053906660e-27;
            for siteIndex = 1:numberSites
                masses(siteIndex) = ...
                    obj.structure(siteIndex).specie.atomic_mass * ...
                    atomicMassUnit;
            end
            velocities = velocities - ...
                mean(masses .* velocities, 1) / mean(masses);
            velocities = velocities ./ sqrt(masses);

            energy = sum(0.5 * masses .* sum(velocities .^ 2, 2));
            boltzmann = 1.380649e-23;
            degreesFreedom = 3 * numberSites - 3;
            scale = sqrt(temperature * degreesFreedom / ...
                (2 * energy / boltzmann));
            velocities = velocities * scale * 1e-5;

            obj.temperature = double(temperature);
            obj.selectiveDynamics_ = [];
            obj.predictorCorrector_ = [];
            obj = obj.syncSiteProperty("selective_dynamics", []);
            obj = obj.syncSiteProperty("predictor_corrector", []);
            obj.velocities = velocities;
        end
    end

    methods (Static)
        function obj = from_str(data, varargin)
            parseOptions = struct("default_names", [], ...
                "read_velocities", true);
            parseOptions = ...
                kssolv.analysis.matgenlab.io.vasp.Poscar.parseOptions( ...
                varargin, ["default_names", "read_velocities"], ...
                parseOptions);
            default_names = parseOptions.default_names;
            read_velocities = parseOptions.read_velocities;
            if ~(ischar(data) || (isstring(data) && isscalar(data)))
                error("KSSOLV:Matgenlab:Poscar:InputType", ...
                    "POSCAR data must be a character vector or string scalar.");
            end
            if ~isscalar(read_velocities) || ~islogical(read_velocities)
                error("KSSOLV:Matgenlab:Poscar:ReadVelocities", ...
                    "read_velocities must be a logical scalar.");
            end

            data = char(string(data));
            data = regexprep(data, "\s+$", "");
            if isempty(data)
                error("KSSOLV:Matgenlab:Poscar:Empty", "Empty POSCAR");
            end
            chunks = regexp(data, "\r?\n\s*\r?\n", "split");
            if isempty(chunks)
                error("KSSOLV:Matgenlab:Poscar:Empty", "Empty POSCAR");
            end
            if read_velocities && numel(chunks) > 3
                error("KSSOLV:Matgenlab:Poscar:ExtraSections", ...
                    "POSCAR contains unsupported extra frames or data sections.");
            end

            rawLines = regexp(chunks{1}, "\r?\n", "split");
            lines = strings(numel(rawLines), 1);
            for index = 1:numel(rawLines)
                line = string(rawLines{index});
                hash = strfind(line, "#");
                if ~isempty(hash)
                    line = extractBefore(line, hash(1));
                end
                lines(index) = strtrim(line);
            end
            if numel(lines) < 7
                error("KSSOLV:Matgenlab:Poscar:Truncated", ...
                    "POSCAR header is truncated.");
            end

            comment = lines(1);
            scale = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                parseScalar(lines(2), "scale factor");
            lattice = zeros(3);
            for row = 1:3
                lattice(row, :) = ...
                    kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    parseNumericRow( ...
                    lines(row + 2), 3, sprintf("lattice row %d", row));
            end
            if scale < 0
                originalVolume = abs(det(lattice));
                if originalVolume <= eps(max(1, norm(lattice, "fro")))^3
                    error("KSSOLV:Matgenlab:Poscar:SingularLattice", ...
                        "A negative scale requires a nonsingular lattice.");
                end
                lattice = lattice * ((-scale / originalVolume) ^ (1 / 3));
            else
                lattice = lattice * scale;
            end

            symbols = strings(1, 0);
            [counts, validCounts] = ...
                kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                tryParseCounts(lines(6));
            vasp5or6 = false;
            if validCounts
                positionLine = 7;
            else
                vasp5or6 = true;
                numberSymbolLines = 0;
                for offset = 1:10
                    candidate = 6 + offset;
                    if candidate > numel(lines)
                        break
                    end
                    [~, isCountLine] = ...
                        kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                        tryParseCounts(lines(candidate));
                    if isCountLine
                        numberSymbolLines = offset;
                        break
                    end
                end
                if numberSymbolLines == 0
                    error("KSSOLV:Matgenlab:Poscar:AtomCounts", ...
                        "Cannot locate POSCAR atom counts.");
                end
                for lineIndex = 6:(5 + numberSymbolLines)
                    tokens = split(lines(lineIndex));
                    tokens(tokens == "") = [];
                    symbols = [symbols, tokens.']; %#ok<AGROW>
                end
                symbols = arrayfun( ...
                    @kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    cleanVasp6Symbol, symbols);
                counts = zeros(1, 0);
                for lineIndex = (6 + numberSymbolLines): ...
                        (5 + 2 * numberSymbolLines)
                    [lineCounts, isCountLine] = ...
                        kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                        tryParseCounts(lines(lineIndex));
                    if ~isCountLine
                        error("KSSOLV:Matgenlab:Poscar:AtomCounts", ...
                            "Invalid atom-count line %d.", lineIndex);
                    end
                    counts = [counts, lineCounts]; %#ok<AGROW>
                end
                if numel(symbols) ~= numel(counts)
                    error("KSSOLV:Matgenlab:Poscar:SymbolCountMismatch", ...
                        "Element-symbol and atom-count groups must have equal length.");
                end
                positionLine = 6 + 2 * numberSymbolLines;
            end
            if any(counts < 0) || isempty(counts)
                error("KSSOLV:Matgenlab:Poscar:AtomCounts", ...
                    "Atom counts must be nonnegative integers.");
            end
            if positionLine > numel(lines)
                error("KSSOLV:Matgenlab:Poscar:Truncated", ...
                    "POSCAR coordinate mode is missing.");
            end

            mode = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                firstToken(lines(positionLine));
            hasSelective = startsWith(lower(mode), "s");
            if hasSelective
                positionLine = positionLine + 1;
                if positionLine > numel(lines)
                    error("KSSOLV:Matgenlab:Poscar:Truncated", ...
                        "POSCAR coordinate mode is missing after selective dynamics.");
                end
                mode = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    firstToken(lines(positionLine));
            end
            cartesian = startsWith(lower(mode), ["c", "k"]);
            numberSites = sum(counts);
            if positionLine + numberSites > numel(lines)
                error("KSSOLV:Matgenlab:Poscar:Truncated", ...
                    "POSCAR contains fewer coordinate rows than atom counts require.");
            end

            defaultNames = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                normalizeNames(default_names);
            atomicSymbols = strings(1, 0);
            if ~isempty(symbols)
                for index = 1:numel(counts)
                    atomicSymbols = [atomicSymbols, ...
                        repmat(symbols(index), 1, counts(index))]; %#ok<AGROW>
                end
            end
            if ~isempty(defaultNames)
                if numel(counts) > numel(defaultNames)
                    error("KSSOLV:Matgenlab:Poscar:DefaultNamesLength", ...
                        "default_names has fewer elements than POSCAR.");
                end
                compareCount = min(numel(symbols), numel(defaultNames));
                overwrite = isempty(symbols) || ...
                    any(defaultNames(1:compareCount) ~= symbols(1:compareCount));
                if overwrite
                    vasp5or6 = true;
                    atomicSymbols = strings(1, 0);
                    for index = 1:numel(counts)
                        atomicSymbols = [atomicSymbols, ...
                            repmat(defaultNames(index), 1, counts(index))]; %#ok<AGROW>
                    end
                    warning("KSSOLV:Matgenlab:Poscar:ElementsOverwritten", ...
                        "Elements in POSCAR would be overwritten by default_names.");
                end
            end

            if ~vasp5or6
                symbolColumn = 4;
                if hasSelective, symbolColumn = 7; end
                inferred = strings(1, numberSites);
                validInference = true;
                for siteIndex = 1:numberSites
                    tokens = split(lines(positionLine + siteIndex));
                    tokens(tokens == "") = [];
                    if numel(tokens) < symbolColumn || ...
                            ~kssolv.analysis.matgenlab.core.Element. ...
                            is_valid_symbol(tokens(symbolColumn))
                        validInference = false;
                        break
                    end
                    inferred(siteIndex) = tokens(symbolColumn);
                end
                if validInference
                    atomicSymbols = inferred;
                    vasp5or6 = true;
                else
                    atomicSymbols = strings(1, 0);
                    for group = 1:numel(counts)
                        element = ...
                            kssolv.analysis.matgenlab.core.Element.from_Z(group);
                        atomicSymbols = [atomicSymbols, ...
                            repmat(element.symbol, 1, counts(group))]; %#ok<AGROW>
                    end
                    warning("KSSOLV:Matgenlab:Poscar:UnknownElements", ...
                        "Elements in POSCAR cannot be determined. " + ...
                        "Defaulting to false names.");
                end
            end
            if numel(atomicSymbols) ~= numberSites
                error("KSSOLV:Matgenlab:Poscar:SymbolCountMismatch", ...
                    "Expanded element symbols do not match the number of sites.");
            end
            for index = 1:numel(atomicSymbols)
                if ~kssolv.analysis.matgenlab.core.Element. ...
                        is_valid_symbol(atomicSymbols(index))
                    error("KSSOLV:Matgenlab:Poscar:InvalidElement", ...
                        "Invalid element symbol '%s'.", atomicSymbols(index));
                end
            end

            coordinates = zeros(numberSites, 3);
            selective = [];
            if hasSelective
                selective = false(numberSites, 3);
            end
            for siteIndex = 1:numberSites
                line = lines(positionLine + siteIndex);
                tokens = split(line);
                tokens(tokens == "") = [];
                if numel(tokens) < 3
                    tokens = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                        repairConcatenatedCoordinates(tokens);
                end
                if numel(tokens) < 3
                    error("KSSOLV:Matgenlab:Poscar:Coordinate", ...
                        "Cannot parse coordinates on site line %d.", siteIndex);
                end
                coordinates(siteIndex, :) = ...
                    kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    parseNumericTokens( ...
                    tokens(1:3), sprintf("coordinate row %d", siteIndex));
                if cartesian
                    coordinates(siteIndex, :) = ...
                        coordinates(siteIndex, :) * scale;
                end
                if hasSelective
                    flags = strings(1, 0);
                    if numel(tokens) >= 6
                        flags = tokens(4:6).';
                    end
                    if numel(flags) ~= 3 || any(~ismember(flags, ["T", "F"]))
                        warning("KSSOLV:Matgenlab:Poscar:SelectiveDynamics", ...
                            "Selective dynamics values must be either 'T' or 'F'.");
                    end
                    padded = repmat("", 1, 3);
                    padded(1:min(3, numel(flags))) = ...
                        flags(1:min(3, numel(flags)));
                    selective(siteIndex, :) = padded == "T"; %#ok<AGROW>
                    if atomicSymbols(siteIndex) == "F" && ...
                            numel(tokens) >= 7 && any(tokens(4:7) == "F")
                        warning("KSSOLV:Matgenlab:Poscar:FluorineSelectiveDynamics", ...
                            "Selective dynamics toggled with Fluorine element " + ...
                            "detected. Make sure the 4th-6th entry each " + ...
                            "position line is selective dynamics info.");
                    end
                end
            end
            if ~isempty(selective) && all(selective, "all")
                warning("KSSOLV:Matgenlab:Poscar:AllDegreesRelaxed", ...
                    "Ignoring selective dynamics tag, as no ionic degrees " + ...
                    "of freedom were fixed.");
            end

            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, atomicSymbols, coordinates, ...
                to_unit_cell = false, validate_proximity = false, ...
                coords_are_cartesian = cartesian);

            latticeVelocities = [];
            velocities = [];
            predictor = [];
            preamble = "";
            if read_velocities
                afterCoordinates = positionLine + numberSites;
                if numel(lines) > afterCoordinates && ...
                        startsWith(lower(lines(afterCoordinates + 1)), "l")
                    if numel(lines) < afterCoordinates + 8
                        error("KSSOLV:Matgenlab:Poscar:LatticeVelocities", ...
                            "Lattice-velocity section is truncated.");
                    end
                    latticeVelocities = zeros(6, 3);
                    for row = 1:6
                        latticeVelocities(row, :) = ...
                            kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                            parseNumericRow( ...
                            lines(afterCoordinates + 2 + row), 3, ...
                            sprintf("lattice velocity row %d", row));
                    end
                end
                if numel(chunks) > 1
                    velocityLines = ...
                        kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                        nonemptyLines(chunks{2});
                    velocities = zeros(numel(velocityLines), 3);
                    for row = 1:numel(velocityLines)
                        velocities(row, :) = ...
                            kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                            parseNumericRow( ...
                            velocityLines(row), 3, ...
                            sprintf("velocity row %d", row));
                    end
                    velocities = ...
                        kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                        validateSiteMatrix( ...
                        velocities, numberSites, "velocities", false);
                end
                if numel(chunks) > 2
                    predictorLines = ...
                        kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                        nonemptyLines(chunks{3});
                    if numel(predictorLines) ~= 3 + 3 * numberSites
                        error("KSSOLV:Matgenlab:Poscar:PredictorCorrector", ...
                            "Predictor-corrector section has an invalid length.");
                    end
                    preamble = strjoin(predictorLines(1:3), newline);
                    predictor = zeros(numberSites, 3, 3);
                    dataLines = predictorLines(4:end);
                    for derivative = 1:3
                        for siteIndex = 1:numberSites
                            row = ...
                                kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                                parseNumericRow( ...
                                dataLines((derivative - 1) * numberSites + ...
                                siteIndex), 3, ...
                                "predictor-corrector row");
                            predictor(siteIndex, derivative, :) = row;
                        end
                    end
                end
            end

            obj = kssolv.analysis.matgenlab.io.vasp.Poscar( ...
                structure, comment = comment, ...
                selective_dynamics = selective, ...
                true_names = vasp5or6, velocities = velocities, ...
                predictor_corrector = predictor, ...
                predictor_corrector_preamble = preamble, ...
                lattice_velocities = latticeVelocities);
        end

        function obj = from_file(filename, varargin)
            parseOptions = struct("check_for_potcar", true, ...
                "read_velocities", true);
            parseOptions = ...
                kssolv.analysis.matgenlab.io.vasp.Poscar.parseOptions( ...
                varargin, ["check_for_potcar", "read_velocities"], ...
                parseOptions);
            check_for_potcar = parseOptions.check_for_potcar;
            read_velocities = parseOptions.read_velocities;
            filename = string(filename);
            if ~isscalar(filename) || ~isfile(filename)
                error("KSSOLV:Matgenlab:Poscar:MissingFile", ...
                    "POSCAR file '%s' does not exist.", filename);
            end
            if ~isscalar(check_for_potcar) || ~islogical(check_for_potcar)
                error("KSSOLV:Matgenlab:Poscar:CheckPotcar", ...
                    "check_for_potcar must be a logical scalar.");
            end
            names = [];
            configuredChecks = ...
                kssolv.analysis.matgenlab.core.Settings.get( ...
                "PMG_POTCAR_CHECKS", true);
            checksEnabled = ~(islogical(configuredChecks) && ...
                isscalar(configuredChecks) && ~configuredChecks);
            if check_for_potcar && checksEnabled
                names = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    namesFromNeighboringPotcar(filename);
            end
            obj = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str( ...
                kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                readTextFile(filename), default_names = names, ...
                read_velocities = read_velocities);
        end

        function obj = from_dict(value)
            structure = ...
                kssolv.analysis.matgenlab.core.Structure.from_dict( ...
                value.structure);
            selective = [];
            velocities = [];
            predictor = [];
            if isfield(value, "selective_dynamics")
                selective = value.selective_dynamics;
            end
            if isfield(value, "velocities"), velocities = value.velocities; end
            if isfield(value, "predictor_corrector")
                predictor = value.predictor_corrector;
            end
            obj = kssolv.analysis.matgenlab.io.vasp.Poscar( ...
                structure, comment = value.comment, ...
                selective_dynamics = selective, ...
                true_names = logical(value.true_names), ...
                velocities = velocities, ...
                predictor_corrector = predictor);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.io.vasp.Poscar.from_dict(value);
        end
    end

    methods (Access = private)
        function obj = syncSiteProperty(obj, name, value)
            if isfield(obj.structure.site_properties, name)
                obj.structure = obj.structure.remove_site_property(name);
            end
            if ~isempty(value)
                obj.structure = obj.structure.add_site_property( ...
                    name, kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    rowsToCells(value));
            end
        end

        function obj = syncPredictorProperty(obj, value)
            name = "predictor_corrector";
            if isfield(obj.structure.site_properties, name)
                obj.structure = obj.structure.remove_site_property(name);
            end
            if ~isempty(value)
                values = cell(1, obj.structure.num_sites);
                for siteIndex = 1:obj.structure.num_sites
                    values{siteIndex} = reshape(value(siteIndex, :, :), 3, 3);
                end
                obj.structure = ...
                    obj.structure.add_site_property(name, values);
            end
        end
    end

    methods (Static, Access = private)
        function options = parseConstructorOptions(values)
            names = ["comment", "selective_dynamics", "true_names", ...
                "velocities", "predictor_corrector", ...
                "predictor_corrector_preamble", "lattice_velocities", ...
                "sort_structure"];
            options = struct( ...
                "comment", [], ...
                "selective_dynamics", [], ...
                "true_names", true, ...
                "velocities", [], ...
                "predictor_corrector", [], ...
                "predictor_corrector_preamble", [], ...
                "lattice_velocities", [], ...
                "sort_structure", false);
            options = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                parseOptions(values, names, options);
            if ~isscalar(options.true_names) || ~islogical(options.true_names)
                error("KSSOLV:Matgenlab:Poscar:TrueNames", ...
                    "true_names must be a logical scalar.");
            end
            if ~isscalar(options.sort_structure) || ...
                    ~islogical(options.sort_structure)
                error("KSSOLV:Matgenlab:Poscar:SortStructure", ...
                    "sort_structure must be a logical scalar.");
            end
        end

        function options = parseGetStrOptions(values)
            names = ["direct", "vasp4_compatible", "significant_figures"];
            options = struct("direct", true, ...
                "vasp4_compatible", false, "significant_figures", 16);
            options = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                parseOptions(values, names, options);
            if ~isscalar(options.direct) || ~islogical(options.direct)
                error("KSSOLV:Matgenlab:Poscar:Direct", ...
                    "direct must be a logical scalar.");
            end
            if ~isscalar(options.vasp4_compatible) || ...
                    ~islogical(options.vasp4_compatible)
                error("KSSOLV:Matgenlab:Poscar:Vasp4Compatible", ...
                    "vasp4_compatible must be a logical scalar.");
            end
            if ~isscalar(options.significant_figures) || ...
                    ~isnumeric(options.significant_figures) || ...
                    options.significant_figures < 0 || ...
                    options.significant_figures ~= ...
                    fix(options.significant_figures)
                error("KSSOLV:Matgenlab:Poscar:SignificantFigures", ...
                    "significant_figures must be a nonnegative integer.");
            end
            options.direct = logical(options.direct);
            options.vasp4_compatible = logical(options.vasp4_compatible);
            options.significant_figures = ...
                double(options.significant_figures);
        end

        function options = parseOptions(values, orderedNames, options)
            positionalIndex = 1;
            index = 1;
            while index <= numel(values)
                value = values{index};
                isName = (ischar(value) || ...
                    (isstring(value) && isscalar(value))) && ...
                    any(string(value) == orderedNames);
                if isName
                    if index == numel(values)
                        error("KSSOLV:Matgenlab:Poscar:NameValue", ...
                            "Option '%s' is missing its value.", value);
                    end
                    name = char(string(value));
                    options.(name) = values{index + 1};
                    index = index + 2;
                else
                    if positionalIndex > numel(orderedNames)
                        error("KSSOLV:Matgenlab:Poscar:Arguments", ...
                            "Too many positional arguments.");
                    end
                    options.(char(orderedNames(positionalIndex))) = value;
                    positionalIndex = positionalIndex + 1;
                    index = index + 1;
                end
            end
        end

        function value = validateSiteMatrix(value, numberSites, name, logicalData)
            if isempty(value)
                value = [];
                return
            end
            if logicalData
                if ~(islogical(value) || isnumeric(value))
                    error("KSSOLV:Matgenlab:Poscar:SiteArray", ...
                        "%s must be a logical N-by-3 array.", name);
                end
                if isnumeric(value) && any(~ismember(value, [0, 1]), "all")
                    error("KSSOLV:Matgenlab:Poscar:SiteArray", ...
                        "%s must contain only logical values.", name);
                end
                value = logical(value);
            elseif ~isnumeric(value)
                error("KSSOLV:Matgenlab:Poscar:SiteArray", ...
                    "%s must be a numeric N-by-3 array.", name);
            else
                value = double(value);
            end
            if ~isequal(size(value), [numberSites, 3])
                error("KSSOLV:Matgenlab:Poscar:SiteArrayLength", ...
                    "%s array must be same length as the structure.", name);
            end
            if ~logicalData && any(~isfinite(value), "all")
                error("KSSOLV:Matgenlab:Poscar:SiteArrayFinite", ...
                    "%s must contain only finite values.", name);
            end
        end

        function value = validatePredictorCorrector(value, numberSites)
            if isempty(value)
                value = [];
                return
            end
            if ~isnumeric(value) || ...
                    ~isequal(size(value), [numberSites, 3, 3]) || ...
                    any(~isfinite(value), "all")
                error("KSSOLV:Matgenlab:Poscar:PredictorCorrector", ...
                    "predictor_corrector must be a finite N-by-3-by-3 array.");
            end
            value = double(value);
        end

        function value = validateLatticeVelocities(value)
            if isempty(value)
                value = [];
                return
            end
            if ~isnumeric(value) || ~isequal(size(value), [6, 3]) || ...
                    any(~isfinite(value), "all")
                error("KSSOLV:Matgenlab:Poscar:LatticeVelocities", ...
                    "lattice_velocities must be a finite 6-by-3 array.");
            end
            value = double(value);
        end

        function value = validatePreamble(value)
            if isempty(value)
                value = "";
                return
            end
            if ~(ischar(value) || (isstring(value) && isscalar(value)))
                error("KSSOLV:Matgenlab:Poscar:PredictorPreamble", ...
                    "predictor_corrector_preamble must be scalar text.");
            end
            value = string(value);
        end

        function value = validateComment(value)
            if ~(ischar(value) || (isstring(value) && isscalar(value)))
                error("KSSOLV:Matgenlab:Poscar:Comment", ...
                    "comment must be scalar text.");
            end
            value = string(value);
            if contains(value, newline) || contains(value, char(13))
                error("KSSOLV:Matgenlab:Poscar:Comment", ...
                    "comment must contain exactly one line.");
            end
        end

        function cells = rowsToCells(value)
            cells = mat2cell(value, ones(1, size(value, 1)), size(value, 2)).';
        end

        function value = siteMatrixFromStructure(structure, name, logicalData)
            value = [];
            properties = structure.site_properties;
            if ~isfield(properties, name)
                return
            end
            entries = properties.(name);
            value = zeros(structure.num_sites, 3);
            for index = 1:structure.num_sites
                value(index, :) = reshape(entries{index}, 1, 3);
            end
            if logicalData, value = logical(value); end
        end

        function value = predictorFromStructure(structure)
            value = [];
            properties = structure.site_properties;
            if ~isfield(properties, "predictor_corrector")
                return
            end
            entries = properties.predictor_corrector;
            value = zeros(structure.num_sites, 3, 3);
            for index = 1:structure.num_sites
                value(index, :, :) = reshape(entries{index}, 1, 3, 3);
            end
        end

        function value = formatRow(row, format)
            tokens = strings(1, numel(row));
            for index = 1:numel(row)
                tokens(index) = sprintf(format, row(index));
            end
            value = strjoin(tokens, " ");
        end

        function value = parseScalar(line, description)
            tokens = split(strtrim(line));
            tokens(tokens == "") = [];
            if numel(tokens) ~= 1
                error("KSSOLV:Matgenlab:Poscar:Number", ...
                    "Invalid %s.", description);
            end
            value = str2double(replace(lower(tokens(1)), "d", "e"));
            if ~isfinite(value)
                error("KSSOLV:Matgenlab:Poscar:Number", ...
                    "Invalid %s.", description);
            end
        end

        function value = parseNumericRow(line, width, description)
            tokens = split(strtrim(line));
            tokens(tokens == "") = [];
            if numel(tokens) ~= width
                error("KSSOLV:Matgenlab:Poscar:Number", ...
                    "Invalid %s; expected %d values.", description, width);
            end
            value = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                parseNumericTokens(tokens, description);
        end

        function value = parseNumericTokens(tokens, description)
            value = zeros(1, numel(tokens));
            for index = 1:numel(tokens)
                token = replace(lower(tokens(index)), "d", "e");
                value(index) = str2double(token);
            end
            if any(~isfinite(value))
                error("KSSOLV:Matgenlab:Poscar:Number", ...
                    "Invalid numeric value in %s.", description);
            end
        end

        function [counts, valid] = tryParseCounts(line)
            tokens = split(strtrim(line));
            tokens(tokens == "") = [];
            counts = zeros(1, numel(tokens));
            valid = ~isempty(tokens);
            for index = 1:numel(tokens)
                value = str2double(tokens(index));
                if ~isfinite(value) || value ~= fix(value)
                    valid = false;
                    counts = zeros(1, 0);
                    return
                end
                counts(index) = value;
            end
        end

        function value = firstToken(line)
            tokens = split(strtrim(line));
            tokens(tokens == "") = [];
            if isempty(tokens)
                error("KSSOLV:Matgenlab:Poscar:CoordinateMode", ...
                    "POSCAR coordinate mode is empty.");
            end
            value = tokens(1);
        end

        function value = cleanVasp6Symbol(value)
            value = extractBefore(string(value) + "/", "/");
            value = extractBefore(value + "_", "_");
        end

        function value = normalizeNames(names)
            if isempty(names)
                value = strings(1, 0);
                return
            end
            if ischar(names)
                value = string({names});
            elseif isstring(names)
                value = reshape(names, 1, []);
            elseif iscell(names)
                value = reshape(string(names), 1, []);
            else
                error("KSSOLV:Matgenlab:Poscar:DefaultNames", ...
                    "default_names must be a sequence of element symbols.");
            end
            value = arrayfun( ...
                @kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                cleanVasp6Symbol, value);
            for index = 1:numel(value)
                if ~kssolv.analysis.matgenlab.core.Element. ...
                        is_valid_symbol(value(index))
                    error("KSSOLV:Matgenlab:Poscar:DefaultNames", ...
                        "Invalid default element symbol '%s'.", value(index));
                end
            end
        end

        function tokens = repairConcatenatedCoordinates(tokens)
            repaired = strings(1, 0);
            for index = 1:numel(tokens)
                pieces = regexp(char(tokens(index)), ...
                    "(?<![EeDd])(?=-)", "split");
                repaired = [repaired, string(pieces)]; %#ok<AGROW>
            end
            tokens = repaired;
        end

        function lines = nonemptyLines(text)
            raw = regexp(char(text), "\r?\n", "split");
            lines = strtrim(string(raw));
            lines(lines == "") = [];
            lines = reshape(lines, [], 1);
        end

        function names = namesFromNeighboringPotcar(poscarPath)
            folder = fileparts(char(poscarPath));
            files = dir(fullfile(folder, "*POTCAR*"));
            files = files(~[files.isdir]);
            names = strings(1, 0);
            if isempty(files), return; end
            fullPaths = string(fullfile({files.folder}, {files.name}));
            exact = find(string({files.name}) == "POTCAR", 1);
            if ~isempty(exact)
                path = fullPaths(exact);
            else
                fullPaths = sort(fullPaths);
                path = fullPaths(1);
            end
            try
                text = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    readTextFile(path);
                matches = regexp(text, ...
                    "(?m)^\s*TITEL\s*=\s*\S+\s+([A-Z][a-z]?(?:_[^\s]+)?)", ...
                    "tokens");
                if isempty(matches)
                    matches = regexp(text, ...
                        "(?m)^\s*VRHFIN\s*=\s*([A-Z][a-z]?)\s*:", ...
                        "tokens");
                end
                if isempty(matches), return; end
                names = strings(1, numel(matches));
                for index = 1:numel(matches)
                    names(index) = ...
                        kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                        cleanVasp6Symbol(string(matches{index}{1}));
                end
                names = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    normalizeNames(names);
            catch
                names = strings(1, 0);
            end
        end

        function text = readTextFile(filename)
            filename = string(filename);
            lowerName = lower(filename);
            if endsWith(lowerName, ".gz") || endsWith(lowerName, ".bz2")
                temporaryFolder = string(tempname);
                mkdir(temporaryFolder);
                cleanup = onCleanup(@() rmdir(temporaryFolder, "s"));
                if endsWith(lowerName, ".gz")
                    paths = gunzip(filename, temporaryFolder);
                else
                    paths = bunzip2(filename, temporaryFolder);
                end
                text = fileread(paths{1});
                clear cleanup
            else
                text = fileread(filename);
            end
        end
    end
end
