classdef MagneticSpaceGroup < ...
        kssolv.analysis.matgenlab.symmetry.groups.SymmetryGroup
    %#ok<*AGROW>
    %MAGNETICSPACEGROUP Representation of a BNS/OG magnetic space group.
    %
    % The bundled database is a lossless MATLAB-native conversion of
    % pymatgen-core 2026.7.24 symm_data_magnetic.sqlite. Runtime use does
    % not require Python, SQLite, or an external crystallography program.

    properties (SetAccess = private)
        jf (1,1) kssolv.analysis.matgenlab.symmetry.JonesFaithfulTransformation
        data (1,1) struct
    end

    properties (Dependent, SetAccess = private)
        crystal_system
        sg_symbol
    end

    methods
        function obj = MagneticSpaceGroup(label, settingTransformation)
            if nargin < 2
                settingTransformation = "a,b,c;0,0,0";
            end
            database = loadDatabase();
            rowIndex = resolveBns(database, label);
            obj.jf = normalizeTransformation(settingTransformation);
            obj.data = parseRecord(database, rowIndex);
            obj.symbol = obj.data.bns_label;
            obj.symmetry_ops = buildOperations(obj.data, obj.jf);
            obj.order = numel(obj.symmetry_ops);
        end

        function value = get.crystal_system(obj)
            number = obj.data.bns_number(1);
            if number <= 2
                value = "triclinic";
            elseif number <= 15
                value = "monoclinic";
            elseif number <= 74
                value = "orthorhombic";
            elseif number <= 142
                value = "tetragonal";
            elseif number <= 167
                value = "trigonal";
            elseif number <= 194
                value = "hexagonal";
            else
                value = "cubic";
            end
        end

        function value = get.sg_symbol(obj)
            value = obj.data.bns_label;
        end

        function [orbit, orbitMagmoms] = get_orbit( ...
                obj, point, magmom, tolerance)
            if nargin < 4, tolerance = 1e-5; end
            validateattributes(point, "numeric", ...
                {"vector", "numel", 3, "finite"});
            validateattributes(tolerance, "numeric", ...
                {"scalar", "nonnegative", "finite"});
            point = reshape(double(point), 1, 3);
            moment = kssolv.analysis.matgenlab.electronic_structure. ...
                Magmom(magmom);
            orbit = zeros(0, 3);
            orbitMagmoms = cell(1, 0);
            for index = 1:numel(obj.symmetry_ops)
                operation = obj.symmetry_ops{index};
                transformed = mod(round(operation.operate(point), 10), 1);
                if ~kssolv.analysis.matgenlab.symmetry.groups. ...
                        in_array_list(orbit, transformed, tolerance)
                    orbit(end + 1, :) = transformed;
                    transformedMoment = operation.operate_magmom( ...
                        moment.global_moment);
                    orbitMagmoms{end + 1} = ...
                        kssolv.analysis.matgenlab.electronic_structure. ...
                        Magmom(transformedMoment);
                end
            end
        end

        function tf = is_compatible(obj, lattice, tolerance, angleTolerance)
            if nargin < 3, tolerance = 1e-5; end
            if nargin < 4, angleTolerance = 5; end
            lengths = double(lattice.lengths);
            angles = double(lattice.angles);
            check = @(values, references, tol) all( ...
                abs(values(~isnan(references)) - ...
                references(~isnan(references))) < tol);
            switch obj.crystal_system
                case "cubic"
                    tf = check(lengths, repmat(lengths(1), 1, 3), ...
                        tolerance) && check(angles, [90, 90, 90], ...
                        angleTolerance);
                case "hexagonal"
                    tf = check(lengths, [lengths(1), lengths(1), NaN], ...
                        tolerance) && check(angles, [90, 90, 120], ...
                        angleTolerance);
                case "trigonal"
                    if endsWith(obj.sg_symbol, "H")
                        tf = check(lengths, ...
                            [lengths(1), lengths(1), NaN], tolerance) && ...
                            check(angles, [90, 90, 120], angleTolerance);
                    else
                        tf = check(lengths, ...
                            repmat(lengths(1), 1, 3), tolerance);
                    end
                case "tetragonal"
                    tf = check(lengths, ...
                        [lengths(1), lengths(1), NaN], tolerance) && ...
                        check(angles, [90, 90, 90], angleTolerance);
                case "orthorhombic"
                    tf = check(angles, [90, 90, 90], angleTolerance);
                case "monoclinic"
                    tf = check(angles, [90, NaN, 90], angleTolerance);
                otherwise
                    tf = true;
            end
        end

        function description = data_str(obj, includeOg)
            if nargin < 2, includeOg = true; end
            description = "";
            identity = kssolv.analysis.matgenlab.symmetry. ...
                JonesFaithfulTransformation.from_transformation_str( ...
                "a,b,c;0,0,0");
            if obj.jf ~= identity
                description = "Non-standard setting: ....." + newline + ...
                    transformationDescription(obj.jf) + newline + newline + ...
                    "Standard setting information: " + newline;
            end
            data = obj.data;
            bnsNumber = strjoin(string(data.bns_number), ".");
            if includeOg
                ogId = sprintf("\t\tOG: %s %s", ...
                    strjoin(string(data.og_number), "."), data.og_label);
            else
                ogId = "";
            end
            bnsOperatorText = strjoin(string(cellfun( ...
                @(entry) entry.str, data.bns_operators, ...
                "UniformOutput", false)), " ");
            if data.magtype == 4 && includeOg
                operatorPrefix = "Operators (BNS): ";
                wyckoffPrefix = "Wyckoff Positions (BNS): ";
                transformText = "OG-BNS Transform: (" + ...
                    data.og_bns_transform + ")" + newline;
            else
                operatorPrefix = "Operators: ";
                wyckoffPrefix = "Wyckoff Positions: ";
                transformText = "";
            end
            bnsOperatorText = wrapWords(bnsOperatorText, ...
                operatorPrefix, strlength(operatorPrefix));
            latticeText = "";
            if numel(data.bns_lattice) > 3
                latticeText = strjoin(string(cellfun( ...
                    @(entry) entry.str, data.bns_lattice(4:end), ...
                    "UniformOutput", false)), " ");
            end
            bnsWyckoff = formatWyckoff(data.bns_wyckoff);
            wyckoffHeader = wyckoffPrefix + latticeText;
            description = description + "BNS: " + bnsNumber + " " + ...
                data.bns_label + ogId + newline + transformText + ...
                bnsOperatorText + newline + wyckoffHeader + ...
                newline + bnsWyckoff;
            if data.magtype == 4 && includeOg
                ogOperatorText = strjoin(string(cellfun( ...
                    @(entry) entry.str, data.og_operators, ...
                    "UniformOutput", false)), " ");
                ogOperatorText = wrapWords(ogOperatorText, ...
                    "Operators (OG): ", strlength("Operators (OG): "));
                ogLattice = strjoin(string(cellfun( ...
                    @(entry) entry.str, data.og_lattice, ...
                    "UniformOutput", false)), " ");
                description = description + newline + ogOperatorText + ...
                    newline + "Wyckoff Positions (OG): " + ogLattice + ...
                    newline + formatWyckoff(data.og_wyckoff);
            elseif data.magtype == 4
                description = description + newline + ...
                    "Alternative OG setting exists for this space group.";
            end
            description = char(description);
        end

        function description = dataStr(obj, includeOg)
            if nargin < 2
                description = obj.data_str();
            else
                description = obj.data_str(includeOg);
            end
        end

        function value = char(obj)
            value = obj.data_str(false);
        end

        function value = string(obj)
            value = string(char(obj));
        end

        function tf = eq(obj, other)
            tf = isa(other, ...
                "kssolv.analysis.matgenlab.symmetry.maggroups." + ...
                "MagneticSpaceGroup") && ...
                obj.data.og_number(3) == other.data.og_number(3);
        end

        function tf = ne(obj, other)
            tf = ~eq(obj, other);
        end
    end

    methods (Static)
        function obj = from_og(label)
            database = loadDatabase();
            rowIndex = resolveOg(database, label);
            obj = kssolv.analysis.matgenlab.symmetry.maggroups. ...
                MagneticSpaceGroup(string(database.labels{rowIndex, 1}));
        end

        function obj = fromOg(label)
            obj = kssolv.analysis.matgenlab.symmetry.maggroups. ...
                MagneticSpaceGroup.from_og(label);
        end
    end
