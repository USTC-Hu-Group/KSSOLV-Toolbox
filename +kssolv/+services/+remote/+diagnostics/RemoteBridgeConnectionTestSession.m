classdef RemoteBridgeConnectionTestSession < handle
    %REMOTEBRIDGECONNECTIONTESTSESSION Nonblocking bridge smoke test.

    properties (SetAccess = private)
        Configuration struct
        Bridge
        Record struct = struct()
        BundlePath (1, 1) string = ""
        State (1, 1) string = "Created"
        Report struct = struct()
        ErrorIdentifier (1, 1) string = ""
        ErrorSummary (1, 1) string = ""
    end

    properties (Constant)
        TerminalStates = ["Succeeded", "Failed", "Cancelled"]
    end

    methods
        function this = RemoteBridgeConnectionTestSession( ...
                configuration, bridge)
            arguments
                configuration struct
                bridge = kssolv.services.remote.bridge.RemoteMatlabBridge()
            end
            this.Configuration = kssolv.services.remote.config. ...
                RemoteConfiguration.sanitized(configuration);
            this.Bridge = bridge;
        end

        function start(this)
            if this.State ~= "Created"
                error("KSSOLV:Remote:ConnectionTestAlreadyStarted", ...
                    "The remote connection test has already started.");
            end
            this.State = "Submitting";
            try
                [this.Record, this.BundlePath] = this.Bridge.submitProbe( ...
                    this.Configuration);
                this.State = mapRecordState(this.Record.State);
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
            try
                this.Record = this.Bridge.refresh( ...
                    this.Configuration, this.Record);
                this.State = mapRecordState(this.Record.State);
                if this.Record.State == "Finished"
                    [outputs, this.Record] = this.Bridge.fetch( ...
                        this.Configuration, this.Record);
                    probe = outputs{1};
                    validateProbe(probe);
                    if string(probe.MatlabRelease) ~= ...
                            string(this.Record.BridgeMatlabRelease)
                        error("KSSOLV:Remote:BridgeServerReleaseMismatch", ...
                            "Remote MATLAB is R%s, but the Parallel " + ...
                            "Server worker is R%s.", ...
                            this.Record.BridgeMatlabRelease, ...
                            probe.MatlabRelease);
                    end
                    this.Report = struct( ...
                        "Succeeded", true, ...
                        "ProfileName", ...
                            this.Configuration.RemoteBridgeProfileName, ...
                        "Probe", probe, ...
                        "FinishedAt", datetime("now", "TimeZone", "UTC"));
                    this.State = "Succeeded";
                elseif this.Record.State == "Failed"
                    this.State = "Failed";
                    this.ErrorIdentifier = this.Record.ErrorIdentifier;
                    this.ErrorSummary = this.Record.ErrorSummary;
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
                this.Record = this.Bridge.cancel( ...
                    this.Configuration, this.Record);
                this.State = "Cancelled";
            catch exception
                this.fail(exception);
            end
        end

        function cleanup(this)
            if ~isempty(fieldnames(this.Record))
                try
                    if ~any(this.State == this.TerminalStates)
                        this.cancel();
                    end
                    this.Bridge.cleanupRemote( ...
                        this.Configuration, this.Record);
                catch
                end
            end
            if strlength(this.BundlePath) > 0 && isfile(this.BundlePath)
                delete(this.BundlePath);
            end
            this.BundlePath = "";
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

function state = mapRecordState(value)
switch string(value)
    case {"Created", "Preparing", "Authenticating", "Submitting"}
        state = "Queued";
    case "Queued"
        state = "Queued";
    case "Running"
        state = "Running";
    case "Finished"
        state = "Finished";
    case "Cancelled"
        state = "Cancelled";
    case {"Failed", "ConnectionRequired", "Unknown"}
        state = "Failed";
    otherwise
        state = "Running";
end
end

function validateProbe(probe)
required = ["Hostname", "MatlabRelease", "SlurmJobId", ...
    "WorkerName", "Result"];
if ~isstruct(probe) || ~isscalar(probe) || ...
        ~all(isfield(probe, required)) || probe.Result ~= 3
    error("KSSOLV:Remote:InvalidSmokeResult", ...
        "The bridge smoke job returned invalid diagnostics.");
end
end
