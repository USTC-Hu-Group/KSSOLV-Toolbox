classdef BabelMolAdaptor < handle
    %BABELMOLADAPTOR Bridge molecules and OpenBabel-compatible formats.
    %
    % Common molecular formats are handled natively. Force-field and
    % conformer operations require an explicitly injected MATLAB backend;
    % this class never discovers an executable or invokes a shell.

    properties (Access = private)
        data_ (1,1) kssolv.analysis.matgenlab.io.babel.BabelMolData
        backend_ = []
        backend_state_ = []
    end

    properties (Dependent, SetAccess = private)
        pymatgen_mol
        openbabel_mol
        pybel_mol
    end

    methods
        function obj = BabelMolAdaptor(mol, backend)
            if nargin < 2, backend = []; end
            obj.backend_ = backend;
            if isa(mol, "kssolv.analysis.matgenlab.core.IMolecule")
                if ~mol.is_ordered
                    error("KSSOLV:Matgenlab:Babel:Disordered", ...
                        "OpenBabel Molecule only supports ordered molecules.");
                end
                molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                    mol.species_and_occu, mol.cart_coords, ...
                    charge = mol.charge, ...
                    spin_multiplicity = mol.spin_multiplicity, ...
                    charge_spin_check = false);
                molecule = centerMolecule(molecule);
                obj.data_ = kssolv.analysis.matgenlab.io.babel. ...
                    BabelMolData(molecule, inferBonds(molecule), 3);
                if ~isempty(backend)
                    obj.backend_state_ = callBackend(backend, ...
                        "from_molecule", molecule);
                end
            elseif isa(mol, ...
                    "kssolv.analysis.matgenlab.io.babel.BabelMolData")
                obj.data_ = mol;
                obj.backend_state_ = mol;
            elseif isstruct(mol) && isfield(mol, "x_babel_raw")
                obj.data_ = kssolv.analysis.matgenlab.io.babel. ...
                    BabelMolData(mol, mol.bonds, mol.dimension);
            elseif ~isempty(backend)
                obj.backend_state_ = mol;
                molecule = callBackend(backend, "to_molecule", mol);
                obj.data_ = dataFromMolecule(molecule);
            else
                error("KSSOLV:Matgenlab:Babel:UnsupportedInput", ...
                    "Unsupported input type '%s'; expected Molecule, " + ...
                    "BabelMolData, or an object handled by an explicit backend.", ...
                    class(mol));
            end
        end

        function value = get.pymatgen_mol(obj)
            if ~isempty(obj.backend_) && ~isempty(obj.backend_state_)
                value = callBackend(obj.backend_, ...
                    "to_molecule", obj.backend_state_);
                value = normalizeMolecule(value);
            else
                value = obj.data_.getMolecule().copy();
            end
        end

        function value = get.openbabel_mol(obj)
            if ~isempty(obj.backend_) && ~isempty(obj.backend_state_)
                value = obj.backend_state_;
            else
                value = obj.data_;
            end
        end

        function value = get.pybel_mol(obj)
            % Native mode exposes the same immutable molecular state through
            % a pybel-like view. An injected backend may provide pybel_mol.
            if ~isempty(obj.backend_) && backendHas(obj.backend_, "pybel_mol")
                value = callBackend(obj.backend_, ...
                    "pybel_mol", obj.backend_state_);
            else
                value = obj.openbabel_mol;
            end
        end

        function localopt(obj, forcefield, steps)
            if nargin < 2 || strlength(string(forcefield)) == 0
                forcefield = "mmff94";
            end
            if nargin < 3 || isempty(steps), steps = 500; end
            obj.requireBackend("localopt");
            obj.backend_state_ = callBackend(obj.backend_, "localopt", ...
                obj.backend_state_, char(string(forcefield)), double(steps));
            obj.synchronize();
        end

        function make3d(obj, forcefield, steps)
            if nargin < 2 || strlength(string(forcefield)) == 0
                forcefield = "mmff94";
            end
            if nargin < 3 || isempty(steps), steps = 50; end
            obj.requireBackend("make3d");
            obj.backend_state_ = callBackend(obj.backend_, "make3d", ...
                obj.backend_state_, char(string(forcefield)), double(steps));
            obj.synchronize();
            obj.data_.dimension = 3;
        end

        function add_hydrogen(obj)
            obj.requireBackend("add_hydrogen");
            obj.backend_state_ = callBackend(obj.backend_, ...
                "add_hydrogen", obj.backend_state_);
            obj.synchronize();
        end

        function remove_bond(obj, idx1, idx2)
            validateattributes(idx1, {'numeric'}, ...
                {'scalar', 'integer', 'positive'});
            validateattributes(idx2, {'numeric'}, ...
                {'scalar', 'integer', 'positive'});
            if ~isempty(obj.backend_) && backendHas(obj.backend_, "remove_bond")
                obj.backend_state_ = callBackend(obj.backend_, ...
                    "remove_bond", obj.backend_state_, idx1, idx2);
                obj.synchronize();
            end
            matches = (obj.data_.bonds(:, 1) == idx1 & ...
                obj.data_.bonds(:, 2) == idx2) | ...
                (obj.data_.bonds(:, 1) == idx2 & ...
                obj.data_.bonds(:, 2) == idx1);
            obj.data_.bonds(matches, :) = [];
        end

        function rotor_conformer(obj, varargin)
            [rotorArgs, algorithm, forcefield] = ...
                parseRotorArguments(varargin);
            obj.requireBackend("rotor_conformer");
            obj.backend_state_ = callBackend(obj.backend_, ...
                "rotor_conformer", obj.backend_state_, rotorArgs, ...
                char(algorithm), char(forcefield));
            obj.synchronize();
        end

        function gen3d_conformer(obj)
            obj.requireBackend("gen3d_conformer");
            obj.backend_state_ = callBackend(obj.backend_, ...
                "gen3d_conformer", obj.backend_state_);
            obj.synchronize();
            obj.data_.dimension = 3;
        end

        function conformers = confab_conformers(obj, varargin)
            options = struct(forcefield = "mmff94", freeze_atoms = [], ...
                rmsd_cutoff = 0.5, energy_cutoff = 50.0, ...
                conf_cutoff = 100000, verbose = false);
            options = parseNameValues(options, varargin);
            obj.requireBackend("confab_conformers");
            result = callBackend(obj.backend_, "confab_conformers", ...
                obj.backend_state_, options);
            if isstruct(result) && isfield(result, "state")
                obj.backend_state_ = result.state;
                result = result.conformers;
            end
            if ~iscell(result), result = num2cell(result); end
            conformers = cellfun(@normalizeMolecule, result, ...
                UniformOutput = false);
            obj.data_.conformers = conformers;
            if ~isempty(conformers)
                obj.data_.setMolecule(conformers{1});
            end
        end

        function write_file(obj, filename, file_format)
            if nargin < 3 || strlength(string(file_format)) == 0
                file_format = "xyz";
            end
            file_format = normalizeFormat(file_format);
            if isNativeFormat(file_format)
                text = serializeMolecules({obj.pymatgen_mol}, ...
                    obj.data_.bonds, file_format);
                writeTextFile(filename, text);
                return
            end
            obj.requireBackend("write_file");
            if backendHas(obj.backend_, "write_file")
                callBackend(obj.backend_, "write_file", ...
                    obj.backend_state_, char(string(filename)), ...
                    char(file_format));
            elseif backendHas(obj.backend_, "write_string")
                text = callBackend(obj.backend_, "write_string", ...
                    obj.backend_state_, char(file_format));
                writeTextFile(filename, text);
            else
                obj.missingBackendOperation("write_file");
            end
        end
    end

    methods (Static)
        function value = from_file(filename, file_format, ...
                return_all_molecules, backend)
            if nargin < 2 || strlength(string(file_format)) == 0
                [~, ~, extension] = fileparts(string(filename));
                file_format = erase(lower(extension), ".");
            end
            if nargin < 3 || isempty(return_all_molecules)
                return_all_molecules = false;
            end
            if nargin < 4, backend = []; end
            if ~isfile(filename)
                error("KSSOLV:Matgenlab:Babel:MissingFile", ...
                    "Molecule file '%s' does not exist.", filename);
            end
            format = normalizeFormat(file_format);
            if isNativeFormat(format)
                molecules = parseMolecules(fileread(filename), format);
                value = adaptMolecules(molecules, return_all_molecules, backend);
                return
            end
            if isempty(backend)
                missingDependency("from_file", format);
            end
            if backendHas(backend, "read_file")
                states = callBackend(backend, "read_file", ...
                    char(string(filename)), char(format));
                value = adaptBackendStates(states, ...
                    return_all_molecules, backend);
            else
                value = kssolv.analysis.matgenlab.io.babel. ...
                    BabelMolAdaptor.from_str(fileread(filename), ...
                    format, backend);
            end
        end

        function value = from_molecule_graph(mol, backend)
            if nargin < 2, backend = []; end
            if ~isa(mol, ...
                    "kssolv.analysis.matgenlab.core.MoleculeGraph")
                error("KSSOLV:Matgenlab:Babel:MoleculeGraph", ...
                    "mol must be a MoleculeGraph.");
            end
            value = kssolv.analysis.matgenlab.io.babel. ...
                BabelMolAdaptor(mol.molecule, backend);
            edges = mol.graph.edges;
            bonds = zeros(numel(edges), 3);
            for index = 1:numel(edges)
                order = edges(index).weight;
                if isempty(order), order = 1; end
                bonds(index, :) = [edges(index).from_index, ...
                    edges(index).to_index, order];
            end
            value.data_.bonds = bonds;
        end

        function value = from_str(string_data, file_format, backend)
            if nargin < 2 || strlength(string(file_format)) == 0
                file_format = "xyz";
            end
            if nargin < 3, backend = []; end
            format = normalizeFormat(file_format);
            if isNativeFormat(format)
                molecules = parseMolecules(string_data, format);
                value = adaptMolecules(molecules, false, backend);
                return
            end
            if isempty(backend)
                missingDependency("from_str", format);
            end
            state = callBackend(backend, "read_string", ...
                char(string_data), char(format));
            value = kssolv.analysis.matgenlab.io.babel. ...
                BabelMolAdaptor(state, backend);
        end

        function formats = supported_formats()
            formats = ["xyz", "pdb", "mol", "mdl", "sdf", "sd", ...
                "mol2", "ml2", "sy2", "cml", "mrv"];
        end
    end

    methods (Access = private)
        function requireBackend(obj, operation)
            if isempty(obj.backend_) || ...
                    ~backendHas(obj.backend_, operation)
                obj.missingBackendOperation(operation);
            end
        end

        function missingBackendOperation(~, operation)
            error("KSSOLV:Matgenlab:Babel:BackendRequired", ...
                "BabelMolAdaptor.%s requires an explicitly injected " + ...
                "OpenBabel-compatible MATLAB backend; no executable or " + ...
                "Python process is discovered implicitly.", operation);
        end

        function synchronize(obj)
            molecule = callBackend(obj.backend_, ...
                "to_molecule", obj.backend_state_);
            obj.data_.setMolecule(normalizeMolecule(molecule));
            obj.data_.bonds = inferBonds(obj.data_.getMolecule());
        end
    end
