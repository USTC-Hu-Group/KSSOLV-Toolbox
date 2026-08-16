classdef RemoteMatlabBridge < handle
    %REMOTEMATLABBRIDGE Drive a matching-release MATLAB client over SSH.

    properties (SetAccess = immutable)
        AccessFactory
    end

    methods
        function this = RemoteMatlabBridge(accessFactory)
            arguments
                accessFactory = kssolv.services.remote.transport.RemoteAccessFactory()
            end
            this.AccessFactory = accessFactory;
        end

        function record = submitWorkflow(this, configuration, snapshot, ...
                record, bundlePath)
            kssolv.services.remote.execution.WorkflowSnapshotBuilder.validate(snapshot);
            record = this.submitOperation(configuration, snapshot, record, ...
                bundlePath, "Workflow");
        end

        function [record, bundlePath] = submitProbe(this, configuration, ...
                bundleRoot)
            arguments
                this
                configuration struct
                bundleRoot (1, 1) string = fullfile(tempdir, ...
                    "KSSOLV", "remote", "bridge-probes")
            end
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            bundlePath = "";
            bundleManifest = struct();
            if configuration.CodeDeploymentMode == "AttachCurrentToolbox"
                [bundlePath, bundleManifest] = ...
                    kssolv.services.remote.execution.CodeBundleBuilder( ...
                    bundleRoot).build("Probe");
            end
            record = kssolv.services.remote.job.RemoteJobRecord.create( ...
                configuration.Id, "Connection test", "");
            record.ExecutionMode = configuration.ExecutionMode;
            record.BundlePath = bundlePath;
            if ~isempty(fieldnames(bundleManifest))
                record.BundleContentHash = ...
                    string(bundleManifest.ContentIndexSha256);
            end
            try
                record = this.submitOperation(configuration, struct(), ...
                    record, bundlePath, "Probe");
            catch exception
                if strlength(bundlePath) > 0 && isfile(bundlePath)
                    delete(bundlePath);
                end
                try
                    this.cleanupRemote(configuration, record);
                catch
                end
                rethrow(exception)
            end
        end

        function record = refresh(this, configuration, record)
            access = this.AccessFactory.create(configuration);
            status = this.invoke(access, configuration, record, "status", "");
            record = applyStatus(record, status);
        end

        function record = cancel(this, configuration, record)
            access = this.AccessFactory.create(configuration);
            status = this.invoke(access, configuration, record, "cancel", "");
            record = applyStatus(record, status);
        end

        function [outputs, record] = fetch(this, configuration, record)
            access = this.AccessFactory.create(configuration);
            status = this.invoke(access, configuration, record, "fetch", "");
            record = applyStatus(record, status);
            if record.State ~= "Retrieved"
                error("KSSOLV:Remote:BridgeFetchFailed", ...
                    "The bridge did not produce a retrievable result: %s", ...
                    record.ErrorSummary);
            end
            localRoot = string(tempname);
            mkdir(localRoot);
            cleanup = onCleanup(@()removeLocal(localRoot));
            remoteResult = remoteJoin(record.RemoteWorkspace, "result.mat");
            access.copyFileFromRemote(char(remoteResult), char(localRoot));
            localResult = fullfile(localRoot, "result.mat");
            if ~isfile(localResult)
                error("KSSOLV:Remote:BridgeResultMissing", ...
                    "The bridge result file was not downloaded.");
            end
            ensureKssolvRuntime();
            value = load(localResult, "outputs");
            if ~isfield(value, "outputs") || ~iscell(value.outputs)
                error("KSSOLV:Remote:BridgeResultInvalid", ...
                    "The bridge result file has an invalid payload.");
            end
            outputs = value.outputs;
            outputs = restoreWorkflowEnvelopes(outputs);
            clear cleanup
        end

        function cleanupRemote(this, configuration, record)
            if ~isfield(record, "RemoteWorkspace") || ...
                    strlength(string(record.RemoteWorkspace)) == 0
                return
            end
            access = this.AccessFactory.create(configuration);
            access.remoteDelete(char(record.RemoteWorkspace));
        end
    end

    methods (Access = private)
        function record = submitOperation(this, configuration, snapshot, ...
                record, bundlePath, operation)
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            if ~any(configuration.ExecutionMode == ["Bridge", "Mirror"])
                error("KSSOLV:Remote:BridgeModeRequired", ...
                    "Remote MATLAB transport requires Bridge or Mirror mode.");
            end
            record.ExecutionMode = configuration.ExecutionMode;
            record.MatlabProfileName = ...
                configuration.RemoteBridgeProfileName;
            if configuration.CodeDeploymentMode == "AttachCurrentToolbox"
                if strlength(string(record.BundleContentHash)) == 0
                    error("KSSOLV:Remote:BridgeBundleIdentityMissing", ...
                        "The bridge worker bundle has no content identity.");
                end
                record.RemoteToolboxRoot = remoteJoin( ...
                    configuration.RemoteJobStorageLocation, ...
                    ".kssolv-cache", "toolbox", ...
                    string(record.BundleContentHash));
            else
                record.RemoteToolboxRoot = configuration.RemoteKssolvRoot;
            end
            record.RemoteWorkspace = remoteJoin( ...
                configuration.RemoteJobStorageLocation, ...
                workspaceCategory(configuration.ExecutionMode), ...
                record.LocalJobId);
            access = this.AccessFactory.create(configuration);
            cleanupState = containers.Map( ...
                "KeyType", "char", "ValueType", "logical");
            cleanupState("Succeeded") = false;
            failedWorkspaceCleanup = onCleanup(@() ...
                cleanupFailedWorkspaceUnlessSucceeded( ...
                access, record.RemoteWorkspace, cleanupState));
            if ismethod(access, "verifyWorkspaceVisibility")
                access.verifyWorkspaceVisibility(record.RemoteWorkspace);
            else
                [status, output] = runLoginCommand(access, char( ...
                    "mkdir -p -- " + shellQuote( ...
                    record.RemoteWorkspace)));
                assertRemoteCommand(status, output, ...
                    "create bridge workspace");
            end

            stagingRoot = string(tempname);
            mkdir(stagingRoot);
            cleanup = onCleanup(@()removeLocal(stagingRoot));
            request = struct( ...
                "Version", 2, ...
                "Operation", operation, ...
                "ExecutionMode", protocolExecutionMode( ...
                    configuration.ExecutionMode), ...
                "LocalJobId", record.LocalJobId, ...
                "ProfileName", configuration.RemoteBridgeProfileName, ...
                "PoolSize", configuration.PoolSize, ...
                "CodeDeploymentMode", configuration.CodeDeploymentMode, ...
                "RemoteKssolvRoot", configuration.RemoteKssolvRoot, ...
                "RemoteToolboxRoot", record.RemoteToolboxRoot, ...
                "BundleContentHash", record.BundleContentHash);
            requestPath = fullfile(stagingRoot, "request.json");
            kssolv.services.remote.internal.AtomicJsonFile.write( ...
                requestPath, request);
            access.copyFileToRemote(char(requestPath), ...
                char(record.RemoteWorkspace));
            if operation == "Workflow"
                snapshotPath = fullfile(stagingRoot, "snapshot.mat");
                save(snapshotPath, "snapshot", "-v7");
                access.copyFileToRemote(char(snapshotPath), ...
                    char(record.RemoteWorkspace));
            end
            if configuration.CodeDeploymentMode == "AttachCurrentToolbox"
                if strlength(bundlePath) == 0 || ~isfile(bundlePath)
                    error("KSSOLV:Remote:BridgeBundleMissing", ...
                        "The bridge worker bundle is missing.");
                end
                if ~remoteCacheAvailable(access, record.RemoteToolboxRoot)
                    access.copyFileToRemote(char(bundlePath), ...
                        char(record.RemoteWorkspace));
                end
            end
            clear cleanup

            bridgeStatus = this.invoke(access, configuration, record, ...
                "submit", bundlePath);
            validateBridgeRelease(configuration, bridgeStatus);
            record = applyStatus(record, bridgeStatus);
            if record.State == "Failed"
                error("KSSOLV:Remote:BridgeSubmissionFailed", ...
                    "Remote MATLAB could not submit the job: %s", ...
                    record.ErrorSummary);
            end
            cleanupState("Succeeded") = true; %#ok<NASGU>
            clear failedWorkspaceCleanup
        end

        function bridgeStatus = invoke(~, access, configuration, record, ...
                action, bundlePath)
            workspace = record.RemoteWorkspace;
            if configuration.CodeDeploymentMode == "AttachCurrentToolbox"
                toolboxRoot = string(record.RemoteToolboxRoot);
                if strlength(toolboxRoot) == 0
                    % Backward compatibility for jobs submitted before
                    % content-addressed remote toolbox caching.
                    toolboxRoot = remoteJoin(workspace, "toolbox");
                end
            else
                toolboxRoot = configuration.RemoteKssolvRoot;
            end
            expression = "";
            if action == "submit" && ...
                    configuration.CodeDeploymentMode == "AttachCurrentToolbox"
                [~, name, extension] = fileparts(bundlePath);
                archive = remoteJoin(workspace, string(name) + extension);
                expression = cacheInstallExpression(toolboxRoot, archive, ...
                    string(record.LocalJobId), ...
                    string(record.BundleContentHash));
            end
            expression = expression + "addpath(" + ...
                matlabLiteral(toolboxRoot) + "); " + ...
                "kssolv.services.remote.bridge.RemoteMatlabBridgeEntrypoint.run(" + ...
                matlabLiteral(action) + "," + matlabLiteral(workspace) + ");";
            executable = remoteJoin(configuration.ClusterMatlabRoot, ...
                "bin", "matlab");
            command = shellQuote(executable) + " -batch " + ...
                shellQuote(expression);
            [status, output] = runBridgeCommand(access, char(command));
            assertRemoteCommand(status, output, "run remote MATLAB bridge");
            bridgeStatus = parseStatus(output);
        end
    end
