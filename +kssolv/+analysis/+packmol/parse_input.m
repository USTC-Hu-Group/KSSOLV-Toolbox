function config = parse_input(input, options)
%PARSE_INPUT Parse the m3g/packmol input grammar into a MATLAB structure.
arguments
    input {mustBeTextScalar}
    options.WorkingDirectory {mustBeTextScalar} = pwd
    options.Output {mustBeTextScalar} = ""
end

input = string(input);
workingDirectory = string(options.WorkingDirectory);
inputCandidate = input;
if ~isfile(inputCandidate) && ...
        isfile(fullfile(workingDirectory, inputCandidate))
    inputCandidate = fullfile(workingDirectory, inputCandidate);
end
if isfile(inputCandidate)
    inputPath = inputCandidate;
    inputPath = string(java.io.File(char(inputPath)).getCanonicalPath());
    text = string(fileread(inputPath));
else
    inputPath = "";
    text = input;
end
if ~isfolder(workingDirectory)
    error("KSSOLV:Packmol:Directory", ...
        "Working directory '%s' does not exist.", workingDirectory);
end

rawLines = splitlines(text);
tokens = cell(numel(rawLines), 1);
for i = 1:numel(rawLines)
    tokens{i} = kssolv.analysis.packmol.tokenize(rawLines(i));
    if ~isempty(tokens{i})
        tokens{i}(1) = lower(tokens{i}(1));
        if numel(tokens{i}) > 1 && any(tokens{i}(1) == ...
                ["inside", "outside", "over", "above", "below", ...
                 "end", "filetype", "avoid_overlap", ...
                 "constrain_rotation"])
            tokens{i}(2) = lower(tokens{i}(2));
        end
    end
end

settings = kssolv.analysis.packmol.defaults();
settings = parseGlobals(tokens, settings);
if strlength(string(options.Output)) > 0
    settings.output = string(options.Output);
end
if ~isfinite(settings.tolerance) || settings.tolerance <= 0
    error("KSSOLV:Packmol:Input", ...
        "Overall tolerance not set or not positive.");
end
if strlength(settings.output) == 0
    error("KSSOLV:Packmol:Input", "Output file not specified.");
end
if isnan(settings.short_tol_dist)
    settings.short_tol_dist = settings.tolerance / 2;
end
if settings.short_tol_dist <= 0 || ...
        settings.short_tol_dist > settings.tolerance
    error("KSSOLV:Packmol:Input", ...
        "short_tol_dist must be positive and no larger than tolerance.");
end
if settings.short_tol_scale <= 0
    error("KSSOLV:Packmol:Input", ...
        "short_tol_scale must be positive.");
end

structureCount = 0;
for lineIndex = 1:numel(tokens)
    if ~isempty(tokens{lineIndex}) && tokens{lineIndex}(1) == "structure"
        structureCount = structureCount + 1;
    end
end
settings.nloop_all = settings.nloop;
if settings.nloop_all == 0
    settings.nloop_all = 200 * structureCount;
end
if settings.nloop0 == 0
    settings.nloop0 = 20 * structureCount;
end

structures = repmat(emptyStructure(), 0, 1);
i = 1;
while i <= numel(tokens)
    row = tokens{i};
    if isempty(row) || row(1) ~= "structure"
        i = i + 1;
        continue
    end
    if numel(row) < 2
        inputError(i, "Missing structure filename.");
    end
    startLine = i;
    finishLine = 0;
    depth = 0;
    for j = i + 1:numel(tokens)
        candidate = tokens{j};
        if isempty(candidate)
            continue
        end
        if candidate(1) == "atoms"
            depth = depth + 1;
        elseif numel(candidate) >= 2 && candidate(1) == "end" && ...
                candidate(2) == "atoms"
            depth = depth - 1;
        elseif depth == 0 && numel(candidate) >= 2 && ...
                candidate(1) == "end" && candidate(2) == "structure"
            finishLine = j;
            break
        elseif depth == 0 && candidate(1) == "structure"
            inputError(j, ...
                "Structure specification missing 'end structure'.");
        end
    end
    if finishLine == 0
        inputError(startLine, ...
            "Structure specification missing 'end structure'.");
    end
    structures(end + 1, 1) = parseStructure( ... %#ok<AGROW>
        tokens, startLine, finishLine, workingDirectory, settings);
    i = finishLine + 1;
end
if isempty(structures)
    error("KSSOLV:Packmol:Input", ...
        "At least one structure block is required.");
end