end

function data = dataFromMolecule(molecule)
molecule = normalizeMolecule(molecule);
data = kssolv.analysis.matgenlab.io.babel.BabelMolData( ...
    molecule, inferBonds(molecule), coordinateDimension(molecule));
end

function molecule = normalizeMolecule(value)
if isa(value, "kssolv.analysis.matgenlab.core.IMolecule")
    molecule = kssolv.analysis.matgenlab.core.Molecule( ...
        value.species_and_occu, value.cart_coords, ...
        charge = value.charge, ...
        spin_multiplicity = value.spin_multiplicity, ...
        charge_spin_check = false);
else
    error("KSSOLV:Matgenlab:Babel:BackendMolecule", ...
        "The injected backend must return a matgenlab Molecule.");
end
end

function molecule = centerMolecule(molecule)
if molecule.num_sites > 0
    coordinates = molecule.cart_coords;
    molecule = molecule.translate_sites(1:molecule.num_sites, ...
        -0.5 * (min(coordinates, [], 1) + max(coordinates, [], 1)));
end
end

function dimension = coordinateDimension(molecule)
coordinates = molecule.cart_coords;
if isempty(coordinates) || all(abs(coordinates) < 1e-14, "all")
    dimension = 0;
elseif all(abs(coordinates(:, 3)) < 1e-14)
    dimension = 2;
