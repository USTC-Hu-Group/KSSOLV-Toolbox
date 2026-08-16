classdef StandaloneBridgeTest < matlab.unittest.TestCase
    methods (Test)
        function runsProbeWithoutParallelServer(testCase)
            workspace = string(tempname);
            mkdir(workspace);
            testCase.addTeardown(@()cleanupWorkspace(workspace));
            request = struct( ...
                "Version", 1, ...
                "Operation", "Probe", ...
                "ExecutionMode", "StandaloneMatlab", ...
                "LocalJobId", "standalone-test", ...
                "ProfileName", "", ...
                "PoolSize", 0, ...
                "CodeDeploymentMode", "ClusterInstalled", ...
                "RemoteKssolvRoot", string(KSSOLV_Toolbox.RootDirectory));
            kssolv.services.remote.internal.AtomicJsonFile.write( ...
                fullfile(workspace, "request.json"), request);

            submitted = kssolv.services.remote.bridge. ...
                RemoteMatlabBridgeEntrypoint.run("submit", workspace);
            testCase.verifyEqual(string(submitted.State), "Queued");
            testCase.verifyEqual(double(submitted.MatlabJobId), -1);

            status = waitForTerminal(workspace, 90);
            testCase.verifyEqual(string(status.State), "Finished", ...
                string(status.ErrorSummary));
            fetched = kssolv.services.remote.bridge. ...
                RemoteMatlabBridgeEntrypoint.run("fetch", workspace);
            testCase.verifyEqual(string(fetched.State), "Retrieved");
            value = load(fullfile(workspace, "result.mat"), "outputs");
            testCase.verifyEqual(value.outputs{1}.Result, 3);
            testCase.verifyEqual(value.outputs{1}.MatlabRelease, ...
                string(version("-release")));
        end

        function cancelsDetachedMatlabByValidatedProcessId(testCase)
            workspace = createWorkspace(testCase);

            submitted = kssolv.services.remote.bridge. ...
                RemoteMatlabBridgeEntrypoint.run("submit", workspace);
            testCase.verifyEqual(string(submitted.State), "Queued");
            cancelled = kssolv.services.remote.bridge. ...
                RemoteMatlabBridgeEntrypoint.run("cancel", workspace);

            testCase.verifyEqual(string(cancelled.State), "Cancelled");
            pause(3);
            testCase.verifyFalse(isfile(fullfile(workspace, "result.mat")));
        end

        function cancelsRunningDetachedMatlab(testCase)
            workspace = createWorkspace(testCase);

            submitted = kssolv.services.remote.bridge. ...
                RemoteMatlabBridgeEntrypoint.run("submit", workspace);
            testCase.verifyEqual(string(submitted.State), "Queued");
            waitForState(workspace, "Running", 30);
            cancelled = kssolv.services.remote.bridge. ...
                RemoteMatlabBridgeEntrypoint.run("cancel", workspace);

            testCase.verifyEqual(string(cancelled.State), "Cancelled");
            pause(3);
            testCase.verifyFalse(isfile(fullfile(workspace, "result.mat")));
        end

        function refusesToCancelUnrelatedMatlabProcess(testCase)
            workspace = string(tempname);
            mkdir(workspace);
            testCase.addTeardown(@()cleanupWorkspace(workspace));
            processId = currentProcessId();
            submittedAt = datetime("now", "TimeZone", "UTC") - days(1);
            submittedAt.Format = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX";
            control = struct( ...
                "Version", 1, ...
                "ExecutionMode", "StandaloneMatlab", ...
                "ProfileName", "", ...
                "MatlabJobId", -1, ...
                "ProcessId", processId, ...
                "LauncherProcessId", processId, ...
                "SubmittedAt", string(submittedAt));
            save(fullfile(workspace, "control.mat"), "control", "-v7");

            status = kssolv.services.remote.bridge. ...
                RemoteMatlabBridgeEntrypoint.run("cancel", workspace);
            [aliveStatus, ~] = system(sprintf("kill -0 %d", processId));

            testCase.verifyEqual(string(status.State), "Failed");
            testCase.verifyEqual(string(status.ErrorIdentifier), ...
                "KSSOLV:Remote:StandaloneProcessLost");
            testCase.verifyEqual(aliveStatus, 0, ...
                "PID validation terminated the unrelated MATLAB process.");
        end
    end
end

function workspace = createWorkspace(testCase)
workspace = string(tempname);
mkdir(workspace);
testCase.addTeardown(@()cleanupWorkspace(workspace));
request = struct( ...
    "Version", 1, ...
    "Operation", "Probe", ...
    "ExecutionMode", "StandaloneMatlab", ...
    "LocalJobId", "standalone-cancel-test", ...
    "ProfileName", "", ...
    "PoolSize", 0, ...
    "CodeDeploymentMode", "ClusterInstalled", ...
    "RemoteKssolvRoot", string(KSSOLV_Toolbox.RootDirectory));
kssolv.services.remote.internal.AtomicJsonFile.write( ...
    fullfile(workspace, "request.json"), request);
end

function status = waitForTerminal(workspace, timeout)
started = tic;
while toc(started) < timeout
    path = fullfile(workspace, "status.json");
    if isfile(path)
        try
            status = jsondecode(fileread(path));
            if any(string(status.State) == ["Finished", "Failed"])
                return
            end
        catch
        end
    end
    pause(0.25);
end
error("KSSOLV:Remote:TestTimeout", ...
    "Standalone Bridge did not finish within %.0f seconds.", timeout);
end

function status = waitForState(workspace, expectedState, timeout)
started = tic;
while toc(started) < timeout
    path = fullfile(workspace, "status.json");
    if isfile(path)
        try
            status = jsondecode(fileread(path));
            if string(status.State) == expectedState
                return
            end
            if string(status.State) == "Failed"
                error("KSSOLV:Remote:StandaloneFailed", ...
                    "%s", string(status.ErrorSummary));
            end
        catch exception
            if exception.identifier == "KSSOLV:Remote:StandaloneFailed"
                rethrow(exception)
            end
        end
    end
    pause(0.02);
end
error("KSSOLV:Remote:TestTimeout", ...
    "Standalone Bridge did not reach %s within %.0f seconds.", ...
    expectedState, timeout);
end

function cleanupWorkspace(workspace)
controlPath = fullfile(workspace, "control.mat");
if isfile(controlPath)
    try
        value = load(controlPath, "control");
        pid = double(value.control.ProcessId);
        [status, command] = system(sprintf( ...
            "ps -ww -p %d -o command=", pid));
        if status == 0 && contains(string(command), workspace)
            killStatus = system(sprintf("kill -TERM %d", pid));
            if killStatus ~= 0
                warning("KSSOLV:Remote:TestCleanupFailed", ...
                    "Unable to terminate standalone test process %d.", ...
                    pid);
            end
        end
    catch
    end
end
if isfolder(workspace)
    rmdir(workspace, "s");
end
end

function value = currentProcessId()
if exist("matlabProcessID", "file") == 2 || ...
        exist("matlabProcessID", "builtin") == 5
    value = double(matlabProcessID);
else
    value = double(feature("getpid")); %#ok<FEATGPID>
end
end