config = struct( ...
    "input_text", text, ...
    "input_path", inputPath, ...
    "working_directory", workingDirectory, ...
    "settings", settings, ...
    "structures", structures, ...
    "upstream_commit", "14e50c65fa9120b58e1ba33ad482c7c7260f72b2");
end

function settings = parseGlobals(tokens, settings)
insideStructure = false;
for i = 1:numel(tokens)
    row = tokens{i};
    if isempty(row)
        continue
    end
    key = row(1);
    if key == "structure"
        insideStructure = true;
        continue
    elseif key == "end" && numel(row) >= 2 && row(2) == "structure"
        insideStructure = false;
        continue
    end
    switch key
        case "tolerance"
            settings.tolerance = numberAt(row, 2, i);
        case "output"
            textAt(row, 2, i);
            settings.output = row(2);
        case "filetype"
            textAt(row, 2, i);
            settings.filetype = lower(row(2));
            if ~any(settings.filetype == ["pdb", "xyz", "tinker"])
                inputError(i, "File type must be pdb, xyz, or tinker.");
            end
        case "seed"
            settings.seed = integerAt(row, 2, i);
            if settings.seed == -1
                settings.seed = sum(clock .* [1, 1, 1, 1, 100, 10]);
            end
        case {"precision", "movefrac", "discale", "sidemax", ...
                "short_tol_dist", "short_tol_scale"}
            settings.(char(key)) = numberAt(row, 2, i);
        case {"writeout", "maxit"}
            settings.(char(key)) = integerAt(row, 2, i);
        case {"nloop", "nloop0"}
            if ~insideStructure
                settings.(char(key)) = integerAt(row, 2, i);
            end
        case {"randominitialpoint", "check", "chkgrad", "writebad", ...
                "movebadrandom", "disable_movebad", "packall", ...
                "use_short_tol", "add_amber_ter", ...
                "amber_ter_preserve", "hexadecimal_indices", ...
                "ignore_conect", "non_standard_conect"}
            settings.(char(key)) = true;
        case "avoid_overlap"
            textAt(row, 2, i);
            settings.avoid_overlap = lower(row(2)) == "yes";
        case "add_box_sides"
            settings.add_box_sides = true;
            if numel(row) >= 2
                value = str2double(row(2));
                if isfinite(value)
                    settings.add_box_sides_offset = value;
                end
            end
        case "pbc"
            values = numbersAfter(row, 1, i);
            if numel(values) == 3
                settings.pbc_min = zeros(1, 3);
                settings.pbc_max = values;
            elseif numel(values) == 6
                settings.pbc_min = values(1:3);
                settings.pbc_max = values(4:6);
            else
                inputError(i, "pbc expects three or six numbers.");
            end
            if any(settings.pbc_max <= settings.pbc_min)
                inputError(i, "PBC lengths must be positive.");
            end
            settings.using_pbc = true;
        case {"restart_from", "restart_to"}
            if ~insideStructure
                textAt(row, 2, i);
                settings.(char(key)) = row(2);
            end
        case "writecrd"
            textAt(row, 2, i);
            settings.crd = true;
            settings.crdfile = row(2);
        case "fbins"
            settings.fbins = numberAt(row, 2, i);
        case {"iprint1", "iprint2"}
            settings.(char(key)) = integerAt(row, 2, i);
        otherwise
            if ~insideStructure
                inputError(i, "Keyword not recognized: " + key);
            end
    end
end
end

function value = parseStructure(tokens, first, last, directory, settings)
value = emptyStructure();
value.source = tokens{first}(2);
sourcePath = value.source;
if ~isfile(sourcePath)
    sourcePath = fullfile(directory, sourcePath);
end
value.molecule = kssolv.analysis.packmol.read_structure( ...
    sourcePath, settings.filetype);
natom = size(value.molecule.coordinates, 1);
value.radius = repmat(settings.tolerance / 2, natom, 1);
value.fscale = ones(natom, 1);
value.short_radius = repmat(settings.short_tol_dist / 2, natom, 1);
value.short_radius_scale = repmat(settings.short_tol_scale, natom, 1);
value.use_short_radius = repmat(settings.use_short_tol, natom, 1);
value.nloop = settings.nloop_all;
value.nloop0 = settings.nloop0;

