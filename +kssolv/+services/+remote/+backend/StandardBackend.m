classdef StandardBackend < kssolv.services.remote.backend.RemoteBackend
    %STANDARDBACKEND Client-owned MATLAB Parallel Server jobs.

    properties (SetAccess = immutable)
        ClusterFactory
    end

    methods
        function this = StandardBackend(clusterFactory, executionMode)
            arguments
                clusterFactory = kssolv.services.remote.cluster.ClusterFactory()
                executionMode (1, 1) string = "Standard"
            end
            this@kssolv.services.remote.backend.RemoteBackend(executionMode);
            this.ClusterFactory = clusterFactory;
        end

        function session = testConnection(this, configuration, purpose)
            probeResources = string(purpose) ~= "ConnectionOnly";
            session = kssolv.services.remote.diagnostics.RemoteConnectionTestSession( ...
                configuration, this.ClusterFactory, ...
                ProbeResources=probeResources);
        end

        function record = submitWorkflow(this, configuration, snapshot, ...
                record, bundleRoot)
            kssolv.services.remote.execution.WorkflowSnapshotBuilder.validate(snapshot);
            bundlePath = "";
            attachedFiles = strings(0, 1);
            additionalPaths = strings(0, 1);
            runner = @kssolv.services.remote.execution.RemoteWorkflowRunner.execute;
            inputs = {snapshot};
            if configuration.CodeDeploymentMode == "ClusterInstalled"
                additionalPaths = configuration.RemoteKssolvRoot;
            else
                bundlePath = kssolv.services.remote.execution.CodeBundleBuilder( ...
                    bundleRoot).build();
                attachedFiles = bundlePath;
                runner = ...
                    @kssolv.services.remote.execution.RemoteBundleBootstrap.execute;
                [~, name, extension] = fileparts(bundlePath);
                inputs = {snapshot, name + extension};
            end
            record.BundlePath = bundlePath;
            try
                record = this.submitFunction(configuration, record, ...
                    runner, 1, inputs, ...
                    PoolSize=configuration.PoolSize, ...
                    AttachedFiles=attachedFiles, ...
                    AdditionalPaths=additionalPaths);
            catch exception
                removeArtifact(bundlePath);
                rethrow(exception)
            end
        end

        function record = submitFunction(this, configuration, record, ...
                functionHandle, numberOfOutputs, inputs, options)
            arguments
                this
                configuration struct
                record struct
                functionHandle (1, 1) function_handle
                numberOfOutputs (1, 1) double
                inputs cell = {}
                options.PoolSize double = NaN
                options.AttachedFiles = strings(0, 1)
                options.AdditionalPaths = strings(0, 1)
            end
            cluster = this.ClusterFactory.ensureProfile(configuration);
            record.MatlabProfileName = string(cluster.Profile);
            record.State = "Submitting";
            poolSize = options.PoolSize;
            if isnan(poolSize)
                poolSize = configuration.PoolSize;
            end
            argumentsList = batchArguments(options.AttachedFiles, ...
                options.AdditionalPaths, poolSize);
            job = batch(cluster, functionHandle, numberOfOutputs, ...
                inputs, argumentsList{:});
            record.MatlabJobId = double(job.ID);
            if strlength(record.SubmittedAt) == 0
                record.SubmittedAt = nowText();
            end
            record.LastCheckedAt = nowText();
            record.State = mapState(job, record.State);
            record.SchedulerJobIds = schedulerIds(job);
        end

        function record = refresh(this, configuration, record)
            [job, ~] = this.findMatlabJob(configuration, record);
            if isempty(job)
                record.State = "Unknown";
                record.ErrorSummary = ...
                    "MATLAB job metadata is not available.";
                return
            end
            record.State = mapState(job, record.State);
            record.SchedulerJobIds = schedulerIds(job);
            try
                record.Diary = string(evalc("diary(job)"));
            catch
            end
            [identifier, summary] = taskError(job);
            if strlength(summary) > 0
                record.State = "Failed";
                record.ErrorIdentifier = identifier;
                record.ErrorSummary = summary;
            end
        end

        function record = cancel(this, configuration, record)
            [job, ~] = this.findMatlabJob(configuration, record);
            if isempty(job)
                record.State = "Unknown";
                return
            end
            cancel(job);
            record.State = "Cancelled";
        end

        function [outputs, record] = fetch(this, configuration, record)
            [job, ~] = this.findMatlabJob(configuration, record);
            if isempty(job)
                error("KSSOLV:Remote:MatlabJobMissing", ...
                    "MATLAB job metadata is not available.");
            end
            outputs = fetchOutputs(job);
            for index = 1:numel(outputs)
                outputs{index} = kssolv.services.remote.execution. ...
                    RemoteWorkflowRunner.restoreEnvelopeAfterTransport( ...
                    outputs{index});
            end
            try
                record.Diary = string(evalc("diary(job)"));
            catch
            end
            record.State = "Retrieved";
        end

        function [job, cluster] = findMatlabJob(this, configuration, record)
            cluster = this.ClusterFactory.ensureProfile(configuration);
            if isnan(record.MatlabJobId)
                job = [];
                return
            end
            job = findJob(cluster, "ID", record.MatlabJobId);
            if numel(job) > 1
                job = job(1);
            end
        end
    end
end

function argumentsList = batchArguments(attached, paths, poolSize)
argumentsList = {};
attached = string(attached(:));
attached(strlength(attached) == 0) = [];
if ~isempty(attached)
    argumentsList = [argumentsList, ...
        {"AttachedFiles", cellstr(attached)}];
end
paths = string(paths(:));
paths(strlength(paths) == 0) = [];
if ~isempty(paths)
    argumentsList = [argumentsList, ...
        {"AdditionalPaths", cellstr(paths)}];
end
if poolSize > 0
    argumentsList = [argumentsList, {"Pool", poolSize}];
end
end

function state = mapState(job, previousState)
switch lower(string(job.State))
    case {"pending", "queued", "unavailable"}
        state = "Queued";
    case "running"
        state = "Running";
    case "finished"
        if previousState == "Retrieved"
            state = "Retrieved";
        elseif any(previousState == ["Cancelling", "Cancelled"])
            state = "Cancelled";
        else
            state = "Finished";
        end
    case "failed"
        state = "Failed";
    otherwise
        state = "Unknown";
end
end

function ids = schedulerIds(job)
ids = strings(0, 1);
try
    raw = getTaskSchedulerIDs(job);
    if isstruct(raw) || istable(raw)
        raw = string(jsonencode(raw));
    else
        raw = string(raw);
    end
    ids = raw(:);
    ids(strlength(ids) == 0) = [];
catch
end
end

function [identifier, summary] = taskError(job)
identifier = "";
summary = "";
try
    tasks = job.Tasks;
    for index = 1:numel(tasks)
        exception = tasks(index).Error;
        if ~isempty(exception)
            identifier = string(exception.identifier);
            summary = string(exception.getReport( ...
                "extended", "hyperlinks", "off"));
            return
        end
    end
catch
end
end

function removeArtifact(path)
if strlength(string(path)) == 0
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
