classdef RemoteMatlabBridgeEntrypoint
    %REMOTEMATLABBRIDGEENTRYPOINT Matching-release bridge process entry.

    methods (Static)
        function status = run(action, workspace)
            action = string(action);
            workspace = string(workspace);
            status = baseStatus();
            try
                prepareToolbox(workspace);
                switch action
                    case "submit"
                        status = submitJob(workspace);
                    case "status"
                        if isStandalone(workspace)
                            status = inspectStandalone(workspace, "");
                        else
                            [job, control] = recoverJob(workspace);
                            status = inspectJob(job, control, "");
                        end
                    case "cancel"
                        if isStandalone(workspace)
                            status = cancelStandalone(workspace);
                        else
                            [job, control] = recoverJob(workspace);
                            cancel(job);
                            status = inspectJob(job, control, "Cancelled");
                        end
                    case "fetch"
                        if isStandalone(workspace)
                            status = inspectStandalone(workspace, "");
                            if status.State ~= "Finished" && ...
                                    status.State ~= "Retrieved"
                                error("KSSOLV:Remote:BridgeJobNotFinished", ...
                                    "Bridge job is in state %s.", ...
                                    status.State);
                            end
                            if ~isfile(fullfile(workspace, "result.mat"))
                                error("KSSOLV:Remote:BridgeResultMissing", ...
                                    "The standalone Bridge result is missing.");
                            end
                            status.State = "Retrieved";
                        else
                            [job, control] = recoverJob(workspace);
                            current = inspectJob(job, control, "");
                            if current.State ~= "Finished" && ...
                                    current.State ~= "Retrieved"
                                error("KSSOLV:Remote:BridgeJobNotFinished", ...
                                    "Bridge job is in state %s.", ...
                                    current.State);
                            end
                            outputs = fetchOutputs(job);
                            save(fullfile(workspace, "result.mat"), ...
                                "outputs", "-v7.3");
                            status = inspectJob(job, control, "Retrieved");
                        end
                    otherwise
                        error("KSSOLV:Remote:BridgeActionInvalid", ...
                            "Unsupported bridge action %s.", action);
                end
            catch exception
                status.State = "Failed";
                status.ErrorIdentifier = string(exception.identifier);
                status.ErrorSummary = string(exception.getReport( ...
                    "extended", "hyperlinks", "off"));
            end
            status.UpdatedAt = nowText();
            writeStatus(workspace, status);
        end

        function status = runStandalone(workspace)
            workspace = string(workspace);
            status = baseStatus();
            try
                prepareToolbox(workspace);
                control = loadControl(workspace);
                control.ProcessId = currentProcessId();
                save(fullfile(workspace, "control.mat"), ...
                    "control", "-v7");
                status = standaloneBase(control, "Running");
                status.UpdatedAt = nowText();
                writeStatusFile(workspace, status);
                % Leave a short cancellation window after the durable PID
                % hand-off and before user code starts.
                pause(2);
                outputs = executeStandalone(workspace);
                save(fullfile(workspace, "result.mat"), ...
                    "outputs", "-v7.3");
                status = standaloneBase(control, "Finished");
            catch exception
                status.State = "Failed";
                status.ErrorIdentifier = string(exception.identifier);
                status.ErrorSummary = string(exception.getReport( ...
                    "extended", "hyperlinks", "off"));
            end
            status.UpdatedAt = nowText();
            writeStatus(workspace, status);
        end
    end
end

function status = submitJob(workspace)
request = jsondecode(fileread(fullfile(workspace, "request.json")));
if executionMode(request) == "StandaloneMatlab"
    status = launchStandalone(workspace, request);
    return
end
profileName = string(request.ProfileName);
profiles = string(parallel.listProfiles());
if ~any(profiles == profileName)
    error("KSSOLV:Remote:BridgeProfileNotFound", ...
        "Remote MATLAB profile %s was not found.", profileName);
end
toolboxRoot = toolboxRootFor(workspace);
addpath(toolboxRoot);
cluster = parcluster(char(profileName));
argumentsList = {"AutoAttachFiles", false, "AutoAddClientPath", false, ...
    "AdditionalPaths", {char(toolboxRoot)}};
poolSize = double(request.PoolSize);
if poolSize > 0
    argumentsList = [argumentsList, {"Pool", poolSize}];
