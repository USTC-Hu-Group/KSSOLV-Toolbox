classdef OpenSshRemoteAccess < handle
    %OPENSSHREMOTEACCESS Reusable native OpenSSH transport for MFA targets.

    properties (SetAccess = immutable)
        Configuration struct
        ControlRoot (1, 1) string
        ControlPath (1, 1) string
    end

    methods (Static)
        function value = isAvailable()
            if ispc
                value = system("where ssh >NUL 2>NUL") == 0 && ...
                    system("where scp >NUL 2>NUL") == 0;
            else
                value = system( ...
                    "command -v ssh >/dev/null 2>&1 && " + ...
                    "command -v scp >/dev/null 2>&1") == 0;
            end
        end
    end

    methods
        function this = OpenSshRemoteAccess(configuration)
            arguments
                configuration struct
            end
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            if ~this.isAvailable()
                error("KSSOLV:Remote:OpenSshUnavailable", ...
                    "Multifactor Bridge/Mirror connections require the " + ...
                    "OpenSSH ssh and scp commands on the local computer.");
            end
            this.Configuration = configuration;
            if ispc
                this.ControlRoot = string(tempname);
            else
                % Unix-domain socket paths are commonly limited to about
                % 104 bytes.  macOS tempdir is much longer than that.
                this.ControlRoot = string(tempname("/tmp"));
            end
            mkdir(this.ControlRoot);
            this.ControlPath = fullfile(this.ControlRoot, "control.sock");
            try
                this.connect();
            catch exception
                this.removeControlRoot();
                rethrow(exception)
            end
        end

        function [status, output] = runCommand(this, command)
            arguments
                this
                command
            end
            invocation = join(["ssh", "-S", ...
                shellQuote(this.ControlPath), "-o", ...
                "ControlMaster=no", "--", shellQuote(this.target()), ...
                shellQuote(string(command))], " ");
            [status, output] = system(char(invocation));
            output = char(string(output));
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
            targetPath = remoteJoin(string(destination), name + extension);
            invocation = join(["scp", "-q", "-o", ...
                "ControlMaster=no", "-o", ...
                shellQuote("ControlPath=" + this.ControlPath), "--", ...
                shellQuote(string(source)), ...
                shellQuote(this.target() + ":" + targetPath)], " ");
            [status, output] = system(char(invocation));
            assertTransfer(status, output, "upload", source);
        end

        function copyFileFromRemote(this, source, destination)
            [~, name, extension] = fileparts(string(source));
            targetPath = fullfile(string(destination), name + extension);
            invocation = join(["scp", "-q", "-o", ...
                "ControlMaster=no", "-o", ...
                shellQuote("ControlPath=" + this.ControlPath), "--", ...
                shellQuote(this.target() + ":" + string(source)), ...
                shellQuote(targetPath)], " ");
            [status, output] = system(char(invocation));
            assertTransfer(status, output, "download", source);
        end

        function remoteDelete(this, path)
            [status, output] = this.runCommand( ...
                "rm -rf -- " + shellQuote(string(path)));
            if status ~= 0
                error("KSSOLV:Remote:SshDeleteFailed", ...
                    "Unable to remove remote data %s: %s", ...
                    string(path), strip(string(output)));
            end
        end

        function delete(this)
            try
                invocation = join(["ssh", "-S", ...
                    shellQuote(this.ControlPath), "-O", "exit", "--", ...
                    shellQuote(this.target())], " ");
                system(char(invocation));
            catch
            end
            this.removeControlRoot();
        end
    end

    methods (Access = private)
        function connect(this)
            options = [ ...
                "-o", "ControlMaster=yes", ...
                "-o", "ControlPersist=600", ...
                "-o", "ControlPath=" + this.ControlPath, ...
                "-o", "ServerAliveInterval=30", ...
                "-o", "ServerAliveCountMax=3", ...
                "-o", "NumberOfPasswordPrompts=3", ...
                "-o", "PreferredAuthentications=keyboard-interactive," + ...
                    "password,publickey", ...
                "-o", "StrictHostKeyChecking=accept-new"];
            invocation = join(["ssh", options, "-f", "-N", "--", ...
                shellQuote(this.target())], " ");
            status = system(char(invocation));
            if status ~= 0 || ~isfile(this.ControlPath)
                error("KSSOLV:Remote:SshConnectionFailed", ...
                    "OpenSSH could not establish the multifactor " + ...
                    "connection to %s.", this.Configuration.Host);
            end
        end

        function value = target(this)
            value = this.Configuration.Username + "@" + ...
                this.Configuration.Host;
        end

        function removeControlRoot(this)
            if isfolder(this.ControlRoot)
                rmdir(this.ControlRoot, "s");
            end
        end
    end
end

function assertTransfer(status, output, operation, path)
if status ~= 0
    error("KSSOLV:Remote:SshTransferFailed", ...
        "Unable to %s %s through OpenSSH: %s", operation, ...
        string(path), strip(string(output)));
end
end

function value = shellQuote(text)
singleQuoteEscape = "'" + """" + "'" + """" + "'";
value = "'" + replace(string(text), "'", singleQuoteEscape) + "'";
end

function value = remoteJoin(left, right)
value = strip(string(left), "right", "/") + "/" + ...
    strip(string(right), "left", "/");
end
