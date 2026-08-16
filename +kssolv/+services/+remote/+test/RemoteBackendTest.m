classdef RemoteBackendTest < matlab.unittest.TestCase
    methods (Test)
        function factoryResolvesFourConcreteBackends(testCase)
            clusterFactory = kssolv.services.remote.cluster.ClusterFactory( ...
                string(tempname));
            bridge = kssolv.services.remote.bridge.RemoteMatlabBridge( ...
                kssolv.services.remote.test.FakeRemoteAccessFactory( ...
                kssolv.services.remote.test.FakeRemoteAccess()));
            factory = kssolv.services.remote.backend.RemoteBackendFactory( ...
                clusterFactory, bridge);
            configurations = [ ...
                standardConfiguration()
                routedConfiguration("Bridge")
                routedConfiguration("Mirror")
                cloudConfiguration()];
            expectedClasses = [ ...
                "kssolv.services.remote.backend.StandardBackend"
                "kssolv.services.remote.backend.BridgeBackend"
                "kssolv.services.remote.backend.MirrorBackend"
                "kssolv.services.remote.backend.CloudBackend"];

            for index = 1:numel(configurations)
                backend = factory.create(configurations(index));
                testCase.verifyClass(backend, expectedClasses(index));
                testCase.verifyEqual(backend.ExecutionMode, ...
                    configurations(index).ExecutionMode);
                for method = ["submitWorkflow", "refresh", "cancel", ...
                        "fetch", "cleanup", "testConnection"]
                    testCase.verifyTrue(ismethod(backend, method));
                end
            end
        end

        function cloudProfileRunsThroughCommonLifecycle(testCase)
            testCase.assumeTrue(any(string(parallel.listProfiles()) == ...
                "Processes"));
            root = string(tempname);
            mkdir(root);
            testCase.addTeardown(@()removeFolder(root));
            configurationStore = ...
                kssolv.services.remote.config.RemoteConfigurationStore(root);
            jobStore = kssolv.services.remote.job.RemoteJobStore(root);
            configuration = cloudConfiguration();
            configurationStore.upsert(configuration);
            manager = kssolv.services.remote.job.RemoteJobManager( ...
                configurationStore, jobStore, ...
                kssolv.services.remote.cluster.ClusterFactory( ...
                fullfile(root, "matlab-jobs")));

            record = manager.submitFunction(configuration.Id, ...
                @plus, 1, {2, 3}, WorkflowName="Cloud contract");
            [job, ~] = manager.findMatlabJob(record);
            cleanup = onCleanup(@()deleteJob(job));
            wait(job);
            [outputs, record] = manager.fetch(record.LocalJobId);

            testCase.verifyEqual(outputs{1}, 5);
            testCase.verifyEqual(record.ExecutionMode, "Cloud");
            testCase.verifyEqual(record.CloudProvider, "PrivateCloud");
            testCase.verifyEqual(record.State, "Retrieved");
            clear cleanup
        end

        function jobUsesSnapshotAfterConfigurationDeletion(testCase)
            testCase.assumeTrue(any(string(parallel.listProfiles()) == ...
                "Processes"));
            root = string(tempname);
            mkdir(root);
            testCase.addTeardown(@()removeFolder(root));
            configurationStore = ...
                kssolv.services.remote.config.RemoteConfigurationStore(root);
            jobStore = kssolv.services.remote.job.RemoteJobStore(root);
            configuration = standardConfiguration();
            configurationStore.upsert(configuration);
            manager = kssolv.services.remote.job.RemoteJobManager( ...
                configurationStore, jobStore, ...
                kssolv.services.remote.cluster.ClusterFactory( ...
                fullfile(root, "matlab-jobs")));
            record = manager.submitFunction(configuration.Id, ...
                @plus, 1, {7, 8}, WorkflowName="Durable snapshot");
            [job, ~] = manager.findMatlabJob(record);
            cleanup = onCleanup(@()deleteJob(job));
            wait(job);
            testCase.verifyTrue(configurationStore.remove(configuration.Id));

            recovered = kssolv.services.remote.job.RemoteJobManager( ...
                configurationStore, ...
                kssolv.services.remote.job.RemoteJobStore(root), ...
                kssolv.services.remote.cluster.ClusterFactory( ...
                fullfile(root, "matlab-jobs")));
            [outputs, record] = recovered.fetch(record.LocalJobId);

            testCase.verifyEqual(outputs{1}, 15);
            testCase.verifyEqual(record.State, "Retrieved");
            clear cleanup
        end

        function cloudJobRecoversAfterConfigurationDeletion(testCase)
            testCase.assumeTrue(any(string(parallel.listProfiles()) == ...
                "Processes"));
            root = string(tempname);
            mkdir(root);
            testCase.addTeardown(@()removeFolder(root));
            configurationStore = ...
                kssolv.services.remote.config.RemoteConfigurationStore(root);
            jobStore = kssolv.services.remote.job.RemoteJobStore(root);
            configuration = cloudConfiguration();
            configurationStore.upsert(configuration);
            manager = kssolv.services.remote.job.RemoteJobManager( ...
                configurationStore, jobStore, ...
                kssolv.services.remote.cluster.ClusterFactory( ...
                fullfile(root, "matlab-jobs")));
            record = manager.submitFunction(configuration.Id, ...
                @plus, 1, {10, 11}, WorkflowName="Cloud recovery");
            [job, ~] = manager.findMatlabJob(record);
            cleanup = onCleanup(@()deleteJob(job));
            wait(job);
            testCase.verifyTrue(configurationStore.remove(configuration.Id));

            recovered = kssolv.services.remote.job.RemoteJobManager( ...
                kssolv.services.remote.config. ...
                RemoteConfigurationStore(root), ...
                kssolv.services.remote.job.RemoteJobStore(root), ...
                kssolv.services.remote.cluster.ClusterFactory( ...
                fullfile(root, "matlab-jobs")));
            [outputs, fetched] = recovered.fetch(record.LocalJobId);

            testCase.verifyEqual(outputs{1}, 21);
            testCase.verifyEqual(fetched.ExecutionMode, "Cloud");
            testCase.verifyEqual(fetched.State, "Retrieved");
            clear cleanup
        end

        function cloudProvidersDiscoverAndValidateProfiles(testCase)
            testCase.assumeTrue(any(string(parallel.listProfiles()) == ...
                "Processes"));
            names = ["MathWorksCloudCenter", "AWS", "PrivateCloud"];
            for name = names
                provider = kssolv.services.remote.cloud. ...
                    CloudProviderFactory.create(name);
                profiles = provider.discoverProfiles();
                testCase.verifyTrue(any(string({profiles.Name}) == ...
                    "Processes"));
                configuration = cloudConfiguration();
                configuration.CloudProvider = name;
                report = provider.validateProfile(configuration);
                testCase.verifyEqual(report.Provider, name);
                testCase.verifyEqual(report.ProfileName, "Processes");
            end
        end

        function cloudProviderDiagnosesMissingProfile(testCase)
            configuration = cloudConfiguration();
            configuration.ExistingProfileName = ...
                "KSSOLV-profile-that-does-not-exist";
            provider = kssolv.services.remote.cloud.PrivateCloudProvider();

            testCase.verifyError(@()provider.validateProfile(configuration), ...
                "KSSOLV:Remote:CloudProfileNotFound");
            testCase.verifyError(@()kssolv.services.remote.cloud. ...
                CloudProviderFactory.create("Unsupported"), ...
                "KSSOLV:Remote:InvalidCloudProvider");
        end

        function routedBackendsHonorDurableLifecycleContract(testCase)
            for mode = ["Bridge", "Mirror"]
                root = string(tempname);
                mkdir(root);
                cleanup = onCleanup(@()removeFolder(root));
                configurationStore = ...
                    kssolv.services.remote.config.RemoteConfigurationStore(root);
                jobStore = kssolv.services.remote.job.RemoteJobStore(root);
                configuration = routedConfiguration(mode);
                configuration.CodeDeploymentMode = "ClusterInstalled";
                configuration.RemoteKssolvRoot = "/shared/KSSOLV";
                configurationStore.upsert(configuration);
                access = kssolv.services.remote.test.FakeRemoteAccess();
                bridge = kssolv.services.remote.bridge.RemoteMatlabBridge( ...
                    kssolv.services.remote.test. ...
                    FakeRemoteAccessFactory(access));
                manager = kssolv.services.remote.job.RemoteJobManager( ...
                    configurationStore, jobStore, ...
                    kssolv.services.remote.cluster.ClusterFactory( ...
                    fullfile(root, "matlab-jobs")), bridge);

                record = manager.submitWorkflow(configuration.Id, ...
                    kssolv.services.remote.test.smallLiHSnapshot());
                testCase.verifyEqual(record.ExecutionMode, mode);
                testCase.verifyEqual(record.State, "Queued");
                testCase.verifyTrue(configurationStore.remove( ...
                    configuration.Id));

                recovered = kssolv.services.remote.job.RemoteJobManager( ...
                    kssolv.services.remote.config. ...
                    RemoteConfigurationStore(root), ...
                    kssolv.services.remote.job.RemoteJobStore(root), ...
                    kssolv.services.remote.cluster.ClusterFactory( ...
                    fullfile(root, "matlab-jobs")), bridge);
                refreshed = recovered.refresh(record.LocalJobId);
                testCase.verifyEqual(refreshed.State, "Finished");
                [outputs, fetched] = recovered.fetch(record.LocalJobId);
                testCase.verifyEqual(fetched.State, "Retrieved");
                testCase.verifyEqual(outputs{1}.Context("energy"), -1.25);
                recovered.cleanupRemoteArtifacts(record.LocalJobId);
                recovered.cleanupRemoteArtifacts(record.LocalJobId);
                testCase.verifyEqual(access.DeletedPaths, ...
                    repmat(record.RemoteWorkspace, 2, 1));

                cancelRecord = ...
                    kssolv.services.remote.job.RemoteJobRecord.create( ...
                    configuration.Id, "Cancel contract");
                cancelRecord.ExecutionMode = mode;
                cancelRecord.ConfigurationSnapshot = configuration;
                cancelRecord.RemoteWorkspace = ...
                    configuration.RemoteJobStorageLocation + "/" + ...
                    lower(mode) + "/cancel-contract";
                cancelRecord.State = "Running";
                jobStore.upsert(cancelRecord);
                cancelled = recovered.cancel(cancelRecord.LocalJobId);
                testCase.verifyEqual(cancelled.State, "Cancelled");
                again = recovered.cancel(cancelRecord.LocalJobId);
                testCase.verifyEqual(again.State, "Cancelled");
                clear cleanup
            end
        end
    end
