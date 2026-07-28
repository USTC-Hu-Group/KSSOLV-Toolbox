classdef PackmolSet < kssolv.analysis.matgenlab.io.InputSet
    %PACKMOLSET Named PACKMOL inputs with an explicit execution boundary.

    properties
        seed (1,1) double = 1
        inputfile (1,1) string = "packmol.inp"
        outputfile (1,1) string = "packmol_out.xyz"
        stdoutfile (1,1) string = "packmol.stdout"
        control_params = struct()
        tolerance (1,1) double = 2
        executor = []
    end

    methods
        function obj = PackmolSet(inputs, options)
            arguments
                inputs = containers.Map( ...
                    "KeyType", "char", "ValueType", "any")
                options.seed (1,1) double = 1
                options.inputfile (1,1) string = "packmol.inp"
                options.outputfile (1,1) string = "packmol_out.xyz"
                options.stdoutfile (1,1) string = "packmol.stdout"
                options.control_params = struct()
                options.tolerance (1,1) double = 2
                options.executor = []
            end
            kwargs = struct("seed", options.seed, ...
                "inputfile", options.inputfile, ...
                "outputfile", options.outputfile, ...
                "stdoutfile", options.stdoutfile, ...
                "control_params", options.control_params, ...
                "tolerance", options.tolerance);
            obj@kssolv.analysis.matgenlab.io.InputSet(inputs, kwargs);
            obj.seed = options.seed;
            obj.inputfile = options.inputfile;
            obj.outputfile = options.outputfile;
            obj.stdoutfile = options.stdoutfile;
            obj.control_params = options.control_params;
            obj.tolerance = options.tolerance;
            obj.executor = options.executor;
            if ~isempty(obj.executor) && ~isa(obj.executor, "function_handle")
                error("KSSOLV:Matgenlab:Packmol:ExecutorType", ...
                    "executor must be a MATLAB function handle.");
            end
        end

        function run(obj, path, timeout, executor)
            %RUN Execute PACKMOL via an explicitly supplied MATLAB callback.
            if nargin < 2 || strlength(string(path)) == 0, path = "."; end
            if nargin < 3 || isempty(timeout), timeout = 30; end
            if nargin < 4 || isempty(executor), executor = obj.executor; end
            if isempty(executor)
                error("KSSOLV:Matgenlab:Packmol:ExecutorRequired", ...
                    "Running PackmolSet requires an explicit executor " + ...
                    "function handle; implicit PATH execution is disabled.");
            end
            if ~isa(executor, "function_handle")
                error("KSSOLV:Matgenlab:Packmol:ExecutorType", ...
                    "executor must be a MATLAB function handle.");
            end
            path = string(path);
            inputPath = fullfile(path, obj.inputfile);
            if ~isfolder(path)
                error("KSSOLV:Matgenlab:Packmol:Directory", ...
                    "PACKMOL working directory '%s' does not exist.", path);
            end
            if ~isfile(inputPath)
                error("KSSOLV:Matgenlab:Packmol:InputFile", ...
                    "PACKMOL input file '%s' does not exist.", inputPath);
            end
            request = struct( ...
                "command", "packmol", ...
                "arguments", strings(1, 0), ...
                "working_directory", path, ...
                "stdin_path", obj.inputfile, ...
                "stdin", string(fileread(inputPath)), ...
                "timeout", double(timeout), ...
                "inputfile", obj.inputfile, ...
                "outputfile", obj.outputfile, ...
                "stdoutfile", obj.stdoutfile);
            result = executor(request);
            [stdout, stderr, status, timedOut] = normalizeResult(result);
            if timedOut
                error("KSSOLV:Matgenlab:Packmol:Timeout", ...
                    "PACKMOL did not finish within %g seconds.", timeout);
            end
            if status ~= 0
                error("KSSOLV:Matgenlab:Packmol:ExecutionFailed", ...
                    "Packmol failed with error code %d and stderr: %s", ...
                    status, stderr);
            end
            if contains(stdout, "ERROR")
                if contains(stdout, "Could not open file.")
                    error("KSSOLV:Matgenlab:Packmol:PathSpaces", ...
                        "Your packmol might be too old to handle paths " + ...
                        "with spaces. Please use a newer version or paths " + ...
                        "without spaces.");
                end
                pieces = split(stdout, "ERROR");
                message = pieces(end);
                error("KSSOLV:Matgenlab:Packmol:PackingFailed", ...
                    "Packmol failed with return code 0 and stdout: %s", ...
                    message);
            end
            writeText(fullfile(path, obj.stdoutfile), stdout);
        end
    end

    methods (Static)
        function obj = from_directory(~)
            obj = kssolv.analysis.matgenlab.io.packmol.PackmolSet(); %#ok<NASGU>
            error("KSSOLV:Matgenlab:Packmol:FromDirectory", ...
                "from_directory has not been implemented in PackmolSet");
        end

        function obj = fromDirectory(directory)
            obj = kssolv.analysis.matgenlab.io.packmol.PackmolSet. ...
                from_directory(directory);
        end
    end
end

function [stdout, stderr, status, timedOut] = normalizeResult(result)
stdout = ""; stderr = ""; status = 0; timedOut = false;
if ischar(result) || isstring(result)
    stdout = string(result);
elseif isstruct(result)
    if isfield(result, "stdout")
        stdout = string(result.stdout);
    elseif isfield(result, "output")
        stdout = string(result.output);
    end
    if isfield(result, "stderr"), stderr = string(result.stderr); end
    if isfield(result, "status"), status = double(result.status); end
    if isfield(result, "timed_out")
        timedOut = logical(result.timed_out);
    elseif isfield(result, "timedOut")
        timedOut = logical(result.timedOut);
    end
else
    error("KSSOLV:Matgenlab:Packmol:ExecutorResult", ...
        "executor must return text or a result struct.");
end
if ~isscalar(status) || ~isfinite(status)
    error("KSSOLV:Matgenlab:Packmol:ExecutorResult", ...
        "executor status must be a finite scalar.");
end
end

function writeText(filename, contents)
fileId = fopen(filename, "w", "n", "UTF-8");
if fileId < 0
    error("KSSOLV:Matgenlab:Packmol:StdoutFile", ...
        "Unable to write PACKMOL stdout file '%s'.", filename);
end
cleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, char(contents), "char");
clear cleanup
end
