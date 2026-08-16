classdef ClusterFactory < handle
    %CLUSTERFACTORY Create and own KSSOLV Slurm cluster profiles.

    properties (SetAccess = immutable)
        JobStorageRoot (1, 1) string
    end

    methods
        function this = ClusterFactory(jobStorageRoot)
            arguments
                jobStorageRoot (1, 1) string = ...
                    fullfile(prefdir, "KSSOLV", "remote", "matlab-jobs")
            end
            this.JobStorageRoot = jobStorageRoot;
        end

        function cluster = build(this, configuration)
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            if any(configuration.ExecutionMode == ["Bridge", "Mirror"])
                error("KSSOLV:Remote:BridgeDoesNotUseLocalCluster", ...
                    "Bridge configurations are submitted by the remote " + ...
                    "MATLAB client and do not create a local cluster object.");
            end
            kssolv.services.remote.cluster.ClusterFactory.requireToolbox();
            if configuration.ProfileSource == "ExistingMatlabProfile"
                profiles = string(parallel.listProfiles());
                if ~any(profiles == configuration.ExistingProfileName)
                    error("KSSOLV:Remote:MatlabProfileNotFound", ...
                        "MATLAB cluster profile %s was not found.", ...
                        configuration.ExistingProfileName);
                end
                cluster = parcluster(configuration.ExistingProfileName);
                if configuration.ExecutionMode == "Standard"
                    kssolv.services.remote.cluster.ClusterFactory. ...
                        assertExistingProfileRelease( ...
                        configuration, cluster);
                end
                cluster = this.attachRoutedAccess(cluster, configuration);
                return
            end

            kssolv.services.remote.cluster.ClusterFactory. ...
                assertReleaseCompatible(configuration);

            if configuration.HasSharedFilesystem
                localStorage = configuration.RemoteJobStorageLocation;
            else
                localStorage = fullfile(this.JobStorageRoot, ...
                    configuration.Id);
            end
            if ~isfolder(localStorage)
                [created, detail] = mkdir(localStorage);
                if ~created
                    error("KSSOLV:Remote:JobStorageCreateFailed", ...
                        "Unable to create local job storage %s: %s", ...
                        localStorage, detail);
                end
            end
            kssolv.services.remote.internal.AtomicJsonFile. ...
                restrictPermissions(localStorage, "rwx------");

            cluster = parallel.cluster.Slurm( ...
                "HasSharedFilesystem", ...
                    configuration.HasSharedFilesystem, ...
                "JobStorageLocation", char(localStorage), ...
                "ClusterMatlabRoot", ...
                    char(configuration.ClusterMatlabRoot), ...
                "OperatingSystem", "unix", ...
                "NumWorkers", configuration.NumWorkers, ...
                "PreferredPoolNumWorkers", ...
                    max(1, configuration.PoolSize), ...
                "RequiresOnlineLicensing", ...
                    configuration.RequiresOnlineLicensing);
            if configuration.RequiresOnlineLicensing && ...
                    strlength(configuration.LicenseNumber) > 0
                cluster.LicenseNumber = char(configuration.LicenseNumber);
            end
            submitArguments = ...
                kssolv.services.remote.cluster.SlurmArguments.build(configuration);
            if strlength(submitArguments) > 0
                cluster.SubmitArguments = char(submitArguments);
            end
            if configuration.ConnectionMode == "SSH"
                cluster.AdditionalProperties.ClusterHost = ...
                    char(configuration.Host);
                cluster.AdditionalProperties.Username = ...
                    char(configuration.Username);
                cluster.AdditionalProperties.AuthenticationMode = ...
                    char(configuration.AuthenticationMode);
                if ~configuration.HasSharedFilesystem
                    cluster.AdditionalProperties. ...
                        RemoteJobStorageLocation = ...
                        char(configuration.RemoteJobStorageLocation);
                end
                if configuration.AuthenticationMode == "IdentityFile"
                    cluster.AdditionalProperties.IdentityFile = ...
                        char(configuration.IdentityFile);
                end
            end
            cluster = this.attachRoutedAccess(cluster, configuration);
        end

        function cluster = ensureProfile(this, configuration)
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            if configuration.ProfileSource == "ExistingMatlabProfile"
                cluster = this.build(configuration);
                return
            end
            cluster = this.build(configuration);
            profiles = string(parallel.listProfiles());
            if any(profiles == configuration.ManagedProfileName)
                cluster.saveAsProfile(char(configuration.ManagedProfileName), ...
                    Overwrite=true);
            else
                cluster.saveAsProfile(char(configuration.ManagedProfileName));
            end
            cluster = parcluster(configuration.ManagedProfileName);
            cluster = this.attachRoutedAccess(cluster, configuration);
        end

        function removed = removeManagedProfile(~, configuration)
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                normalize(configuration);
            removed = false;
            if configuration.ProfileSource ~= "ManagedSlurm"
                return
            end
            profiles = string(parallel.listProfiles());
            if ~any(profiles == configuration.ManagedProfileName)
                return
            end
            if ~isempty(which("parallel.deleteProfile"))
                parallel.deleteProfile(configuration.ManagedProfileName);
                removed = true;
            else
                warning("KSSOLV:Remote:ProfileRemovalUnavailable", ...
                    "This MATLAB release cannot delete profiles " + ...
                    "programmatically. Remove profile %s in the Cluster " + ...
                    "Profile Manager.", configuration.ManagedProfileName);
            end
        end
    end

    methods (Access = private)
        function cluster = attachRoutedAccess(~, cluster, configuration)
            routed = configuration.ExecutionMode == "Standard" && ...
                configuration.ConnectionMode == "SSH" && ...
                (strlength(configuration.PostLoginScript) > 0 || ...
                configuration.PostLoginCommandTemplate ~= "{command}" || ...
                ~isempty(configuration.PostLoginPromptRules));
            if ~routed
                return
            end
            if ~isprop(cluster, "UserData") || ...
                    ~isprop(cluster, "AdditionalProperties")
                error("KSSOLV:Remote:RoutedProfileUnsupported", ...
                    "MATLAB profile %s does not expose the Generic " + ...
                    "scheduler connection required by a post-login " + ...
                    "command template.", string(cluster.Profile));
            end
            cluster.AdditionalProperties.ClusterHost = ...
                char(configuration.Host);
            cluster.AdditionalProperties.Username = ...
                char(configuration.Username);
            cluster.AdditionalProperties.AuthenticationMode = ...
                char(configuration.AuthenticationMode);
            cluster.AdditionalProperties.RemoteJobStorageLocation = ...
                char(configuration.RemoteJobStorageLocation);
            if configuration.AuthenticationMode == "IdentityFile"
                cluster.AdditionalProperties.IdentityFile = ...
                    char(configuration.IdentityFile);
            end
            access = kssolv.services.remote.cluster.RoutedRemoteClusterAccess. ...
                getConnected(configuration);
            cluster.UserData = struct("RemoteConnection", access);
        end
    end

    methods (Static)
        function requireToolbox()
            if isempty(meta.class.fromName("parallel.cluster.Slurm")) || ...
                    isempty(which("parallel.listProfiles"))
                error("KSSOLV:Remote:ParallelToolboxUnavailable", ...
                    "Parallel Computing Toolbox with Slurm support is " + ...
                    "required for remote computing.");
            end
        end

        function assertReleaseCompatible(configuration)
            root = string(configuration.ClusterMatlabRoot);
            token = regexp(char(root), ...
                '(?i)(R[0-9]{4}[ab])(?:[/\\]|$)', 'tokens', 'once');
            if isempty(token)
                return
            end
            remoteRelease = string(token{1});
            localRelease = "R" + string(version("-release"));
            if ~strcmpi(remoteRelease, localRelease)
                error("KSSOLV:Remote:ClusterMatlabReleaseMismatch", ...
                    "The cluster MATLAB root indicates %s, but this " + ...
                    "client runs %s. MATLAB Parallel Server jobs require " + ...
                    "matching releases.", remoteRelease, localRelease);
            end
        end

        function assertExistingProfileRelease(configuration, cluster)
            root = string(configuration.ClusterMatlabRoot);
            if strlength(root) == 0 && ...
                    isprop(cluster, "ClusterMatlabRoot")
                root = string(cluster.ClusterMatlabRoot);
            end
            if strlength(root) == 0 && ...
                    isprop(cluster, "AdditionalProperties") && ...
                    isprop(cluster.AdditionalProperties, ...
                    "ClusterMatlabRoot")
                root = string( ...
                    cluster.AdditionalProperties.ClusterMatlabRoot);
            end
            if strlength(root) == 0 && isa(cluster, ...
                    "parallel.cluster.Local")
                return
            end
            if strlength(root) == 0
                error("KSSOLV:Remote:StandardReleaseUnverified", ...
                    "Standard mode cannot verify the MATLAB release " + ...
                    "for existing profile %s. Configure Cluster MATLAB " + ...
                    "root with a release-qualified path such as " + ...
                    "/opt/MATLAB/R%s.", configuration.ExistingProfileName, ...
                    version("-release"));
            end
            candidate = configuration;
            candidate.ClusterMatlabRoot = root;
            kssolv.services.remote.cluster.ClusterFactory. ...
                assertReleaseCompatible(candidate);
        end
    end
end
