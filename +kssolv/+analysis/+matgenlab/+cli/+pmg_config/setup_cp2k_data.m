function setup_cp2k_data(cp2k_data_dirs, varargin)
%SETUP_CP2K_DATA Build a pymatgen-compatible CP2K resource directory.
%
% setup_cp2k_data([source, destination]) parses every *BASIS* and
% *POTENTIAL* file in source and writes one resource file per element.
% Existing destinations require the explicit overwrite=true option.

arguments
    cp2k_data_dirs
end
arguments (Repeating)
    varargin
end

options = parseOptions(varargin{:});
paths = reshape(string(cp2k_data_dirs), 1, []);
if numel(paths) ~= 2
    error("KSSOLV:Matgenlab:PmgConfig:Cp2kDirectories", ...
        "cp2k_data_dirs must contain source and destination paths.");
end
sourceDirectory = absolutePath(paths(1));
targetDirectory = absolutePath(paths(2));
if ~isfolder(sourceDirectory)
    error("KSSOLV:Matgenlab:PmgConfig:Cp2kSource", ...
        "CP2K data directory does not exist: %s", sourceDirectory);
end
prepareTarget(targetDirectory, options.overwrite);

symbols = kssolv.analysis.matgenlab.core.PeriodicTableData.symbols(false);
potentials = emptyBuckets(symbols);
bases = emptyBuckets(symbols);

potentialFiles = matchingFiles(sourceDirectory, "*POTENTIAL*");
for index = 1:numel(potentialFiles)
    filename = potentialFiles(index);
    chunks = safeChunks(filename);
    for chunkIndex = 1:numel(chunks)
        try
            item = kssolv.analysis.matgenlab.io.cp2k.GthPotential. ...
                from_str(chunks{chunkIndex});
            symbol = char(string(item.element));
            if ~isKey(potentials, symbol), continue; end
            item.filename = string(fileBaseName(filename));
            item.version = [];
            record = item.as_dict();
            record.raw = string(item.raw);
            record.n_elecs = item.n_elecs;
            record.r_loc = item.r_loc;
            record.nexp_ppl = item.nexp_ppl;
            record.c_exp_ppl = item.c_exp_ppl;
            record.nprj = item.nprj;
            potentials(symbol) = appendRecord( ...
                potentials(symbol), ...
                hashText(canonicalPotential(item)), record);
        catch
            % Upstream deliberately skips malformed and unknown chunks.
        end
    end
end

basisFiles = matchingFiles(sourceDirectory, "*BASIS*");
for index = 1:numel(basisFiles)
    filename = basisFiles(index);
    chunks = safeChunks(filename);
    for chunkIndex = 1:numel(chunks)
        try
            item = kssolv.analysis.matgenlab.io.cp2k. ...
                GaussianTypeOrbitalBasisSet.from_str(chunks{chunkIndex});
            symbol = char(string(item.element));
            if ~isKey(bases, symbol), continue; end
            item.filename = string(fileBaseName(filename));
            record = item.as_dict();
            record.raw = string(item.raw);
            record.nset = item.nset;
            record.n = item.n;
            record.lmin = item.lmin;
            record.lmax = item.lmax;
            record.nshell = item.nshell;
            record.exponents = item.exponents;
            record.coefficients = item.coefficients;
            bases(symbol) = appendRecord( ...
                bases(symbol), hashText(canonicalBasis(item)), record);
        catch
            % Upstream deliberately skips malformed and unknown chunks.
        end
    end
end

for index = 1:numel(symbols)
    symbol = char(symbols(index));
    writeElementFile(fullfile(targetDirectory, symbol), ...
        potentials(symbol), bases(symbol));
end
end

function options = parseOptions(varargin)
options = struct("overwrite", false);
if isempty(varargin), return; end
if isscalar(varargin) && isstruct(varargin{1})
    input = varargin{1};
    names = fieldnames(input);
    for index = 1:numel(names)
        options.(names{index}) = input.(names{index});
    end
elseif mod(numel(varargin), 2) == 0
    for index = 1:2:numel(varargin)
        options.(char(string(varargin{index}))) = varargin{index + 1};
    end
else
    error("KSSOLV:Matgenlab:PmgConfig:Options", ...
        "Options must be a struct or name-value pairs.");
end
options.overwrite = logical(options.overwrite);
end

function prepareTarget(path, overwrite)
if isfolder(path)
    if ~overwrite
        error("KSSOLV:Matgenlab:PmgConfig:DestinationExists", ...
            "Destination exists; pass overwrite=true to continue: %s", path);
    end
elseif isfile(path)
    error("KSSOLV:Matgenlab:PmgConfig:DestinationFile", ...
        "Destination is a file: %s", path);
