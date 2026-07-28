classdef BaderAnalysis
    %BADERANALYSIS Native Bader-output analysis with an explicit runner.
    %
    % External execution is deliberately isolated behind executor. The
    % executor receives a request struct and returns stdout, stderr, status,
    % and either acf_text or acf_filename. No shell process is started by
    % this class.

    properties (SetAccess = private)
        data (1,:) struct = struct( ...
            "x", {}, "y", {}, "z", {}, "charge", {}, ...
            "min_dist", {}, "atomic_vol", {})
        vacuum_volume (1,1) double = 0
        vacuum_charge (1,1) double = 0
        nelectrons (1,1) double = 0
        chgcar = []
        cube = []
        potcar = []
        structure = []
        atomic_densities (1,:) cell = cell(1, 0)
        nelects (1,:) double = zeros(1, 0)
        reference_used (1,1) logical = false
        version (1,1) double = -1
        parse_atomic_densities (1,1) logical = false
        executor = []
        bader_path (1,1) string = "bader"
    end

    properties (Dependent, SetAccess = private)
        summary
    end

    methods
        function obj = BaderAnalysis(chgcar_filename, potcar_filename, ...
                chgref_filename, cube_filename, bader_path, ...
                parse_atomic_densities, options)
            arguments
                chgcar_filename = ""
                potcar_filename = ""
                chgref_filename = ""
                cube_filename = ""
                bader_path = ""
                parse_atomic_densities (1,1) logical = false
                options.executor = []
                options.acf_text = ""
                options.nelects = []
                options.atomic_densities = []
            end
            chgcar_filename = string(chgcar_filename);
            potcar_filename = string(potcar_filename);
            chgref_filename = string(chgref_filename);
            cube_filename = string(cube_filename);
            if strlength(chgcar_filename) == 0 && ...
                    strlength(cube_filename) == 0
                error("KSSOLV:Matgenlab:Bader:InputRequired", ...
                    "You must provide either a Cube file or a CHGCAR.");
            end
            if strlength(chgcar_filename) > 0 && ...
                    strlength(cube_filename) > 0
                error("KSSOLV:Matgenlab:Bader:ConflictingInputs", ...
                    "Cannot parse cube and CHGCAR at the same time.");
            end
            if strlength(string(bader_path)) > 0
                obj.bader_path = string(bader_path);
            end
            obj.parse_atomic_densities = parse_atomic_densities;
            obj.reference_used = strlength(chgref_filename) > 0;
            obj.executor = options.executor;
            if ~isempty(obj.executor) && ...
                    ~isa(obj.executor, "function_handle")
                error("KSSOLV:Matgenlab:Bader:ExecutorType", ...
                    "executor must be a MATLAB function handle.");
            end

            if strlength(chgcar_filename) > 0
                obj.chgcar = kssolv.analysis.matgenlab.io.vasp.Chgcar. ...
                    from_file(chgcar_filename);
                obj.structure = obj.chgcar.structure;
                if strlength(potcar_filename) > 0
                    obj.potcar = ...
                        kssolv.analysis.matgenlab.io.vasp.Potcar. ...
                        from_file(potcar_filename);
                    obj.nelects = electronCounts( ...
                        obj.chgcar.poscar.natoms, obj.potcar);
                end
                inputFilename = chgcar_filename;
            else
                obj.cube = ...
                    kssolv.analysis.matgenlab.io.common.VolumetricData. ...
                    from_cube(cube_filename);
                obj.structure = obj.cube.structure;
                inputFilename = cube_filename;
            end
            if ~isempty(options.nelects)
                obj.nelects = reshape(double(options.nelects), 1, []);
            end

            acfText = string(options.acf_text);
            if strlength(acfText) == 0
                if isempty(obj.executor)
                    error("KSSOLV:Matgenlab:Bader:ExecutorRequired", ...
                        "External Bader execution requires an explicit " + ...
                        "executor function handle.");
                end
                request = struct( ...
                    "command", obj.bader_path, ...
                    "input_filename", inputFilename, ...
                    "reference_filename", chgref_filename, ...
                    "parse_atomic_densities", parse_atomic_densities);
                result = callExecutor(obj.executor, request);
                [stdout, stderr, status, acfText, densities] = ...
                    normalizeResult(result);
                if status ~= 0
                    error("KSSOLV:Matgenlab:Bader:Execution", ...
                        "Bader executor exited with status %d: %s " + ...
                        "(stdout: %s)", status, stderr, stdout);
                end
                obj.version = parseVersion(stdout);
                if parse_atomic_densities
                    if isempty(densities)
                        error("KSSOLV:Matgenlab:Bader:AtomicDensities", ...
                            "The executor must return atomic_densities " + ...
                            "when parse_atomic_densities is true.");
                    end
                    obj.atomic_densities = normalizeDensities(densities);
                end
            end
            [obj.data, obj.vacuum_charge, obj.vacuum_volume, ...
                obj.nelectrons] = parseAcf(acfText);
        end

        function value = get_charge(obj, atom_index)
            obj.validateAtomIndex(atom_index);
            value = obj.data(atom_index).charge;
        end

        function value = get_charge_transfer(obj, atom_index, nelect)
            if nargin < 3, nelect = []; end
            obj.validateAtomIndex(atom_index);
            if isempty(nelect)
                if isempty(obj.nelects)
                    error("KSSOLV:Matgenlab:Bader:NoNelect", ...
                        "No NELECT info! Need POTCAR for VASP or a " + ...
                        "nelect argument for a cube file.");
                end
                nelect = obj.nelects(atom_index);
            end
            value = obj.get_charge(atom_index) - double(nelect);
        end

        function value = get_partial_charge(obj, atom_index, nelect)
            if nargin < 3, nelect = []; end
            value = -obj.get_charge_transfer(atom_index, nelect);
        end

        function result = get_charge_decorated_structure(obj)
            charges = -arrayfun(@(index) obj.get_charge(index), ...
                1:obj.structure.num_sites);
            result = obj.structure.copy();
            result = result.add_site_property("charge", charges);
        end

        function result = get_oxidation_state_decorated_structure( ...
                obj, nelects)
            if nargin < 2, nelects = []; end
            result = kssolv.analysis.matgenlab.core.Structure. ...
                from_sites(obj.structure.sites, ...
                properties = obj.structure.structure_properties);
            charges = zeros(1, result.num_sites);
            for index = 1:result.num_sites
                if isempty(nelects)
                    charges(index) = obj.get_partial_charge(index);
                else
                    charges(index) = obj.get_partial_charge( ...
                        index, nelects(index));
                end
            end
            result = result.add_oxidation_state_by_site(charges);
        end

        function result = get_decorated_structure(obj, ...
                property_name, average)
            if nargin < 3, average = false; end
            values = arrayfun(@(index) obj.get_charge(index), ...
                1:obj.structure.num_sites);
            if average
                values = values ./ [obj.data.atomic_vol];
            end
            result = kssolv.analysis.matgenlab.core.Structure. ...
                from_sites(obj.structure.sites, ...
                properties = obj.structure.structure_properties);
            result = result.add_site_property(property_name, values);
            if string(property_name) == "spin"
                result = result.add_spin_by_site(values);
            end
        end

        function value = get.summary(obj)
            value = struct( ...
                "min_dist", [obj.data.min_dist], ...
                "charge", [obj.data.charge], ...
                "atomic_volume", [obj.data.atomic_vol], ...
                "vacuum_charge", obj.vacuum_charge, ...
                "vacuum_volume", obj.vacuum_volume, ...
                "reference_used", obj.reference_used, ...
                "bader_version", obj.version);
            if obj.parse_atomic_densities
                value.charge_densities = obj.atomic_densities;
            end
            if ~isempty(obj.potcar)
                value.charge_transfer = arrayfun(@(index) ...
                    obj.get_charge_transfer(index), 1:numel(obj.data));
            end
        end
    end

    methods (Static)
        function obj = from_path(path, suffix, varargin)
            if nargin < 2, suffix = ""; end
            options = parseOptions(struct( ...
                "executor", [], "bader_path", "", ...
                "parse_atomic_densities", false), varargin);
            chgcar = findFile(path, "CHGCAR", suffix, true);
            potcar = findFile(path, "POTCAR", "", false);
            first = findFile(path, "AECCAR0", suffix, false);
            second = findFile(path, "AECCAR2", suffix, false);
            reference = "";
            cleanup = [];
            if strlength(first) > 0 && strlength(second) > 0
                temporary = string(tempname) + ".CHGCAR_ref";
                summed = ...
                    kssolv.analysis.matgenlab.io.vasp.Chgcar. ...
                    from_file(first) + ...
                    kssolv.analysis.matgenlab.io.vasp.Chgcar. ...
                    from_file(second);
                summed.write_file(temporary);
                cleanup = onCleanup(@() deleteIfFile(temporary));
                reference = temporary;
            end
            obj = kssolv.analysis.matgenlab.command_line. ...
                bader_caller.BaderAnalysis(chgcar, potcar, reference, ...
                "", options.bader_path, ...
                logical(options.parse_atomic_densities), ...
                executor = options.executor);
            if ~isempty(cleanup), clear cleanup; end
        end
    end

    methods (Access = private)
        function validateAtomIndex(obj, index)
            if ~isscalar(index) || index ~= fix(index) || index < 1 || ...
                    index > numel(obj.data)
                error("KSSOLV:Matgenlab:Bader:AtomIndex", ...
                    "atom_index must identify a parsed atom.");
            end
        end
    end
