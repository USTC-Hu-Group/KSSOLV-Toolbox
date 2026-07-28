function setup_potcars(potcar_dirs, varargin)
%SETUP_POTCARS Normalize a VASP POTCAR tree into compressed resources.

options = parseOptions(varargin{:});
paths = reshape(string(potcar_dirs), 1, []);
if numel(paths) ~= 2
    error("KSSOLV:Matgenlab:PmgConfig:PotcarDirectories", ...
        "potcar_dirs must contain source and destination paths.");
end
sourceDirectory = canonical(paths(1));
targetDirectory = canonical(paths(2));
if ~isfolder(sourceDirectory)
    error("KSSOLV:Matgenlab:PmgConfig:PotcarSource", ...
        "POTCAR source directory does not exist: %s", sourceDirectory);
end
prepareTarget(targetDirectory, options.overwrite);

listing = dir(fullfile(sourceDirectory, "**", "POTCAR*"));
listing = listing(~[listing.isdir]);
if isempty(listing), return; end
paths = string(fullfile({listing.folder}, {listing.name}));
[~, order] = sort(paths);
listing = listing(order);
seen = containers.Map("KeyType", "char", "ValueType", "logical");
mapping = functionalMapping();
for index = 1:numel(listing)
    source = string(fullfile(listing(index).folder, listing(index).name));
    speciesDirectory = string(listing(index).folder);
    [functionalDirectory, species] = fileparts(speciesDirectory);
    [~, functional, functionalExtension] = fileparts(functionalDirectory);
    functional = string(functional) + string(functionalExtension);
    if functional == "" || species == "", continue; end
    if isKey(mapping, char(functional))
        functional = string(mapping(char(functional)));
    end
    if species == "Osmium", species = "Os"; end
    identity = char(functional + "/" + species);
    if isKey(seen, identity), continue; end
    seen(identity) = true;
    try
        destinationDirectory = fullfile(targetDirectory, functional);
        if ~isfolder(destinationDirectory), mkdir(destinationDirectory); end
        writeCompressedPotcar(source, destinationDirectory, species);
    catch exception
        warning("KSSOLV:Matgenlab:PmgConfig:PotcarSkipped", ...
            "Unable to process '%s': %s", source, exception.message);
    end
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

function mapping = functionalMapping()
mapping = containers.Map( ...
    ["potpaw_PBE", "potpaw_PBE_52", "potpaw_PBE.52", ...
    "potpaw_PBE_54", "potpaw_PBE.54", "potpaw_PBE_64", ...
    "potpaw_PBE.64", "potpaw_LDA", "potpaw_LDA.52", ...
    "potpaw_LDA_52", "potpaw_LDA.54", "potpaw_LDA_54", ...
    "potpaw_LDA_64", "potpaw_LDA.64", "potpaw_GGA", ...
    "potUSPP_LDA", "potUSPP_GGA"], ...
    ["POT_GGA_PAW_PBE", "POT_GGA_PAW_PBE_52", ...
    "POT_GGA_PAW_PBE_52", "POT_GGA_PAW_PBE_54", ...
    "POT_GGA_PAW_PBE_54", "POT_PAW_PBE_64", ...
    "POT_PAW_PBE_64", "POT_LDA_PAW", "POT_LDA_PAW_52", ...
    "POT_LDA_PAW_52", "POT_LDA_PAW_54", ...
    "POT_LDA_PAW_54", "POT_LDA_PAW_64", ...
    "POT_LDA_PAW_64", "POT_GGA_PAW_PW91", ...
    "POT_LDA_US", "POT_GGA_US_PW91"]);
end

function writeCompressedPotcar(source, destinationDirectory, species)
temporaryDirectory = fullfile(destinationDirectory, ...
    ".matgenlab-" + string(char(java.util.UUID.randomUUID())));
mkdir(temporaryDirectory);
cleanup = onCleanup(@() removeDirectory(temporaryDirectory));
lowerSource = lower(source);
if endsWith(lowerSource, [".gz", ".z"])
    extracted = gunzip(source, temporaryDirectory);
    plainSource = string(extracted{1});
elseif endsWith(lowerSource, ".bz2")
    extracted = bunzip2(source, temporaryDirectory);
    plainSource = string(extracted{1});
else
    plainSource = fullfile(temporaryDirectory, "POTCAR");
    copyfile(source, plainSource);
end
plainDestination = fullfile(destinationDirectory, "POTCAR." + species);
copyfile(plainSource, plainDestination, "f");
generated = gzip(plainDestination, destinationDirectory);
delete(plainDestination);
expected = string(plainDestination) + ".gz";
if string(generated{1}) ~= expected
    movefile(generated{1}, expected, "f");
end
clear cleanup
removeDirectory(temporaryDirectory);
end

function removeDirectory(path)
if isfolder(path), rmdir(path, "s"); end
end

function path = canonical(path)
path = string(path);
if ~startsWith(path, filesep) && ...
        ~(ispc && ~isempty(regexp(path, "^[A-Za-z]:[\\/]", "once")))
    path = fullfile(pwd, path);
end
path = string(char(java.io.File(char(path)).getCanonicalPath()));
end
