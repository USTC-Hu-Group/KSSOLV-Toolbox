classdef RemoteAccessFactory < handle
    %REMOTEACCESSFACTORY Create an authenticated SSH/file-transfer session.

    properties (Access = private)
        CredentialCache
        AccessCache
        CredentialProvider
        CredentialCipher
    end

    methods
        function this = RemoteAccessFactory(options)
            arguments
                options.CredentialProvider = []
                options.CredentialCipher = ...
                    kssolv.services.remote.security.LocalCredentialCipher()
            end
            this.CredentialCache = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            this.AccessCache = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            this.CredentialProvider = options.CredentialProvider;
            this.CredentialCipher = options.CredentialCipher;
        end

        function access = create(this, configuration)
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            if isempty(meta.class.fromName( ...
                    "parallel.cluster.RemoteClusterAccess"))
                error("KSSOLV:Remote:RemoteAccessUnavailable", ...
                    "This MATLAB release does not provide " + ...
                    "parallel.cluster.RemoteClusterAccess.");
            end
            argumentsList = {"AuthenticationMode", ...
                char(configuration.AuthenticationMode)};
            if configuration.AuthenticationMode == "IdentityFile"
                argumentsList = [argumentsList, {"IdentityFilename", ...
                    char(configuration.IdentityFile)}];
            end
            if any(configuration.ExecutionMode == ["Bridge", "Mirror"])
                % Bridge transfers protocol files explicitly and must not
                % attach a MATLAB JobStorage mirror to those files.
                key = char(configuration.Id);
                if isKey(this.AccessCache, key) && ...
                        isvalid(this.AccessCache(key))
                    access = this.AccessCache(key);
                else
                    savedMfa = configuration.AuthenticationMode == ...
                        "Multifactor" && strlength( ...
                        configuration.EncryptedPassword) > 0;
                    if configuration.AuthenticationMode == "Multifactor" && ...
                            ~savedMfa && ...
                            kssolv.services.remote.transport.OpenSshRemoteAccess. ...
                            isAvailable()
                        access = kssolv.services.remote.transport. ...
                            OpenSshRemoteAccess(configuration);
                    else
                        access = kssolv.services.remote.transport.SshRemoteAccess( ...
                            configuration, CredentialCipher= ...
                            this.CredentialCipher);
                    end
                    this.AccessCache(key) = access;
                end
            else
                access = parallel.cluster.RemoteClusterAccess. ...
                    getConnectedAccessWithMirror( ...
                    char(configuration.Host), ...
                    char(configuration.RemoteJobStorageLocation), ...
                    char(configuration.Username), argumentsList{:});
            end
            if any(configuration.ExecutionMode == ["Bridge", "Mirror"]) && ...
                    (strlength(configuration.PostLoginScript) > 0 || ...
                    configuration.PostLoginCommandTemplate ~= ...
                    "{command}" || ...
                    ~isempty(configuration.PostLoginPromptRules))
                access = kssolv.services.remote.transport.RemoteCommandAccess( ...
                    access, configuration, CredentialProvider= ...
                    @(value)this.getCredential(value));
            end
        end

        function access = createMatlabSessionAccess(this, configuration)
            %CREATEMATLABSESSIONACCESS SSH transport without Parallel Server.
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            required = ["Host", "Username", "ClusterMatlabRoot", ...
                "RemoteJobStorageLocation"];
            for name = required
                if strlength(string(configuration.(name))) == 0
                    error("KSSOLV:Remote:MatlabSessionConfigurationIncomplete", ...
                        "Remote Command Window requires %s.", name);
                end
            end
            key = char("matlab-session|" + configuration.Id);
            if isKey(this.AccessCache, key) && ...
                    isvalid(this.AccessCache(key))
                access = this.AccessCache(key);
            else
                savedMfa = configuration.AuthenticationMode == ...
                    "Multifactor" && strlength( ...
                    configuration.EncryptedPassword) > 0;
                if configuration.AuthenticationMode == "Multifactor" && ...
                        ~savedMfa && ...
                        kssolv.services.remote.transport. ...
                        OpenSshRemoteAccess.isAvailable()
                    access = kssolv.services.remote.transport. ...
                        OpenSshRemoteAccess(configuration);
                else
                    access = kssolv.services.remote.transport. ...
                        SshRemoteAccess(configuration, ...
                        CredentialCipher=this.CredentialCipher);
                end
                this.AccessCache(key) = access;
            end
            if strlength(configuration.PostLoginScript) > 0 || ...
                    configuration.PostLoginCommandTemplate ~= "{command}" || ...
                    ~isempty(configuration.PostLoginPromptRules)
                access = kssolv.services.remote.transport. ...
                    RemoteCommandAccess(access, configuration, ...
                    CredentialProvider=@(value)this.getCredential(value));
            end
        end

        function clearCredentials(this)
            keys = this.CredentialCache.keys;
            for index = 1:numel(keys)
                value = this.CredentialCache(keys{index});
                try
                    value(:) = char(0); %#ok<NASGU>
                catch
                end
            end
            if ~isempty(keys)
                remove(this.CredentialCache, keys);
            end
        end
    end

    methods (Access = private)
        function value = getCredential(this, configuration)
            key = char(configuration.Id);
            if isfield(configuration, "PromptRuleIndex")
                key = key + "|" + ...
                    string(configuration.PromptRuleIndex);
                key = char(key);
            end
            if isKey(this.CredentialCache, key)
                value = this.CredentialCache(key);
                return
            end
            if isempty(this.CredentialProvider)
                value = kssolv.services.remote.transport.RemoteCommandAccess. ...
                    promptCredential(configuration);
            else
                value = this.CredentialProvider(configuration);
            end
            value = string(value);
            this.CredentialCache(key) = value;
        end
    end
end
