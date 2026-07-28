function install_software(install, varargin)
%INSTALL_SOFTWARE Build an optional package in an explicit work directory.

options = parseOptions(varargin{:});
install = string(install);
if ~isscalar(install) || ~ismember(install, ["enumlib", "bader"])
    error("KSSOLV:Matgenlab:PmgConfig:Software", ...
        "install must be 'enumlib' or 'bader'.");
end
compiler = detectCompiler(options.executor, options.work_dir);
builderOptions = struct("work_dir", options.work_dir, ...
    "executor", options.executor, "transport", options.transport, ...
    "cleanup", options.cleanup);
if install == "enumlib"
    success = kssolv.analysis.matgenlab.cli.pmg_config.build_enum( ...
        compiler, builderOptions);
else
    success = kssolv.analysis.matgenlab.cli.pmg_config.build_bader( ...
        compiler, builderOptions);
end
if ~success
    warning("KSSOLV:Matgenlab:PmgConfig:BuildFailed", ...
        "Unable to build %s.", install);
end
end

function options = parseOptions(varargin)
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
if string(options.work_dir) == "" || ~isfolder(options.work_dir)
    error("KSSOLV:Matgenlab:PmgConfig:WorkDirectory", ...
        "An existing explicit work_dir is required.");
end
if ~isa(options.executor, "function_handle") || ...
        ~isa(options.transport, "function_handle")
    error("KSSOLV:Matgenlab:PmgConfig:Injection", ...
        "Explicit executor and transport function handles are required.");
end
end

function compiler = detectCompiler(executor, folder)
compiler = "";
for candidate = ["ifort", "gfortran"]
    request = struct("action", "probe", "program", candidate, ...
        "arguments", "--version", "working_directory", string(folder), ...
        "environment", struct());
    result = executor(request);
    if succeeded(result)
        compiler = candidate;
        break
    end
end
if compiler == ""
    error("KSSOLV:Matgenlab:PmgConfig:Compiler", ...
        "No Fortran compiler was reported by the executor.");
end
end

function value = succeeded(result)
if islogical(result) && isscalar(result)
    value = result;
elseif isnumeric(result) && isscalar(result)
    value = result == 0;
elseif isstruct(result) && isfield(result, "status")
    value = double(result.status) == 0;
else
    value = false;
end
end