selectedAtoms = [];
insideAtoms = false;
for i = first + 1:last - 1
    row = tokens{i};
    if isempty(row)
        continue
    end
    key = row(1);
    if key == "atoms"
        if insideAtoms
            inputError(i, "Nested atoms selections are not supported.");
        end
        selectedAtoms = numbersAfter(row, 1, i);
        if isempty(selectedAtoms) || any(selectedAtoms ~= fix(selectedAtoms)) || ...
                any(selectedAtoms < 1) || any(selectedAtoms > natom)
            inputError(i, "Invalid atom selection.");
        end
        selectedAtoms = unique(selectedAtoms, "stable");
        insideAtoms = true;
        continue
    elseif key == "end" && numel(row) >= 2 && row(2) == "atoms"
        selectedAtoms = [];
        insideAtoms = false;
        continue
    end
    if insideAtoms
        activeAtoms = selectedAtoms;
    else
        activeAtoms = 1:natom;
    end
    switch key
        case "number"
            value.number = integerAt(row, 2, i);
        case {"center", "centerofmass"}
            value.center = true;
        case "fixed"
            if insideAtoms
                inputError(i, "fixed cannot appear inside an atoms block.");
            end
            values = numbersAfter(row, 1, i);
            if numel(values) ~= 6
                inputError(i, "fixed expects six numbers.");
            end
            value.fixed = true;
            value.fixed_pose = values;
        case {"inside", "outside", "over", "above", "below"}
            value.constraints(end + 1, 1) = parseConstraint( ... %#ok<AGROW>
                row, activeAtoms, i);
        case "radius"
            value.radius(activeAtoms) = numberAt(row, 2, i);
        case "fscale"
            value.fscale(activeAtoms) = numberAt(row, 2, i);
        case "short_radius"
            value.short_radius(activeAtoms) = numberAt(row, 2, i);
            value.use_short_radius(activeAtoms) = true;
        case "short_radius_scale"
            value.short_radius_scale(activeAtoms) = numberAt(row, 2, i);
            value.use_short_radius(activeAtoms) = true;
        case "constrain_rotation"
            textAt(row, 4, i);
            axis = lower(row(2));
            axisIndex = find(axis == ["y", "z", "x"], 1);
            if isempty(axisIndex)
                inputError(i, "constrain_rotation axis must be x, y, or z.");
            end
            value.rotation_constrained(axisIndex) = true;
            value.rotation_bounds(axisIndex, :) = ...
                [numberAt(row, 3, i), numberAt(row, 4, i)] * pi / 180;
        case "maxmove"
            value.maxmove = integerAt(row, 2, i);
        case "nloop"
            value.nloop = integerAt(row, 2, i);
        case "nloop0"
            value.nloop0 = integerAt(row, 2, i);
        case "restart_from"
            textAt(row, 2, i);
            value.restart_from = row(2);
        case "restart_to"
            textAt(row, 2, i);
            value.restart_to = row(2);
        case "resnumbers"
            value.resnumbers = integerAt(row, 2, i);
        case "connect"
            textAt(row, 2, i);
            value.connect = lower(row(2)) ~= "no";
        case "changechains"
            value.changechains = true;
        case "chain"
            textAt(row, 2, i);
            value.chain = row(2);
        case "segid"
            textAt(row, 2, i);
            value.segid = row(2);
        case {"tolerance", "output", "filetype", "seed", ...
                "precision", "movefrac", "discale", "sidemax", ...
                "short_tol_dist", "short_tol_scale", "writeout", ...
                "maxit", "randominitialpoint", "check", "chkgrad", ...
                "writebad", "movebadrandom", "disable_movebad", ...
                "packall", "use_short_tol", "add_amber_ter", ...
                "amber_ter_preserve", "hexadecimal_indices", ...
                "ignore_conect", "non_standard_conect", ...
                "avoid_overlap", "add_box_sides", "pbc", ...
                "writecrd", "fbins", "iprint1", "iprint2"}
            % Packmol scans these as global controls even when they are
            % physically located inside a structure block.
        otherwise
            inputError(i, "Keyword not valid in structure block: " + key);
    end
end
if insideAtoms
    inputError(last, "Atom selection missing 'end atoms'.");
end
if value.number < 1 || value.number ~= fix(value.number)
    inputError(first, "A positive integer number is required.");
end
if value.fixed && value.number ~= 1
    inputError(first, "A fixed structure must have number 1.");
end
if value.fixed && ...
        (value.restart_from ~= "none" || value.restart_to ~= "none")
    inputError(first, "Restart files cannot be used for fixed structures.");
end
if ~value.fixed && isempty(value.constraints) && ~settings.using_pbc
    inputError(first, "Every movable molecule needs a geometrical constraint.");