end

function cleanupFailedWorkspaceUnlessSucceeded(access, workspace, state)
if isKey(state, "Succeeded") && state("Succeeded")
    return
end
try
    access.remoteDelete(char(workspace));
catch
end
end

function ensureKssolvRuntime()
toolboxFile = string(which("KSSOLV_Toolbox"));
if strlength(toolboxFile) == 0
    return
end
coreRoot = fullfile(fileparts(toolboxFile), "+kssolv", "+core", ...
    "kssolv-3o");
if isfolder(coreRoot)
    addpath(coreRoot);
    if exist("KSSOLV", "class") == 8
        KSSOLV.startup();
    else
        addpath(genpath(fullfile(coreRoot, "src")));
    end
end
end

function outputs = restoreWorkflowEnvelopes(outputs)
for index = 1:numel(outputs)
    outputs{index} = kssolv.services.remote.execution.RemoteWorkflowRunner. ...
        restoreEnvelopeAfterTransport(outputs{index});
end
end

function value = applyStatus(record, status)
value = record;
fields = ["State", "ErrorIdentifier", "ErrorSummary"];
for field = fields
    if isfield(status, field)
        value.(field) = status.(field);
    end
end
if isfield(status, "BridgeMatlabRelease") && ...
        strlength(string(status.BridgeMatlabRelease)) > 0
    value.BridgeMatlabRelease = status.BridgeMatlabRelease;