else
    dimension = 3;
end
end

function bonds = inferBonds(molecule)
bonds = zeros(0, 3);
for first = 1:molecule.num_sites
    for second = first + 1:molecule.num_sites
        try
            bonded = kssolv.analysis.matgenlab.core.CovalentBond. ...
                is_bonded(molecule.get_site(first), ...
                molecule.get_site(second), 0.2);
        catch
            bonded = false;
        end
        if bonded
            bonds(end + 1, :) = [first, second, 1]; %#ok<AGROW>
        end
    end
end
end

function [rotorArgs, algorithm, forcefield] = parseRotorArguments(values)
algorithm = "WeightedRotorSearch";
forcefield = "mmff94";
rotorArgs = values;
index = 1;
while index <= numel(rotorArgs) - 1
    name = lower(string(rotorArgs{index}));
    if (ischar(rotorArgs{index}) || isstring(rotorArgs{index})) && ...
            any(name == ["algo", "forcefield"])
        if name == "algo"
            algorithm = string(rotorArgs{index + 1});
        else
            forcefield = string(rotorArgs{index + 1});
        end
        rotorArgs(index:index + 1) = [];
    else
        index = index + 1;
    end
end
valid = ["SystematicRotorSearch", "RandomRotorSearch", ...
    "WeightedRotorSearch"];
