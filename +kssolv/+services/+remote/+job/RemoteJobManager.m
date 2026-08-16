classdef RemoteJobManager < handle
    %REMOTEJOBMANAGER Persist and orchestrate all remote backend lifecycles.

    properties (SetAccess = immutable)
        ConfigurationStore
        JobStore
        ClusterFactory
        Bridge
        BackendFactory
    end

    methods
        function this = RemoteJobManager(configurationStore, jobStore, ...
                clusterFactory, bridge)
            arguments
                configurationStore = ...
                    kssolv.services.remote.config.RemoteConfigurationStore()
                jobStore = kssolv.services.remote.job.RemoteJobStore()
                clusterFactory = kssolv.services.remote.cluster.ClusterFactory()
                bridge = kssolv.services.remote.bridge.RemoteMatlabBridge()
            end
            this.ConfigurationStore = configurationStore;
            this.JobStore = jobStore;
            this.ClusterFactory = clusterFactory;
            this.Bridge = bridge;
            this.BackendFactory = ...
                kssolv.services.remote.backend.RemoteBackendFactory( ...
                clusterFactory, bridge);
        end

        function record = submitFunction(this, configurationId, ...
                functionHandle, numberOfOutputs, inputs, options)
            arguments
                this
                configurationId (1, 1) string
                functionHandle (1, 1) function_handle
                numberOfOutputs (1, 1) double ...
                    {mustBeNonnegative, mustBeInteger}
                inputs cell = {}
                options.WorkflowName (1, 1) string = ""
                options.ProjectIdentity (1, 1) string = ""
                options.PoolSize double = NaN
                options.AttachedFiles = strings(0, 1)
                options.AdditionalPaths = strings(0, 1)
                options.BundlePath (1, 1) string = ""
            end
            configuration = this.enabledConfiguration(configurationId);
            if any(configuration.ExecutionMode == ["Bridge", "Mirror"])
                error("KSSOLV:Remote:BridgeWorkflowOnly", ...
                    "%s mode accepts serialized KSSOLV workflows, not " + ...
                    "arbitrary desktop function handles.", ...
                    configuration.ExecutionMode);
            end
            backend = this.BackendFactory.create(configuration);
            record = createRecord(configuration, options.WorkflowName, ...
                options.ProjectIdentity);
            record.BundlePath = options.BundlePath;
            record.SubmittedAt = nowText();
            record.State = "Preparing";
            this.JobStore.upsert(record);
            try
                record = backend.submitFunction(configuration, record, ...
                    functionHandle, numberOfOutputs, inputs, ...
                    PoolSize=options.PoolSize, ...
                    AttachedFiles=options.AttachedFiles, ...
                    AdditionalPaths=options.AdditionalPaths);
                this.JobStore.upsert(record);
            catch exception
                record = applyFailure(record, exception, "Failed");
                this.JobStore.upsert(record);
                rethrow(exception)
            end
        end

        function record = submitWorkflow(this, configurationId, ...
                snapshot, options)
            arguments
                this
                configurationId (1, 1) string
                snapshot struct
                options.BundleRoot (1, 1) string = ...
                    fullfile(prefdir, "KSSOLV", "remote", "bundles")
            end
            kssolv.services.remote.execution.WorkflowSnapshotBuilder.validate(snapshot);
            configuration = this.enabledConfiguration(configurationId);
            backend = this.BackendFactory.create(configuration);
            record = createRecord(configuration, ...
                string(snapshot.WorkflowName), ...
                string(snapshot.ProjectIdentity));
            record.SubmittedAt = nowText();
            if any(configuration.ExecutionMode == ["Bridge", "Mirror"])
                record.State = "Authenticating";
            else
                record.State = "Preparing";
            end
            this.JobStore.upsert(record);
            try
                record = backend.submitWorkflow(configuration, snapshot, ...
                    record, options.BundleRoot);
                this.JobStore.upsert(record);
            catch exception
                record = applyFailure(record, exception, "Failed");
                this.JobStore.upsert(record);
                rethrow(exception)
            end
        end

        function [envelope, record] = fetchWorkflow(this, localJobId)
            existing = this.JobStore.get(localJobId);
            if existing.ResultImported
                error("KSSOLV:Remote:ResultAlreadyImported", ...
                    "Remote job %s was already imported.", localJobId);
            end
            [outputs, record] = this.fetch(localJobId);
            if numel(outputs) ~= 1 || ~isstruct(outputs{1}) || ...
                    ~isfield(outputs{1}, "Context")
                error("KSSOLV:Remote:InvalidWorkflowResult", ...
                    "Remote job %s returned an invalid workflow result.", ...
                    localJobId);
            end
            envelope = outputs{1};
        end

        function cleanupLocalArtifacts(this, localJobId)
            record = this.JobStore.get(localJobId);
            removeArtifact(record.BundlePath);
            record.BundlePath = "";
            record.LastCheckedAt = nowText();
            this.JobStore.upsert(record);
        end

        function cleanupRemoteArtifacts(this, localJobId)
            record = this.JobStore.get(localJobId);
            configuration = this.configurationForRecord(record);
            backend = this.BackendFactory.create(configuration);
            backend.cleanup(configuration, record);
        end

        function removed = deleteRecord(this, localJobId)
            %DELETERECORD Remove only the local journal entry.
            % The remote job and its remote workspace are intentionally
            % left untouched; cancelling and remote cleanup are separate
            % explicit operations.
            removed = this.deleteRecords(localJobId) == 1;
        end

        function removedCount = deleteRecords(this, localJobIds)
            %DELETERECORDS Atomically remove local journal entries.
            localJobIds = unique(strip(string(localJobIds(:))), "stable");
            localJobIds(strlength(localJobIds) == 0) = [];
            records = this.JobStore.list();
            storedIds = string({records.LocalJobId}).';
            missing = localJobIds(~ismember(localJobIds, storedIds));
            if ~isempty(missing)
                error("KSSOLV:Remote:JobNotFound", ...
                    "Remote job %s was not found.", missing(1));
            end
            keep = ~ismember(storedIds, localJobIds);
            removedCount = sum(~keep);
            if removedCount > 0
                this.JobStore.save(records(keep));
            end
        end

        function record = refresh(this, localJobId)
            record = this.JobStore.get(localJobId);
            try
                configuration = this.configurationForRecord(record);
                backend = this.BackendFactory.create(configuration);
                record = backend.refresh(configuration, record);
                record.ErrorIdentifier = "";
                if record.State ~= "Failed"
                    record.ErrorSummary = "";
                end
            catch exception
                record = applyFailure(record, exception, "Unknown");
            end
            record.LastCheckedAt = nowText();
            this.JobStore.upsert(record);
        end

        function records = refreshAll(this)
            records = this.JobStore.list();
            terminal = ["Retrieved", "Failed", "Cancelled"];
            for index = 1:numel(records)
                if ~any(records(index).State == terminal)
                    records(index) = this.refresh( ...
                        records(index).LocalJobId);
                end
            end
        end

        function record = cancel(this, localJobId)
            record = this.JobStore.get(localJobId);
            if any(record.State == ["Cancelled", "Retrieved", "Failed"])
                return
            end
            record.State = "Cancelling";
            record.LastCheckedAt = nowText();
            this.JobStore.upsert(record);
            try
                configuration = this.configurationForRecord(record);
                backend = this.BackendFactory.create(configuration);
                record = backend.cancel(configuration, record);
            catch exception
                record = applyFailure(record, exception, "Unknown");
            end
            record.LastCheckedAt = nowText();
            this.JobStore.upsert(record);
        end

        function [outputs, record] = fetch(this, localJobId)
            record = this.refresh(localJobId);
            if ~any(record.State == ["Finished", "Retrieved"])
                error("KSSOLV:Remote:JobNotFinished", ...
                    "Remote job %s is in state %s.", ...
                    localJobId, record.State);
            end
            priorState = record.State;
            if priorState ~= "Retrieved"
                record.State = "Fetching";
                this.JobStore.upsert(record);
            end
            try
                configuration = this.configurationForRecord(record);
                backend = this.BackendFactory.create(configuration);
                [outputs, record] = backend.fetch(configuration, record);
                record.LastCheckedAt = nowText();
                this.JobStore.upsert(record);
            catch exception
                record = applyFailure(record, exception, "Finished");
                this.JobStore.upsert(record);
                rethrow(exception)
            end
        end

        function record = markImported(this, localJobId)
            record = this.JobStore.get(localJobId);
            if record.State ~= "Retrieved"
                error("KSSOLV:Remote:ResultNotRetrieved", ...
                    "Only retrieved remote results can be marked imported.");
            end
            record.ResultImported = true;
            record.LastCheckedAt = nowText();
            this.JobStore.upsert(record);
        end

        function [job, cluster] = findMatlabJob(this, record)
            configuration = this.configurationForRecord(record);
            backend = this.BackendFactory.create(configuration);
            if ~isa(backend, "kssolv.services.remote.backend.StandardBackend")
                error("KSSOLV:Remote:BridgeJobIsRemote", ...
                    "%s jobs are not owned by the desktop MATLAB client.", ...
                    record.ExecutionMode);
            end
            [job, cluster] = backend.findMatlabJob(configuration, record);
        end
    end

    methods (Access = private)
        function configuration = enabledConfiguration(this, id)
            configuration = this.ConfigurationStore.get(id);
            if ~configuration.Enabled
                error("KSSOLV:Remote:ConfigurationDisabled", ...
                    "Remote configuration %s is disabled.", ...
                    configuration.DisplayName);
            end
        end

        function configuration = configurationForRecord(this, record)
            if isfield(record, "ConfigurationSnapshot") && ...
                    isstruct(record.ConfigurationSnapshot) && ...
                    ~isempty(fieldnames(record.ConfigurationSnapshot))
                configuration = ...
                    kssolv.services.remote.config.RemoteConfiguration.sanitized( ...
                    record.ConfigurationSnapshot);
                % Job records intentionally omit encrypted credentials.
                % Rehydrate only those fields from the saved configuration
                % while keeping all execution settings frozen at submit time.
                try
                    saved = this.ConfigurationStore.get( ...
                        record.ConfigurationId);
                    configuration = mergeStoredCredentials( ...
                        configuration, saved);
                catch exception
                    if exception.identifier ~= ...
                            "KSSOLV:Remote:ConfigurationNotFound"
                        rethrow(exception)
                    end
                end
                return
            end
            configuration = this.ConfigurationStore.get( ...
                record.ConfigurationId);
            if configuration.ExecutionMode ~= record.ExecutionMode
                error("KSSOLV:Remote:JobBackendMismatch", ...
                    "Job %s belongs to %s mode, but its configuration " + ...
                    "now selects %s.", record.LocalJobId, ...
                    record.ExecutionMode, configuration.ExecutionMode);
            end
        end
    end