end
operation = "Workflow";
if isfield(request, "Operation")
    operation = string(request.Operation);
end
if operation == "Probe"
    runner = @kssolv.services.remote.diagnostics.remoteProbe;
    inputs = {};
else
    value = load(fullfile(workspace, "snapshot.mat"), "snapshot");
    snapshot = value.snapshot;
    kssolv.services.remote.execution.WorkflowSnapshotBuilder.validate(snapshot);
    runner = @kssolv.services.remote.execution.RemoteWorkflowRunner.executeBridge;
    inputs = {snapshot};
end
job = batch(cluster, runner, 1, inputs, argumentsList{:});
control = struct( ...
    "Version", 1, ...
    "ProfileName", profileName, ...
    "MatlabJobId", double(job.ID), ...
    "SubmittedAt", nowText());
save(fullfile(workspace, "control.mat"), "control", "-v7");
status = inspectJob(job, control, "");
end

function status = launchStandalone(workspace, ~)
control = struct( ...
    "Version", 1, ...
    "ExecutionMode", "StandaloneMatlab", ...
    "ProfileName", "", ...
    "MatlabJobId", -1, ...
    "ProcessId", -1, ...
    "LauncherProcessId", -1, ...
    "SubmittedAt", nowText());
save(fullfile(workspace, "control.mat"), "control", "-v7");
toolboxRoot = toolboxRootFor(workspace);
expression = "addpath(" + matlabLiteral(toolboxRoot) + ...
    "); kssolv.services.remote.bridge.RemoteMatlabBridgeEntrypoint." + ...
    "runStandalone(" + matlabLiteral(workspace) + ");";
executable = fullfile(string(matlabroot), "bin", "matlab");
logPath = fullfile(workspace, "standalone.log");
command = "nohup " + shellQuote(executable) + " -batch " + ...
    shellQuote(expression) + " >" + shellQuote(logPath) + ...
    " 2>&1 < /dev/null & echo $!";
[commandStatus, output] = system(char(command));
tokens = regexp(char(output), '(?m)^([0-9]+)\s*$', 'tokens');
if commandStatus ~= 0 || isempty(tokens)
    error("KSSOLV:Remote:StandaloneLaunchFailed", ...
        "Unable to launch standalone remote MATLAB: %s", ...
        strip(string(output)));
end

control.LauncherProcessId = str2double(tokens{end}{1});
control.ProcessId = control.LauncherProcessId;
save(fullfile(workspace, "control.mat"), "control", "-v7");
status = standaloneBase(control, "Queued");
end

function value = currentProcessId()
if exist("matlabProcessID", "file") == 2 || ...
        exist("matlabProcessID", "builtin") == 5
    value = double(matlabProcessID);
else
    % feature('getpid') is available in older releases supported by the
    % release-neutral Mirror protocol, including R2024a.
    value = double(feature("getpid")); %#ok<FEATGPID>
end
end

function outputs = executeStandalone(workspace)
request = jsondecode(fileread(fullfile(workspace, "request.json")));
operation = "Workflow";
if isfield(request, "Operation")
    operation = string(request.Operation);
end
if operation == "Probe"
    outputs = {kssolv.services.remote.diagnostics.remoteProbe()};
else
    value = load(fullfile(workspace, "snapshot.mat"), "snapshot");
    snapshot = value.snapshot;
    kssolv.services.remote.execution.WorkflowSnapshotBuilder.validate(snapshot);
    outputs = {kssolv.services.remote.execution.RemoteWorkflowRunner. ...
        executeBridge(snapshot)};
end
end

function status = inspectStandalone(workspace, stateOverride)
control = loadControl(workspace);
statusPath = fullfile(workspace, "status.json");
if isfile(statusPath)
    try
        status = jsondecode(fileread(statusPath));
    catch
        status = standaloneBase(control, "Unknown");
    end
else
    status = standaloneBase(control, "Queued");