if ~any(algorithm == valid), algorithm = "WeightedRotorSearch"; end
end

function options = parseNameValues(options, values)
if isscalar(values) && isstruct(values{1})
    names = fieldnames(values{1});
    for index = 1:numel(names)
        if isfield(options, names{index})
            options.(names{index}) = values{1}.(names{index});
        end
    end
    return
end
for index = 1:2:numel(values)
    if index == numel(values), break, end
    name = char(lower(string(values{index})));
    if isfield(options, name), options.(name) = values{index + 1}; end
end
end

function tf = backendHas(backend, operation)
if isstruct(backend)
    tf = isfield(backend, operation) && ...
        isa(backend.(operation), "function_handle");
else
    tf = isobject(backend) && ismethod(backend, operation);
end
end

function varargout = callBackend(backend, operation, varargin)
if ~backendHas(backend, operation)
    error("KSSOLV:Matgenlab:Babel:BackendContract", ...
        "Injected backend does not implement '%s'.", operation);
end
[varargout{1:nargout}] = backend.(operation)(varargin{:});
end

function missingDependency(operation, format)
error("KSSOLV:Matgenlab:Babel:BackendRequired", ...
    "BabelMolAdaptor.%s for format '%s' requires an explicitly " + ...
    "injected OpenBabel-compatible MATLAB backend.", operation, format);
end

function value = adaptMolecules(molecules, returnAll, backend)
if isempty(molecules)
    error("KSSOLV:Matgenlab:Babel:NoMolecule", ...
        "No molecule was found in the supplied data.");