end

function value = mergeStoredCredentials(value, saved)
fields = ["RememberTotpSecret", "EncryptedPassword", ...
    "EncryptedTotpSecret"];
for field = fields
    if isfield(saved, field)
        value.(field) = saved.(field);
    end
end
value = kssolv.services.remote.config.RemoteConfiguration.sanitized(value);
end

function record = createRecord(configuration, workflowName, projectIdentity)
record = kssolv.services.remote.job.RemoteJobRecord.create( ...
    configuration.Id, workflowName, projectIdentity);
record.ExecutionMode = configuration.ExecutionMode;
record.CloudProvider = "";
if configuration.ExecutionMode == "Cloud"
    record.CloudProvider = configuration.CloudProvider;
end
record.ConfigurationSnapshot = configuration;
end

function record = applyFailure(record, exception, fallbackState)
record.LastCheckedAt = nowText();
record.ErrorIdentifier = string(exception.identifier);
record.ErrorSummary = string(exception.message);
if isAuthenticationException(exception)
    record.State = "ConnectionRequired";
else
    record.State = fallbackState;
end
end

function value = isAuthenticationException(exception)
messageText = lower(string(exception.identifier) + " " + ...
    string(exception.message));
tokens = ["authentication", "multifactor", "two-factor", "2fa", ...
    "password", "credential", "ssh", "login", "permission denied", ...
    "usercancelledoperation", "user cancelled operation"];
value = any(contains(messageText, tokens));
end

function removeArtifact(path)
path = string(path);
if strlength(path) == 0
    return
end
if isfolder(path)
    rmdir(path, "s");
elseif isfile(path)
    delete(path);
end
end

function value = nowText()
value = string(datetime("now", "TimeZone", "UTC", ...
    "Format", "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"));
end