else
    [created, message] = mkdir(path);
    if ~created
        error("KSSOLV:Matgenlab:PmgConfig:CreateDirectory", ...
            "Unable to create '%s': %s", path, message);
    end
end
end

function files = matchingFiles(folder, pattern)
listing = dir(fullfile(folder, pattern));
listing = listing(~[listing.isdir]);
if isempty(listing)
    files = strings(0, 1);
else
    [~, order] = sort({listing.name});
    listing = listing(order);
    files = string(fullfile({listing.folder}, {listing.name})).';
end
end

function chunks = safeChunks(filename)
try
    chunks = kssolv.analysis.matgenlab.io.cp2k.chunk(fileread(filename));
catch
    chunks = {};
end
end

function buckets = emptyBuckets(symbols)
buckets = containers.Map("KeyType", "char", "ValueType", "any");
for index = 1:numel(symbols)
    buckets(char(symbols(index))) = struct( ...
        "hashes", strings(0, 1), "records", {cell(0, 1)});
end
end

function bucket = appendRecord(bucket, hash, record)
bucket.hashes(end + 1, 1) = string(hash);
bucket.records{end + 1, 1} = record;
end

function hash = hashText(text)
digest = java.security.MessageDigest.getInstance("MD5");
digest.update(uint8(lower(char(string(text)))));
bytes = typecast(digest.digest(), "uint8");
hash = lower(string(reshape(dec2hex(bytes, 2).', 1, [])));
end

function text = canonicalPotential(item)
header = string(item.element) + " " + string(item.name);
aliases = reshape(string(item.alias_names), 1, []);
if ~isempty(aliases), header = header + " " + join(aliases, " "); end
text = header + " " + newline;
text = text + join(compose("%g", item.n_elecs), " ") + newline;
text = text + sprintf(" %.14f %d", item.r_loc, item.nexp_ppl);
for coefficient = reshape(item.c_exp_ppl, 1, [])
    text = text + sprintf(" % .14f", coefficient);
end
text = text + " " + newline + sprintf("%g ", item.nprj) + newline;
end

function text = canonicalBasis(item)
header = string(item.element) + " " + string(item.name);
aliases = reshape(string(item.alias_names), 1, []);
if ~isempty(aliases), header = header + " " + join(aliases, " "); end
text = header + " " + newline + sprintf("%d", item.nset) + newline;
for setIndex = 1:item.nset
    headerValues = [item.n(setIndex), item.lmin(setIndex), ...
        item.lmax(setIndex), numel(item.exponents{setIndex}), ...
        reshape(item.nshell{setIndex}, 1, [])];
    text = text + join(compose("%g", headerValues), " ") + newline;
    for exponentIndex = 1:numel(item.exponents{setIndex})
        text = text + sprintf("\t  %.14f", ...
            item.exponents{setIndex}(exponentIndex));
        coefficients = item.coefficients{setIndex}{exponentIndex};
        for coefficient = reshape(coefficients, 1, [])
            text = text + sprintf(" % .14f", coefficient);
        end
        text = text + " " + newline;
    end
end
end

function writeElementFile(path, potentials, bases)
file = fopen(path, "w", "n", "UTF-8");
if file < 0
    error("KSSOLV:Matgenlab:PmgConfig:Write", ...
        "Unable to write CP2K resource file: %s", path);
end
cleanup = onCleanup(@() fclose(file));
fprintf(file, "potentials:\n");
writeRecords(file, potentials);
fprintf(file, "basis_sets:\n");
writeRecords(file, bases);
clear cleanup
end

function writeRecords(file, bucket)
for index = 1:numel(bucket.hashes)
    record = bucket.records{index};
    fprintf(file, "  '%s':\n", bucket.hashes(index));
    fprintf(file, "    name: %s\n", string(record.name));
    fprintf(file, "    filename: %s\n", string(record.filename));
    fprintf(file, "    element: %s\n", string(record.element));
    fprintf(file, "    potential: %s\n", string(record.potential));
    fprintf(file, "    raw: %s\n", ...
        jsonencode(string(record.raw), "PrettyPrint", false));
    fprintf(file, "    data: %s\n", ...
        jsonencode(record, "PrettyPrint", false));
end
end

function name = fileBaseName(path)
[~, stem, extension] = fileparts(path);
name = stem + extension;
end

function path = absolutePath(path)
path = string(path);
if ~isAbsolute(path)
    path = string(fullfile(pwd, path));
end
path = string(char(java.io.File(char(path)).getCanonicalPath()));
end

function value = isAbsolute(path)
value = startsWith(path, filesep);
if ispc
    value = value || ~isempty(regexp(path, "^[A-Za-z]:[\\/]", "once"));
end
end