end
adaptors = cellfun(@(molecule) ...
    kssolv.analysis.matgenlab.io.babel.BabelMolAdaptor( ...
    molecule, backend), molecules, UniformOutput = false);
if returnAll, value = adaptors; else, value = adaptors{1}; end
end

function value = adaptBackendStates(states, returnAll, backend)
if ~iscell(states), states = {states}; end
adaptors = cellfun(@(state) ...
    kssolv.analysis.matgenlab.io.babel.BabelMolAdaptor( ...
    state, backend), states, UniformOutput = false);
if isempty(adaptors)
    error("KSSOLV:Matgenlab:Babel:NoMolecule", ...
        "No molecule was found in the supplied data.");
end
if returnAll, value = adaptors; else, value = adaptors{1}; end
end

function format = normalizeFormat(value)
format = lower(strip(string(value)));
switch format
    case {"mdl"}
        format = "mol";
    case {"sd"}
        format = "sdf";
    case {"ml2", "sy2"}
        format = "mol2";
end
end

function tf = isNativeFormat(format)
tf = any(format == ["xyz", "pdb", "mol", "sdf", ...
    "mol2", "cml", "mrv"]);
end

function molecules = parseMolecules(text, format)
switch format
    case "xyz"
        molecules = parseXYZRaw(text);
    case "pdb"
        molecules = parsePDB(text);
    case {"mol", "sdf"}
        molecules = parseMol(text, format == "sdf");
    case "mol2"
        molecules = parseMol2(text);
    case {"cml", "mrv"}
        molecules = parseXMLMolecules(text);
    otherwise
        error("KSSOLV:Matgenlab:Babel:Format", ...
            "Unsupported native molecular format '%s'.", format);
end
end

function molecules = parseXYZRaw(text)
lines = splitlines(string(text));
molecules = cell(1, 0);
lineIndex = 1;
while lineIndex <= numel(lines)
    if strip(lines(lineIndex)) == ""
        lineIndex = lineIndex + 1;
        continue
    end
    count = str2double(strip(lines(lineIndex)));
    if isnan(count) || count < 0 || count ~= fix(count)
        error("KSSOLV:Matgenlab:Babel:XYZCount", ...
            "Invalid XYZ atom count on line %d.", lineIndex);
    end
    if lineIndex + count + 1 > numel(lines)
        error("KSSOLV:Matgenlab:Babel:XYZTruncated", ...
            "XYZ frame on line %d is truncated.", lineIndex);
    end
    species = strings(count, 1);
    coordinates = zeros(count, 3);
    for atom = 1:count
        tokens = split(strip(lines(lineIndex + 1 + atom)));
        if numel(tokens) < 4
            error("KSSOLV:Matgenlab:Babel:XYZAtom", ...
                "Invalid XYZ coordinate on line %d.", ...
                lineIndex + 1 + atom);
        end
        species(atom) = tokens(1);
        coordinates(atom, :) = str2double(replace(tokens(2:4), ...
            ["D", "d"], ["E", "e"]));
    end
    molecules{end + 1} = struct(x_babel_raw = true, ...
        species = species, coordinates = coordinates, ...
        bonds = zeros(0, 3), ...
        dimension = rawCoordinateDimension(coordinates)); %#ok<AGROW>
    lineIndex = lineIndex + count + 2;
end
end

function dimension = rawCoordinateDimension(coordinates)
if isempty(coordinates) || all(abs(coordinates) < 1e-14, "all")
    dimension = 0;
elseif all(abs(coordinates(:, 3)) < 1e-14)
    dimension = 2;
else
    dimension = 3;
end
end

function molecules = parsePDB(text)
lines = splitlines(string(text));
modelBreaks = find(startsWith(strip(lines), "MODEL"));
if isempty(modelBreaks)
    groups = {lines};
