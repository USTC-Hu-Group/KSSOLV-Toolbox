classdef BorgQueen < handle
    %BORGQUEEN Recursively assimilate calculation trees with a drone.
    properties (Access = private)
        drone
        number_of_drones (1,1) double = 1
        data cell = {}
    end

    methods
        function obj = BorgQueen(drone, rootpath, numberOfDrones)
            if nargin == 0, return; end
            if nargin < 2, rootpath = []; end
            if nargin < 3 || isempty(numberOfDrones), numberOfDrones = 1; end
            if ~isa(drone, ...
                    "kssolv.analysis.matgenlab.apps.borg.AbstractDrone")
                error("KSSOLV:Matgenlab:BorgQueen:Drone", ...
                    "drone must implement AbstractDrone.");
            end
            numberOfDrones = double(numberOfDrones);
            if ~isscalar(numberOfDrones) || numberOfDrones < 1 || ...
                    numberOfDrones ~= fix(numberOfDrones)
                error("KSSOLV:Matgenlab:BorgQueen:DroneCount", ...
                    "number_of_drones must be a positive integer.");
            end
            obj.drone = drone;
            obj.number_of_drones = numberOfDrones;
            if ~isempty(rootpath) && strlength(string(rootpath)) > 0
                if numberOfDrones > 1
                    obj.parallel_assimilate(rootpath);
                else
                    obj.serial_assimilate(rootpath);
                end
            end
        end

        function parallel_assimilate(obj, rootpath)
            paths = obj.validPaths(rootpath);
            count = numel(paths);
            if count == 0, return; end
            usedParallel = false;
            if obj.number_of_drones > 1 && ...
                    exist("backgroundPool", "file") == 2 && ...
                    exist("parfeval", "file") == 2
                try
                    pool = backgroundPool;
                    futures = parallel.FevalFuture.empty(0, count);
                    for index = 1:count
                        futures(index) = parfeval(pool, @assimilateOne, ...
                            1, obj.drone, paths(index));
                    end
                    for index = 1:count
                        value = fetchOutputs(futures(index));
                        if ~isempty(value)
                            obj.data{end + 1} = value;
                        end
                    end
                    usedParallel = true;
                catch exception
                    warning("KSSOLV:Matgenlab:BorgQueen:ParallelFallback", ...
                        "Parallel assimilation unavailable: %s", ...
                        exception.message);
                end
            end
            if ~usedParallel
                obj.assimilatePaths(paths);
            end
        end

        function serial_assimilate(obj, root)
            obj.assimilatePaths(obj.validPaths(root));
        end

        function value = get_data(obj)
            value = obj.data;
        end

        function save_data(obj, filename)
            text = kssolv.analysis.matgenlab.util.encode(obj.data);
            writeCompressedText(filename, text);
        end

        function load_data(obj, filename)
            text = readCompressedText(filename);
            decoded = kssolv.analysis.matgenlab.util.decode( ...
                text, "Strict", false);
            if iscell(decoded)
                obj.data = reshape(decoded, 1, []);
            elseif isempty(decoded)
                obj.data = {};
            else
                obj.data = {decoded};
            end
        end
    end

    methods (Access = private)
        function assimilatePaths(obj, paths)
            for index = 1:numel(paths)
                value = obj.drone.assimilate(paths(index));
                % serial_assimilate in pymatgen preserves an empty result;
                % successful production drones return an MSONable entry.
                obj.data{end + 1} = value;
            end
        end

        function paths = validPaths(obj, root)
            root = string(root);
            if ~isscalar(root) || ~isfolder(root)
                error("KSSOLV:Matgenlab:BorgQueen:Root", ...
                    "Root directory '%s' does not exist.", root);
            end
            directories = recursiveDirectories(root);
            paths = strings(1, 0);
            for directory = directories
                listing = dir(directory);
                subdirectories = listing([listing.isdir]);
                subdirectoryNames = string({subdirectories.name});
                subdirectoryNames = subdirectoryNames( ...
                    ~ismember(subdirectoryNames, [".", ".."]));
                files = listing(~[listing.isdir]);
                fileNames = string({files.name});
                found = obj.drone.get_valid_paths( ...
                    {directory, cellstr(subdirectoryNames), ...
                    cellstr(fileNames)});
                if ~isempty(found)
                    paths = [paths, reshape(string(found), 1, [])]; ...
                        %#ok<AGROW>
                end
            end
            paths = unique(paths, "stable");
        end
    end
