classdef SshRemoteAccessTest < matlab.unittest.TestCase
    methods (Test)
        function preservesDirectoryCopyContract(testCase)
            client = kssolv.services.remote.test.FakeSshClient();
            access = kssolv.services.remote.transport.SshRemoteAccess( ...
                bridgeConfiguration(), Client=client);

            access.copyFileToRemote("/local/request.json", ...
                "/remote/workspace");
            access.copyFileFromRemote("/remote/workspace/result.mat", ...
                "/local/results");

            testCase.verifyEqual(client.UploadTarget, ...
                "/remote/workspace/request.json");
            testCase.verifyEqual(client.DownloadTarget, ...
                fullfile("/local/results", "result.mat"));
        end

        function markerSupervisorCollectsAndTerminatesCommand(testCase)
            client = kssolv.services.remote.test.FakeSshClient();
            access = kssolv.services.remote.transport.SshRemoteAccess( ...
                bridgeConfiguration(), Client=client);

            [status, output] = access.runCommandUntilMarker( ...
                "ssh node7 -- matlab -batch work", ...
                "KSSOLV_BRIDGE_STATUS:");

            testCase.verifyEqual(status, 0);
            testCase.verifyEqual(string(output), "ok");
            command = client.Commands(end);
            testCase.verifyTrue(contains(command, "mktemp -d"));
            testCase.verifyTrue(contains(command, ...
                "KSSOLV_BRIDGE_STATUS:"));
            testCase.verifyTrue(contains(command, "kill ""$child"""));
        end

        function savedPasswordBypassesInteractivePrompt(testCase)
            keyRoot = string(tempname);
            mkdir(keyRoot);
            cleanup = onCleanup(@()rmdir(keyRoot, "s"));
            cipher = kssolv.services.remote.security.LocalCredentialCipher(keyRoot);
            configuration = bridgeConfiguration();
            configuration.AuthenticationMode = "Password";
            configuration.EncryptedPassword = cipher.encrypt( ...
                "saved-password");

            actual = kssolv.services.remote.transport.SshRemoteAccess. ...
                resolvePassword(configuration, cipher);

            testCase.verifyEqual(actual, "saved-password");
        end

        function missingSavedPasswordDoesNotOpenInteractivePrompt(testCase)
            configuration = bridgeConfiguration();
            configuration.AuthenticationMode = "Password";
            configuration.EncryptedPassword = "";

            testCase.verifyError(@() ...
                kssolv.services.remote.transport.SshRemoteAccess. ...
                resolvePassword(configuration), ...
                "KSSOLV:Remote:StoredCredentialMissing");
        end
    end
end

function value = bridgeConfiguration()
value = kssolv.services.remote.config.RemoteConfiguration.create(struct( ...
    "DisplayName", "SSH transport", ...
    "SubmissionMode", "RemoteMatlabBridge", ...
    "Host", "bridge.example.test", ...
    "Username", join(["test", "user"], "-"), ...
    "ClusterMatlabRoot", "/opt/MATLAB/R2024a", ...
    "RemoteJobStorageLocation", "/remote", ...
    "RemoteBridgeProfileName", "remote-slurm"));
end