else
    ends = find(startsWith(strip(lines), "ENDMDL"));
    groups = cell(1, numel(modelBreaks));
    for index = 1:numel(modelBreaks)
        finish = numel(lines);
        next = ends(ends > modelBreaks(index));
        if ~isempty(next), finish = next(1); end
        groups{index} = lines(modelBreaks(index):finish);
    end
end
molecules = cell(1, 0);
for groupIndex = 1:numel(groups)
    species = strings(0, 1);
    coords = zeros(0, 3);
    for line = reshape(groups{groupIndex}, 1, [])
        raw = char(line);
        if ~(startsWith(raw, "ATOM  ") || startsWith(raw, "HETATM"))
            continue
        end
        raw = pad(raw, 80);
        symbol = strip(string(raw(77:78)));
        if symbol == ""
            atomName = regexprep(strip(string(raw(13:16))), "[^A-Za-z]", "");
            token = regexp(char(atomName), "^[A-Z][a-z]?", ...
                "match", "once");
            if isempty(token), token = regexp(char(atomName), ...
                    "^[A-Za-z]", "match", "once"); end
            symbol = string(token);
            symbol = upper(extractBefore(symbol, 2)) + ...
                lower(extractAfter(symbol, 1));
        end
        values = [str2double(raw(31:38)), ...
            str2double(raw(39:46)), str2double(raw(47:54))];
        if any(isnan(values))
            tokens = regexp(raw, ...
                "^(?:ATOM|HETATM)\s+\d+\s+\S+.*?\s+" + ...
                "([-+0-9.]+)\s+([-+0-9.]+)\s+([-+0-9.]+)", ...
                "tokens", "once");
            if isempty(tokens), continue, end
            values = str2double(tokens);
        end
        species(end + 1, 1) = symbol; %#ok<AGROW>
        coords(end + 1, :) = values; %#ok<AGROW>
    end
    if ~isempty(species)
        molecules{end + 1} = kssolv.analysis.matgenlab.core. ...
            Molecule(species, coords, charge_spin_check = false); %#ok<AGROW>
    end
end
end

function molecules = parseMol(text, splitRecords)
if splitRecords
    records = regexp(char(text), "\$\$\$\$", "split");
else
    records = {char(text)};
end
molecules = cell(1, 0);
for recordIndex = 1:numel(records)
    lines = splitlines(string(records{recordIndex}));
    if numel(lines) < 4, continue, end
    counts = regexp(char(lines(4)), ...
        "^\s*(\d+)\s+(\d+)", "tokens", "once");
    if isempty(counts), continue, end
    atomCount = str2double(counts{1});
    if numel(lines) < atomCount + 4, continue, end
    species = strings(atomCount, 1);
    coords = zeros(atomCount, 3);
    for atom = 1:atomCount
        tokens = regexp(char(lines(atom + 4)), ...
            "^\s*([-+0-9.eEdD]+)\s+([-+0-9.eEdD]+)\s+" + ...
            "([-+0-9.eEdD]+)\s+([A-Za-z][A-Za-z]?)", ...
            "tokens", "once");
        if isempty(tokens)
            error("KSSOLV:Matgenlab:Babel:MolAtom", ...
                "Invalid MOL atom record %d.", atom);
        end
        coords(atom, :) = str2double(replace(string(tokens(1:3)), ...
            ["D", "d"], ["E", "e"]));
        species(atom) = string(tokens{4});
    end
    molecules{end + 1} = kssolv.analysis.matgenlab.core. ...
        Molecule(species, coords, charge_spin_check = false); %#ok<AGROW>
end
end

