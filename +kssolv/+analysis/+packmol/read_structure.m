function molecule = read_structure(filename, filetype)
%READ_STRUCTURE Read a Packmol PDB, XYZ, or TINKER template molecule.

filename = string(filename);
filetype = lower(string(filetype));
if ~isfile(filename)
    error("KSSOLV:Packmol:OpenFile", ...
        "Could not open structure file '%s'.", filename);
end
switch filetype
    case "xyz"
        molecule = readXyz(filename);
    case "pdb"
        molecule = readPdb(filename);
    case "tinker"
        molecule = readTinker(filename);
    otherwise
        error("KSSOLV:Packmol:FileType", ...
            "File type must be pdb, xyz, or tinker.");
end
molecule.filename = filename;
molecule.filetype = filetype;
molecule.original_coordinates = molecule.coordinates;
end

function molecule = readXyz(filename)
lines = splitlines(string(fileread(filename)));
if isempty(lines)
    invalid(filename);
end
n = str2double(strtrim(lines(1)));
if ~isfinite(n) || n < 1 || n ~= fix(n) || numel(lines) < n + 2
    invalid(filename);
end
symbols = strings(n, 1);
coordinates = zeros(n, 3);
for i = 1:n
    values = kssolv.analysis.packmol.tokenize(lines(i + 2));
    if numel(values) < 4
        invalid(filename);
    end
    symbols(i) = values(1);
    coordinates(i, :) = str2double(values(2:4));
end
if any(~isfinite(coordinates), "all")
    invalid(filename);
end
molecule = baseMolecule(symbols, coordinates);
molecule.title = strtrim(lines(2));
molecule.records = strings(n, 1);
molecule.connectivity = cell(n, 1);
molecule.atom_types = zeros(n, 1);
end

function molecule = readPdb(filename)
lines = splitlines(string(fileread(filename)));
selected = startsWith(lines, "ATOM") | startsWith(lines, "HETATM");
records = lines(selected);
n = numel(records);
if n == 0
    invalid(filename);
end
coordinates = zeros(n, 3);
symbols = strings(n, 1);
serials = zeros(n, 1);
terBeforeAtom = false(n + 1, 1);
atomCount = 0;
for lineIndex = 1:numel(lines)
    if startsWith(lines(lineIndex), "ATOM") || ...
            startsWith(lines(lineIndex), "HETATM")
        atomCount = atomCount + 1;
    elseif startsWith(lines(lineIndex), "TER")
        terBeforeAtom(min(atomCount + 1, n + 1)) = true;
    end
end
for i = 1:n
    record = normalizedPdbRecord(records(i));
    coordinates(i, :) = [ ...
        str2double(extractBetween(record, 31, 38)), ...
        str2double(extractBetween(record, 39, 46)), ...
        str2double(extractBetween(record, 47, 54))];
    serials(i) = str2double(extractBetween(record, 7, 11));
    residue = str2double(extractBetween(record, 23, 26));
    if ~isfinite(serials(i)) || serials(i) ~= fix(serials(i)) || ...
            ~isfinite(residue) || residue ~= fix(residue)
        invalid(filename);
    end
    symbol = strtrim(extractBetween(record, 77, 78));
    if strlength(symbol) == 0
        symbol = regexprep(strtrim(extractBetween(record, 13, 16)), ...
            "[^A-Za-z]", "");
        if strlength(symbol) > 2
            symbol = extractBefore(symbol, 3);
        end
    end
    symbols(i) = symbol;
end
if any(~isfinite(coordinates), "all")
    invalid(filename);
end
connectivity = cell(n, 1);
conectLines = lines(startsWith(lines, "CONECT"));
for line = reshape(conectLines, 1, [])
    values = sscanf(char(extractAfter(line, 6)), "%d").';
    if numel(values) < 2
        record = char(pad(line, 80));
        values = zeros(1, 0);
        for column = 7:5:77
            parsed = str2double(record(column:min(column + 4, 80)));
            if isfinite(parsed)
                values(end + 1) = parsed; %#ok<AGROW>
            end
        end
    end
    if numel(values) < 2
        continue
    end
    source = find(serials == values(1), 1);
    if isempty(source)
        continue
    end
    targets = zeros(1, 0);
    for serial = values(2:end)
        target = find(serials == serial, 1);
        if ~isempty(target)
            targets(end + 1) = target; %#ok<AGROW>
        end
    end
    combined = [connectivity{source}, targets];
    connectivity{source} = combined(1:min(9, numel(combined)));
end
molecule = baseMolecule(symbols, coordinates);
molecule.title = string(filename);
molecule.records = records;
molecule.connectivity = connectivity;
molecule.atom_types = zeros(n, 1);
molecule.ter_before_atom = terBeforeAtom;
end

function molecule = readTinker(filename)
lines = splitlines(string(fileread(filename)));
first = kssolv.analysis.packmol.tokenize(lines(1));
if isempty(first)
    invalid(filename);
end
n = str2double(first(1));
if ~isfinite(n) || n < 1 || n ~= fix(n) || numel(lines) < n + 1
    invalid(filename);
end
symbols = strings(n, 1);
coordinates = zeros(n, 3);
connectivity = cell(n, 1);
records = strings(n, 1);
atomTypes = zeros(n, 1);
for i = 1:n
    values = kssolv.analysis.packmol.tokenize(lines(i + 1));
    if numel(values) < 6
        invalid(filename);
    end
    symbols(i) = values(2);
    coordinates(i, :) = str2double(values(3:5));
    atomTypes(i) = str2double(values(6));
    if numel(values) > 6
        connectivity{i} = str2double(values(7:end));
    else
        connectivity{i} = zeros(1, 0);
    end
    records(i) = lines(i + 1);
end
if any(~isfinite(coordinates), "all") || ...
        any(~isfinite(atomTypes)) || any(atomTypes ~= fix(atomTypes)) || ...
        any(cellfun(@(values) any(~isfinite(values)) || ...
            any(values ~= fix(values)), connectivity))
    invalid(filename);
end
molecule = baseMolecule(symbols, coordinates);
if numel(first) > 1
    molecule.title = join(first(2:end), " ");
else
    molecule.title = "Without_title";
end
molecule.records = records;
molecule.connectivity = connectivity;
molecule.atom_types = atomTypes;
end

function molecule = baseMolecule(symbols, coordinates)
n = size(coordinates, 1);
molecule = struct( ...
    "symbols", reshape(string(symbols), [], 1), ...
    "coordinates", double(coordinates), ...
    "original_coordinates", double(coordinates), ...
    "title", "", ...
    "records", strings(n, 1), ...
    "connectivity", {cell(n, 1)}, ...
    "atom_types", zeros(n, 1), ...
    "ter_before_atom", false(n + 1, 1), ...
    "filename", "", ...
    "filetype", "");
end

function record = normalizedPdbRecord(value)
record = char(pad(value, 80));
record = record(1:80);
end

function invalid(filename)
error("KSSOLV:Packmol:StructureFile", ...
    "Failed to read a valid molecular structure from '%s'.", filename);
end
