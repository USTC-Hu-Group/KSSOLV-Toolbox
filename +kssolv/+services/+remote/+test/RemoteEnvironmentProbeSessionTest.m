classdef RemoteEnvironmentProbeSessionTest < matlab.unittest.TestCase
    %REMOTEENVIRONMENTPROBESESSIONTEST Probe isolation and cancellation.

    methods (Test)
        function startsOnProcessProfileAndCanBeCancelled(testCase)
            testCase.assumeTrue(any(string(parallel.listProfiles()) == ...
                "Processes"));
            keyRoot = string(tempname);
            mkdir(keyRoot);
            testCase.addTeardown(@()removeFolder(keyRoot));
            configuration = kssolv.services.remote.config. ...
                RemoteConfiguration.defaults();
            configuration.ExecutionMode = "Mirror";
            configuration.Host = "probe.example.test";
            configuration.Username = "user";
            configuration.ClusterMatlabRoot = "/";
            configuration.RemoteJobStorageLocation = "/tmp";
            session = kssolv.services.remote.diagnostics. ...
                RemoteEnvironmentProbeSession(configuration, keyRoot);
            testCase.addTeardown(@()delete(session));

            session.start();

            testCase.verifyEqual(string(session.Cluster.Profile), ...
                "Processes");
            testCase.verifyFalse(isa(session.Job, ...
                "parallel.FevalFuture"));
            started = tic;
            session.cancel();
            cancelSeconds = toc(started);
            testCase.verifyEqual(session.State, "Cancelled");
            testCase.verifyEqual(session.Phase, "Cancelled");
            testCase.verifyLessThan(cancelSeconds, 8);
        end
    end
end

function removeFolder(path)
if isfolder(path)
    rmdir(path, "s");
end
end