end
status.BridgeMatlabRelease = string(status.BridgeMatlabRelease);
status.MatlabProfileName = "";
status.MatlabJobId = -1;
status.SubmittedAt = string(control.SubmittedAt);
status.State = string(status.State);
status.ErrorIdentifier = string(status.ErrorIdentifier);
status.ErrorSummary = string(status.ErrorSummary);
if any(status.State == ["Queued", "Running", "Unknown"]) && ...
        ~standaloneProcessAlive(control, workspace)
    if isfile(fullfile(workspace, "result.mat"))
        status.State = "Finished";
    elseif status.State ~= "Running" && ...
            withinStandaloneStartupGrace(control)
        % The launcher can return before the operating system exposes the
        % final MATLAB command line through ps.  Keep a newly submitted
        % process queued instead of recording a permanent false failure.
        status.State = "Queued";
    else
        status.State = "Failed";
        status.ErrorIdentifier = "KSSOLV:Remote:StandaloneProcessLost";
        status.ErrorSummary = "The standalone MATLAB process exited " + ...
            "without producing a result.";
    end
end
if strlength(stateOverride) > 0
    status.State = string(stateOverride);
end
logPath = fullfile(workspace, "standalone.log");
if isfile(logPath)
    try
        status.Diary = string(fileread(logPath));
    catch
    end
end
end

function status = cancelStandalone(workspace)
control = loadControl(workspace);
status = inspectStandalone(workspace, "");
if any(status.State == ["Finished", "Failed", "Cancelled", "Retrieved"])
    return
end
[alive, control] = waitForStandaloneProcess(control, workspace, 30);
if ~alive
    status.State = "Failed";
    status.ErrorIdentifier = "KSSOLV:Remote:StandaloneProcessLost";
    status.ErrorSummary = "The standalone MATLAB process is not running.";
    return
end
[killStatus, killOutput] = system(sprintf("kill -TERM %d", ...
    double(control.ProcessId)));
if killStatus ~= 0
    error("KSSOLV:Remote:StandaloneCancelFailed", ...
        "Unable to cancel standalone MATLAB process %d: %s", ...
        control.ProcessId, strip(string(killOutput)));
end
status.State = "Cancelled";
end

function [alive, control] = waitForStandaloneProcess( ...
        control, workspace, timeout)
started = tic;
alive = standaloneProcessAlive(control, workspace);
while ~alive && toc(started) < timeout
    pause(0.1);
    try
        control = loadControl(workspace);
    catch
    end
    alive = standaloneProcessAlive(control, workspace);
end
end

function value = withinStandaloneStartupGrace(control)
value = false;
try
    submitted = datetime(string(control.SubmittedAt), ...
        "InputFormat", "yyyy-MM-dd'T'HH:mm:ss.SSSXXX", ...
        "TimeZone", "UTC");
    value = seconds(datetime("now", "TimeZone", "UTC") - submitted) < 15;
catch
end
end

function alive = standaloneProcessAlive(control, workspace)
pid = double(control.ProcessId);
alive = false;
if ~isfinite(pid) || pid < 1 || fix(pid) ~= pid
    return
end
[status, output] = system(sprintf("ps -ww -p %d -o command=", pid));
alive = status == 0 && contains(string(output), string(workspace));
end

function status = standaloneBase(control, state)
status = baseStatus();
status.MatlabProfileName = "";
status.MatlabJobId = -1;
status.SubmittedAt = string(control.SubmittedAt);
status.State = string(state);
end

function mode = executionMode(request)
mode = "ParallelServer";
if isfield(request, "ExecutionMode") && ...
        strlength(string(request.ExecutionMode)) > 0
    mode = string(request.ExecutionMode);
end
end

function value = isStandalone(workspace)
value = false;
controlPath = fullfile(workspace, "control.mat");
if isfile(controlPath)
    control = loadControl(workspace);
    value = isfield(control, "ExecutionMode") && ...
        string(control.ExecutionMode) == "StandaloneMatlab";
    return
end
requestPath = fullfile(workspace, "request.json");
if isfile(requestPath)
    value = executionMode(jsondecode(fileread(requestPath))) == ...
        "StandaloneMatlab";
end
end

function control = loadControl(workspace)
path = fullfile(workspace, "control.mat");
if ~isfile(path)
    error("KSSOLV:Remote:BridgeControlMissing", ...
        "The bridge control record is missing.");
end
value = load(path, "control");
control = value.control;
end

function root = toolboxRootFor(workspace)
request = jsondecode(fileread(fullfile(workspace, "request.json")));
if string(request.CodeDeploymentMode) == "AttachCurrentToolbox"
    if isfield(request, "RemoteToolboxRoot") && ...
            strlength(string(request.RemoteToolboxRoot)) > 0
        root = string(request.RemoteToolboxRoot);
    else
        root = fullfile(workspace, "toolbox");
    end