end
if any(value.radius <= 0) || any(value.fscale <= 0) || ...
        any(value.short_radius <= 0) || ...
        any(value.short_radius(value.use_short_radius) >= ...
            value.radius(value.use_short_radius))
    inputError(first, "Invalid radius or fscale parameters.");
end
if value.fixed && value.center
    center = mean(value.molecule.coordinates, 1);
    value.molecule.coordinates = value.molecule.coordinates - center;
elseif ~value.fixed
    center = mean(value.molecule.coordinates, 1);
    value.molecule.coordinates = value.molecule.coordinates - center;
end
if value.maxmove == 0
    value.maxmove = value.number;
end
end

function constraint = parseConstraint(row, atoms, line)
placement = row(1);
shape = row(2);
parameters = numbersAfter(row, 2, line);
if placement == "inside"
    valid = struct("cube", 4, "box", 6, "sphere", 4, ...
        "ellipsoid", 7, "cylinder", 8);
    typeMap = struct("cube", 2, "box", 3, "sphere", 4, ...
        "ellipsoid", 5, "cylinder", 12);
elseif placement == "outside"
    valid = struct("cube", 4, "box", 6, "sphere", 4, ...
        "ellipsoid", 7, "cylinder", 8);
    typeMap = struct("cube", 6, "box", 7, "sphere", 8, ...
        "ellipsoid", 9, "cylinder", 13);
elseif any(placement == ["over", "above", "below"])
    valid = struct("plane", 4, "xygauss", 6);
    if shape == "plane"
        if placement == "below"
            typeMap = struct("plane", 11);
        else
            typeMap = struct("plane", 10);
        end
    else
        if placement == "below"
            typeMap = struct("xygauss", 15);
        else
            typeMap = struct("xygauss", 14);
        end
    end
else
    inputError(line, "Invalid constraint placement.");
end
field = char(shape);
if ~isfield(valid, field) || numel(parameters) ~= valid.(field)
    inputError(line, "Invalid parameters for " + placement + " " + shape + ".");
end
if shape == "cylinder"
    directionNorm = norm(parameters(4:6));
    if directionNorm < 1.0e-10
        inputError(line, "Cylinder director vector cannot be zero.");
    end
    parameters(4:6) = parameters(4:6) / directionNorm;
    parameters = [parameters(1:7), directionNorm^2, parameters(8)];
end
constraint = struct( ...
    "type", typeMap.(field), ...
    "placement", placement, ...
    "shape", shape, ...
    "parameters", reshape(parameters, 1, []), ...
    "atoms", reshape(double(atoms), 1, []), ...
    "line", line);
end

function value = emptyStructure()
emptyConstraint = struct( ...
    "type", {}, "placement", {}, "shape", {}, ...
    "parameters", {}, "atoms", {}, "line", {});
value = struct( ...
    "source", "", ...
    "molecule", struct(), ...
    "number", 0, ...
    "fixed", false, ...
    "fixed_pose", zeros(1, 6), ...
    "center", false, ...
    "constraints", emptyConstraint, ...
    "radius", zeros(0, 1), ...
    "fscale", zeros(0, 1), ...
    "short_radius", zeros(0, 1), ...
    "short_radius_scale", zeros(0, 1), ...
    "use_short_radius", false(0, 1), ...
    "rotation_constrained", false(1, 3), ...
    "rotation_bounds", zeros(3, 2), ...
    "maxmove", 0, ...
    "nloop", 0, ...
    "nloop0", 0, ...
    "restart_from", "none", ...
    "restart_to", "none", ...
    "resnumbers", -1, ...
    "connect", true, ...
    "changechains", false, ...
    "chain", "#", ...
    "segid", "");
end

function value = numberAt(row, index, line)
textAt(row, index, line);
value = str2double(row(index));
if ~isfinite(value)
    inputError(line, "Expected a finite numeric value.");
end
end

function value = integerAt(row, index, line)
value = numberAt(row, index, line);
if value ~= fix(value)
    inputError(line, "Expected an integer value.");
end
end

function values = numbersAfter(row, index, line)
if numel(row) <= index
    values = zeros(1, 0);
    return
end
values = str2double(row(index + 1:end));
if any(~isfinite(values))
    inputError(line, "Expected finite numeric values.");
end
end

function textAt(row, index, line)
if numel(row) < index || strlength(row(index)) == 0
    inputError(line, "Missing input value.");
end
end

function inputError(line, message)
error("KSSOLV:Packmol:Input", "Line %d: %s", line, message);
end