end
if isfield(status, "MatlabProfileName") && ...
        strlength(string(status.MatlabProfileName)) > 0
    value.MatlabProfileName = status.MatlabProfileName;
end

if isfield(status, "MatlabJobId") && ...
        isfinite(double(status.MatlabJobId)) && ...
        double(status.MatlabJobId) >= 0
    value.MatlabJobId = status.MatlabJobId;
end
if isfield(status, "SchedulerJobIds") && ...
        ~isempty(status.SchedulerJobIds)
    value.SchedulerJobIds = status.SchedulerJobIds;
end
if isfield(status, "Diary") && strlength(string(status.Diary)) > 0
    value.Diary = status.Diary;
end
if isfield(status, "SubmittedAt") && strlength(record.SubmittedAt) == 0
    value.SubmittedAt = string(status.SubmittedAt);
end
value.LastCheckedAt = nowText();
value = kssolv.services.remote.job.RemoteJobRecord.normalize(value);
end

function validateBridgeRelease(configuration, status)
if ~isfield(status, "BridgeMatlabRelease") || ...
        strlength(string(status.BridgeMatlabRelease)) == 0
    error("KSSOLV:Remote:BridgeReleaseMissing", ...
        "Remote MATLAB did not report its release.");
end
token = regexp(char(configuration.ClusterMatlabRoot), ...
    '(?i)(R[0-9]{4}[ab])(?:[/\\]|$)', 'tokens', 'once');
if isempty(token)
    return
end
expected = erase(string(token{1}), "R");
actual = string(status.BridgeMatlabRelease);
if ~strcmpi(expected, actual)
    error("KSSOLV:Remote:BridgeMatlabReleaseMismatch", ...
        "The configured MATLAB root indicates %s, but the bridge " + ...
        "process reports R%s.", token{1}, actual);
end
end

function value = parseStatus(output)
prefix = "KSSOLV_BRIDGE_STATUS:";
lines = splitlines(string(output));
matches = lines(startsWith(strip(lines), prefix));
if isempty(matches)
    error("KSSOLV:Remote:BridgeStatusMissing", ...
        "Remote MATLAB did not return bridge status. Output: %s", ...
        strip(string(output)));
