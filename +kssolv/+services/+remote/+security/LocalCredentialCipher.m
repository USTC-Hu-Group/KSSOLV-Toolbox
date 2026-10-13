classdef LocalCredentialCipher < handle
    %LOCALCREDENTIALCIPHER Encrypt configuration secrets for this install.

    properties (SetAccess = immutable)
        KeyRoot (1, 1) string
    end

    methods
        function this = LocalCredentialCipher(keyRoot)
            arguments
                keyRoot (1, 1) string = fullfile( ...
                    prefdir, "KSSOLV", "remote", "credentials")
            end
            this.KeyRoot = keyRoot;
        end

        function encrypted = encrypt(this, plaintext)
            arguments
                this
                plaintext (1, 1) string
            end
            if strlength(plaintext) == 0
                error("KSSOLV:Remote:CredentialEmpty", ...
                    "A stored credential must not be empty.");
            end
            keys = this.loadOrCreateKeys();
            publicKey = matlab.net.base64decode(keys.PublicKey);
            raw = kssolv.util.Crypto.rsaEncrypt(publicKey, ...
                unicode2native(char(plaintext), "UTF-8"));
            encrypted = string(matlab.net.base64encode(raw));
        end

        function plaintext = decrypt(this, encrypted)
            arguments
                this
                encrypted (1, 1) string
            end
            if strlength(encrypted) == 0
                error("KSSOLV:Remote:StoredCredentialMissing", ...
                    "The encrypted credential is missing.");
            end
            keys = this.loadKeys();
            privateKey = matlab.net.base64decode(keys.PrivateKey);
            try
                raw = matlab.net.base64decode(encrypted);
                decoded = kssolv.util.Crypto.rsaDecrypt(privateKey, raw);
                plaintext = string(native2unicode(decoded, "UTF-8"));
            catch exception
                error("KSSOLV:Remote:CredentialDecryptFailed", ...
                    "The saved credential cannot be decrypted with this " + ...
                    "installation's local key: %s", exception.message);
            end
        end

        function value = hasKey(this)
            value = isfile(this.keyPath());
        end
    end

    methods (Access = private)
        function keys = loadOrCreateKeys(this)
            if this.hasKey()
                keys = this.loadKeys();
                return
            end
            [privateKey, publicKey] = kssolv.util.Crypto.rsaKeyPair(3072);
            keys = struct( ...
                "Version", 1, ...
                "Algorithm", "RSA-OAEP-SHA256", ...
                "PrivateKey", string(matlab.net.base64encode(privateKey)), ...
                "PublicKey", string(matlab.net.base64encode(publicKey)));
            kssolv.services.remote.internal.AtomicJsonFile.write( ...
                this.keyPath(), keys);
        end

        function keys = loadKeys(this)
            if ~this.hasKey()
                error("KSSOLV:Remote:CredentialKeyMissing", ...
                    "The local credential key %s is missing. Saved remote " + ...
                    "credentials cannot be recovered.", this.keyPath());
            end
            keys = kssolv.services.remote.internal.AtomicJsonFile.read( ...
                this.keyPath(), struct());
            if ~isstruct(keys) || ~isscalar(keys) || ...
                    ~all(isfield(keys, ["Version", "Algorithm", ...
                    "PrivateKey", "PublicKey"])) || ...
                    double(keys.Version) ~= 1
                error("KSSOLV:Remote:CredentialKeyInvalid", ...
                    "The local credential key file is invalid.");
            end
        end

        function value = keyPath(this)
            value = fullfile(this.KeyRoot, "local-rsa-key.json");
        end
    end
end
