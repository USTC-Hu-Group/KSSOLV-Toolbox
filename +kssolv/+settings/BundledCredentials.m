classdef BundledCredentials
    %BUNDLEDCREDENTIALS Decrypt read-only credentials bundled with KSSOLV.
    %
    % Bundled credentials are encrypted at rest to avoid storing secret
    % values as plaintext in MATLAB source or resources. Because the app
    % must decrypt them without user input, this is obfuscation against
    % casual disclosure rather than a substitute for an OS secret store.

    % 开发者：杨柳
    % 版权 2026 合肥瀚海量子科技有限公司

    properties (Constant, Access = private)
        FormatVersion = 1
        Context = 'KSSOLV_MATERIALS_PROJECT_DEFAULT_V1'
        MaterialsProjectFileName = 'materials-project-default.json'
    end

    methods (Static)
        function value = readMaterialsProjectAPIKey()
            %READMATERIALSPROJECTAPIKEY Read the bundled default API key.
            persistent cachedValue
            if ~isempty(cachedValue)
                value = cachedValue;
                return
            end

            try
                path = fullfile(fileparts(mfilename('fullpath')), ...
                    'data', ...
                    kssolv.settings.BundledCredentials. ...
                    MaterialsProjectFileName);
                payload = jsondecode(fileread(path));
                kssolv.settings.BundledCredentials. ...
                    validatePayload(payload);
                plainBytes = kssolv.settings.BundledCredentials. ...
                    decrypt(payload);
                candidate = string(native2unicode( ...
                    plainBytes(:).', 'UTF-8'));
                if strlength(candidate) ~= 32
                    error('KSSOLV:Settings:InvalidBundledCredential', ...
                        'The bundled Materials Project key is invalid.');
                end
                value = candidate;
            catch
                % A missing, damaged, or incompatible optional credential
                % is treated as unavailable so explicit user configuration
                % can still be used.
                value = "";
            end
            cachedValue = value;
        end
    end

    methods (Static, Access = private)
        function plainBytes = decrypt(payload)
            contextBytes = unicode2native( ...
                kssolv.settings.BundledCredentials.Context, 'UTF-8');
            digest = javaMethod( ...
                'getInstance', 'java.security.MessageDigest', 'SHA-256');
            keyBytes = typecast(int8(digest.digest( ...
                typecast(uint8(contextBytes), 'int8'))), 'uint8');
            key = javaObject( ...
                'javax.crypto.spec.SecretKeySpec', ...
                typecast(keyBytes, 'int8'), 'AES');
            nonce = uint8(matlab.net.base64decode(payload.Nonce));
            ciphertext = uint8( ...
                matlab.net.base64decode(payload.Ciphertext));
            parameters = javaObject( ...
                'javax.crypto.spec.GCMParameterSpec', 128, ...
                typecast(nonce(:).', 'int8'));
            cipher = javaMethod( ...
                'getInstance', 'javax.crypto.Cipher', 'AES/GCM/NoPadding');
            cipher.init( ...
                kssolv.settings.BundledCredentials.cipherMode( ...
                'DECRYPT_MODE'), key, parameters);
            cipher.updateAAD(typecast(uint8(contextBytes), 'int8'));
            plainBytes = typecast(int8(cipher.doFinal( ...
                typecast(ciphertext(:).', 'int8'))), 'uint8');
        end

        function validatePayload(payload)
            required = {'Version', 'Algorithm', 'Nonce', 'Ciphertext'};
            if ~isstruct(payload) || ~isscalar(payload) || ...
                    ~all(isfield(payload, required)) || ...
                    payload.Version ~= ...
                    kssolv.settings.BundledCredentials.FormatVersion || ...
                    string(payload.Algorithm) ~= "AES-256-GCM"
                error('KSSOLV:Settings:InvalidBundledCredential', ...
                    'The bundled credential payload is invalid.');
            end
        end

        function mode = cipherMode(name)
            cipherClass = java.lang.Class.forName('javax.crypto.Cipher');
            mode = cipherClass.getField(name).get([]);
        end
    end
end