end
text = extractAfter(strip(matches(end)), strlength(prefix));
try
    value = jsondecode(char(text));
catch exception
    error("KSSOLV:Remote:BridgeStatusInvalid", ...
        "Remote MATLAB returned invalid bridge status: %s", ...
        exception.message);
end
end

function assertRemoteCommand(status, output, operation)
if double(status) ~= 0
    error("KSSOLV:Remote:BridgeCommandFailed", ...
        "Unable to %s (exit %d): %s", operation, status, ...
        strip(string(output)));
end
end

function [status, output] = runLoginCommand(access, command)
if ismethod(access, "runLoginCommand")
    [status, output] = access.runLoginCommand(command);
else
    [status, output] = access.runCommand(command);
end
end

function [status, output] = runBridgeCommand(access, command)
marker = "KSSOLV_BRIDGE_STATUS:";
if ismethod(access, "runCommandUntilMarker")
    [status, output] = access.runCommandUntilMarker(command, char(marker));
else
    [status, output] = access.runCommand(command);
end
end

function value = remoteCacheAvailable(access, toolboxRoot)
marker = remoteJoin(string(toolboxRoot), ".kssolv-cache-complete");
[status, ~] = access.runCommand(char( ...
    "test -f -- " + shellQuote(marker)));
value = double(status) == 0;
end

function expression = cacheInstallExpression( ...
        toolboxRoot, archive, localJobId, contentHash)
marker = remoteJoin(toolboxRoot, ".kssolv-cache-complete");
temporaryRoot = toolboxRoot + ".partial-" + localJobId;
temporaryMarker = remoteJoin(temporaryRoot, ...
    ".kssolv-cache-complete");
expression = ...
    "if ~isfile(" + matlabLiteral(marker) + "), " + ...
    "if isfolder(" + matlabLiteral(temporaryRoot) + ...
    "), rmdir(" + matlabLiteral(temporaryRoot) + ",'s'); end; " + ...
    "mkdir(" + matlabLiteral(temporaryRoot) + "); " + ...
    "unzip(" + matlabLiteral(archive) + "," + ...
    matlabLiteral(temporaryRoot) + "); " + ...
    "fid=fopen(" + matlabLiteral(temporaryMarker) + ",'w'); " + ...
    "if fid<0, error('KSSOLV:Remote:CacheMarkerFailed'," + ...
    "'Unable to create remote toolbox cache marker.'); end; " + ...
    "fprintf(fid,'%s'," + matlabLiteral(contentHash) + "); fclose(fid); " + ...
    "if isfolder(" + matlabLiteral(toolboxRoot) + ") && " + ...
    "~isfile(" + matlabLiteral(marker) + "), rmdir(" + ...
    matlabLiteral(toolboxRoot) + ",'s'); end; " + ...
    "if ~isfolder(" + matlabLiteral(toolboxRoot) + "), " + ...
    "[ok,msg]=movefile(" + matlabLiteral(temporaryRoot) + "," + ...
    matlabLiteral(toolboxRoot) + "); " + ...
    "if ~ok && ~isfile(" + matlabLiteral(marker) + ...
    "), error('KSSOLV:Remote:CacheInstallFailed','%s',msg); end; end; " + ...
    "if isfolder(" + matlabLiteral(temporaryRoot) + ...
    "), rmdir(" + matlabLiteral(temporaryRoot) + ",'s'); end; end; ";
end

function value = remoteJoin(parts)
arguments (Repeating)
    parts (1, 1) string
end
items = string(parts);
value = items(1);
for index = 2:numel(items)
    value = strip(value, "right", "/") + "/" + ...
        strip(items(index), "left", "/");
end
end

function value = protocolExecutionMode(mode)
if mode == "Mirror"
    value = "StandaloneMatlab";
else
    value = "ParallelServer";
end
end

function value = workspaceCategory(mode)
if mode == "Mirror"
    value = "kssolv-mirror";
else
    value = "kssolv-bridge";
end
end

function value = shellQuote(text)
text = string(text);
singleQuoteEscape = "'" + """" + "'" + """" + "'";
value = "'" + replace(text, "'", singleQuoteEscape) + "'";
end

function value = matlabLiteral(text)
value = "'" + replace(string(text), "'", "''") + "'";
end

function value = nowText()
value = string(datetime("now", "TimeZone", "UTC", ...
    "Format", "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"));
end

function removeLocal(path)
if isfolder(path)
    rmdir(path, "s");
elseif isfile(path)
    delete(path);
end
end