end

function value = assimilateOne(drone, path)
value = drone.assimilate(path);
end

function directories = recursiveDirectories(root)
directories = reshape(string(root), 1, []);
listing = dir(fullfile(root, "**"));
if isempty(listing), return; end
listing = listing([listing.isdir]);
names = string(fullfile({listing.folder}, {listing.name}));
names = names(~ismember(string({listing.name}), [".", ".."]));
directories = unique([directories, names], "stable");
end

function writeCompressedText(filename, text)
filename = string(filename);
folder = fileparts(filename);
if strlength(folder) > 0 && ~isfolder(folder)
    error("KSSOLV:Matgenlab:BorgQueen:OutputDirectory", ...
        "Output directory '%s' does not exist.", folder);
end
if endsWith(lower(filename), ".bz2")
    writeBzip2(filename, text);
    return
end
if endsWith(lower(filename), [".gz", ".bz2"])
    temporary = string(tempname);
    mkdir(temporary);
    cleanup = onCleanup(@() rmdir(temporary, "s"));
    plain = fullfile(temporary, "assimilated.json");
    writePlainText(plain, text);
    compressed = string(gzip(plain, temporary));
    [success, message] = movefile(compressed, filename, "f");
    if ~success
        error("KSSOLV:Matgenlab:BorgQueen:Write", "%s", message);
    end
    clear cleanup
else
    writePlainText(filename, text);
end
end

function writeBzip2(filename, text)
fileStream = javaObject("java.io.FileOutputStream", char(filename));
try
    stream = javaObject(char( ...
        "org.apache.commons.compress.compressors.bzip2." + ...
        "BZip2CompressorOutputStream"), fileStream);
catch exception
    fileStream.close();
    rethrow(exception);
end
cleanup = onCleanup(@() closeBzip2(stream, fileStream));
bytes = unicode2native(char(text), "UTF-8");
stream.write(typecast(uint8(bytes), "int8"), 0, numel(bytes));
stream.finish();
clear cleanup
end

function closeBzip2(stream, fileStream)
try
    stream.close();
catch
end
try
    fileStream.close();
catch
end
end

function text = readCompressedText(filename)
filename = string(filename);
if ~isfile(filename)
    error("KSSOLV:Matgenlab:BorgQueen:MissingFile", ...
        "Assimilation file '%s' does not exist.", filename);
end
if endsWith(lower(filename), ".bz2")
    text = readBzip2(filename);
    return
end
if endsWith(lower(filename), [".gz", ".bz2"])
    temporary = string(tempname);
    mkdir(temporary);
    cleanup = onCleanup(@() rmdir(temporary, "s"));
    if endsWith(lower(filename), ".gz")
        paths = gunzip(filename, temporary);
    else
        paths = bunzip2(filename, temporary);
    end
    text = string(fileread(paths{1}));
    clear cleanup
else
    text = string(fileread(filename));
end
end

function text = readBzip2(filename)
fileStream = javaObject("java.io.FileInputStream", char(filename));
try
    stream = javaObject(char( ...
        "org.apache.commons.compress.compressors.bzip2." + ...
        "BZip2CompressorInputStream"), fileStream);
catch exception
    fileStream.close();
    rethrow(exception);
end
cleanup = onCleanup(@() closeBzip2(stream, fileStream));
text = string(javaMethod("toString", ...
    "org.apache.commons.io.IOUtils", stream, "UTF-8"));
clear cleanup
end

function writePlainText(filename, text)
fileId = fopen(filename, "w", "n", "UTF-8");
if fileId < 0
    error("KSSOLV:Matgenlab:BorgQueen:Write", ...
        "Unable to open '%s' for writing.", string(filename));
end
cleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, char(text), "char");
clear cleanup
end
