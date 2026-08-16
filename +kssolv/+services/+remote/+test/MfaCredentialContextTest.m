classdef MfaCredentialContextTest < matlab.unittest.TestCase
    methods (TestMethodTeardown)
        function clearContext(~)
            kssolv.services.remote.security.MfaCredentialContext.shared().clear();
        end
    end

    methods (Test)
        function suppliesSavedPasswordAndGeneratedCode(testCase)
            keyRoot = temporaryRoot(testCase);
            cipher = kssolv.services.remote.security.LocalCredentialCipher(keyRoot);
            configuration = bridgeConfiguration();
            configuration.RememberTotpSecret = true;
            configuration.EncryptedPassword = cipher.encrypt( ...
                "saved-password");
            configuration.EncryptedTotpSecret = cipher.encrypt( ...
                "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ");
            context = kssolv.services.remote.security.MfaCredentialContext.shared();
            cleanup = context.activate(configuration, cipher); %#ok<NASGU>

            testCase.verifyEqual(context.response("Password:"), ...
                "saved-password");
            code = context.response("Verification code:");
            testCase.verifyMatches(code, "^[0-9]{6}$");
        end

        function keyboardCallbackUsesActiveContext(testCase)
            keyRoot = temporaryRoot(testCase);
            cipher = kssolv.services.remote.security.LocalCredentialCipher(keyRoot);
            configuration = bridgeConfiguration();
            configuration.EncryptedPassword = cipher.encrypt( ...
                "saved-password");
            context = kssolv.services.remote.security.MfaCredentialContext.shared();
            cleanup = context.activate(configuration, cipher); %#ok<NASGU>

            value = kssolv.services.remote.security. ...
                keyboardInteractiveCallback( ...
                "Password for test user:");
            testCase.verifyEqual(string(value), "saved-password");
        end
    end
end

function root = temporaryRoot(testCase)
root = string(tempname);
mkdir(root);
testCase.addTeardown(@()removeFolder(root));
end

function removeFolder(path)
if isfolder(path)
    rmdir(path, "s");
end
end

function value = bridgeConfiguration()
value = kssolv.services.remote.config.RemoteConfiguration.create(struct( ...
    "DisplayName", "Stored MFA", ...
    "ExecutionMode", "Bridge", ...
    "Host", "bridge.example.test", ...
    "Username", join(["test", "user"], "-"), ...
    "AuthenticationMode", "Multifactor", ...
    "ClusterMatlabRoot", "/opt/MATLAB/R2024a", ...
    "RemoteJobStorageLocation", "/scratch/test", ...
    "RemoteBridgeProfileName", "remote-slurm"));
end
