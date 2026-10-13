classdef EncryptedStore
    %ENCRYPTEDSTORE 持久化经过加密的 KSSOLV 敏感配置。
    %
    % 每个用户首次保存密钥时生成独立的 RSA-3072 密钥对。每次写入使用
    % 随机 AES-256-GCM 数据密钥加密 API Key，再用 RSA-OAEP 包裹数据
    % 密钥。私钥和密文仅写入当前用户的 MATLAB 配置目录。
    %
    % 该方案用于避免 API Key 以明文形式保存在磁盘上。

    % 开发者：杨柳
    % 版权 2026 合肥瀚海量子科技有限公司

    properties (Constant, Access = private)
        FormatVersion = 1
        KeyPairFileName = 'keypair.json'
        OpenAIAPIKeyFileName = 'openai-api-key.json'
        MaterialsProjectAPIKeyFileName = 'materials-project-api-key.json'
        RSAKeySize = 3072
        GCMNonceSize = 12
        OpenAIAssociatedData = 'KSSOLV_OPENAI_API_KEY_V1'
        MaterialsProjectAssociatedData = ...
            'KSSOLV_MATERIALS_PROJECT_API_KEY_V1'
    end

    methods (Static)
        function value = readOpenAIAPIKey()
            %READOPENAIAPIKEY 读取并解密已保存的 OpenAI API Key。
            value = kssolv.settings.EncryptedStore.readCredential( ...
                kssolv.settings.EncryptedStore.OpenAIAPIKeyFileName, ...
                kssolv.settings.EncryptedStore.OpenAIAssociatedData);
        end

        function writeOpenAIAPIKey(value)
            %WRITEOPENAIAPIKEY 加密并持久化 OpenAI API Key。
            kssolv.settings.EncryptedStore.writeCredential(value, ...
                kssolv.settings.EncryptedStore.OpenAIAPIKeyFileName, ...
                kssolv.settings.EncryptedStore.OpenAIAssociatedData);
        end

        function removeOpenAIAPIKey()
            %REMOVEOPENAIAPIKEY 删除持久化的 API Key 密文。
            kssolv.settings.EncryptedStore.removeCredential( ...
                kssolv.settings.EncryptedStore.OpenAIAPIKeyFileName);
        end

        function value = readMaterialsProjectAPIKey()
            %READMATERIALSPROJECTAPIKEY 读取并解密用户的 MP API Key。
            value = kssolv.settings.EncryptedStore.readCredential( ...
                kssolv.settings.EncryptedStore. ...
                MaterialsProjectAPIKeyFileName, ...
                kssolv.settings.EncryptedStore. ...
                MaterialsProjectAssociatedData);
        end

        function writeMaterialsProjectAPIKey(value)
            %WRITEMATERIALSPROJECTAPIKEY 加密保存用户的 MP API Key。
            kssolv.settings.EncryptedStore.writeCredential(value, ...
                kssolv.settings.EncryptedStore. ...
                MaterialsProjectAPIKeyFileName, ...
                kssolv.settings.EncryptedStore. ...
                MaterialsProjectAssociatedData);
        end

        function removeMaterialsProjectAPIKey()
            %REMOVEMATERIALSPROJECTAPIKEY 删除用户的 MP API Key 密文。
            kssolv.settings.EncryptedStore.removeCredential( ...
                kssolv.settings.EncryptedStore. ...
                MaterialsProjectAPIKeyFileName);
        end
    end

    methods (Static, Access = private)
        function folder = storageFolder()
            userFolders = split(string(userpath), pathsep);
            userFolders = strip(userFolders);
            userFolders(strlength(userFolders) == 0) = [];
            if isempty(userFolders)
                error('KSSOLV:Settings:UserPathUnavailable', ...
                    'MATLAB userpath is not configured.');
            end
            folder = fullfile(char(userFolders(1)), ...
                'KSSOLV_Toolbox', 'credentials');
            if ~isfolder(folder)
                [created, detail] = mkdir(folder);
                if ~created
                    error('KSSOLV:Settings:CredentialDirectoryCreateFailed', ...
                        'Unable to create the credential directory: %s', ...
                        detail);
                end
            end
            kssolv.settings.EncryptedStore.restrictPermissions( ...
                folder, 'rwx------');
        end

        function path = keyPairFile()
            path = fullfile( ...
                kssolv.settings.EncryptedStore.storageFolder(), ...
                kssolv.settings.EncryptedStore.KeyPairFileName);
        end

        function path = credentialFile(fileName)
            path = fullfile( ...
                kssolv.settings.EncryptedStore.storageFolder(), ...
                fileName);
        end

        function value = readCredential(fileName, associatedData)
            value = "";
            encryptedFile = ...
                kssolv.settings.EncryptedStore.credentialFile(fileName);
            if ~isfile(encryptedFile)
                return
            end

            try
                payload = kssolv.settings.EncryptedStore.readJSON( ...
                    encryptedFile);
                kssolv.settings.EncryptedStore.validateSecretPayload(payload);
                privateKey = ...
                    kssolv.settings.EncryptedStore.loadPrivateKey();
                aesKeyBytes = kssolv.settings.EncryptedStore.unwrapKey( ...
                    privateKey, ...
                    kssolv.settings.EncryptedStore.fromBase64( ...
                    payload.WrappedKey));
                plainBytes = kssolv.settings.EncryptedStore.decryptValue( ...
                    aesKeyBytes, ...
                    kssolv.settings.EncryptedStore.fromBase64(payload.Nonce), ...
                    kssolv.settings.EncryptedStore.fromBase64( ...
                    payload.Ciphertext), associatedData);
                value = string(native2unicode(plainBytes(:).', 'UTF-8'));
            catch
                % 损坏或不可读的持久化数据按“未保存密钥”处理。
                value = "";
            end
        end

        function writeCredential(value, fileName, associatedData)
            value = string(value);
            if ~isscalar(value)
                error('KSSOLV:Settings:InvalidAPIKey', ...
                    'The API key must be a scalar string.');
            end
            if strlength(value) == 0
                kssolv.settings.EncryptedStore.removeCredential(fileName);
                return
            end

            [~, publicKey] = ...
                kssolv.settings.EncryptedStore.loadOrCreateKeyPair();
            [aesKeyBytes, nonce, ciphertext] = ...
                kssolv.settings.EncryptedStore.encryptValue( ...
                value, associatedData);
            wrappedKey = kssolv.settings.EncryptedStore.wrapKey( ...
                publicKey, aesKeyBytes);
            payload = struct( ...
                'Version', kssolv.settings.EncryptedStore.FormatVersion, ...
                'Algorithm', 'RSA-3072-OAEP-SHA256+AES-256-GCM', ...
                'WrappedKey', ...
                kssolv.settings.EncryptedStore.toBase64(wrappedKey), ...
                'Nonce', kssolv.settings.EncryptedStore.toBase64(nonce), ...
                'Ciphertext', ...
                kssolv.settings.EncryptedStore.toBase64(ciphertext));
            kssolv.settings.EncryptedStore.writeJSONAtomically( ...
                kssolv.settings.EncryptedStore.credentialFile(fileName), ...
                payload);
        end

        function removeCredential(fileName)
            encryptedFile = ...
                kssolv.settings.EncryptedStore.credentialFile(fileName);
            if isfile(encryptedFile)
                delete(encryptedFile);
            end
        end

        function [privateKey, publicKey] = loadOrCreateKeyPair()
            try
                [privateKey, publicKey] = ...
                    kssolv.settings.EncryptedStore.loadKeyPair();
                return
            catch
                % 缺失或损坏的密钥对将在下一次保存时重新生成。
            end

            [privateKey, publicKey] = kssolv.util.Crypto.rsaKeyPair( ...
                kssolv.settings.EncryptedStore.RSAKeySize);
            payload = struct( ...
                'Version', kssolv.settings.EncryptedStore.FormatVersion, ...
                'Algorithm', 'RSA-3072', ...
                'PrivateKey', kssolv.settings.EncryptedStore.toBase64(privateKey), ...
                'PublicKey', kssolv.settings.EncryptedStore.toBase64(publicKey));
            kssolv.settings.EncryptedStore.writeJSONAtomically( ...
                kssolv.settings.EncryptedStore.keyPairFile(), payload);
        end

        function [privateKey, publicKey] = loadKeyPair()
            payload = kssolv.settings.EncryptedStore.readJSON( ...
                kssolv.settings.EncryptedStore.keyPairFile());
            requiredFields = {'Version', 'PrivateKey', 'PublicKey'};
            if ~isstruct(payload) || ~isscalar(payload) || ...
                    ~all(isfield(payload, requiredFields)) || ...
                    payload.Version ~= ...
                    kssolv.settings.EncryptedStore.FormatVersion
                error('KSSOLV:Settings:InvalidCredentialKeyPair', ...
                    'The stored credential key pair is invalid.');
            end

            privateKey = kssolv.settings.EncryptedStore.fromBase64(payload.PrivateKey);
            publicKey = kssolv.settings.EncryptedStore.fromBase64(payload.PublicKey);
            kssolv.util.Crypto.validateRsaKeyPair(privateKey,publicKey);
        end

        function privateKey = loadPrivateKey()
            [privateKey, ~] = ...
                kssolv.settings.EncryptedStore.loadKeyPair();
        end

        function [aesKeyBytes, nonce, ciphertext] = ...
                encryptValue(value, associatedData)
            aesKeyBytes = kssolv.util.Crypto.random(32);
            nonce = kssolv.util.Crypto.random( ...
                kssolv.settings.EncryptedStore.GCMNonceSize);
            plainBytes = unicode2native(char(value), 'UTF-8');
            ciphertext = kssolv.util.Crypto.aesEncrypt(aesKeyBytes, nonce, ...
                plainBytes, unicode2native(associatedData, 'UTF-8'));
        end

        function plainBytes = ...
                decryptValue(aesKeyBytes, nonce, ciphertext, associatedData)
            plainBytes = kssolv.util.Crypto.aesDecrypt(aesKeyBytes, nonce, ...
                ciphertext, unicode2native(associatedData, 'UTF-8'));
        end

        function wrappedKey = wrapKey(publicKey, aesKeyBytes)
            wrappedKey = kssolv.util.Crypto.rsaEncrypt(publicKey, aesKeyBytes);
        end

        function aesKeyBytes = unwrapKey(privateKey, wrappedKey)
            aesKeyBytes = kssolv.util.Crypto.rsaDecrypt(privateKey, wrappedKey);
        end

        function validateSecretPayload(payload)
            requiredFields = { ...
                'Version', 'WrappedKey', 'Nonce', 'Ciphertext'};
            if ~isstruct(payload) || ~isscalar(payload) || ...
                    ~all(isfield(payload, requiredFields)) || ...
                    payload.Version ~= ...
                    kssolv.settings.EncryptedStore.FormatVersion
                error('KSSOLV:Settings:InvalidEncryptedCredential', ...
                    'The encrypted credential is invalid.');
            end
        end

        function payload = readJSON(path)
            text = fileread(path);
            payload = jsondecode(text);
        end

        function writeJSONAtomically(path, payload)
            folder = fileparts(path);
            temporaryFile = [tempname(folder) '.tmp'];
            cleanup = onCleanup(@() ...
                kssolv.settings.EncryptedStore.deleteIfExists(temporaryFile));
            data = unicode2native(jsonencode(payload), 'UTF-8');
            fileID = fopen(temporaryFile, 'wb');
            if fileID < 0
                error('KSSOLV:Settings:CredentialFileOpenFailed', ...
                    'Unable to open the credential file for writing.');
            end
            fileCleanup = onCleanup(@() fclose(fileID));
            written = fwrite(fileID, data, 'uint8');
            if written ~= numel(data)
                error('KSSOLV:Settings:CredentialFileWriteFailed', ...
                    'Unable to write the complete credential file.');
            end
            clear fileCleanup

            kssolv.settings.EncryptedStore.restrictPermissions( ...
                temporaryFile, 'rw-------');
            [moved, detail] = movefile(temporaryFile, path, 'f');
            if ~moved
                error('KSSOLV:Settings:CredentialFileMoveFailed', ...
                    'Unable to replace the credential file: %s', detail);
            end
            kssolv.settings.EncryptedStore.restrictPermissions( ...
                path, 'rw-------');
            clear cleanup
        end

        function restrictPermissions(path, permissions)
            if ~isunix
                % Windows 的用户配置目录继承当前账户的 ACL。
                return
            end
            kssolv.util.Platform.restrictPermissions(path, permissions);
        end

        function encoded = toBase64(bytes)
            encoded = char(matlab.net.base64encode(uint8(bytes(:).')));
        end

        function bytes = fromBase64(encoded)
            bytes = uint8(matlab.net.base64decode(char(string(encoded))));
        end

        function deleteIfExists(path)
            if isfile(path)
                delete(path);
            end
        end
    end
end
