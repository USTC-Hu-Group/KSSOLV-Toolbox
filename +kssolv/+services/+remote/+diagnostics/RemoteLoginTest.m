classdef RemoteLoginTest
    %REMOTELOGINTEST Verify SSH authentication and post-login setup only.

    methods (Static)
        function configuration = prepareConfiguration(configuration)
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                normalize(configuration);
            if ~any(configuration.ExecutionMode == ...
                    ["Standard", "Bridge", "Mirror"]) || ...
                    configuration.ConnectionMode ~= "SSH"
                error("KSSOLV:Remote:LoginTestModeUnsupported", ...
                    "The login test requires Standard, Bridge, or Mirror " + ...
                    "mode with SSH.");
            end
            if strlength(configuration.Host) == 0
                error("KSSOLV:Remote:LoginTestHostRequired", ...
                    "Enter the SSH host before testing the connection.");
            end
            if strlength(configuration.Username) == 0
                error("KSSOLV:Remote:LoginTestUsernameRequired", ...
                    "Enter the SSH username before testing the connection.");
            end
            if strlength(configuration.ClusterMatlabRoot) == 0
                configuration.ClusterMatlabRoot = "/";
            end
            if strlength(configuration.RemoteJobStorageLocation) == 0
                configuration.RemoteJobStorageLocation = "/tmp";
            end
            if configuration.ExecutionMode == "Bridge" && ...
                    strlength(configuration.RemoteBridgeProfileName) == 0
                configuration.RemoteBridgeProfileName = "local";
            end
            if configuration.CodeDeploymentMode == "ClusterInstalled" && ...
                    strlength(configuration.RemoteKssolvRoot) == 0
                configuration.RemoteKssolvRoot = "/";
            end
            % A connection test deliberately does not use the compute
            % command template. Prompt rules and the post-login script are
            % still exercised by RemoteCommandAccess.
            configuration.PostLoginCommandTemplate = "{command}";
            configuration = kssolv.services.remote.config. ...
                RemoteConfiguration.sanitized(configuration);
        end

        function report = run(configuration, credentialKeyRoot, progressPath)
            arguments
                configuration struct
                credentialKeyRoot (1, 1) string = fullfile( ...
                    prefdir, "KSSOLV", "remote", "credentials")
                progressPath (1, 1) string = ""
            end
            configuration = kssolv.services.remote.diagnostics. ...
                RemoteLoginTest.prepareConfiguration(configuration);
            writePhase(progressPath, "Connecting");
            cipher = kssolv.services.remote.security.LocalCredentialCipher( ...
                credentialKeyRoot);
            if configuration.ExecutionMode == "Standard"
                try
                    access = kssolv.services.remote.transport.SshRemoteAccess( ...
                        configuration, CredentialCipher=cipher);
                catch exception
                    connectionFailure(exception);
                end
                if strlength(configuration.PostLoginScript) > 0 || ...
                        ~isempty(configuration.PostLoginPromptRules)
                    access = kssolv.services.remote.transport. ...
                        RemoteCommandAccess(access, configuration);
                end
                report = runWithAccess(access, progressPath);
            else
                factory = kssolv.services.remote.transport.RemoteAccessFactory( ...
                    CredentialCipher=cipher);
                report = kssolv.services.remote.diagnostics.RemoteLoginTest. ...
                    runWithFactory(configuration, factory, progressPath);
            end
        end

        function report = runWithFactory( ...
                configuration, accessFactory, progressPath)
            if nargin < 3
                progressPath = "";
            end
            configuration = kssolv.services.remote.diagnostics. ...
                RemoteLoginTest.prepareConfiguration(configuration);
            writePhase(progressPath, "Connecting");
            try
                access = accessFactory.create(configuration);
            catch exception
                connectionFailure(exception);
            end
            report = runWithAccess(access, progressPath);
        end
    end
end

function report = runWithAccess(access, progressPath)
writePhase(progressPath, "PostLogin");
marker = "KSSOLV_LOGIN_TEST_OK";
command = "hostname_value=$(hostname 2>/dev/null || printf unknown); " + ...
    "printf 'KSSOLV_LOGIN_HOST=%s\n' ""$hostname_value""; " + ...
    "printf '%s\n' '" + marker + "'";
try
    if ismethod(access, "runCommandUntilMarker")
        [status, output] = access.runCommandUntilMarker( ...
            char(command), char(marker));
    else
        [status, output] = access.runCommand(char(command));
    end
catch exception
    error("KSSOLV:Remote:PostLoginScriptFailed", ...
        "The SSH connection or post-login setup failed: %s", ...
        exception.message);
end
output = string(output);
if status ~= 0 || ~contains(output, marker)
    error("KSSOLV:Remote:PostLoginScriptFailed", ...
        "The SSH connection or post-login setup returned an error: %s", ...
        diagnosticText(output));
end
hostname = markerValue(output, "HOST");
if strlength(hostname) == 0
    hostname = "unknown";
end
report = struct("Succeeded", true, "Hostname", hostname, ...
    "FinishedAt", datetime("now", "TimeZone", "UTC"));
writePhase(progressPath, "Completed");
end

function connectionFailure(exception)
error("KSSOLV:Remote:EnvironmentConnectionFailed", ...
    "Unable to establish the SSH connection: %s", exception.message);
end

function value = markerValue(output, name)
expression = "(?m)^KSSOLV_LOGIN_" + name + "=([^\r\n]*)$";
match = regexp(char(output), char(expression), "tokens", "once");
if isempty(match)
    value = "";
else
    value = strip(string(match{1}));
end
end

function value = diagnosticText(output)
value = strip(replace(string(output), "KSSOLV_LOGIN_TEST_OK", ""));
if strlength(value) == 0
    value = "No additional diagnostic output was returned.";
end
end

function writePhase(path, phase)
if strlength(string(path)) == 0
    return
end
try
    writelines(string(phase), path);
catch
end
end
