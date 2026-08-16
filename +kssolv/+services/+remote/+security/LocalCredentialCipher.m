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
            publicKey = decodePublicKey(keys.PublicKey);
            cipher = javax.crypto.Cipher.getInstance( ...
                "RSA/ECB/OAEPWithSHA-256AndMGF1Padding");
            cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, publicKey);
            text = javaObject("java.lang.String", char(plaintext));
            raw = cipher.doFinal(text.getBytes("UTF-8"));
            encoder = javaMethod("getEncoder", "java.util.Base64");
            encrypted = string(char(encoder.encodeToString(raw)));
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
            privateKey = decodePrivateKey(keys.PrivateKey);
            decoder = javaMethod("getDecoder", "java.util.Base64");
            try
                raw = decoder.decode(char(encrypted));
                cipher = javax.crypto.Cipher.getInstance( ...
                    "RSA/ECB/OAEPWithSHA-256AndMGF1Padding");
                cipher.init(javax.crypto.Cipher.DECRYPT_MODE, privateKey);
                decoded = cipher.doFinal(raw);
                plaintext = string(char(javaObject( ...
                    "java.lang.String", decoded, "UTF-8")));
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
            generator = java.security.KeyPairGenerator.getInstance("RSA");
            generator.initialize(3072);
            pair = generator.generateKeyPair();
            encoder = javaMethod("getEncoder", "java.util.Base64");
            keys = struct( ...
                "Version", 1, ...
                "Algorithm", "RSA-OAEP-SHA256", ...
                "PrivateKey", string(char(encoder.encodeToString( ...
                    pair.getPrivate().getEncoded()))), ...
                "PublicKey", string(char(encoder.encodeToString( ...
                    pair.getPublic().getEncoded()))));
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

function key = decodePublicKey(value)
decoder = javaMethod("getDecoder", "java.util.Base64");
encoded = decoder.decode(char(value));
spec = javaObject("java.security.spec.X509EncodedKeySpec", encoded);
factory = javaMethod("getInstance", "java.security.KeyFactory", "RSA");
key = factory.generatePublic(spec);
end

function key = decodePrivateKey(value)
decoder = javaMethod("getDecoder", "java.util.Base64");
encoded = decoder.decode(char(value));
spec = javaObject("java.security.spec.PKCS8EncodedKeySpec", encoded);
factory = javaMethod("getInstance", "java.security.KeyFactory", "RSA");
key = factory.generatePrivate(spec);
end
