classdef RemoteConnectionTestSession < handle
    %REMOTECONNECTIONTESTSESSION Nonblocking smoke-job state machine.

    properties (SetAccess = private)
        Configuration struct
        Factory
        ProbeResources (1, 1) logical
        Cluster = []
        Job = []
        State (1, 1) string = "Created"
        Report struct = struct()
        ErrorIdentifier (1, 1) string = ""
        ErrorSummary (1, 1) string = ""
    end

    properties (Constant)
        TerminalStates = ["Succeeded", "Failed", "Cancelled"]
    end

    methods
        function this = RemoteConnectionTestSession(configuration, factory, options)
            arguments
                configuration struct
                factory = kssolv.services.remote.cluster.ClusterFactory()
                options.ProbeResources (1, 1) logical = true
            end
            this.Configuration = kssolv.services.remote.config. ...
                RemoteConfiguration.sanitized(configuration);
            this.Factory = factory;
            this.ProbeResources = options.ProbeResources;
        end

        function start(this)
            if this.State ~= "Created"
                error("KSSOLV:Remote:ConnectionTestAlreadyStarted", ...
                    "The remote connection test has already started.");
            end
            this.State = "Submitting";
            try
                this.Cluster = this.Factory.ensureProfile( ...
                    this.Configuration);
                if this.ProbeResources
                    functionHandle = ...
                        @kssolv.services.remote.diagnostics.remoteProbe;
                else
                    functionHandle = @kssolv.services.remote.diagnostics. ...
                        remoteConnectionSmoke;
                end
                this.Job = batch(this.Cluster, functionHandle, 1, {});
                this.State = mapJobState(this.Job);
            catch exception
                this.fail(exception);
                rethrow(exception)
            end
        end

        function state = poll(this)
            if any(this.State == this.TerminalStates)
                state = this.State;
                return
            end
            if isempty(this.Job) || ~isvalid(this.Job)
                this.State = "Failed";
                this.ErrorIdentifier = ...
                    "KSSOLV:Remote:ConnectionTestJobUnavailable";
                this.ErrorSummary = ...
                    "The remote smoke job is no longer available.";
                state = this.State;
                return
            end
            try
                this.State = mapJobState(this.Job);
                if this.State == "Finished"
                    outputs = fetchOutputs(this.Job);
                    result = outputs{1};
                    if this.ProbeResources
                        validateProbe(result);
                        if this.Configuration.ExecutionMode == "Standard" && ...
                                ~strcmpi(string(result.MatlabRelease), ...
                                string(version("-release")))
                            error("KSSOLV:Remote:StandardReleaseMismatch", ...
                                "Standard mode requires matching releases: " + ...
                                "the client is R%s and the worker is R%s.", ...
                                version("-release"), result.MatlabRelease);
                        end
                    else
                        validateConnectionSmoke(result);
                    end
                    this.Report = struct( ...
                        "Succeeded", true, ...
                        "ProfileName", string(this.Cluster.Profile), ...
                        "FinishedAt", datetime("now", "TimeZone", "UTC"));
                    if this.ProbeResources
                        this.Report.Probe = result;
                    else
                        this.Report.Connection = result;
                    end
                    this.State = "Succeeded";
                end
            catch exception
                this.fail(exception);
            end
            state = this.State;
        end

        function cancel(this)
            if any(this.State == this.TerminalStates)
                return
            end
            try
                if ~isempty(this.Job) && isvalid(this.Job)
                    kssolv.services.remote.diagnostics. ...
                        cancelJobPromptly(this.Job);
                end
                this.State = "Cancelled";
            catch exception
                this.fail(exception);
            end
        end

        function cleanup(this)
            if ~isempty(this.Job) && isvalid(this.Job)
                if ~any(this.State == this.TerminalStates)
                    this.cancel();
                end
                try
                    delete(this.Job);
                catch
                end
            end
            this.Job = [];
        end

        function delete(this)
            this.cleanup();
        end
    end

    methods (Access = private)
        function fail(this, exception)
            this.State = "Failed";
            this.ErrorIdentifier = string(exception.identifier);
            this.ErrorSummary = string(exception.message);
        end
    end
end

function state = mapJobState(job)
switch lower(string(job.State))
    case {"pending", "queued", "unavailable"}
        state = "Queued";
    case "running"
        state = "Running";
    case "finished"
        state = "Finished";
    otherwise
        state = "Unknown";
end
end

function validateProbe(probe)
required = ["Hostname", "MatlabRelease", "SlurmJobId", ...
    "WorkerName", "Result"];
if ~isstruct(probe) || ~isscalar(probe) || ...
        ~all(isfield(probe, required)) || probe.Result ~= 3
    error("KSSOLV:Remote:InvalidSmokeResult", ...
        "The remote smoke job returned invalid diagnostics.");
end
end

function validateConnectionSmoke(result)
required = ["Hostname", "Result"];
if ~isstruct(result) || ~isscalar(result) || ...
        ~all(isfield(result, required)) || result.Result ~= 3
    error("KSSOLV:Remote:InvalidConnectionSmokeResult", ...
        "The remote connection smoke job returned invalid diagnostics.");
end
end