end

function value = standardConfiguration()
value = kssolv.services.remote.config.RemoteConfiguration.create(struct( ...
    "DisplayName", "Standard", ...
    "ExecutionMode", "Standard", ...
    "ProfileSource", "ExistingMatlabProfile", ...
    "ExistingProfileName", "Processes", ...
    "NumWorkers", 2, "PoolSize", 0));
end

function value = cloudConfiguration()
value = kssolv.services.remote.config.RemoteConfiguration.create(struct( ...
    "DisplayName", "Private cloud profile", ...
    "ExecutionMode", "Cloud", ...
    "CloudProvider", "PrivateCloud", ...
    "ProfileSource", "ExistingMatlabProfile", ...
    "ExistingProfileName", "Processes", ...
    "NumWorkers", 2, "PoolSize", 0));
end

function value = routedConfiguration(mode)
profile = "";
if mode == "Bridge"
    profile = "remote-slurm";
end
value = kssolv.services.remote.config.RemoteConfiguration.create(struct( ...
    "DisplayName", mode, "ExecutionMode", mode, ...
    "Host", "cluster.example.test", ...
    "Username", join(["test", "user"], "-"), ...
    "ClusterMatlabRoot", "/opt/MATLAB/R2024a", ...
    "RemoteJobStorageLocation", "/scratch/test", ...
    "RemoteBridgeProfileName", profile));
end

function deleteJob(job)
try
    delete(job);
catch
end
end

function removeFolder(path)
if isfolder(path)
    rmdir(path, "s");
end
end
