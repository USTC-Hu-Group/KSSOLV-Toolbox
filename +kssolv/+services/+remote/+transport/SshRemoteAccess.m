classdef SshRemoteAccess < handle
    %SSHREMOTEACCESS Cached SSH/SFTP transport without JobStorage mirroring.

    properties (SetAccess = immutable)
        Client
    end

    methods
        function this = SshRemoteAccess(configuration, options)
            arguments
                configuration struct
                options.Client = []
                options.CredentialCipher = ...
                    kssolv.services.remote.security.LocalCredentialCipher()
            end
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            if ~isempty(options.Client)
                this.Client = options.Client;
                return
            end
            if isempty(meta.class.fromName( ...
                    "matlabshared.internal.sshaccess.SSHClient"))
                error("KSSOLV:Remote:SshTransportUnavailable", ...
                    "This MATLAB release does not provide the SSH/SFTP " + ...
                    "transport required by RemoteMatlabBridge.");
            end
            contextCleanup = []; %#ok<NASGU>
            if configuration.AuthenticationMode == "Multifactor"
                context = kssolv.services.remote.security.MfaCredentialContext.shared();
                contextCleanup = context.activate( ...
                    configuration, options.CredentialCipher); %#ok<NASGU>
            end
            auth = authentication(configuration, options.CredentialCipher);
            try
                this.Client = matlabshared.internal.sshaccess.SSHClient( ...
                    char(configuration.Host), 22, auth);
            catch exception
                error("KSSOLV:Remote:SshConnectionFailed", ...
                    "Unable to connect to %s: %s", configuration.Host, ...
                    exception.message);
            end
            clear contextCleanup
        end

        function [status, output] = runCommand(this, command)
            try
                result = this.Client.runCommand(char(command));
            catch exception
                error("KSSOLV:Remote:SshCommandFailed", ...
                    "Unable to run a command through the Bridge SSH " + ...
                    "connection: %s", exception.message);
            end
            status = double(result.exitcode);
            output = string(strip(result.stdout, "right"));
            errorOutput = string(strip(result.stderr, "right"));
            if strlength(errorOutput) > 0
                if strlength(output) > 0
                    output = output + newline;
                end
                output = output + errorOutput;
            end
            output = char(output);
        end

        function [status, output] = runCommandUntilMarker(this, ...
                command, marker)
            commandRoot = "/tmp/kssolv-bridge-command.XXXXXX";
            script = "command_root=$(mktemp -d " + ...
                shellQuote(commandRoot) + ") || exit 125; " + ...
                "output_file=$command_root/output; " + ...
                "status_file=$command_root/status; " + ...
                "cleanup() { rm -rf -- ""$command_root""; }; " + ...
                "trap cleanup EXIT HUP INT TERM; " + ...
                "( " + string(command) + ...
                "; result=$?; printf '%s' ""$result"" >""$status_file""; " + ...
                "exit ""$result"" ) >""$output_file"" 2>&1 & child=$!; " + ...
                "while :; do " + ...
                "if grep -Fq -- " + shellQuote(string(marker)) + ...
                " ""$output_file"" 2>/dev/null; then " + ...
                "cat ""$output_file""; kill ""$child"" 2>/dev/null || true; " + ...
                "wait ""$child"" 2>/dev/null || true; exit 0; fi; " + ...
                "if test -f ""$status_file""; then " + ...
                "result=$(cat ""$status_file""); cat ""$output_file""; " + ...
                "exit ""$result""; fi; sleep 0.2; done";
            [status, output] = this.runCommand(script);
        end

        function copyFileToRemote(this, source, destination)
            [~, name, extension] = fileparts(string(source));
            target = remoteJoin(string(destination), name + extension);
            try
                this.Client.copyToRemote(char(source), char(target));
            catch exception
                error("KSSOLV:Remote:SshUploadFailed", ...
                    "Unable to upload %s: %s", string(source), ...
                    exception.message);
            end
        end

        function copyFileFromRemote(this, source, destination)
            [~, name, extension] = fileparts(string(source));
            target = fullfile(string(destination), name + extension);
            try
                this.Client.copyFromRemote(char(source), char(target));
            catch exception
                error("KSSOLV:Remote:SshDownloadFailed", ...
                    "Unable to download %s: %s", string(source), ...
                    exception.message);
            end
        end

        function remoteDelete(this, path)
            [status, output] = this.runCommand( ...
                "rm -rf -- " + shellQuote(string(path)));
            if status ~= 0
                error("KSSOLV:Remote:SshDeleteFailed", ...
                    "Unable to remove remote Bridge data %s: %s", ...
                    string(path), strip(string(output)));
            end
        end
    end

    methods (Static, Hidden)
        function password = resolvePassword( ...
                configuration, credentialCipher)
            arguments
                configuration struct
                credentialCipher = ...
                    kssolv.services.remote.security.LocalCredentialCipher()
            end
            if strlength(configuration.EncryptedPassword) == 0
                error("KSSOLV:Remote:StoredCredentialMissing", ...
                    "No saved SSH password is available for %s on %s. " + ...
                    "Open the remote cluster configuration, enter the " + ...
                    "password, and save it before retrying.", ...
                    configuration.Username, configuration.Host);
            end
            password = credentialCipher.decrypt( ...
                configuration.EncryptedPassword);
        end
    end
end

function value = authentication(configuration, credentialCipher)
value = matlabshared.internal.sshaccess.SSHAuthInfoVector;
username = char(configuration.Username);
switch configuration.AuthenticationMode
    case "Agent"
        item = matlabshared.internal.sshaccess.AgentAuth(username);
    case "IdentityFile"
        item = matlabshared.internal.sshaccess.IdentityFileAuth( ...
            username, char(configuration.IdentityFile), '');
    case "Password"
        password = kssolv.services.remote.transport.SshRemoteAccess. ...
            resolvePassword(configuration, credentialCipher);
        item = matlabshared.internal.sshaccess.PasswordAuth( ...
            username, char(password));
    case "Multifactor"
        item = matlabshared.internal.sshaccess.KeyboardInteractiveAuth( ...
            username, ...
            'kssolv.services.remote.security.keyboardInteractiveCallback');
    otherwise
        error("KSSOLV:Remote:AuthenticationModeUnsupported", ...
            "Unsupported SSH authentication mode %s.", ...
            configuration.AuthenticationMode);
end
value.add(item);
end

function value = shellQuote(text)
singleQuoteEscape = "'" + """" + "'" + """" + "'";
value = "'" + replace(string(text), "'", singleQuoteEscape) + "'";
end

function value = remoteJoin(left, right)
value = strip(string(left), "right", "/") + "/" + ...
    strip(string(right), "left", "/");
end
