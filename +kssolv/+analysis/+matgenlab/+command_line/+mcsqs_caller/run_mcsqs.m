function result = run_mcsqs(structure, clusters, scaling, search_time, ...
    directory, instances, temperature, wr, wn, wd, tolerance)
%RUN_MCSQS Run ATAT mcsqs through an explicitly configured executor.
if nargin < 3 || isempty(scaling), scaling = 1; end
if nargin < 4 || isempty(search_time), search_time = 60; end
if nargin < 5, directory = ""; end
if nargin < 6, instances = []; end
if nargin < 7 || isempty(temperature), temperature = 1; end
if nargin < 8 || isempty(wr), wr = 1; end
if nargin < 9 || isempty(wn), wn = 1; end
if nargin < 10 || isempty(wd), wd = 0.5; end
if nargin < 11 || isempty(tolerance), tolerance = 1e-3; end
if structure.is_ordered
    error("KSSOLV:Matgenlab:Mcsqs:Ordered", ...
        "Pick a disordered structure");
end
if isscalar(scaling)
    if scaling ~= fix(scaling)
        error("KSSOLV:Matgenlab:Mcsqs:Scaling", ...
            "scaling should be an integer");
    end
else
    scaling = reshape(double(scaling), 1, []);
    if numel(scaling) ~= 3 || any(scaling ~= fix(scaling)) || ...
            any(scaling <= 0)
        error("KSSOLV:Matgenlab:Mcsqs:Scaling", ...
            "scaling must be an integer or three positive integers");
    end
end
executor = kssolv.analysis.matgenlab.command_line.mcsqs_caller. ...
    mcsqsExecutorStore("get");
if isempty(executor)
    error("KSSOLV:Matgenlab:Mcsqs:ExecutorRequired", ...
        "run_mcsqs requires an explicitly configured ATAT executor.");
end
if strlength(string(directory)) == 0, directory = string(tempname); end
request = struct("structure", structure, "clusters", clusters, ...
    "scaling", scaling, "search_time_minutes", search_time, ...
    "directory", string(directory), "instances", instances, ...
    "temperature", temperature, "wr", wr, "wn", wn, "wd", wd, ...
    "tol", tolerance, "n_atoms", structure.num_sites);
response = executor(request);
if isa(response, "kssolv.analysis.matgenlab.command_line.mcsqs_caller.Sqs")
    result = response;
    return
end
if ~isstruct(response) || ~isfield(response, "bestsqs")
    error("KSSOLV:Matgenlab:Mcsqs:ExecutorResult", ...
        "ATAT executor must return Sqs or a struct containing bestsqs.");
end
objective = fieldOr(response, "objective_function", NaN);
allStructures = fieldOr(response, "allsqs", {});
parsedClusters = fieldOr(response, "clusters", clusters);
resultDirectory = fieldOr(response, "directory", string(directory));
result = kssolv.analysis.matgenlab.command_line.mcsqs_caller.Sqs( ...
    response.bestsqs, objective, allStructures, parsedClusters, ...
    resultDirectory);
end

function value = fieldOr(input, name, defaultValue)
if isfield(input, name), value = input.(name);
else, value = defaultValue;
end
end
