classdef Critic2Caller < handle
    %CRITIC2CALLER Safe Critic2 adapter using an explicitly injected executor.
    %
    % The executor receives a request struct containing input_script,
    % command, and in-memory input files. It must return text or a struct
    % with stdout, stderr, status, cpreport, and yt fields as applicable.

    properties (SetAccess = private)
        input_script (1,1) string = ""
        stdout (1,1) string = ""
        stderr (1,1) string = ""
        cpreport = []
        yt = []
        output = []
        executor = []
    end

    methods
        function obj = Critic2Caller(inputScript, options)
            arguments
                inputScript = ""
                options.executor = []
                options.files (1,1) struct = struct()
                options.command (1,1) string = "critic2"
            end
            obj.input_script = string(inputScript);
            obj.executor = options.executor;
            if isempty(obj.executor)
                error("KSSOLV:Matgenlab:Critic2:ExecutorRequired", ...
                    "External Critic2 execution requires an explicit " + ...
                    "executor function handle.");
            end
            if ~isa(obj.executor, "function_handle")
                error("KSSOLV:Matgenlab:Critic2:ExecutorType", ...
                    "executor must be a MATLAB function handle.");
            end
            request = struct("command", options.command, ...
                "input_filename", "input_script.cri", ...
                "input_script", obj.input_script, ...
                "files", options.files);
            result = obj.callExecutor(request);
            [obj.stdout, obj.stderr, status, obj.cpreport, obj.yt] = ...
                normalizeResult(result);
            if status ~= 0
                error("KSSOLV:Matgenlab:Critic2:Execution", ...
                    "critic2 exited with return code %d: %s", ...
                    status, obj.stdout);
            end
            if strlength(obj.stderr) > 0
                warning("KSSOLV:Matgenlab:Critic2:StandardError", ...
                    "%s", obj.stderr);
            end
        end
    end

    methods (Access = private)
        function result = callExecutor(obj, request)
            count = nargin(obj.executor);
            if count == 1 || count < 0
                result = obj.executor(request);
            elseif count == 2
                result = obj.executor(request.input_script, request.command);
            else
                result = obj.executor(request.input_script, ...
                    request.command, request.files);
            end
        end
    end

    methods (Static)
        function caller = from_chgcar(structure, chgcar, chgcarRef, ...
                userInputSettings, writeCml, writeJson, zpsp, varargin)
            if nargin < 2, chgcar = []; end
            if nargin < 3, chgcarRef = []; end
            if nargin < 4 || isempty(userInputSettings)
                userInputSettings = struct();
            end
            if nargin < 5 || isempty(writeCml), writeCml = false; end
            if nargin < 6 || isempty(writeJson), writeJson = true; end
            if nargin < 7, zpsp = []; end
            options = parseOptions(struct("executor", [], ...
                "command", "critic2"), varargin);

            settings = struct("CPEPS", 0.1, ...
                "SEED", ["WS", "PAIR DIST 10"]);
            names = fieldnames(userInputSettings);
            for index = 1:numel(names)
                settings.(names{index}) = userInputSettings.(names{index});
            end

            lines = "crystal POSCAR";
            files = struct("POSCAR", ...
                kssolv.analysis.matgenlab.io.vasp.Poscar(structure));
            if ~isempty(chgcarRef)
                lines(end + 1) = "load ref.CHGCAR id chg_ref";
                lines(end + 1) = "reference chg_ref";
                files.ref_CHGCAR = chgcarRef;
            end
            if ~isempty(chgcar)
                line = "load int.CHGCAR id chg_int";
                if ~isempty(zpsp)
                    line = line + formatZpsp(zpsp);
                end
                lines(end + 1) = line;
                lines(end + 1) = "integrable chg_int";
                files.int_CHGCAR = chgcar;
            end
            auto = "auto ";
            names = fieldnames(settings);
            for index = 1:numel(names)
                key = string(names{index});
                value = settings.(names{index});
                if iscell(value) || (isstring(value) && ~isscalar(value))
                    values = reshape(string(value), 1, []);
                    for item = values
                        auto = auto + key + " " + item + " ";
                    end
                else
                    auto = auto + key + " " + string(value) + " ";
                end
            end
            lines(end + 1) = auto;
            if logical(writeCml)
                lines(end + 1) = "cpreport ../table.cml cell border graph";
            end
            if logical(writeJson)
                lines(end + 1) = "cpreport cpreport.json";
            end
            if logical(writeJson) && ~isempty(chgcar)
                lines(end + 1) = "yt";
                lines(end + 1) = "yt JSON yt.json";
            end
            caller = kssolv.analysis.matgenlab.command_line. ...
                critic2_caller.Critic2Caller(strjoin(lines, newline), ...
                executor = options.executor, files = files, ...
                command = string(options.command));
            caller.output = kssolv.analysis.matgenlab.command_line. ...
                critic2_caller.Critic2Analysis(structure, ...
                caller.stdout, caller.stderr, caller.cpreport, ...
                caller.yt, zpsp);
        end

        function caller = from_path(path, suffix, zpsp, varargin)
            if nargin < 2, suffix = ""; end
            if nargin < 3, zpsp = []; end
            options = parseOptions(struct("executor", [], ...
                "command", "critic2"), varargin);
            package = "kssolv.analysis.matgenlab.command_line.critic2_caller.";
            chgcarPath = feval(package + "get_filepath", "CHGCAR", ...
                "Could not find CHGCAR!", path, suffix);
            if strlength(chgcarPath) == 0
                error("KSSOLV:Matgenlab:Critic2:MissingChgcar", ...
                    "Could not find CHGCAR in '%s'.", string(path));
            end
            chgcar = kssolv.analysis.matgenlab.io.vasp.Chgcar. ...
                from_file(chgcarPath);
            reference = [];
            if isempty(zpsp)
                potcarPath = feval(package + "get_filepath", "POTCAR", ...
                    "Could not find POTCAR, will not be able to " + ...
                    "calculate charge transfer.", path, suffix);
                if strlength(potcarPath) > 0
                    potcar = kssolv.analysis.matgenlab.io.vasp.Potcar. ...
                        from_file(potcarPath);
                    zpsp = containers.Map("KeyType", "char", ...
                        "ValueType", "double");
                    for index = 1:potcar.count
                        zpsp(char(potcar(index).element)) = ...
                            potcar(index).nelectrons;
                    end
                end
            end
            if isempty(zpsp)
                firstPath = feval(package + "get_filepath", "AECCAR0", ...
                    "Could not find AECCAR0, interpret Bader results " + ...
                    "with caution.", path, suffix);
                secondPath = feval(package + "get_filepath", "AECCAR2", ...
                    "Could not find AECCAR2, interpret Bader results " + ...
                    "with caution.", path, suffix);
                if strlength(firstPath) > 0 && strlength(secondPath) > 0
                    first = kssolv.analysis.matgenlab.io.vasp.Chgcar. ...
                        from_file(firstPath);
                    second = kssolv.analysis.matgenlab.io.vasp.Chgcar. ...
                        from_file(secondPath);
                    reference = first.linear_add(second);
                end
            end
            caller = kssolv.analysis.matgenlab.command_line. ...
                critic2_caller.Critic2Caller.from_chgcar( ...
                chgcar.structure, chgcar, reference, struct(), false, ...
                true, zpsp, "executor", options.executor, ...
                "command", options.command);
        end
    end
