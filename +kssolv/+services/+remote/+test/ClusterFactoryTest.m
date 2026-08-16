classdef ClusterFactoryTest < matlab.unittest.TestCase
    properties
        StorageRoot string
        Factory
    end

    methods (TestMethodSetup)
        function createFactory(testCase)
            testCase.assumeNotEmpty(meta.class.fromName( ...
                "parallel.cluster.Slurm"));
            testCase.StorageRoot = string(tempname);
            mkdir(testCase.StorageRoot);
            testCase.addTeardown(@()removeFolder(testCase.StorageRoot));
            testCase.Factory = kssolv.services.remote.cluster.ClusterFactory( ...
                testCase.StorageRoot);
        end
    end

    methods (Test)
        function buildsMultifactorSlurmCluster(testCase)
            configuration = managedConfiguration();
            configuration.AuthenticationMode = "Multifactor";
            configuration.Partition = "compute";
            configuration.Account = "project-a";
            cluster = testCase.Factory.build(configuration);

            testCase.verifyClass(cluster, "parallel.cluster.Slurm");
            testCase.verifyEqual(string( ...
                cluster.AdditionalProperties.AuthenticationMode), ...
                "Multifactor");
            testCase.verifyEqual(string( ...
                cluster.AdditionalProperties.ClusterHost), ...
                configuration.Host);
            testCase.verifyEqual(string( ...
                cluster.AdditionalProperties.Username), ...
                configuration.Username);
            testCase.verifyEqual(string( ...
                cluster.AdditionalProperties.RemoteJobStorageLocation), ...
                configuration.RemoteJobStorageLocation);
            testCase.verifyTrue(contains(string(cluster.SubmitArguments), ...
                "--partition=compute"));
            testCase.verifyTrue(contains(string(cluster.SubmitArguments), ...
                "--account=project-a"));
        end

        function identityFileIsMappedOnlyForIdentityMode(testCase)
            configuration = managedConfiguration();
            configuration.AuthenticationMode = "IdentityFile";
            configuration.IdentityFile = "/tmp/id_test";
            cluster = testCase.Factory.build(configuration);
            testCase.verifyEqual(string( ...
                cluster.AdditionalProperties.IdentityFile), ...
                configuration.IdentityFile);

            configuration.AuthenticationMode = "Agent";
            configuration.IdentityFile = "";
            cluster = testCase.Factory.build(configuration);
            testCase.verifyFalse(isprop(cluster.AdditionalProperties, ...
                "IdentityFile"));
        end

        function existingProfileDoesNotChangeDefault(testCase)
            before = string(parallel.defaultProfile());
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                create(struct( ...
                "DisplayName", "Existing", ...
                "ProfileSource", "ExistingMatlabProfile", ...
                "ExistingProfileName", "Processes"));
            cluster = testCase.Factory.build(configuration);
            testCase.verifyEqual(string(cluster.Profile), "Processes");
            testCase.verifyEqual(string(parallel.defaultProfile()), before);
        end

        function managedProfileCanBeCreatedAndRemoved(testCase)
            before = string(parallel.defaultProfile());
            configuration = managedConfiguration();
            configuration.ManagedProfileName = "KSSOLV-Test-" + ...
                extractBefore(configuration.Id, 9);
            cleanup = onCleanup(@()removeProfile(configuration));
            cluster = testCase.Factory.ensureProfile(configuration);
            testCase.verifyEqual(string(cluster.Profile), ...
                configuration.ManagedProfileName);
            testCase.verifyTrue(any(string(parallel.listProfiles()) == ...
                configuration.ManagedProfileName));
            testCase.verifyEqual(string(parallel.defaultProfile()), before);
            testCase.verifyTrue(testCase.Factory.removeManagedProfile( ...
                configuration));
            testCase.verifyFalse(any(string(parallel.listProfiles()) == ...
                configuration.ManagedProfileName));
            clear cleanup
        end

        function rejectsUnsafeAdditionalArguments(testCase)
            configuration = managedConfiguration();
            configuration.AdditionalSubmitArgs = ...
                "--comment=ok; touch /tmp/not-allowed";
            testCase.verifyError(@()testCase.Factory.build(configuration), ...
                "KSSOLV:Remote:UnsafeSubmitArguments");
        end

        function remoteProbeIsNonSensitive(testCase)
            result = kssolv.services.remote.diagnostics.remoteProbe();
            testCase.verifyEqual(result.Result, 3);
            encoded = lower(string(jsonencode(result)));
            testCase.verifyFalse(contains(encoded, "password"));
            testCase.verifyFalse(contains(encoded, "totp"));
            testCase.verifyFalse(contains(encoded, "privatekey"));
        end

        function localProfileValidationCanSkipScheduler(testCase)
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                create(struct("DisplayName", "Local validation", ...
                "ProfileSource", "ExistingMatlabProfile", ...
                "ExistingProfileName", "Processes", ...
                "NumWorkers", 2, "PoolSize", 0));
            report = kssolv.services.remote.cluster.ClusterValidator.validate( ...
                configuration, RunSchedulerValidation=false);

            testCase.verifyTrue(report.Succeeded);
            testCase.verifyEqual(report.ProfileName, "Processes");
            testCase.verifyEmpty(fieldnames(report.Probe));
        end

        function rejectsKnownClusterReleaseMismatch(testCase)
            configuration = managedConfiguration();
            configuration.ClusterMatlabRoot = "/opt/MATLAB/R2024a";

            testCase.verifyError(@()testCase.Factory.build(configuration), ...
                "KSSOLV:Remote:ClusterMatlabReleaseMismatch");
        end

        function rejectsExistingProfileReleaseMismatch(testCase)
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                create(struct( ...
                "DisplayName", "Wrong existing release", ...
                "ProfileSource", "ExistingMatlabProfile", ...
                "ExistingProfileName", "Processes", ...
                "ClusterMatlabRoot", "/opt/MATLAB/R2024a"));

            testCase.verifyError(@()testCase.Factory.build(configuration), ...
                "KSSOLV:Remote:ClusterMatlabReleaseMismatch");
        end

        function sharedFilesystemUsesSharedJobStorage(testCase)
            sharedRoot = fullfile(testCase.StorageRoot, "shared-jobs");
            configuration = managedConfiguration();
            configuration.HasSharedFilesystem = true;
            configuration.RemoteJobStorageLocation = sharedRoot;
            cluster = testCase.Factory.build(configuration);

            testCase.verifyEqual(string(cluster.JobStorageLocation), ...
                sharedRoot);
            testCase.verifyFalse(isprop(cluster.AdditionalProperties, ...
                "RemoteJobStorageLocation"));
        end
    end
end

function value = managedConfiguration()
placeholderUsername = join(["remote", "user"], "-");
value = kssolv.services.remote.config.RemoteConfiguration.create(struct( ...
    "DisplayName", "Managed", ...
    "Host", "cluster.example.test", ...
    "Username", placeholderUsername, ...
    "ClusterMatlabRoot", "/opt/MATLAB/R2026b", ...
    "RemoteJobStorageLocation", "/scratch/tester/kssolv", ...
    "NumWorkers", 4, ...
    "PoolSize", 2));
end

function removeProfile(configuration)
if ~isempty(which("parallel.deleteProfile")) && ...
        any(string(parallel.listProfiles()) == ...
        configuration.ManagedProfileName)
    parallel.deleteProfile(configuration.ManagedProfileName);
end
end

function removeFolder(path)
if isfolder(path)
    rmdir(path, "s");
end
end
