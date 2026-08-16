classdef RemoteMatlabSession < handle
    %REMOTEMATLABSESSION Long-lived remote MATLAB used by Command Window.

    properties (SetAccess = immutable)
        Configuration struct
        Access
        SessionId (1, 1) string
        RemoteWorkspace (1, 1) string
        StartupTimeout (1, 1) double
        CommandTimeout (1, 1) double
        WorkerFile (1, 1) string
    end

    properties (SetAccess = private)
        Started (1, 1) logical = false
        Closed (1, 1) logical = false
        Sequence (1, 1) double = 0
    end

    methods
        function this = RemoteMatlabSession(configuration, ...
                accessFactory, options)
            arguments
                configuration struct
                accessFactory = ...
                    kssolv.services.remote.transport.RemoteAccessFactory()
                options.StartupTimeout (1, 1) double = 120
                options.CommandTimeout (1, 1) double = 3600
                options.WorkerFile (1, 1) string = string(which( ...
                    "kssolv.services.remote.execution." + ...
                    "remoteCommandSessionWorker"))
            end
            configuration = kssolv.services.remote.config. ...
                RemoteConfiguration.sanitized(configuration);
            if ismethod(accessFactory, "createMatlabSessionAccess")
                access = accessFactory.createMatlabSessionAccess( ...
                    configuration);
            else
                access = accessFactory.create(configuration);
            end
            if strlength(options.WorkerFile) == 0 || ...
                    ~isfile(options.WorkerFile)
                error("KSSOLV:Remote:CommandSessionWorkerMissing", ...
                    "The remote Command Window worker is unavailable.");
            end
            this.Configuration = configuration;
            this.Access = access;
            this.SessionId = kssolv.services.remote.config. ...
                RemoteConfiguration.newId();
            this.RemoteWorkspace = remoteJoin( ...
                configuration.RemoteJobStorageLocation, ...
                "kssolv-command-window", this.SessionId);
            this.StartupTimeout = options.StartupTimeout;
            this.CommandTimeout = options.CommandTimeout;
            this.WorkerFile = options.WorkerFile;
        end

        function output = execute(this, command, options)
            arguments
                this
                command (1, 1) string
                options.StatusReporter = []
            end
            if this.Closed
                error("KSSOLV:Remote:CommandSessionClosed", ...
                    "The remote MATLAB session is closed.");
            end
            if ~this.Started
                reportStatus(options.StatusReporter, "Starting", ...
                    this.Configuration.DisplayName);
                this.start();
            end
            reportStatus(options.StatusReporter, "Sending", "");
            this.Sequence = this.Sequence + 1;
            requestId = sprintf("%08d", this.Sequence);
            pendingName = "request-" + requestId + ".pending";
            requestName = "request-" + requestId + ".json";
            responseName = "response-" + requestId + ".json";
            localRoot = string(tempname);
            mkdir(localRoot);
            cleanup = onCleanup(@()removeLocal(localRoot));
            localRequest = fullfile(localRoot, pendingName);
            request = struct("Version", 1, "Id", requestId, ...
                "Command", command);
            kssolv.services.remote.internal.AtomicJsonFile.write( ...
                localRequest, request);
            this.Access.copyFileToRemote(char(localRequest), ...
                char(this.RemoteWorkspace));

            markerSuffix = replace(this.SessionId, "-", "_") + ...
                "_" + requestId;
            beginMarker = "KSSOLV_COMMAND_RESPONSE_BEGIN_" + markerSuffix;
            endMarker = "KSSOLV_COMMAND_RESPONSE_END_" + markerSuffix;
            remotePending = remoteJoin(this.RemoteWorkspace, pendingName);
            remoteRequest = remoteJoin(this.RemoteWorkspace, requestName);
            remoteResponse = remoteJoin(this.RemoteWorkspace, responseName);
            attempts = max(1, ceil(this.CommandTimeout * 5));
            commandLine = "mv -- " + shellQuote(remotePending) + " " + ...
                shellQuote(remoteRequest) + "; " + ...
                "for i in $(seq 1 " + attempts + "); do " + ...
                "if test -f " + shellQuote(remoteResponse) + "; then " + ...
                "printf '" + beginMarker + "\n'; " + ...
                "cat -- " + shellQuote(remoteResponse) + "; " + ...
                "printf '\n" + endMarker + "\n'; exit 0; fi; " + ...
                processLostShell(this.RemoteWorkspace) + ...
                "sleep 0.2; done; " + ...
                "printf 'Remote MATLAB command timed out.\n' >&2; exit 124";
            reportStatus(options.StatusReporter, "Waiting", "");
            [status, raw] = runUntilMarker( ...
                this.Access, commandLine, endMarker);
            if status ~= 0
                error("KSSOLV:Remote:CommandSessionRequestFailed", ...
                    "Remote MATLAB command failed: %s", ...
                    strip(string(raw)));
            end
            responseText = extractResponse(raw, beginMarker, endMarker);
            try
                response = jsondecode(char(responseText));
            catch exception
                error("KSSOLV:Remote:CommandSessionResponseInvalid", ...
                    "Remote MATLAB returned an invalid response: %s", ...
                    exception.message);
            end
            output = string(response.Output);
            this.removeResponse(remoteResponse);
            reportStatus(options.StatusReporter, "Finished", "");
            clear cleanup
        end

        function start(this)
            if this.Started
                return
            end
            [status, output] = this.Access.runCommand(char( ...
                "umask 077; mkdir -p -- " + ...
                shellQuote(this.RemoteWorkspace)));
            assertCommand(status, output, "create session workspace");
            try
                this.Access.copyFileToRemote(char(this.WorkerFile), ...
                    char(this.RemoteWorkspace));
                [~, workerName] = ...
                    fileparts(this.WorkerFile);
                expression = "addpath(" + ...
                    matlabLiteral(this.RemoteWorkspace) + "); " + ...
                    workerName + "(" + ...
                    matlabLiteral(this.RemoteWorkspace) + ");";
                executable = remoteJoin( ...
                    this.Configuration.ClusterMatlabRoot, "bin", "matlab");
                logPath = remoteJoin(this.RemoteWorkspace, "session.log");
                pidPath = remoteJoin(this.RemoteWorkspace, "session.pid");
                launch = "nohup " + shellQuote(executable) + " -batch " + ...
                    shellQuote(expression) + " >" + shellQuote(logPath) + ...
                    " 2>&1 < /dev/null & pid=$!; " + ...
                    "printf '%s\n' ""$pid"" >" + shellQuote(pidPath);
                [status, output] = this.Access.runCommand(char(launch));
                assertCommand(status, output, "start remote MATLAB session");
                this.waitUntilReady();
                this.Started = true;
            catch exception
                this.cleanupWorkspace();
                rethrow(exception)
            end
        end

        function close(this)
            if this.Closed
                return
            end
            this.Closed = true;
            if this.Started
                stopPath = remoteJoin(this.RemoteWorkspace, "stop");
                pidPath = remoteJoin(this.RemoteWorkspace, "session.pid");
                command = ": >" + shellQuote(stopPath) + "; " + ...
                    validatedPidShell(pidPath) + ...
                    "if test -n ""$pid""; then " + ...
                    "for i in $(seq 1 50); do " + ...
                    "kill -0 ""$pid"" 2>/dev/null || break; " + ...
                    "sleep 0.1; done; " + ...
                    "if kill -0 ""$pid"" 2>/dev/null; then " + ...
                    "kill -TERM ""$pid"" 2>/dev/null || true; " + ...
                    "for i in $(seq 1 20); do " + ...
                    "kill -0 ""$pid"" 2>/dev/null || break; " + ...
                    "sleep 0.1; done; fi; " + ...
                    "if kill -0 ""$pid"" 2>/dev/null; then " + ...
                    "kill -KILL ""$pid"" 2>/dev/null || true; fi; fi";
                try
                    this.Access.runCommand(char(command));
                catch
                end
            end
            this.cleanupWorkspace();
            this.Started = false;
        end

        function delete(this)
            try
                this.close();
            catch
            end
        end
    end

    methods (Access = private)
        function waitUntilReady(this)
            readyPath = remoteJoin(this.RemoteWorkspace, "ready.json");
            attempts = max(1, ceil(this.StartupTimeout * 5));
            command = "for i in $(seq 1 " + attempts + "); do " + ...
                "if test -f " + shellQuote(readyPath) + ...
                "; then exit 0; fi; " + ...
                processLostShell(this.RemoteWorkspace) + ...
                "sleep 0.2; done; " + ...
                "printf 'Remote MATLAB session startup timed out.\n' " + ...
                ">&2; exit 124";
            [status, output] = this.Access.runCommand(char(command));
            assertCommand(status, output, "wait for remote MATLAB session");
        end

        function removeResponse(this, path)
            try
                this.Access.runCommand(char( ...
                    "rm -f -- " + shellQuote(path)));
            catch
            end
        end

        function cleanupWorkspace(this)
            if strlength(this.RemoteWorkspace) == 0
                return
            end
            try
                this.Access.remoteDelete(char(this.RemoteWorkspace));
            catch
            end
        end
    end