end

function values = electronCounts(natoms, potcar)
values = zeros(1, sum(natoms));
offset = 0;
for speciesIndex = 1:numel(natoms)
    count = natoms(speciesIndex);
    values(offset + (1:count)) = potcar(speciesIndex).nelectrons;
    offset = offset + count;
end
end

function result = callExecutor(executor, request)
count = nargin(executor);
if count == 1 || count < 0
    result = executor(request);
else
    result = executor(request.input_filename, ...
        request.reference_filename, request.command);
end
end

function [stdout, stderr, status, acfText, densities] = ...
        normalizeResult(result)
stdout = ""; stderr = ""; status = 0; densities = [];
if ~isstruct(result)
    error("KSSOLV:Matgenlab:Bader:ExecutorResult", ...
        "Executor result must be a struct containing acf_text.");
end
if isfield(result, "stdout"), stdout = string(result.stdout); end
if isfield(result, "stderr"), stderr = string(result.stderr); end
if isfield(result, "status"), status = double(result.status); end
if isfield(result, "returncode")
    status = double(result.returncode);
end
if isfield(result, "acf_text")
    acfText = string(result.acf_text);
elseif isfield(result, "acf_filename")
    acfText = string(fileread(result.acf_filename));
else
    error("KSSOLV:Matgenlab:Bader:ExecutorResult", ...
        "Executor result must include acf_text or acf_filename.");