else
    root = string(request.RemoteKssolvRoot);
end
end

function prepareToolbox(workspace)
requestPath = fullfile(workspace, "request.json");
if ~isfile(requestPath)
    return
end
toolboxRoot = toolboxRootFor(workspace);
addpath(toolboxRoot);
coreRoot = fullfile(toolboxRoot, "+kssolv", "+core", "kssolv-3o");
if isfolder(coreRoot)
    addpath(coreRoot);
end
end

function [job, control] = recoverJob(workspace)
control = loadControl(workspace);
cluster = parcluster(char(control.ProfileName));
job = findJob(cluster, "ID", double(control.MatlabJobId));
if isempty(job)
    error("KSSOLV:Remote:BridgeJobMissing", ...
        "MATLAB job %d is not available in profile %s.", ...
        control.MatlabJobId, control.ProfileName);
end
if numel(job) > 1
    job = job(1);
end
end

function status = inspectJob(job, control, stateOverride)
status = baseStatus();
status.MatlabProfileName = string(control.ProfileName);
status.MatlabJobId = double(control.MatlabJobId);
status.SubmittedAt = string(control.SubmittedAt);
status.State = mapState(job);
if strlength(stateOverride) > 0
    status.State = string(stateOverride);
end
status.SchedulerJobIds = schedulerIds(job);
try
    status.Diary = string(evalc("diary(job)"));
catch
end
[identifier, summary] = taskError(job);
if strlength(summary) > 0
    status.State = "Failed";
    status.ErrorIdentifier = identifier;
    status.ErrorSummary = summary;
elseif status.State == "Failed"
    status.ErrorIdentifier = "KSSOLV:Remote:BridgeJobFailed";
    status.ErrorSummary = "The remote MATLAB job failed without a task " + ...
        "exception. Inspect the job diary and scheduler debug log.";
end
end

function status = baseStatus()
status = struct( ...
    "Version", 1, ...
    "BridgeMatlabRelease", string(version("-release")), ...
    "MatlabProfileName", "", ...
    "MatlabJobId", -1, ...
    "SchedulerJobIds", strings(0, 1), ...
    "SubmittedAt", "", ...
    "State", "Unknown", ...
    "Diary", "", ...
    "ErrorIdentifier", "", ...
    "ErrorSummary", "", ...
    "UpdatedAt", "");
end

function state = mapState(job)
switch lower(string(job.State))
    case {"pending", "queued", "unavailable"}
        state = "Queued";
    case "running"
        state = "Running";
    case "finished"
        state = "Finished";
    case "failed"
        state = "Failed";
    otherwise
        state = "Unknown";
end
end

function ids = schedulerIds(job)
ids = strings(0, 1);
try
    raw = getTaskSchedulerIDs(job);
    if isstruct(raw) || istable(raw)
        ids = string(jsonencode(raw));
    elseif ischar(raw)
        ids = string(raw);
    else
        ids = string(raw(:));
    end
    ids(strlength(ids) == 0) = [];
catch
end
end

function [identifier, summary] = taskError(job)
identifier = "";
summary = "";
try
    tasks = job.Tasks;
    for index = 1:numel(tasks)
        exception = tasks(index).Error;
        if ~isempty(exception)
            identifier = string(exception.identifier);
            summary = string(exception.getReport( ...
                "extended", "hyperlinks", "off"));
            return
        end
    end
catch
end
end

function writeStatus(workspace, status)
writeStatusFile(workspace, status);
text = string(jsonencode(status));
fprintf("KSSOLV_BRIDGE_STATUS:%s\n", text);
end

function writeStatusFile(workspace, status)
text = string(jsonencode(status));
path = fullfile(workspace, "status.json");
fileId = fopen(path, "w");
if fileId < 0
    error("KSSOLV:Remote:BridgeStatusWriteFailed", ...
        "Unable to write bridge status %s.", path);
end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId, "%s", text);
clear cleanup
end

function value = nowText()
value = string(datetime("now", "TimeZone", "UTC", ...
    "Format", "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"));
end

function value = shellQuote(text)
singleQuoteEscape = "'" + """" + "'" + """" + "'";
value = "'" + replace(string(text), "'", singleQuoteEscape) + "'";
end

function value = matlabLiteral(text)
value = "'" + replace(string(text), "'", "''") + "'";
end