function molecules = parseMol2(text)
chunks = regexp(char(text), "(?=@<TRIPOS>MOLECULE)", "split");
chunks = chunks(~cellfun(@(item) isempty(strtrim(item)), chunks));
molecules = cell(1, 0);
for chunkIndex = 1:numel(chunks)
    lines = splitlines(string(chunks{chunkIndex}));
    atomStart = find(strip(lines) == "@<TRIPOS>ATOM", 1);
    if isempty(atomStart), continue, end
    atomEnd = find(startsWith(strip(lines(atomStart + 1:end)), ...
        "@<TRIPOS>"), 1);
    if isempty(atomEnd), atomEnd = numel(lines) - atomStart;
    else, atomEnd = atomEnd - 1; end
    species = strings(atomEnd, 1);
    coords = zeros(atomEnd, 3);
    count = 0;
    for index = atomStart + (1:atomEnd)
        tokens = split(strip(lines(index)));
        if numel(tokens) < 6, continue, end
        count = count + 1;
        coords(count, :) = str2double(tokens(3:5));
        atomType = extractBefore(tokens(6) + ".", ".");
        symbol = regexp(char(atomType), "^[A-Za-z]{1,2}", ...
            "match", "once");
        species(count) = string(symbol);
    end
    species = species(1:count);
    coords = coords(1:count, :);
    if count > 0
        molecules{end + 1} = kssolv.analysis.matgenlab.core. ...
            Molecule(species, coords, charge_spin_check = false); %#ok<AGROW>
    end
end
end

function molecules = parseXMLMolecules(text)
blocks = regexp(char(text), ...
    '(?s)<molecule[^>]*>.*?</molecule>', 'match');
if isempty(blocks), blocks = {char(text)}; end
molecules = cell(1, 0);
for blockIndex = 1:numel(blocks)
    atoms = regexp(blocks{blockIndex}, '<atom[^>]*>', 'match');
    species = strings(numel(atoms), 1);
    coords = zeros(numel(atoms), 3);
    count = 0;
    for atomIndex = 1:numel(atoms)
        symbol = xmlAttribute(atoms{atomIndex}, "elementType");
        if symbol == "", continue, end
        count = count + 1;
        species(count) = symbol;
        x = xmlNumber(atoms{atomIndex}, ["x3", "x2"]);
        y = xmlNumber(atoms{atomIndex}, ["y3", "y2"]);
        z = xmlNumber(atoms{atomIndex}, "z3");
        if isnan(x), x = 0; end
        if isnan(y), y = 0; end
        if isnan(z), z = 0; end
        coords(count, :) = [x, y, z];
    end
    if count > 0
        molecules{end + 1} = kssolv.analysis.matgenlab.core. ...
            Molecule(species(1:count), coords(1:count, :), ...
            charge_spin_check = false); %#ok<AGROW>
    end
end
end

function value = xmlAttribute(text, name)
pattern = [char(name), '\s*=\s*"([^"]+)"'];
token = regexp(text, pattern, 'tokens', 'once');
if isempty(token)
    pattern = [char(name), '\s*=\s*''([^'']+)'''];
    token = regexp(text, pattern, 'tokens', 'once');
end
if isempty(token), value = ""; else, value = string(token{1}); end
end

function value = xmlNumber(text, names)
names = reshape(string(names), 1, []);
value = NaN;
for name = names
    token = xmlAttribute(text, name);
    if token ~= ""
        value = str2double(token);
        return
    end
end
end

function text = serializeMolecules(molecules, bonds, format)
switch format
    case "xyz"
        text = string(kssolv.analysis.matgenlab.io.xyz.XYZ(molecules));
    case "pdb"
        text = serializePDB(molecules{1});
    case {"mol", "sdf"}
        text = serializeMol(molecules{1}, bonds);
        if format == "sdf", text = text + newline + "$$$$"; end
    case "mol2"
        text = serializeMol2(molecules{1}, bonds);
    case {"cml", "mrv"}
        text = serializeCML(molecules{1}, format == "mrv");
    otherwise
        error("KSSOLV:Matgenlab:Babel:Format", ...
            "Unsupported native molecular format '%s'.", format);
end
end