end

function reportStatus(reporter, phase, detail)
if isempty(reporter)
    return
end
try
    reporter(string(phase), string(detail));
catch
end
end

function [status, output] = runUntilMarker(access, command, marker)
if ismethod(access, "runCommandUntilMarker")
    [status, output] = access.runCommandUntilMarker( ...
        char(command), char(marker));
else
    [status, output] = access.runCommand(char(command));
end
end

function value = extractResponse(raw, beginMarker, endMarker)
raw = string(raw);
beginIndex = strfind(raw, beginMarker);
endIndex = strfind(raw, endMarker);
if isempty(beginIndex) || isempty(endIndex) || ...
        endIndex(end) <= beginIndex(end)
    error("KSSOLV:Remote:CommandSessionResponseMissing", ...
        "Remote MATLAB did not return a complete command response.");
end
startAt = beginIndex(end) + strlength(beginMarker);
value = extractBetween(raw, startAt + 1, endIndex(end) - 1);
value = strip(value);
end

function value = processLostShell(workspace)
pidPath = remoteJoin(workspace, "session.pid");
logPath = remoteJoin(workspace, "session.log");
value = validatedPidShell(pidPath) + ...
    "if test -n ""$pid"" && ! kill -0 ""$pid"" 2>/dev/null; then " + ...
    "cat -- " + shellQuote(logPath) + " 2>/dev/null || true; " + ...
    "printf 'Remote MATLAB session exited unexpectedly.\n' >&2; " + ...
    "exit 125; fi; ";
end

function value = validatedPidShell(pidPath)
value = "pid=''; if test -f " + shellQuote(pidPath) + ...
    "; then candidate=$(cat -- " + shellQuote(pidPath) + ...
    "); case ""$candidate"" in ''|*[!0-9]*) ;; *) pid=$candidate ;; esac; fi; ";
end

function assertCommand(status, output, operation)
if status ~= 0
    error("KSSOLV:Remote:CommandSessionOperationFailed", ...
        "Unable to %s: %s", operation, strip(string(output)));
end
end

function removeLocal(path)
if isfolder(path)
    rmdir(path, "s");
end
end

function value = remoteJoin(parts)
arguments (Repeating)
    parts (1, 1) string
end
items = string(parts);
value = items(1);
for index = 2:numel(items)
    value = strip(value, "right", "/") + "/" + ...
        strip(items(index), "left", "/");
end
end

function value = shellQuote(text)
singleQuoteEscape = "'" + """" + "'" + """" + "'";
value = "'" + replace(string(text), "'", singleQuoteEscape) + "'";
end

function value = matlabLiteral(text)
value = "'" + replace(string(text), "'", "''") + "'";
end
