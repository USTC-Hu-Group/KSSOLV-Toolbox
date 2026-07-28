classdef GulpCaller
    %GULPCALLER Safe GULP runner using an explicitly supplied executor.

    properties (SetAccess = private)
        cmd (1,1) string = "gulp"
        executor = []
    end

    methods
        function obj = GulpCaller(cmd, options)
            arguments
                cmd = "gulp"
                options.executor = []
            end
            if isa(cmd, "function_handle") && isempty(options.executor)
                options.executor = cmd;
                cmd = "gulp";
            end
            obj.cmd = string(cmd);
            obj.executor = options.executor;
            if ~isempty(obj.executor) && ~isa(obj.executor, "function_handle")
                error("KSSOLV:Matgenlab:GULP:ExecutorType", ...
                    "executor must be a MATLAB function handle.");
            end
        end

        function output = run(obj, gin)
            if isempty(obj.executor)
                throw(kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                    GulpError("External GULP execution requires an " + ...
                    "explicit executor function handle."));
            end
            argumentCount = nargin(obj.executor);
            if argumentCount == 1
                result = obj.executor(string(gin));
            else
                result = obj.executor(string(gin), obj.cmd);
            end
            [stdout, stderr, status] = normalizeResult(result);
            if status ~= 0 && strlength(stderr) == 0
                stderr = "GULP executor exited with status " + status + ".";
            end
            if contains(lower(stderr), "error")
                throw(kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                    GulpError(stderr));
            end
            if contains(stdout, "ERROR")
                throw(kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                    GulpError(stdout));
            end
            marker = ...
                "Conditions for a minimum have not been satisfied";
            if contains(stdout, marker)
                throw(kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                    GulpConvergenceError(stdout));
            end
            if status ~= 0
                throw(kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                    GulpError(stderr));
            end
            output = join(splitlines(stdout), newline) + newline;
        end
    end
end

function [stdout, stderr, status] = normalizeResult(result)
stderr = ""; status = 0;
if ischar(result) || isstring(result)
    stdout = string(result);
elseif isstruct(result)
    if isfield(result, "stdout"), stdout = string(result.stdout);
    elseif isfield(result, "output"), stdout = string(result.output);
    else
        error("KSSOLV:Matgenlab:GULP:ExecutorResult", ...
            "Executor result must include stdout or output.");
    end
    if isfield(result, "stderr"), stderr = string(result.stderr); end
    if isfield(result, "status"), status = double(result.status); end
else
    error("KSSOLV:Matgenlab:GULP:ExecutorResult", ...
        "Executor must return text or a result struct.");
end
end
