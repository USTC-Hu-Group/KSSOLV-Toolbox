classdef RemoteEnvironmentProbeSession < handle
    %REMOTEENVIRONMENTPROBESESSION Cancellable process-based SSH discovery.

    properties (SetAccess = private)
        Configuration struct
        CredentialKeyRoot (1, 1) string
        Cluster = []
        Job = []
        State (1, 1) string = "Created"
        Phase (1, 1) string = "Starting"
        ProgressPath (1, 1) string = ""
        StartedAt = NaT
        Report struct = struct()
        ErrorIdentifier (1, 1) string = ""
        ErrorSummary (1, 1) string = ""
    end

    properties (Constant)
        TerminalStates = ["Succeeded", "Failed", "Cancelled"]
    end

    methods
        function this = RemoteEnvironmentProbeSession( ...
                configuration, credentialKeyRoot)
            arguments
                configuration struct
                credentialKeyRoot (1, 1) string
            end
            this.Configuration = kssolv.services.remote.diagnostics. ...
                RemoteEnvironmentProbe.prepareConfiguration(configuration);
            this.CredentialKeyRoot = credentialKeyRoot;
            this.ProgressPath = string(tempname) + ".phase";
        end

        function start(this)
            if this.State ~= "Created"
                error("KSSOLV:Remote:ConnectionTestAlreadyStarted", ...
                    "The remote connection test has already started.");
            end
            try
                this.StartedAt = datetime("now");
                this.Phase = "Starting";
                writePhase(this.ProgressPath, this.Phase);
                % matlabshared.internal.sshaccess cannot run on a thread
                % worker. A local batch job keeps the dialog responsive and
                % cancellable while running the probe in a MATLAB process.
                this.Cluster = localProcessCluster();
                this.Job = batch(this.Cluster, ...
                    @kssolv.services.remote.diagnostics.RemoteEnvironmentProbe.run, ...
                    1, {this.Configuration, this.CredentialKeyRoot, ...
                    this.ProgressPath});
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
                    "KSSOLV:Remote:EnvironmentProbeUnavailable";
                this.ErrorSummary = ...
                    "The remote environment probe is unavailable.";
                state = this.State;
                return
            end
            try
                this.refreshPhase();
                this.State = mapJobState(this.Job);
                if this.State == "Finished"
                    outputs = fetchOutputs(this.Job);
                    probe = outputs{1};
                    this.Report = struct("Succeeded", true, ...
                        "Probe", probe, ...
                        "FinishedAt", datetime("now", ...
                        "TimeZone", "UTC"));
                    this.State = "Succeeded";
                end
            catch exception
                this.fail(preferTaskError(this.Job, exception));
            end
            state = this.State;
        end

        function cancel(this)
            if any(this.State == this.TerminalStates)
                return
            end
            this.State = "Cancelling";
            this.Phase = "Cancelling";
            try
                if ~isempty(this.Job) && isvalid(this.Job)
                    kssolv.services.remote.diagnostics. ...
                        cancelJobPromptly(this.Job);
                end
                this.State = "Cancelled";
                this.Phase = "Cancelled";
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
            this.Cluster = [];
            if strlength(this.ProgressPath) > 0 && ...
                    isfile(this.ProgressPath)
                try
                    delete(this.ProgressPath);
                catch
                end
            end
        end

        function delete(this)
            this.cleanup();
        end
    end

    methods (Access = private)
        function refreshPhase(this)
            if strlength(this.ProgressPath) == 0 || ...
                    ~isfile(this.ProgressPath)
                return
            end
            try
                value = strip(string(fileread(this.ProgressPath)));
                if isscalar(value) && strlength(value) > 0
                    this.Phase = value;
                end
            catch
            end
        end

        function fail(this, exception)
            this.State = "Failed";
            this.ErrorIdentifier = string(exception.identifier);
            this.ErrorSummary = string(exception.message);
        end
    end
end

function writePhase(path, phase)
writelines(string(phase), path);
end

function exception = preferTaskError(job, fallback)
exception = fallback;
try
    tasks = job.Tasks;
    if ~isempty(tasks) && ~isempty(tasks(1).Error)
        exception = tasks(1).Error;
    end
catch
end
end

function cluster = localProcessCluster()
profiles = string(parallel.listProfiles());
if any(profiles == "Processes")
    cluster = parcluster("Processes");
elseif any(profiles == "local")
    cluster = parcluster("local");
else
    error("KSSOLV:Remote:LocalProcessProfileUnavailable", ...
        "A local process-based parallel profile is required for SSH discovery.");
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
        state = "Running";
end
end
