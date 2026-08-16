classdef RemoteCommandAccess < handle
    %REMOTECOMMANDACCESS Route bridge commands through a target shell.

    properties (SetAccess = immutable)
        Delegate
        Configuration struct
        CredentialProvider
        InteractiveRunner
    end

    methods
        function this = RemoteCommandAccess(delegate, configuration, options)
            arguments
                delegate
                configuration struct
                options.CredentialProvider = ...
                    @kssolv.services.remote.transport.RemoteCommandAccess.promptCredential
                options.InteractiveRunner = ...
                    @kssolv.services.remote.transport.RemoteCommandAccess.runInteractive
            end
            this.Delegate = delegate;
            this.Configuration = ...
                kssolv.services.remote.config.RemoteConfiguration.sanitized( ...
                configuration);
            this.CredentialProvider = options.CredentialProvider;
            this.InteractiveRunner = options.InteractiveRunner;
        end

        function [status, output] = runCommand(this, command)
            [status, output] = this.execute(command, "");
        end

        function [status, output] = runCommandUntilMarker(this, ...
                command, marker)
            [status, output] = this.execute(command, string(marker));
        end

        function [status, output] = runLoginCommand(this, command)
            if ismethod(this.Delegate, "runLoginCommand")
                [status, output] = this.Delegate.runLoginCommand(command);
            else
                [status, output] = this.Delegate.runCommand(command);
            end
        end

        function copyFileToRemote(this, source, destination)
            stagingRoot = this.createLoginStaging();
            cleanup = onCleanup(@()this.removeLoginStaging(stagingRoot));
            [~, name, extension] = fileparts(string(source));
            stagedFile = this.copyFileToLoginStaging( ...
                string(source), stagingRoot, name + extension);
            targetFile = remoteJoin(string(destination), name + extension);
            payload = "umask 077; mkdir -p -- " + ...
                shellQuote(string(destination)) + " && cat > " + ...
                shellQuote(targetFile);
            wrapped = this.routeCommand(payload, false);
            [status, output] = this.executeWrapped( ...
                "cat -- " + shellQuote(stagedFile) + " | " + wrapped, "");
            if status ~= 0
                error("KSSOLV:Remote:RoutedUploadFailed", ...
                    "Unable to upload %s to the routed compute target: %s", ...
                    string(source), strip(string(output)));
            end
            clear cleanup
        end

        function copyFileFromRemote(this, source, destination)
            stagingRoot = this.createLoginStaging();
            cleanup = onCleanup(@()this.removeLoginStaging(stagingRoot));
            [~, name, extension] = fileparts(string(source));
            stagedFile = remoteJoin(stagingRoot, name + extension);
            wrapped = this.routeCommand( ...
                "cat -- " + shellQuote(string(source)), false);
            [status, output] = this.executeWrapped( ...
                wrapped + " > " + shellQuote(stagedFile), "");
            if status ~= 0
                error("KSSOLV:Remote:RoutedDownloadFailed", ...
                    "Unable to download %s from the routed compute " + ...
                    "target: %s", string(source), strip(string(output)));
            end
            this.Delegate.copyFileFromRemote(stagedFile, destination);
            clear cleanup
        end

        function remoteDelete(this, path)
            [status, output] = this.runCommand( ...
                "rm -rf -- " + shellQuote(string(path)));
            if status ~= 0
                error("KSSOLV:Remote:RoutedDeleteFailed", ...
                    "Unable to remove routed compute data %s: %s", ...
                    string(path), strip(string(output)));
            end
        end

        function verifyWorkspaceVisibility(this, path)
            arguments
                this
                path (1, 1) string
            end
            probeFile = remoteJoin(path, ...
                ".kssolv-workspace-test-" + ...
                kssolv.services.remote.config.RemoteConfiguration.newId());
            command = "umask 077; mkdir -p -- " + shellQuote(path) + ...
                " && test -d " + shellQuote(path) + ...
                " && : > " + shellQuote(probeFile) + ...
                " && rm -f -- " + shellQuote(probeFile);
            [status, output] = this.runCommand(char(command));
            if status ~= 0
                error("KSSOLV:Remote:WorkspaceCreateFailed", ...
                    "The final compute user cannot create and write the " + ...
                    "remote workspace %s: %s", ...
                    path, strip(string(output)));
            end
        end
    end

    methods (Access = private)
        function [status, output] = execute(this, command, marker)
            wrapped = this.routeCommand(string(command), true);
            [status, output] = this.executeWrapped(wrapped, marker);
        end

        function wrapped = routeCommand(this, command, includeScript)
            if includeScript && ...
                    strlength(this.Configuration.PostLoginScript) > 0
                command = "set -e" + newline + ...
                    this.Configuration.PostLoginScript + newline + command;
            end
            if this.Configuration.PostLoginCommandTemplate == "{command}"
                wrapped = command;
            else
                wrapped = wrapRoutedCommand( ...
                    this.Configuration.PostLoginCommandTemplate, command);
            end
        end

        function [status, output] = executeWrapped(this, wrapped, marker)
            rules = this.Configuration.PostLoginPromptRules;
            if isempty(rules)
                if strlength(marker) > 0 && ismethod(this.Delegate, ...
                        "runCommandUntilMarker")
                    [status, output] = this.Delegate. ...
                        runCommandUntilMarker(char(wrapped), char(marker));
                else
                    [status, output] = this.Delegate.runCommand(char(wrapped));
                end
                return
            end
            credentials = strings(numel(rules), 1);
            for index = 1:numel(rules)
                promptConfiguration = this.Configuration;
                promptConfiguration.PromptRuleIndex = index;
                credentials(index) = requestCredential( ...
                    this.CredentialProvider, promptConfiguration, index);
                if strlength(credentials(index)) == 0
                    error("KSSOLV:Remote:InteractiveCredentialEmpty", ...
                        "Remote interactive credential %d cannot be empty.", ...
                        index);
                end
            end
            cleanup = onCleanup(@()clearCredential(credentials));
            [status, output] = this.InteractiveRunner( ...
                this.Delegate, this.Configuration, wrapped, credentials, ...
                marker);
            clear cleanup
        end

        function root = createLoginStaging(this)
            marker = "KSSOLV_ROUTE_STAGING=";
            command = "root=$(mktemp -d /tmp/kssolv-route.XXXXXX)" + ...
                " || exit 125; chmod 700 ""$root"" || exit 125; " + ...
                "printf '" + marker + "%s\n' ""$root""";
            [status, output] = this.Delegate.runCommand(char(command));
            match = regexp(char(string(output)), ...
                '(?m)^KSSOLV_ROUTE_STAGING=([^\r\n]+)$', ...
                'tokens', 'once');
            if status ~= 0 || isempty(match)
                error("KSSOLV:Remote:RoutedStagingCreateFailed", ...
                    "Unable to create a temporary transfer directory on " + ...
                    "the SSH login host: %s", strip(string(output)));
            end
            root = string(match{1});
        end

        function removeLoginStaging(this, root)
            try
                this.Delegate.remoteDelete(char(root));
            catch
            end
        end

        function stagedFile = copyFileToLoginStaging( ...
                this, source, stagingRoot, remoteName)
            stagedFile = remoteJoin(stagingRoot, remoteName);
            details = dir(source);
            chunkBytes = 1024 * 1024;
            if isempty(details) || details.bytes <= chunkBytes
                this.Delegate.copyFileToRemote(char(source), ...
                    char(stagingRoot));
                return
            end

            localRoot = string(tempname);
            mkdir(localRoot);
            cleanup = onCleanup(@()removeLocal(localRoot));
            [input, message] = fopen(source, "rb");
            if input < 0
                error("KSSOLV:Remote:RoutedUploadReadFailed", ...
                    "Unable to read %s for routed upload: %s", ...
                    source, message);
            end
            inputCleanup = onCleanup(@()fclose(input));
            remoteParts = strings(0, 1);
            index = 0;
            while true
                bytes = fread(input, chunkBytes, "*uint8");
                if isempty(bytes)
                    break
                end
                index = index + 1;
                partName = remoteName + sprintf(".part%05d", index);
                localPart = fullfile(localRoot, partName);
                writeBinary(localPart, bytes);
                this.Delegate.copyFileToRemote(char(localPart), ...
                    char(stagingRoot));
                remoteParts(end + 1) = remoteJoin( ...
                    stagingRoot, partName); %#ok<AGROW>
            end
            clear inputCleanup

            command = "cat -- " + join(shellQuote(remoteParts), " ") + ...
                " > " + shellQuote(stagedFile) + " && rm -f -- " + ...
                join(shellQuote(remoteParts), " ");
            [status, output] = this.Delegate.runCommand(char(command));
            if status ~= 0
                error("KSSOLV:Remote:RoutedUploadAssembleFailed", ...
                    "Unable to assemble routed upload %s: %s", ...
                    source, strip(string(output)));
            end
            clear cleanup
        end
        end

    methods (Static)
        function credential = promptCredential(configuration)
            title = "KSSOLV Remote Computing";
            index = 1;
            if isfield(configuration, "PromptRuleIndex")
                index = double(configuration.PromptRuleIndex);
            end
            rules = configuration.PostLoginPromptRules;
            if index < 1 || index > numel(rules)
                error("KSSOLV:Remote:InteractivePromptRuleMissing", ...
                    "Post-login credential rule %d is unavailable.", index);
            end
            message = string(rules(index).CredentialLabel) + ...
                " for " + string(configuration.DisplayName) + ":";
            if usejava("desktop")
                field = javaObjectEDT("javax.swing.JPasswordField");
                panel = javaObjectEDT("javax.swing.JPanel", ...
                    java.awt.BorderLayout(8, 8));
                panel.add(javaObjectEDT("javax.swing.JLabel", char(message)), ...
                    java.awt.BorderLayout.NORTH);
                panel.add(field, java.awt.BorderLayout.CENTER);
                result = javax.swing.JOptionPane.showConfirmDialog([], ...
                    panel, char(title), ...
                    javax.swing.JOptionPane.OK_CANCEL_OPTION, ...
                    javax.swing.JOptionPane.PLAIN_MESSAGE);
                if result ~= javax.swing.JOptionPane.OK_OPTION
                    error("KSSOLV:Remote:InteractiveCredentialCancelled", ...
                        "Remote interactive credential entry was cancelled.");
                end
                credential = string(char(field.getPassword().'));
            else
                credential = string(matlabshared.internal.readPassword( ...
                    char(message + " ")));
            end
        end

        function [status, output] = runInteractive(delegate, ...
                configuration, wrappedCommand, credentials, marker)
            localRoot = string(tempname);
            mkdir(localRoot);
            localCleanup = onCleanup(@()removeLocal(localRoot));
            exchangeId = kssolv.services.remote.config.RemoteConfiguration.newId();
            remoteRoot = "/tmp/kssolv-bridge-interactive/" + exchangeId;
            remoteCleanup = onCleanup(@()removeRemote(delegate, remoteRoot));
            keyPath = remoteJoin(remoteRoot, "private.pem");
            publicPath = remoteJoin(remoteRoot, "public.pem");
            scriptPath = remoteJoin(remoteRoot, "bridge-expect.tcl");

            setup = "umask 077; mkdir -p -- " + shellQuote(remoteRoot) + ...
                " && command -v expect >/dev/null 2>&1" + ...
                " && command -v openssl >/dev/null 2>&1" + ...
                " && openssl genpkey -algorithm RSA" + ...
                " -pkeyopt rsa_keygen_bits:2048 -out " + ...
                shellQuote(keyPath) + " 2>/dev/null" + ...
                " && openssl pkey -in " + shellQuote(keyPath) + ...
                " -pubout -out " + shellQuote(publicPath) + ...
                " && cat -- " + shellQuote(publicPath);
            [setupStatus, publicKey] = delegate.runCommand(char(setup));
            if double(setupStatus) ~= 0 || ...
                    ~contains(string(publicKey), "BEGIN PUBLIC KEY")
                error("KSSOLV:Remote:InteractivePrerequisiteMissing", ...
                    "The target-command mode requires expect and openssl " + ...
                    "on the SSH login host. Remote output: %s", ...
                    strip(string(publicKey)));
            end

            localScript = fullfile(localRoot, "bridge-expect.tcl");
            writeText(localScript, expectProgram());
            delegate.copyFileToRemote(char(localScript), char(remoteRoot));
            cipherPaths = strings(numel(credentials), 1);
            localCiphers = strings(numel(credentials), 1);
            for index = 1:numel(credentials)
                name = "credential-" + index + ".bin";
                cipherPaths(index) = remoteJoin(remoteRoot, name);
                localCiphers(index) = fullfile(localRoot, name);
                writeBinary(localCiphers(index), ...
                    encryptCredential(publicKey, credentials(index)));
                delegate.copyFileToRemote(char(localCiphers(index)), ...
                    char(remoteRoot));
            end
            [chmodStatus, chmodOutput] = delegate.runCommand(char( ...
                "chmod 600 " + join(shellQuote(cipherPaths), " ") + " " + ...
                shellQuote(scriptPath)));
            if double(chmodStatus) ~= 0
                error("KSSOLV:Remote:InteractiveUploadFailed", ...
                    "Unable to protect remote credential exchange files: %s", ...
                    strip(string(chmodOutput)));
            end

            rules = configuration.PostLoginPromptRules;
            allPatterns = strings(numel(rules), 1);
            command = "env KSSOLV_BRIDGE_KEY=" + shellQuote(keyPath) + ...
                " KSSOLV_BRIDGE_PROMPT_COUNT=" + numel(rules);
            for index = 1:numel(rules)
                pattern = string(rules(index).Pattern);
                if startsWith(pattern, "(?i)")
                    pattern = extractAfter(pattern, 4);
                end
                allPatterns(index) = "(?:" + pattern + ")";
                command = command + " KSSOLV_BRIDGE_CIPHER_" + index + ...
                    "=" + shellQuote(cipherPaths(index)) + ...
                    " KSSOLV_BRIDGE_PROMPT_" + index + "=" + ...
                    shellQuote(pattern);
            end
            command = command + " KSSOLV_BRIDGE_ALL_PROMPTS=" + ...
                shellQuote(join(allPatterns, "|")) + ...
                " expect -- " + shellQuote(scriptPath) + " -- " + ...
                shellQuote(wrappedCommand);
            if strlength(marker) > 0 && ...
                    ismethod(delegate, "runCommandUntilMarker")
                [status, output] = delegate.runCommandUntilMarker( ...
                    char(command), char(marker));
            else
                [status, output] = delegate.runCommand(char(command));
            end
            clear remoteCleanup localCleanup
        end
    end
end

function encrypted = encryptCredential(publicKey, credential)
text = regexprep(char(publicKey), ...
    '-----BEGIN PUBLIC KEY-----|-----END PUBLIC KEY-----|\s', '');
decoder = javaMethod("getMimeDecoder", "java.util.Base64");
encoded = decoder.decode(text);
spec = javaObject("java.security.spec.X509EncodedKeySpec", encoded);
factory = javaMethod("getInstance", "java.security.KeyFactory", "RSA");
key = factory.generatePublic(spec);
cipher = javaMethod("getInstance", "javax.crypto.Cipher", ...
    "RSA/ECB/PKCS1Padding");
cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, key);
secretText = javaObject("java.lang.String", char(credential));
secretBytes = secretText.getBytes("UTF-8");
raw = cipher.doFinal(secretBytes);
encrypted = uint8(mod(double(raw), 256));
end

function text = expectProgram()
lines = [ ...
    "#!/usr/bin/expect -f"
    "set timeout 120"
    "set key $env(KSSOLV_BRIDGE_KEY)"
    "set promptCount $env(KSSOLV_BRIDGE_PROMPT_COUNT)"
    "set allPrompts $env(KSSOLV_BRIDGE_ALL_PROMPTS)"
    "for {set i 1} {$i <= $promptCount} {incr i} {"
    "    set cipher $env(KSSOLV_BRIDGE_CIPHER_$i)"
    "    set prompts($i) $env(KSSOLV_BRIDGE_PROMPT_$i)"
    "    set credentials($i) [exec openssl pkeyutl -decrypt -inkey $key -in $cipher -pkeyopt rsa_padding_mode:pkcs1]"
    "}"
    "set command [lindex $argv end]"
    "set current 1"
    "spawn -noecho /bin/sh -lc $command"
    "while {1} {"
    "    if {$current <= $promptCount} {"
    "        set expected $prompts($current)"
    "        expect {"
    "            -nocase -re $expected {"
    "                send -- ""$credentials($current)\r"""
    "                set credentials($current) """""
    "                incr current"
    "            }"
    "            -nocase -re $allPrompts {"
    "                send -- ""\003"""
    "                puts stderr ""KSSOLV: unexpected or repeated interactive prompt"""
    "                exit 126"
    "            }"
    "            timeout {"
    "                send -- ""\003"""
    "                puts stderr ""KSSOLV: timed out waiting for interactive prompt"""
    "                exit 124"
    "            }"
    "            eof { break }"
    "        }"
    "    } else {"
    "        expect {"
    "            -nocase -re $allPrompts {"
    "                send -- ""\003"""
    "                puts stderr ""KSSOLV: interactive credential was rejected"""
    "                exit 126"
    "            }"
    "            timeout {"
    "                send -- ""\003"""
    "                puts stderr ""KSSOLV: interactive command timed out"""
    "                exit 124"
    "            }"
    "            eof { break }"
    "        }"
    "    }"
    "}"
    "set result [wait]"
    "if {[lindex $result 2] != 0} { exit 127 }"
    "exit [lindex $result 3]"];
text = join(lines, newline) + newline;
end

function credential = requestCredential(provider, configuration, index)
try
    providerInputs = nargin(provider);
catch
    providerInputs = 1;
end
if providerInputs < 0 || providerInputs >= 2
    credential = provider(configuration, index);
else
    credential = provider(configuration);
end
credential = string(credential);
if ~isscalar(credential)
    error("KSSOLV:Remote:InteractiveCredentialInvalid", ...
        "A credential provider must return one scalar credential.");
end
end

function writeBinary(path, value)
fileId = fopen(path, "w");
if fileId < 0
    error("KSSOLV:Remote:InteractiveLocalWriteFailed", ...
        "Unable to write temporary encrypted credential data.");
end
cleanup = onCleanup(@()fclose(fileId));
fwrite(fileId, value, "uint8");
clear cleanup
end

function writeText(path, value)
fileId = fopen(path, "w");
if fileId < 0
    error("KSSOLV:Remote:InteractiveLocalWriteFailed", ...
        "Unable to write the temporary Expect program.");
end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId, "%s", value);
clear cleanup
end

function removeRemote(delegate, path)
try
    delegate.remoteDelete(char(path));
catch
end
end

function removeLocal(path)
if isfolder(path)
    rmdir(path, "s");
elseif isfile(path)
    delete(path);
end
end

function clearCredential(value)
try
    value(:) = char(0); %#ok<NASGU>
catch
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
text = string(text);
singleQuoteEscape = "'" + """" + "'" + """" + "'";
value = "'" + replace(text, "'", singleQuoteEscape) + "'";
end

function value = wrapRoutedCommand(template, command)
% Preserve the payload through every remote shell introduced by SSH.
template = string(template);
placeholder = "{command}";
prefix = extractBefore(template, placeholder);
sshTokens = regexpi(char(prefix), ...
    '(^|[\s;&|()])ssh([\s]|$)', 'match');
quoted = string(command);
for index = 1:(1 + numel(sshTokens))
    quoted = shellQuote(quoted);
end
value = replace(template, placeholder, quoted);
end
