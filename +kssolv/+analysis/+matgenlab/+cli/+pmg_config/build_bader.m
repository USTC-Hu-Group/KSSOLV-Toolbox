function state = build_bader(fortran_command, varargin)
%BUILD_BADER Build Bader through explicitly injected transport/executor.

if nargin < 1 || isempty(fortran_command), fortran_command = "gfortran"; end
options = buildOptions(varargin{:});
archive = fullfile(options.work_dir, "bader.tar.gz");
sourceDirectory = fullfile(options.work_dir, "bader-source");
if isfile(archive) || isfolder(sourceDirectory) || isfile(sourceDirectory)
    error("KSSOLV:Matgenlab:PmgConfig:BuildCollision", ...
        "Bader build paths already exist inside work_dir.");
end
request = struct("action", "download", ...
    "url", "https://theory.cm.utexas.edu/henkelman/code/bader/" + ...
    "download/bader.tar.gz", "destination", archive);
state = true;
try
    requireSuccess(options.transport(request), "Bader transport");
    mkdir(sourceDirectory);
    extractRequest = struct("action", "extract", "program", "tar", ...
        "arguments", ["-zxf", archive, "-C", sourceDirectory], ...
        "working_directory", options.work_dir, ...
        "destination", sourceDirectory, "environment", struct());
    requireSuccess(options.executor(extractRequest), "Bader extraction");
    makefile = fullfile(sourceDirectory, ...
        "makefile.osx_" + string(fortran_command));
    if ~isfile(makefile)
        error("KSSOLV:Matgenlab:PmgConfig:Makefile", ...
            "Bader compiler makefile was not found: %s", makefile);
    end
    copyfile(makefile, fullfile(sourceDirectory, "makefile"), "f");
    invoke(options.executor, "make", strings(0, 1), sourceDirectory);
    executable = fullfile(sourceDirectory, "bader");
    if ~isfile(executable)
        error("KSSOLV:Matgenlab:PmgConfig:MissingExecutable", ...
            "Bader build did not create %s.", executable);
    end
    movefile(executable, fullfile(options.work_dir, "bader"), "f");
catch exception
    warning("KSSOLV:Matgenlab:PmgConfig:BuildBader", "%s", ...
        exception.message);
    state = false;
end
if options.cleanup
    if isfolder(sourceDirectory), rmdir(sourceDirectory, "s"); end
    if isfile(archive), delete(archive); end
end
end

function options = buildOptions(varargin)
options = struct("work_dir", "", "executor", [], ...
    "transport", [], "cleanup", true);
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
if string(options.work_dir) == ""
    error("KSSOLV:Matgenlab:PmgConfig:WorkDirectory", ...
        "An explicit work_dir is required.");
end
options.work_dir = canonical(options.work_dir);
if ~isfolder(options.work_dir)
    error("KSSOLV:Matgenlab:PmgConfig:WorkDirectory", ...
        "work_dir does not exist: %s", options.work_dir);
end
if ~isa(options.executor, "function_handle") || ...
        ~isa(options.transport, "function_handle")
    error("KSSOLV:Matgenlab:PmgConfig:Injection", ...
        "Explicit executor and transport function handles are required.");
end
options.cleanup = logical(options.cleanup);
end

function invoke(executor, program, arguments, folder)
request = struct("action", "execute", "program", string(program), ...
    "arguments", reshape(string(arguments), 1, []), ...
    "working_directory", string(folder), "environment", struct());
requireSuccess(executor(request), program);
end

function requireSuccess(result, label)
if islogical(result) && isscalar(result)
    success = result;
elseif isnumeric(result) && isscalar(result)
    success = result == 0;
elseif isstruct(result) && isfield(result, "status")
    success = double(result.status) == 0;
else
    success = false;
end
if ~success
    error("KSSOLV:Matgenlab:PmgConfig:ExternalFailure", ...
        "%s failed.", string(label));
end
end

function path = canonical(path)
path = string(path);
if ~startsWith(path, filesep) && ...
        ~(ispc && ~isempty(regexp(path, "^[A-Za-z]:[\\/]", "once")))
    path = fullfile(pwd, path);
end
path = string(char(java.io.File(char(path)).getCanonicalPath()));
end
