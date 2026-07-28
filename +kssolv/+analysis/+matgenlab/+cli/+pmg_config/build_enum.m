function state = build_enum(fortran_command, varargin)
%BUILD_ENUM Build enumlib through explicitly injected transport/executor.
%
% No network or process is invoked implicitly. transport(request) must
% materialize the requested source tree, while executor(request) performs
% each external build command.

if nargin < 1 || isempty(fortran_command), fortran_command = "gfortran"; end
options = buildOptions(varargin{:});
sourceDirectory = fullfile(options.work_dir, "enumlib");
if isfolder(sourceDirectory) || isfile(sourceDirectory)
    error("KSSOLV:Matgenlab:PmgConfig:BuildCollision", ...
        "Build source path already exists: %s", sourceDirectory);
end
request = struct("action", "git_clone", ...
    "url", "https://github.com/msg-byu/enumlib", ...
    "destination", sourceDirectory, "recursive", true);
state = true;
try
    requireSuccess(options.transport(request), "enumlib transport");
    invoke(options.executor, "make", strings(0, 1), ...
        fullfile(sourceDirectory, "symlib", "src"), ...
        struct("F90", string(fortran_command)));
    invoke(options.executor, "make", strings(0, 1), ...
        fullfile(sourceDirectory, "src"), struct());
    invoke(options.executor, "make", "enum.x", ...
        fullfile(sourceDirectory, "src"), struct());
    executable = fullfile(sourceDirectory, "src", "enum.x");
    if ~isfile(executable)
        error("KSSOLV:Matgenlab:PmgConfig:MissingExecutable", ...
            "enumlib build did not create %s.", executable);
    end
    copyfile(executable, fullfile(options.work_dir, "enum.x"), "f");
catch exception
    warning("KSSOLV:Matgenlab:PmgConfig:BuildEnum", "%s", ...
        exception.message);
    state = false;
end
if options.cleanup && isfolder(sourceDirectory)
    rmdir(sourceDirectory, "s");
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

function invoke(executor, program, arguments, folder, environment)
request = struct("action", "execute", "program", string(program), ...
    "arguments", reshape(string(arguments), 1, []), ...
    "working_directory", string(folder), "environment", environment);
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
