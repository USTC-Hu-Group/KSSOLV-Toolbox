classdef MirrorTransportTest < matlab.unittest.TestCase
    %MIRRORTRANSPORTTEST Exercise detached Mirror transport and recovery.

    methods (Test)
        function detachedLiHSurvivesManagerRecreation(testCase)
            root = string(tempname);
            mkdir(root);
            testCase.addTeardown(@()cleanupRoot(root));
            configurationStore = ...
                kssolv.services.remote.config.RemoteConfigurationStore(root);
            jobStore = kssolv.services.remote.job.RemoteJobStore(root);
            configuration = localMirrorConfiguration(root);
            configurationStore.upsert(configuration);
            bridge = kssolv.services.remote.bridge.RemoteMatlabBridge( ...
                kssolv.services.remote.test.FakeRemoteAccessFactory( ...
                kssolv.services.remote.test.LocalRemoteAccess()));
            manager = kssolv.services.remote.job.RemoteJobManager( ...
                configurationStore, jobStore, ...
                kssolv.services.remote.cluster.ClusterFactory( ...
                fullfile(root, "matlab-jobs")), bridge);

            record = manager.submitWorkflow(configuration.Id, ...
                kssolv.services.remote.test.smallLiHSnapshot());
            workspace = record.RemoteWorkspace;
            testCase.verifyEqual(record.ExecutionMode, "Mirror");
            testCase.verifyEqual(record.State, "Queued");
            testCase.verifyTrue(configurationStore.remove(configuration.Id));
            waitForTerminalStatus(workspace, 120);

            recovered = kssolv.services.remote.job.RemoteJobManager( ...
                kssolv.services.remote.config.RemoteConfigurationStore(root), ...
                kssolv.services.remote.job.RemoteJobStore(root), ...
                kssolv.services.remote.cluster.ClusterFactory( ...
                fullfile(root, "matlab-jobs")), bridge);
            [envelope, fetched] = recovered.fetchWorkflow( ...
                record.LocalJobId);
            info = envelope.Context("info");
            baseline = -5.9666002670969;

            testCase.verifyEqual(fetched.State, "Retrieved");
            testCase.verifyTrue(info.converge);
            testCase.verifyLessThan(info.SCFerrvec(end), 1e-6);
            testCase.verifyLessThanOrEqual(abs(info.Etotvec(end) - ...
                baseline) / abs(baseline), 1e-6);
            testCase.verifyClass(envelope.Context("molecule"), "Crystal");
            molecule = envelope.Context("molecule");
            testCase.verifyNotEmpty(molecule.get("supercell"));
            testCase.verifyTrue(isnan(fetched.MatlabJobId));
            testCase.verifyEmpty(fetched.SchedulerJobIds);
            recovered.cleanupRemoteArtifacts(record.LocalJobId);
            testCase.verifyFalse(isfolder(workspace));
        end
    end
end

function value = localMirrorConfiguration(root)
value = kssolv.services.remote.config.RemoteConfiguration.create(struct( ...
    "DisplayName", "Local Mirror transport", ...
    "ExecutionMode", "Mirror", ...
    "Host", "localhost", ...
    "Username", join(["local", "test"], "-"), ...
    "AuthenticationMode", "Agent", ...
    "ClusterMatlabRoot", string(matlabroot), ...
    "RemoteJobStorageLocation", root, ...
    "CodeDeploymentMode", "ClusterInstalled", ...
    "RemoteKssolvRoot", string(KSSOLV_Toolbox.RootDirectory), ...
    "NumWorkers", 1, "PoolSize", 0));
end

function status = waitForTerminalStatus(workspace, timeout)
started = tic;
while toc(started) < timeout
    path = fullfile(workspace, "status.json");
    if isfile(path)
        try
            status = jsondecode(fileread(path));
            if any(string(status.State) == ["Finished", "Failed"])
                if string(status.State) == "Failed"
                    error("KSSOLV:Remote:MirrorTransportFailed", ...
                        "%s", string(status.ErrorSummary));
                end
                return
            end
        catch exception
            if exception.identifier == ...
                    "KSSOLV:Remote:MirrorTransportFailed"
                rethrow(exception)
            end
        end
    end
    pause(0.25);
end
error("KSSOLV:Remote:TestTimeout", ...
    "Detached Mirror did not finish within %.0f seconds.", timeout);
end

function cleanupRoot(root)
workspaces = dir(fullfile(root, "kssolv-mirror", "*", "control.mat"));
for index = 1:numel(workspaces)
    workspace = string(workspaces(index).folder);
    try
        value = load(fullfile(workspace, "control.mat"), "control");
        pid = double(value.control.ProcessId);
        [status, command] = system(sprintf( ...
            "ps -ww -p %d -o command=", pid));
        if status == 0 && contains(string(command), workspace)
            system(sprintf("kill -TERM %d", pid));
        end
    catch
    end
end
if isfolder(root)
    rmdir(root, "s");
end
end