end

function database = loadDatabase()
persistent cachedDatabase
if isempty(cachedDatabase)
    packageDirectory = fileparts(mfilename("fullpath"));
    cachedDatabase = load(fullfile(packageDirectory, ...
        "magnetic_space_groups.mat"));
end
database = cachedDatabase;
end

function rowIndex = resolveBns(database, label)
if ischar(label) || (isstring(label) && isscalar(label))
    normalized = regexprep(string(label), "\s+", "");
    rowIndex = find(string(database.labels(:, 1)) == normalized, 1);
elseif isnumeric(label) && isscalar(label)
    validateattributes(label, "numeric", ...
        {"integer", ">=", 1, "<=", 1651});
    rowIndex = find(database.metadata(:, 6) == label, 1);
elseif isnumeric(label) && isvector(label) && numel(label) == 2
    label = double(label(:).');
    rowIndex = find(database.metadata(:, 2) == label(1) & ...
        database.metadata(:, 3) == label(2), 1);
else
    error("KSSOLV:Matgenlab:MagneticSpaceGroup:InvalidBnsLabel", ...
        "label must be a BNS string, two-number BNS sequence, or index.");
end
if isempty(rowIndex)
    error("KSSOLV:Matgenlab:MagneticSpaceGroup:UnknownBnsLabel", ...
        "Unknown BNS magnetic-space-group label.");
end
end

function rowIndex = resolveOg(database, label)
if ischar(label) || (isstring(label) && isscalar(label))
    rowIndex = find(string(database.labels(:, 2)) == string(label), 1);
elseif isnumeric(label) && isvector(label) && numel(label) == 3
    label = double(label(:).');
    rowIndex = find(database.metadata(:, 4) == label(1) & ...
        database.metadata(:, 5) == label(2) & ...
        database.metadata(:, 6) == label(3), 1);
else
    error("KSSOLV:Matgenlab:MagneticSpaceGroup:InvalidOgLabel", ...
        "label must be an OG string or three-number OG sequence.");
end
if isempty(rowIndex)
    error("KSSOLV:Matgenlab:MagneticSpaceGroup:UnknownOgLabel", ...
        "Unknown OG magnetic-space-group label.");
end
end

function transformation = normalizeTransformation(value)
className = "kssolv.analysis.matgenlab.symmetry." + ...
    "JonesFaithfulTransformation";
if isa(value, className)
    transformation = value;
elseif ischar(value) || (isstring(value) && isscalar(value))
    transformation = kssolv.analysis.matgenlab.symmetry. ...
        JonesFaithfulTransformation.from_transformation_str(string(value));
else
    error("KSSOLV:Matgenlab:MagneticSpaceGroup:Transformation", ...
        "setting_transformation must be a string or JonesFaithfulTransformation.");
end
end

function data = parseRecord(database, rowIndex)
metadata = double(database.metadata(rowIndex, :));
data = struct( ...
    "magtype", metadata(1), ...
    "bns_number", metadata(2:3), ...
    "bns_label", string(database.labels{rowIndex, 1}), ...
    "og_number", metadata(4:6), ...
    "og_label", string(database.labels{rowIndex, 2}), ...
    "og_bns_transform", parseTransformation( ...
        signedBlob(database.blobs{rowIndex, 1})), ...
    "bns_operators", {parseOperators(database, metadata(2), ...
        signedBlob(database.blobs{rowIndex, 2}))}, ...
    "bns_lattice", {parseLattice( ...
        signedBlob(database.blobs{rowIndex, 3}))}, ...
    "bns_wyckoff", {parseWyckoff( ...
        signedBlob(database.blobs{rowIndex, 4}))}, ...
    "og_operators", {parseOperators(database, metadata(2), ...
        signedBlob(database.blobs{rowIndex, 5}))}, ...
    "og_lattice", {parseLattice( ...
        signedBlob(database.blobs{rowIndex, 6}))}, ...
    "og_wyckoff", {parseWyckoff( ...
        signedBlob(database.blobs{rowIndex, 7}))});
end

function values = signedBlob(blob)
if isempty(blob)
    values = zeros(1, 0);
else
    values = double(typecast(uint8(blob(:)), "int8")).';
end
end

function entries = parseOperators(database, bnsNumber, blob)
entries = cell(1, 0);
if isempty(blob), return; end
isHexagonal = bnsNumber >= 143 && bnsNumber <= 194;
for offset = 1:6:numel(blob)
    raw = blob(offset:offset + 5);
    pointIndex = find(database.point_metadata(:, 1) == raw(1) - 1 & ...
        database.point_metadata(:, 2) == isHexagonal, 1);
    matrix = reshape(database.point_matrices(pointIndex, :), 3, 3).';
    translation = raw(2:4) / raw(5);
    operation = kssolv.analysis.matgenlab.core.MagSymmOp. ...
        fromRotationAndTranslationAndTimeReversal( ...
        matrix, translation, raw(6));
    seitz = "(" + string(database.point_symbols{pointIndex}) + "|" + ...
        fractionString(translation(1)) + "," + ...
        fractionString(translation(2)) + "," + ...
        fractionString(translation(3)) + ")";
    if raw(6) == -1, seitz = seitz + "'"; end
    entries{end + 1} = struct("op", operation, "str", seitz);
end
end

function entries = parseLattice(blob)
entries = cell(1, 0);
for offset = 1:4:numel(blob)
    raw = blob(offset:offset + 3);
    vector = raw(1:3) / raw(4);
    text = "(" + fractionString(vector(1)) + "," + ...
        fractionString(vector(2)) + "," + ...
        fractionString(vector(3)) + ")+";
    entries{end + 1} = struct("vector", vector, "str", text);
end
end

function entries = parseWyckoff(blob)
entries = cell(1, 0);
if isempty(blob), return; end
numberSites = blob(1);
offset = 0;
siteNumber = 1;
while numel(entries) < numberSites
    multiplicity = blob(2 + offset);
    label = string(blob(3 + offset) * multiplicity) + ...
        wyckoffLabel(numberSites - siteNumber);
    sites = strings(1, multiplicity);
    for index = 1:multiplicity
        startIndex = 4 + offset + (index - 1) * 22;
        raw = blob(startIndex:startIndex + 21);
        translation = raw(1:3) / raw(4);
        matrix = [raw(5), raw(8), raw(11); ...
            raw(6), raw(9), raw(12); ...
            raw(7), raw(10), raw(13)];
        magneticMatrix = [raw(14), raw(17), raw(20); ...
            raw(15), raw(18), raw(21); ...
            raw(16), raw(19), raw(22)];
        coordinateText = kssolv.analysis.matgenlab.util. ...
            transformation_to_string(matrix, translation);
        magneticText = kssolv.analysis.matgenlab.util. ...
            transformation_to_string(magneticMatrix, [0, 0, 0], ...
            ["x", "y", "z"], "m");
        sites(index) = "(" + coordinateText + ";" + magneticText + ")";
    end
    entries{end + 1} = struct( ...
        "label", label, "str", strjoin(sites, " "));
    siteNumber = siteNumber + 1;
    offset = offset + multiplicity * 22 + 2;
end
end

function label = wyckoffLabel(index)
if index <= 25
    label = string(char(double('a') + index));
else
    label = "alpha";
end
end

function value = parseTransformation(blob)
if isempty(blob)
    value = string.empty(1, 0);
    return
end
matrix = reshape(blob(1:9), 3, 3).';
origin = blob(10:12) / blob(13);
value = kssolv.analysis.matgenlab.util.transformation_to_string( ...
    matrix, [0, 0, 0], ["a", "b", "c"]) + ";" + ...
    fractionString(origin(1)) + "," + fractionString(origin(2)) + ...
    "," + fractionString(origin(3));
end

function operations = buildOperations(data, transformation)
operations = cellfun(@(entry) entry.op, data.bns_operators, ...
    "UniformOutput", false);
centered = cell(1, 0);
for latticeIndex = 1:numel(data.bns_lattice)
    vector = data.bns_lattice{latticeIndex}.vector;
    if isequal(vector, [1, 0, 0]) || isequal(vector, [0, 1, 0]) || ...
            isequal(vector, [0, 0, 1])
        continue
    end
    for operationIndex = 1:numel(operations)
        operation = operations{operationIndex};
        centered{end + 1} = ...
            kssolv.analysis.matgenlab.core.MagSymmOp. ...
            fromRotationAndTranslationAndTimeReversal( ...
            operation.rotation_matrix, ...
            operation.translation_vector + vector, ...
            operation.time_reversal);
    end
end
operations = [operations, centered];
operations = cellfun(@(operation) ...
    transformation.transform_symmop(operation), operations, ...
    "UniformOutput", false);
end

function text = fractionString(value)
if value == 0
    text = "0";
    return
end
[numerator, denominator] = rat(value, 1e-12);
if denominator == 1
    text = string(numerator);
else
    text = string(numerator) + "/" + string(denominator);
end
end

function text = formatWyckoff(entries)
lines = strings(1, numel(entries));
for index = 1:numel(entries)
    prefix = entries{index}.label + "  ";
    lines(index) = wrapWords(entries{index}.str, prefix, strlength(prefix));
end
text = strjoin(lines, newline);
end

function result = wrapWords(text, initialPrefix, subsequentIndent)
words = split(string(text));
prefix = string(initialPrefix);
indent = string(repmat(' ', 1, double(subsequentIndent)));
line = prefix;
lines = strings(1, 0);
for index = 1:numel(words)
    candidate = line + words(index);
    if strlength(candidate) > 70 && strlength(line) > strlength(prefix)
        lines(end + 1) = strip(line, "right");
        line = indent + words(index) + " ";
        prefix = indent;
    else
        line = candidate + " ";
    end
end
lines(end + 1) = strip(line, "right");
result = strjoin(lines, newline);
end

function text = transformationDescription(transformation)
matrixLines = join(string(transformation.P), " ");
text = "JonesFaithfulTransformation with P:" + newline + ...
    strjoin(matrixLines, newline) + newline + "and p:" + newline + ...
    strjoin(string(transformation.p), " ");
end
