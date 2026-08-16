classdef LocalCredentialCipherTest < matlab.unittest.TestCase
    methods (Test)
        function roundTripsWithoutPlaintextInCipher(testCase)
            root = temporaryRoot(testCase);
            cipher = kssolv.services.remote.security.LocalCredentialCipher(root);
            plaintext = "example-credential";
            encrypted = cipher.encrypt(plaintext);

            testCase.verifyNotEqual(encrypted, plaintext);
            testCase.verifyFalse(contains(encrypted, plaintext));
            testCase.verifyEqual(cipher.decrypt(encrypted), plaintext);
            testCase.verifyTrue(cipher.hasKey());
        end

        function differentInstallKeyCannotDecrypt(testCase)
            first = kssolv.services.remote.security.LocalCredentialCipher( ...
                fullfile(temporaryRoot(testCase), "first"));
            second = kssolv.services.remote.security.LocalCredentialCipher( ...
                fullfile(temporaryRoot(testCase), "second"));
            encrypted = first.encrypt("example-credential");
            second.encrypt("prime-second-key");

            testCase.verifyError(@()second.decrypt(encrypted), ...
                "KSSOLV:Remote:CredentialDecryptFailed");
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
