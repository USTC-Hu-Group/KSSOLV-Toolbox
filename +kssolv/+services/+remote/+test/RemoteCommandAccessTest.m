classdef RemoteCommandAccessTest < matlab.unittest.TestCase
    methods (Test)
        function wrapsTargetCommandWithoutChangingLoginCommands(testCase)
            delegate = kssolv.services.remote.test.FakeRemoteAccess();
            configuration = bridgeConfiguration();
            configuration.PostLoginCommandTemplate = ...
                "ssh node7 -- {command}";
            access = kssolv.services.remote.transport.RemoteCommandAccess( ...
                delegate, configuration);

            access.runLoginCommand("mkdir -p /shared/work");
            access.runCommand("printf '%s' bridge");

            testCase.verifyEqual(delegate.LoginCommands, ...
                "mkdir -p /shared/work");
            testCase.verifyTrue(contains(delegate.Commands(end), ...
                "ssh node7 --"));
            testCase.verifyTrue(contains(delegate.Commands(end), ...
                "printf"));
        end

        function routesBridgeMarkerThroughWrappedTarget(testCase)
            delegate = kssolv.services.remote.test.FakeRemoteAccess();
            configuration = bridgeConfiguration();
            configuration.PostLoginCommandTemplate = ...
                "ssh node7 -- {command}";
            access = kssolv.services.remote.transport.RemoteCommandAccess( ...
                delegate, configuration);

            access.runCommandUntilMarker("matlab -batch work", ...
                "KSSOLV_BRIDGE_STATUS:");

            testCase.verifyEqual(delegate.CompletionMarkers, ...
                "KSSOLV_BRIDGE_STATUS:");
            testCase.verifyTrue(contains(delegate.Commands(end), ...
                "ssh node7 --"));
        end

        function nestedSshPreservesCommandForFinalSuUser(testCase)
            delegate = kssolv.services.remote.test.FakeRemoteAccess();
            configuration = bridgeConfiguration();
            template = "sudo -n -- ssh -o BatchMode=yes " + ...
                "gpu6 -- su - yliu7949 -c {command}";
            configuration.PostLoginCommandTemplate = template;
            access = kssolv.services.remote.transport.RemoteCommandAccess( ...
                delegate, configuration);
            command = "id -un; printf '%s\n' ""$HOME""";

            access.runCommand(command);

            expected = replace(template, "{command}", ...
                quoteForShell(quoteForShell(command)));
            testCase.verifyEqual(delegate.Commands(end), expected);
        end

        function postLoginScriptRunsBeforeAndGatesTargetCommand(testCase)
            configuration = bridgeConfiguration();
            configuration.PostLoginScript = ...
                "printf 'KSSOLV_SCRIPT_RAN\n'; false; " + ...
                "printf 'KSSOLV_SCRIPT_CONTINUED\n'";
            access = kssolv.services.remote.transport.RemoteCommandAccess( ...
                kssolv.services.remote.test.LocalRemoteAccess(), ...
                configuration);

            [status, output] = access.runCommand( ...
                "printf 'KSSOLV_TARGET_RAN\n'");

            testCase.verifyNotEqual(status, 0);
            testCase.verifyTrue(contains(string(output), ...
                "KSSOLV_SCRIPT_RAN"));
            testCase.verifyFalse(contains(string(output), ...
                "KSSOLV_SCRIPT_CONTINUED"));
            testCase.verifyFalse(contains(string(output), ...
                "KSSOLV_TARGET_RAN"));
        end

        function threeSshModesSupportPlainAndRoutedCommands(testCase)
            for mode = ["Standard", "Bridge", "Mirror"]
                configuration = bridgeConfiguration();
                configuration.ExecutionMode = mode;
                configuration.PostLoginCommandTemplate = "{command}";
                plainDelegate = ...
                    kssolv.services.remote.test.FakeRemoteAccess();
                plain = kssolv.services.remote.transport.RemoteCommandAccess( ...
                    plainDelegate, configuration);
                plain.runCommand("printf plain");
                testCase.verifyEqual(plainDelegate.Commands(end), ...
                    "printf plain");

                configuration.PostLoginCommandTemplate = ...
                    "ssh node7 -- {command}";
                routedDelegate = ...
                    kssolv.services.remote.test.FakeRemoteAccess();
                routed = kssolv.services.remote.transport.RemoteCommandAccess( ...
                    routedDelegate, configuration);
                routed.runCommand("printf routed");
                testCase.verifyTrue(contains( ...
                    routedDelegate.Commands(end), "ssh node7 --"));
                testCase.verifyTrue(contains( ...
                    routedDelegate.Commands(end), "printf routed"));
            end
        end

        function rejectsWorkspaceHiddenFromRoutedTarget(testCase)
            configuration = bridgeConfiguration();
            configuration.PostLoginCommandTemplate = ...
                "ssh node7 -- {command}";
            delegate = kssolv.services.remote.test.FakeRemoteAccess();
            access = kssolv.services.remote.transport.RemoteCommandAccess( ...
                delegate, configuration);

            access.verifyWorkspaceVisibility("/shared/work");
            testCase.verifyTrue(any(contains( ...
                delegate.Commands, "ssh node7 --")));
            testCase.verifyTrue(any(contains( ...
                delegate.Commands, "test -d")));

            delegate.FailOn = "test -d";
            testCase.verifyError(@()access.verifyWorkspaceVisibility( ...
                "/shared/work"), ...
                "KSSOLV:Remote:WorkspaceCreateFailed");
            delegate.FailOn = "mkdir -p";
            testCase.verifyError(@()access.verifyWorkspaceVisibility( ...
                "/shared/work"), ...
                "KSSOLV:Remote:WorkspaceCreateFailed");
        end

        function routedTransferUsesLoginHostStaging(testCase)
            root = string(tempname);
            mkdir(root);
            testCase.addTeardown(@()removeFolder(root));
            source = fullfile(root, "request.txt");
            writelines("routed transfer payload", source);
            remoteRoot = fullfile(root, "final-user-workspace");
            downloadRoot = fullfile(root, "download");
            mkdir(downloadRoot);
            configuration = bridgeConfiguration();
            configuration.PostLoginCommandTemplate = "sh -c {command}";
            access = kssolv.services.remote.transport.RemoteCommandAccess( ...
                kssolv.services.remote.test.LocalRemoteAccess(), ...
                configuration);

            access.copyFileToRemote(source, remoteRoot);
            remoteFile = fullfile(remoteRoot, "request.txt");
            testCase.verifyEqual(string(fileread(remoteFile)), ...
                "routed transfer payload" + newline);

            access.copyFileFromRemote(remoteFile, downloadRoot);
            downloaded = fullfile(downloadRoot, "request.txt");
            testCase.verifyEqual(string(fileread(downloaded)), ...
                "routed transfer payload" + newline);

            access.remoteDelete(remoteFile);
            testCase.verifyFalse(isfile(remoteFile));
        end

        function answersConfiguredPromptThroughEncryptedExchange(testCase)
            [expectStatus, ~] = system("command -v expect >/dev/null 2>&1");
            [opensslStatus, ~] = system( ...
                "command -v openssl >/dev/null 2>&1");
            testCase.assumeEqual(expectStatus, 0);
            testCase.assumeEqual(opensslStatus, 0);
            root = string(tempname);
            mkdir(root);
            testCase.addTeardown(@()removeFolder(root));
            configuration = bridgeConfiguration();
            configuration.RemoteJobStorageLocation = root;
            configuration.RemotePromptPattern = "(?i)root password:";
            credential = join(["test", "elevation"], "-");
            access = kssolv.services.remote.transport.RemoteCommandAccess( ...
                kssolv.services.remote.test.LocalRemoteAccess(), ...
                configuration, CredentialProvider=@(~)credential);
            command = "stty -echo; printf 'Root password:'; " + ...
                "read answer; stty echo; " + ...
                "test ""$answer"" = '" + credential + "'; " + ...
                "printf '\\nKSSOLV_INTERACTIVE_OK\\n'";

            [status, output] = access.runCommand(command);

            testCase.verifyEqual(status, 0, output);
            testCase.verifyTrue(contains(string(output), ...
                "KSSOLV_INTERACTIVE_OK"));
            testCase.verifyFalse(contains(string(output), ...
                credential));
            interactiveRoot = fullfile(root, "kssolv-bridge", ...
                ".interactive");
            if isfolder(interactiveRoot)
                entries = dir(interactiveRoot);
                names = string({entries.name});
                testCase.verifyEqual(sum(~ismember(names, [".", ".."])), 0);
            end
        end

        function answersOrderedPromptsAndRejectsUnexpectedOrder(testCase)
            [expectStatus, ~] = system("command -v expect >/dev/null 2>&1");
            [opensslStatus, ~] = system( ...
                "command -v openssl >/dev/null 2>&1");
            testCase.assumeEqual(expectStatus, 0);
            testCase.assumeEqual(opensslStatus, 0);
            root = string(tempname);
            mkdir(root);
            testCase.addTeardown(@()removeFolder(root));
            configuration = bridgeConfiguration();
            configuration.RemoteJobStorageLocation = root;
            configuration.PostLoginPromptRules = [ ...
                struct("Pattern", "(?i)sudo password:", ...
                    "CredentialLabel", "Sudo credential")
                struct("Pattern", "(?i)node password:", ...
                    "CredentialLabel", "Node credential")];
            credentials = [join(["first", "credential"], "-"); ...
                join(["second", "credential"], "-")];
            access = kssolv.services.remote.transport.RemoteCommandAccess( ...
                kssolv.services.remote.test.LocalRemoteAccess(), ...
                configuration, CredentialProvider= ...
                @(~, index)credentials(index));
            command = "stty -echo; printf 'Sudo password:'; " + ...
                "read first; printf 'Node password:'; read second; " + ...
                "stty echo; test ""$first"" = '" + credentials(1) + ...
                "'; test ""$second"" = '" + credentials(2) + ...
                "'; printf '\nKSSOLV_ORDERED_OK\n'";

            [status, output] = access.runCommand(command);

            testCase.verifyEqual(status, 0, output);
            testCase.verifyTrue(contains(string(output), ...
                "KSSOLV_ORDERED_OK"));
            testCase.verifyFalse(any(contains(string(output), credentials)));

            repeated = "stty -echo; printf 'Sudo password:'; " + ...
                "read first; printf 'Sudo password:'; read second";
            [status, output] = access.runCommand(repeated);
            testCase.verifyNotEqual(status, 0);
            testCase.verifyTrue(contains(string(output), ...
                "unexpected or repeated interactive prompt"));
        end
    end
end

function value = bridgeConfiguration()
value = kssolv.services.remote.config.RemoteConfiguration.create(struct( ...
    "DisplayName", "Target shell", ...
    "ExecutionMode", "Bridge", ...
    "Host", "bridge.example.test", ...
    "Username", join(["test", "user"], "-"), ...
    "AuthenticationMode", "Multifactor", ...
    "ClusterMatlabRoot", "/opt/MATLAB/R2024a", ...
    "RemoteJobStorageLocation", "/tmp/kssolv-test", ...
    "RemoteBridgeProfileName", "remote-slurm", ...
    "CodeDeploymentMode", "ClusterInstalled", ...
    "RemoteKssolvRoot", "/shared/KSSOLV"));
end

function removeFolder(path)
if isfolder(path)
    rmdir(path, "s");
end
end

function value = quoteForShell(text)
singleQuoteEscape = "'" + """" + "'" + """" + "'";
value = "'" + replace(string(text), "'", singleQuoteEscape) + "'";
end