end
if isfield(result, "atomic_densities")
    densities = result.atomic_densities;
end
end

function version = parseVersion(stdout)
version = -1;
tokens = regexp(char(stdout), ...
    '(?i)(?:version\s*)?([0-9]+(?:\.[0-9]+)?)', 'tokens');
if ~isempty(tokens)
    values = cellfun(@(entry) str2double(entry{1}), tokens);
    version = values(end);
end
end

function densities = normalizeDensities(value)
if iscell(value), densities = reshape(value, 1, []);
elseif isstruct(value), densities = num2cell(value);
else
    error("KSSOLV:Matgenlab:Bader:AtomicDensities", ...
        "atomic_densities must be a cell or struct array.");
end
end

function [data, vacuumCharge, vacuumVolume, electrons] = parseAcf(text)
lines = splitlines(string(text));
headers = ["x", "y", "z", "charge", "min_dist", "atomic_vol"];
data = struct("x", {}, "y", {}, "z", {}, "charge", {}, ...
    "min_dist", {}, "atomic_vol", {});
vacuumCharge = 0; vacuumVolume = 0; electrons = 0;
inAtoms = false;
for index = 1:numel(lines)
    line = strtrim(lines(index));
    if strlength(line) == 0, continue; end
    upperLine = upper(line);
    if startsWith(upperLine, "VACUUM CHARGE")
        vacuumCharge = valueAfterColon(line);
    elseif startsWith(upperLine, "VACUUM VOLUME")
        vacuumVolume = valueAfterColon(line);
    elseif startsWith(upperLine, "NUMBER OF ELECTRONS")
        electrons = valueAfterColon(line);
    elseif startsWith(line, "-")
        inAtoms = ~isempty(data);
    else
        values = sscanf(line, "%f").';
        if numel(values) == 7 && values(1) == fix(values(1))
            inAtoms = true;
            row = cell2struct(num2cell(values(2:end)), ...
                cellstr(headers), 2);
            data(end + 1) = row; %#ok<AGROW>
        elseif inAtoms
            continue
        end
    end
end
if isempty(data)
    error("KSSOLV:Matgenlab:Bader:AcfParse", ...
        "ACF output contains no atomic records.");
end
end

function value = valueAfterColon(line)
pieces = split(line, ":");
if numel(pieces) < 2
    error("KSSOLV:Matgenlab:Bader:AcfParse", ...
        "Expected ':' in ACF summary line '%s'.", line);
end
value = str2double(strtrim(pieces(end)));
if isnan(value)
    error("KSSOLV:Matgenlab:Bader:AcfParse", ...
        "Invalid numeric ACF summary line '%s'.", line);
end
end

function output = findFile(path, filename, suffix, required)
pattern = fullfile(string(path), string(filename) + string(suffix) + "*");
matches = dir(pattern);
matches = matches(~[matches.isdir]);
if isempty(matches)
    if required
        error("KSSOLV:Matgenlab:Bader:MissingChgcar", ...
            "Could not find CHGCAR!");
    end
    output = "";
    return
end
names = sort(string({matches.name}), "descend");
output = fullfile(string(path), names(1));
end

function options = parseOptions(options, values)
if isempty(values), return; end
if isscalar(values) && isstruct(values{1})
    supplied = values{1};
    names = fieldnames(supplied);
    for index = 1:numel(names)
        options.(names{index}) = supplied.(names{index});
    end
    return
end
if mod(numel(values), 2) ~= 0
    error("KSSOLV:Matgenlab:Bader:Options", ...
        "Optional arguments must be name/value pairs.");
end
for index = 1:2:numel(values)
    name = char(string(values{index}));
    if ~isfield(options, name)
        error("KSSOLV:Matgenlab:Bader:Options", ...
            "Unknown option '%s'.", name);
    end
    options.(name) = values{index + 1};
end
end

function deleteIfFile(path)
if isfile(path), delete(path); end
end