function text = serializePDB(molecule)
lines = strings(molecule.num_sites + 2, 1);
lines(1) = "COMPND    MATGENLAB";
for index = 1:molecule.num_sites
    site = molecule.get_site(index);
    symbol = site.specie.symbol;
    lines(index + 1) = sprintf( ...
        "HETATM%5d %-4s MOL     1    %8.3f%8.3f%8.3f  1.00  0.00          %2s", ...
        index, char(symbol), site.x, site.y, site.z, char(symbol));
end
lines(end) = "END";
text = strjoin(lines, newline);
end

function text = serializeMol(molecule, bonds)
lines = strings(4 + molecule.num_sites + size(bonds, 1) + 1, 1);
lines(1) = molecule.formula;
lines(2) = "  matgenlab";
lines(3) = "";
lines(4) = sprintf("%3d%3d  0  0  0  0            999 V2000", ...
    molecule.num_sites, size(bonds, 1));
for index = 1:molecule.num_sites
    site = molecule.get_site(index);
    lines(index + 4) = sprintf( ...
        "%10.4f%10.4f%10.4f %-3s 0  0  0  0  0  0  0  0  0  0  0  0", ...
        site.x, site.y, site.z, char(site.specie.symbol));
end
offset = 4 + molecule.num_sites;
for index = 1:size(bonds, 1)
    lines(offset + index) = sprintf("%3d%3d%3d  0  0  0  0", ...
        bonds(index, 1), bonds(index, 2), round(bonds(index, 3)));
end
lines(end) = "M  END";
text = strjoin(lines, newline);
end

function text = serializeMol2(molecule, bonds)
lines = ["@<TRIPOS>MOLECULE"; molecule.formula; ...
    sprintf("%d %d 0 0 0", molecule.num_sites, size(bonds, 1)); ...
    "SMALL"; "NO_CHARGES"; ""; "@<TRIPOS>ATOM"];
for index = 1:molecule.num_sites
    site = molecule.get_site(index);
    lines(end + 1) = sprintf("%7d %-4s %12.6f %12.6f %12.6f %-3s 1 MOL 0.0", ...
        index, char(site.specie.symbol + index), ...
        site.x, site.y, site.z, char(site.specie.symbol)); %#ok<AGROW>
end
lines(end + 1) = "@<TRIPOS>BOND";
for index = 1:size(bonds, 1)
    lines(end + 1) = sprintf("%6d %4d %4d %s", index, ...
        bonds(index, 1), bonds(index, 2), ...
        bondOrderString(bonds(index, 3))); %#ok<AGROW>
end
text = strjoin(lines, newline);
end

function value = bondOrderString(order)
if abs(order - 1.5) < 1e-8, value = "ar";
else, value = string(round(order)); end
end

function text = serializeCML(molecule, marvin)
atoms = strings(molecule.num_sites, 1);
for index = 1:molecule.num_sites
    site = molecule.get_site(index);
    atoms(index) = sprintf( ...
        '<atom id="a%d" elementType="%s" x3="%.10g" y3="%.10g" z3="%.10g"/>', ...
        index, char(site.specie.symbol), site.x, site.y, site.z);
end
body = "    " + strjoin(atoms, newline + "    ");
if marvin
    text = "<cml xmlns=""http://www.chemaxon.com"">" + newline + ...
        "  <MDocument><MChemicalStruct><molecule>" + newline + ...
        "  <atomArray>" + newline + body + newline + ...
        "  </atomArray></molecule></MChemicalStruct></MDocument>" + ...
        newline + "</cml>";
else
    text = "<cml xmlns=""http://www.xml-cml.org/schema"">" + newline + ...
        "  <molecule><atomArray>" + newline + body + newline + ...
        "  </atomArray></molecule>" + newline + "</cml>";
end
end

function writeTextFile(filename, text)
file = fopen(filename, "w", "n", "UTF-8");
if file < 0
    error("KSSOLV:Matgenlab:Babel:Write", ...
        "Cannot open '%s' for writing.", filename);
end
cleanup = onCleanup(@() fclose(file));
fwrite(file, char(text), "char");
clear cleanup
end
