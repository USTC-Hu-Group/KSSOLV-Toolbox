classdef MfaCredentialContext < handle
    %MFACREDENTIALCONTEXT Supply saved password and TOTP to SSH callbacks.

    properties (Access = private)
        Configuration struct = struct()
        CredentialCipher = []
        Active (1, 1) logical = false
    end

    methods (Static)
        function value = shared()
            persistent instance
            if isempty(instance) || ~isvalid(instance)
                instance = kssolv.services.remote.security.MfaCredentialContext();
            end
            value = instance;
        end
    end

    methods
        function cleanup = activate(this, configuration, credentialCipher)
            arguments
                this
                configuration struct
                credentialCipher = ...
                    kssolv.services.remote.security.LocalCredentialCipher()
            end
            if this.Active
                error("KSSOLV:Remote:MfaAuthenticationAlreadyActive", ...
                    "Another multifactor authentication is already active.");
            end
            this.Configuration = kssolv.services.remote.config. ...
                RemoteConfiguration.sanitized(configuration);
            this.CredentialCipher = credentialCipher;
            this.Active = true;
            cleanup = onCleanup(@()this.clear());
        end

        function value = isActive(this)
            value = this.Active;
        end

        function value = response(this, promptMessage)
            if ~this.Active
                error("KSSOLV:Remote:MfaAuthenticationNotActive", ...
                    "No multifactor authentication is active.");
            end
            promptMessage = lower(string(promptMessage));
            if isTotpPrompt(promptMessage)
                if this.Configuration.RememberTotpSecret && ...
                        strlength(this.Configuration. ...
                        EncryptedTotpSecret) > 0
                    secret = this.CredentialCipher.decrypt( ...
                        this.Configuration.EncryptedTotpSecret);
                    value = kssolv.services.remote.security.Totp.generate(secret);
                else
                    value = securePrompt(promptMessage);
                end
            elseif isPasswordPrompt(promptMessage)
                value = this.CredentialCipher.decrypt( ...
                    this.Configuration.EncryptedPassword);
            else
                value = securePrompt(promptMessage);
            end
        end

        function clear(this)
            this.Configuration = struct();
            this.CredentialCipher = [];
            this.Active = false;
        end
    end
end

function value = isTotpPrompt(prompt)
tokens = ["verification code", "verification", "one-time", ...
    "one time", "otp", "passcode", "authenticator", "token", ...
    "验证码", "动态码", "一次性"];
value = any(contains(prompt, tokens));
end

function value = isPasswordPrompt(prompt)
value = contains(prompt, "password") || contains(prompt, "密码");
end

function value = securePrompt(promptMessage)
if usejava("desktop")
    value = string(matlabshared.internal.sshaccess.solicitPassword( ...
        "KSSOLV Remote Computing", char(promptMessage)));
else
    value = string(matlabshared.internal.readPassword( ...
        char(promptMessage + " ")));
end
end