end

function [stdout, stderr, status, cpreport, yt] = normalizeResult(result)
stderr = ""; status = 0; cpreport = []; yt = [];
if ischar(result) || isstring(result)
    stdout = string(result);
elseif isstruct(result)
    if isfield(result, "stdout"), stdout = string(result.stdout);
    elseif isfield(result, "output"), stdout = string(result.output);
    else
        error("KSSOLV:Matgenlab:Critic2:ExecutorResult", ...
            "Executor result must include stdout or output.");
    end
    if isfield(result, "stderr"), stderr = string(result.stderr); end
    if isfield(result, "status"), status = double(result.status); end
    if isfield(result, "returncode"), status = double(result.returncode); end
    if isfield(result, "cpreport"), cpreport = result.cpreport; end
    if isfield(result, "yt"), yt = result.yt; end
else
    error("KSSOLV:Matgenlab:Critic2:ExecutorResult", ...
        "Executor must return text or a result struct.");
end
end

function text = formatZpsp(zpsp)
text = " zpsp";
if isa(zpsp, "containers.Map")
    names = string(zpsp.keys);
    for name = names
        text = text + " " + name + " " + ...
            string(fix(double(zpsp(char(name)))));
    end
elseif isstruct(zpsp)
    names = string(fieldnames(zpsp));
    for name = names.'
        text = text + " " + name + " " + ...
            string(fix(double(zpsp.(name))));
    end
else
    error("KSSOLV:Matgenlab:Critic2:Zpsp", ...
        "zpsp must be a struct or containers.Map.");
end
end

function options = parseOptions(options, values)
if isempty(values), return; end
if isscalar(values) && isstruct(values{1})
    names = fieldnames(values{1});
    for index = 1:numel(names)
        options.(names{index}) = values{1}.(names{index});
    end
    return
end
if mod(numel(values), 2) ~= 0
    error("KSSOLV:Matgenlab:Critic2:Options", ...
        "Optional arguments must be name/value pairs.");
end
for index = 1:2:numel(values)
    name = char(string(values{index}));
    if ~isfield(options, name)
        error("KSSOLV:Matgenlab:Critic2:Options", ...
            "Unknown option '%s'.", name);
    end
    options.(name) = values{index + 1};
end
end
