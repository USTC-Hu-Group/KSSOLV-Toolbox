classdef RemoteConnectionTestSessionTest < matlab.unittest.TestCase
    %REMOTECONNECTIONTESTSESSIONTEST Smoke session lifecycle tests.

    properties
        StorageRoot (1, 1) string
        Sessions cell = {}
    end

    methods (TestMethodSetup)
        function setup(testCase)
            testCase.assumeTrue(any(string(parallel.listProfiles()) == ...
                "Processes"));
            testCase.StorageRoot = string(tempname);
            mkdir(testCase.StorageRoot);
            testCase.addTeardown(@()testCase.cleanupSessions());
            testCase.addTeardown(@()removeFolder(testCase.StorageRoot));
        end
    end

    methods (Test)
        function smokeJobCompletesWithoutBlockingPoll(testCase)
            session = testCase.createSession();
            session.start();
            testCase.verifyTrue(any(session.State == ...
                ["Queued", "Running", "Finished"]));

            deadline = tic;
            while ~any(session.State == session.TerminalStates) && ...
                    toc(deadline) < 30
                pause(0.05);
                session.poll();
            end

            testCase.verifyEqual(session.State, "Succeeded");
            testCase.verifyTrue(session.Report.Succeeded);
            testCase.verifyEqual(session.Report.Probe.Result, 3);
            testCase.verifyEqual(session.Report.ProfileName, "Processes");
        end

        function connectionOnlySmokeDoesNotReturnResources(testCase)
            session = testCase.createSession(false);
            session.start();
            deadline = tic;
            while ~any(session.State == session.TerminalStates) && ...
                    toc(deadline) < 30
                pause(0.05);
                session.poll();
            end

            testCase.verifyEqual(session.State, "Succeeded");
            testCase.verifyTrue(session.Report.Succeeded);
            testCase.verifyTrue(isfield(session.Report, "Connection"));
            testCase.verifyFalse(isfield(session.Report, "Probe"));
            testCase.verifyEqual(session.Report.Connection.Result, 3);
        end

        function cancellationIsIdempotent(testCase)
            session = testCase.createSession();
            session.start();
            session.cancel();
            session.cancel();

            testCase.verifyEqual(session.State, "Cancelled");
        end

        function startIsSingleUse(testCase)
            session = testCase.createSession();
            session.start();

            testCase.verifyError(@()session.start(), ...
                "KSSOLV:Remote:ConnectionTestAlreadyStarted");
        end
    end

    methods (Access = private)
        function session = createSession(testCase, probeResources)
            if nargin < 2
                probeResources = true;
            end
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                create(struct( ...
                "DisplayName", "Local smoke", ...
                "ProfileSource", "ExistingMatlabProfile", ...
                "ExistingProfileName", "Processes", ...
                "NumWorkers", 2, "PoolSize", 0));
            factory = kssolv.services.remote.cluster.ClusterFactory( ...
                fullfile(testCase.StorageRoot, "jobs"));
            session = kssolv.services.remote.diagnostics. ...
                RemoteConnectionTestSession(configuration, factory, ...
                ProbeResources=probeResources);
            testCase.Sessions{end + 1} = session;
        end

        function cleanupSessions(testCase)
            for index = 1:numel(testCase.Sessions)
                try
                    delete(testCase.Sessions{index});
                catch
                end
            end
        end
    end
end

function removeFolder(path)
if isfolder(path)
    rmdir(path, "s");
end
end
