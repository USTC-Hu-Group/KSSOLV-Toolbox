classdef RemoteJobManagerTest < matlab.unittest.TestCase
    properties
        StorageRoot string
        ConfigurationStore
        JobStore
        Manager
        Configuration
        MatlabJobs cell = {}
    end

    methods (TestMethodSetup)
        function createManager(testCase)
            testCase.assumeTrue(any(string(parallel.listProfiles()) == ...
                "Processes"));
            testCase.StorageRoot = string(tempname);
            mkdir(testCase.StorageRoot);
            testCase.addTeardown(@()testCase.cleanupJobs());
            testCase.addTeardown(@()removeFolder(testCase.StorageRoot));
            testCase.ConfigurationStore = ...
                kssolv.services.remote.config.RemoteConfigurationStore( ...
                testCase.StorageRoot);
            testCase.JobStore = kssolv.services.remote.job.RemoteJobStore( ...
                testCase.StorageRoot);
            factory = kssolv.services.remote.cluster.ClusterFactory( ...
                fullfile(testCase.StorageRoot, "matlab-jobs"));
            testCase.Manager = kssolv.services.remote.job.RemoteJobManager( ...
                testCase.ConfigurationStore, testCase.JobStore, factory);
            testCase.Configuration = ...
                kssolv.services.remote.config.RemoteConfiguration.create(struct( ...
                "DisplayName", "Local batch test", ...
                "ProfileSource", "ExistingMatlabProfile", ...
                "ExistingProfileName", "Processes", ...
                "NumWorkers", 2, ...
                "PoolSize", 0));
            testCase.ConfigurationStore.upsert(testCase.Configuration);
        end
    end

    methods (Test)
        function jobStoreRoundTripsAndRejectsDuplicates(testCase)
            first = kssolv.services.remote.job.RemoteJobRecord.create( ...
                testCase.Configuration.Id, "Workflow");
            second = kssolv.services.remote.job.RemoteJobRecord.create( ...
                testCase.Configuration.Id, "Workflow 2");
            testCase.JobStore.save([first; second]);
            actual = testCase.JobStore.list();
            testCase.verifyNumElements(actual, 2);
            testCase.verifyEqual(actual(1).State, "Created");
            testCase.verifyError(@()testCase.JobStore.save([first; first]), ...
                "KSSOLV:Remote:DuplicateJobId");
        end

        function schedulerIdCharacterVectorRemainsScalar(testCase)
            record = kssolv.services.remote.job.RemoteJobRecord.create( ...
                testCase.Configuration.Id, "Scheduler ID");
            record.SchedulerJobIds = '21367';

            normalized = kssolv.services.remote.job.RemoteJobRecord. ...
                normalize(record);

            testCase.verifyEqual(normalized.SchedulerJobIds, "21367");
        end

        function submitsRefreshesAndFetchesLocalBatch(testCase)
            record = testCase.Manager.submitFunction( ...
                testCase.Configuration.Id, @plus, 1, {1, 2}, ...
                WorkflowName="Addition", PoolSize=0);
            testCase.verifyNotEmpty(record.SubmittedAt);
            [job, ~] = testCase.Manager.findMatlabJob(record);
            testCase.MatlabJobs{end + 1} = job;
            wait(job);

            record = testCase.Manager.refresh(record.LocalJobId);
            testCase.verifyEqual(record.State, "Finished");
            [outputs, record] = testCase.Manager.fetch( ...
                record.LocalJobId);
            testCase.verifyEqual(outputs{1}, 3);
            testCase.verifyEqual(record.State, "Retrieved");
            record = testCase.Manager.markImported(record.LocalJobId);
            testCase.verifyTrue(record.ResultImported);
            [retriedOutputs, retriedRecord] = testCase.Manager.fetch( ...
                record.LocalJobId);
            testCase.verifyEqual(retriedOutputs{1}, 3);
            testCase.verifyEqual(retriedRecord.State, "Retrieved");
        end

        function managerRecoversFromNewInstance(testCase)
            record = testCase.Manager.submitFunction( ...
                testCase.Configuration.Id, @plus, 1, {4, 5}, ...
                PoolSize=0);
            [job, ~] = testCase.Manager.findMatlabJob(record);
            testCase.MatlabJobs{end + 1} = job;
            wait(job);

            recoveredManager = ...
                kssolv.services.remote.job.RemoteJobManager( ...
                kssolv.services.remote.config.RemoteConfigurationStore( ...
                    testCase.StorageRoot), ...
                kssolv.services.remote.job.RemoteJobStore( ...
                    testCase.StorageRoot), ...
                kssolv.services.remote.cluster.ClusterFactory( ...
                    fullfile(testCase.StorageRoot, "matlab-jobs")));
            recovered = recoveredManager.refresh(record.LocalJobId);
            testCase.verifyEqual(recovered.State, "Finished");
            outputs = recoveredManager.fetch(record.LocalJobId);
            testCase.verifyEqual(outputs{1}, 9);
        end

        function remoteLiHBundleSurvivesManagerRestart(testCase)
            snapshot = kssolv.services.remote.test.smallLiHSnapshot();
            kssolv.services.remote.execution.RemoteWorkflowRunner.execute(snapshot);
            atomPathBefore = string(which("Atom"));
            bundleRoot = fullfile(testCase.StorageRoot, "bundles");
            record = testCase.Manager.submitWorkflow( ...
                testCase.Configuration.Id, snapshot, ...
                BundleRoot=bundleRoot);
            [job, ~] = testCase.Manager.findMatlabJob(record);
            testCase.MatlabJobs{end + 1} = job;
            wait(job);

            recoveredManager = ...
                kssolv.services.remote.job.RemoteJobManager( ...
                kssolv.services.remote.config.RemoteConfigurationStore( ...
                    testCase.StorageRoot), ...
                kssolv.services.remote.job.RemoteJobStore( ...
                    testCase.StorageRoot), ...
                kssolv.services.remote.cluster.ClusterFactory( ...
                    fullfile(testCase.StorageRoot, "matlab-jobs")));
            [envelope, recovered] = recoveredManager.fetchWorkflow( ...
                record.LocalJobId);
            info = envelope.Context("info");
            energy = info.Etotvec(end);
            baseline = -5.9666002670969;

            testCase.verifyEqual(recovered.State, "Retrieved");
            testCase.verifyTrue(info.converge);
            testCase.verifyTrue(isfinite(energy));
            testCase.verifyLessThan(info.SCFerrvec(end), 1e-6);
            testCase.verifyLessThanOrEqual( ...
                abs(energy - baseline) / abs(baseline), 1e-6);
            testCase.verifyEqual(string({envelope.TaskStates.State}).', ...
                ["Finished"; "Finished"]);
            imported = recoveredManager.markImported(record.LocalJobId);
            testCase.verifyTrue(imported.ResultImported);
            recoveredManager.cleanupLocalArtifacts(record.LocalJobId);
            testCase.verifyFalse(isfile(record.BundlePath));
            testCase.verifyEqual(string(which("Atom")), atomPathBefore);
            testCase.verifyTrue(isfile(atomPathBefore));
        end

        function cancelIsIdempotent(testCase)
            record = testCase.Manager.submitFunction( ...
                testCase.Configuration.Id, @pause, 0, {20}, ...
                PoolSize=0);
            [job, ~] = testCase.Manager.findMatlabJob(record);
            testCase.MatlabJobs{end + 1} = job;
            record = testCase.Manager.cancel(record.LocalJobId);
            testCase.verifyEqual(record.State, "Cancelled");
            again = testCase.Manager.cancel(record.LocalJobId);
            testCase.verifyEqual(again.State, "Cancelled");
        end

        function noSecretsAreWrittenToJobStore(testCase)
            record = kssolv.services.remote.job.RemoteJobRecord.create( ...
                testCase.Configuration.Id, "Safe");
            record.ExecutionMode = testCase.Configuration.ExecutionMode;
            record.ConfigurationSnapshot = testCase.Configuration;
            testCase.JobStore.upsert(record);
            text = lower(string(fileread(testCase.JobStore.path())));
            testCase.verifyFalse(contains(text, '"password"'));
            testCase.verifyFalse(contains(text, "totp"));
            testCase.verifyFalse(contains(text, "privatekey"));
            testCase.verifyFalse(contains(text, '"submissionmode"'));
            testCase.verifyFalse(contains(text, ...
                '"remotebridgeexecutionmode"'));
            testCase.verifyFalse(contains(text, ...
                '"remotecommandtemplate"'));
        end

        function migratesV1JobUsingConfigurationMode(testCase)
            root = string(tempname);
            mkdir(root);
            cleanup = onCleanup(@()removeFolder(root));
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                defaults();
            configuration.DisplayName = "Legacy mirror";
            configuration.SubmissionMode = "RemoteMatlabBridge";
            configuration.RemoteBridgeExecutionMode = ...
                "StandaloneMatlab";
            configuration.Host = "legacy.example.test";
            configuration.Username = "legacy-user";
            configuration.ClusterMatlabRoot = "/opt/MATLAB/R2024a";
            configuration.RemoteJobStorageLocation = "/scratch/legacy";
            configuration.RemoteCommandTemplate = ...
                "ssh node7 -- {command}";
            configuration = rmfield(configuration, ...
                {'ExecutionMode', 'CloudProvider', 'CloudResourceName', ...
                'CloudRegion', 'PostLoginScript', ...
                'PostLoginCommandTemplate', ...
                'PostLoginPromptRules'});
            configuration.Version = 1;
            kssolv.services.remote.internal.AtomicJsonFile.write( ...
                fullfile(root, "configurations-v1.json"), ...
                struct("Version", 1, "Configurations", configuration));

            job = kssolv.services.remote.job.RemoteJobRecord.create( ...
                string(configuration.Id), "Legacy workflow");
            job.Version = 1;
            job.SubmissionMode = "RemoteMatlabBridge";
            job = rmfield(job, {'ExecutionMode', 'CloudProvider', ...
                'BackendProtocolVersion', 'ConfigurationSnapshot'});
            kssolv.services.remote.internal.AtomicJsonFile.write( ...
                fullfile(root, "jobs-v1.json"), ...
                struct("Version", 1, "Jobs", job));

            store = kssolv.services.remote.job.RemoteJobStore(root);
            migrated = store.list();
            persisted = string(fileread(store.path()));

            testCase.verifyEqual(migrated.ExecutionMode, "Mirror");
            testCase.verifyEqual( ...
                migrated.ConfigurationSnapshot.ExecutionMode, "Mirror");
            testCase.verifyTrue(isfile(fullfile(root, "jobs-v1.json")));
            testCase.verifyTrue(isfile( ...
                fullfile(root, "configurations-v1.json")));
            testCase.verifyFalse(contains(persisted, '"SubmissionMode"'));
            testCase.verifyFalse(contains(persisted, ...
                '"RemoteBridgeExecutionMode"'));
        end

        function authenticationCancellationRequiresConnection(testCase)
            factory = kssolv.services.remote.test. ...
                ThrowingClusterFactory( ...
                "parallelexamples:GenericSLURM:UserCancelledOperation", ...
                "User cancelled operation.");
            manager = kssolv.services.remote.job.RemoteJobManager( ...
                testCase.ConfigurationStore, testCase.JobStore, factory);

            testCase.verifyError(@()manager.submitFunction( ...
                testCase.Configuration.Id, @plus, 1, {1, 2}), ...
                "parallelexamples:GenericSLURM:UserCancelledOperation");
            records = testCase.JobStore.list();
            testCase.verifyEqual(records(end).State, ...
                "ConnectionRequired");
            testCase.verifyNotEmpty(records(end).SubmittedAt);
        end

        function sshFailureRequiresConnectionOnRefresh(testCase)
            record = kssolv.services.remote.job.RemoteJobRecord.create( ...
                testCase.Configuration.Id, "Disconnected");
            record.MatlabJobId = 99;
            record.State = "Running";
            testCase.JobStore.upsert(record);
            factory = kssolv.services.remote.test. ...
                ThrowingClusterFactory("KSSOLV:Test:SSHUnavailable", ...
                "SSH authentication is required.");
            manager = kssolv.services.remote.job.RemoteJobManager( ...
                testCase.ConfigurationStore, testCase.JobStore, factory);

            refreshed = manager.refresh(record.LocalJobId);
            testCase.verifyEqual(refreshed.State, "ConnectionRequired");
        end

        function workflowResultCannotBeImportedTwice(testCase)
            record = testCase.Manager.submitFunction( ...
                testCase.Configuration.Id, @testWorkflowEnvelope, ...
                1, {}, PoolSize=0);
            [job, ~] = testCase.Manager.findMatlabJob(record);
            testCase.MatlabJobs{end + 1} = job;
            wait(job);

            [envelope, fetched] = testCase.Manager.fetchWorkflow( ...
                record.LocalJobId);
            testCase.verifyEqual(envelope.Context("energy"), -1.25);
            testCase.Manager.markImported(fetched.LocalJobId);
            testCase.verifyError(@()testCase.Manager.fetchWorkflow( ...
                fetched.LocalJobId), ...
                "KSSOLV:Remote:ResultAlreadyImported");
        end

        function bundleCleanupIsIdempotent(testCase)
            bundle = fullfile(testCase.StorageRoot, "bundle-to-clean");
            mkdir(bundle);
            record = kssolv.services.remote.job.RemoteJobRecord.create( ...
                testCase.Configuration.Id, "Cleanup");
            record.BundlePath = bundle;
            testCase.JobStore.upsert(record);

            testCase.Manager.cleanupLocalArtifacts(record.LocalJobId);
            testCase.Manager.cleanupLocalArtifacts(record.LocalJobId);

            testCase.verifyFalse(isfolder(bundle));
            actual = testCase.JobStore.get(record.LocalJobId);
            testCase.verifyEqual(actual.BundlePath, "");
        end

        function deleteRecordsRemoveOnlyJournalEntries(testCase)
            bundle = fullfile(testCase.StorageRoot, "retained-bundle.zip");
            writelines("bundle", bundle);
            record = kssolv.services.remote.job.RemoteJobRecord.create( ...
                testCase.Configuration.Id, "Old record");
            record.BundlePath = bundle;
            record.RemoteWorkspace = "/remote/workspace/old-record";
            record.State = "Retrieved";
            testCase.JobStore.upsert(record);
            retained = kssolv.services.remote.job.RemoteJobRecord.create( ...
                testCase.Configuration.Id, "Retained record");
            retained.State = "Failed";
            testCase.JobStore.upsert(retained);
            second = kssolv.services.remote.job.RemoteJobRecord.create( ...
                testCase.Configuration.Id, "Second old record");
            second.State = "Cancelled";
            testCase.JobStore.upsert(second);

            removed = testCase.Manager.deleteRecords( ...
                [record.LocalJobId; second.LocalJobId; record.LocalJobId]);

            testCase.verifyEqual(removed, 2);
            remaining = testCase.JobStore.list();
            testCase.verifyNumElements(remaining, 1);
            testCase.verifyEqual(remaining.LocalJobId, retained.LocalJobId);
            testCase.verifyTrue(isfile(bundle));
            testCase.verifyError(@()testCase.Manager.deleteRecord( ...
                record.LocalJobId), "KSSOLV:Remote:JobNotFound");
        end
    end

    methods
        function cleanupJobs(testCase)
            for index = 1:numel(testCase.MatlabJobs)
                job = testCase.MatlabJobs{index};
                try
                    if isvalid(job)
                        cancel(job);
                        delete(job);
                    end
                catch
                end
            end
        end
    end
end

function value = testWorkflowEnvelope()
context = containers.Map("KeyType", "char", "ValueType", "any");
context("energy") = -1.25;
value = struct("Context", context, "WorkflowName", "Test", ...
    "RemoteNodeIds", strings(0, 1), ...
    "LocalNodeIds", strings(0, 1));
end

function removeFolder(path)
if isfolder(path)
    rmdir(path, "s");
end
end
