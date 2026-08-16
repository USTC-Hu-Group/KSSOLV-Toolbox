classdef RoutedRemoteClusterAccess < parallel.cluster.RemoteClusterAccess
    %ROUTEDREMOTECLUSTERACCESS Route Slurm control commands after SSH login.
    %
    % This remains a RemoteClusterAccess subclass so the MathWorks Slurm
    % plugin can use its supported file-mirroring lifecycle.  Only
    % runCommand is overridden; file transfer still terminates on the login
    % host and the configured workspace must be visible from the routed
    % target.

    properties (SetAccess = immutable)
        Configuration struct
    end

    properties (Access = private)
        Router
        CredentialCache
    end

    methods (Static)
        function access = getConnected(configuration)
            persistent cache
            if isempty(cache) || ~isvalid(cache)
                cache = containers.Map("KeyType", "char", ...
                    "ValueType", "any");
            end
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            key = char(configuration.Id + "|" + ...
                configuration.RemoteJobStorageLocation);
            if isKey(cache, key)
                candidate = cache(key);
                if isvalid(candidate) && candidate.IsConnected
                    access = candidate;
                    return
                end
                remove(cache, key);
            end
            access = kssolv.services.remote.cluster.RoutedRemoteClusterAccess( ...
                configuration);
            cache(key) = access;
        end
    end

    methods
        function this = RoutedRemoteClusterAccess(configuration)
            arguments
                configuration struct
            end
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            parentArguments = {"AuthenticationMode", ...
                char(configuration.AuthenticationMode)};
            if configuration.AuthenticationMode == "IdentityFile"
                parentArguments = [parentArguments, ...
                    {"IdentityFilename", char(configuration.IdentityFile)}];
            end
            this@parallel.cluster.RemoteClusterAccess( ...
                char(configuration.Username), parentArguments{:});
            this.Configuration = configuration;
            this.CredentialCache = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            % Always enable the remote file endpoint.  The scheduler plugin
            % uses it only for non-shared jobs; the interactive credential
            % exchange uses it in both storage topologies.
            connect(this, char(configuration.Host), ...
                char(configuration.RemoteJobStorageLocation));
            delegate = ...
                kssolv.services.remote.cluster.RoutedRemoteClusterDelegate(this);
            this.Router = kssolv.services.remote.transport.RemoteCommandAccess( ...
                delegate, configuration, CredentialProvider= ...
                @(value)this.getCredential(value));
            this.Router.verifyWorkspaceVisibility( ...
                configuration.RemoteJobStorageLocation);
        end

        function [status, output] = runCommand( ...
                this, command, bypassRouting)
            arguments
                this
                command
                bypassRouting (1, 1) logical = false
            end
            if bypassRouting
                [status, output] = ...
                    runCommand@parallel.cluster.RemoteClusterAccess( ...
                    this, command);
            else
                [status, output] = this.Router.runCommand(command);
            end
        end

        function varargout = copyFileToRemote( ...
                this, source, destination)
            [varargout{1:nargout}] = ...
                copyFileToRemote@parallel.cluster.RemoteClusterAccess( ...
                this, source, destination);
        end

        function varargout = copyFileFromRemote( ...
                this, source, destination)
            [varargout{1:nargout}] = ...
                copyFileFromRemote@parallel.cluster.RemoteClusterAccess( ...
                this, source, destination);
        end

        function remoteDelete(this, path)
            remoteDelete@parallel.cluster.RemoteClusterAccess(this, path);
        end

        function delete(this)
            this.clearCredentials();
            delete@parallel.cluster.RemoteClusterAccess(this);
        end
    end

    methods (Access = private)
        function value = getCredential(this, configuration)
            suffix = "1";
            if isfield(configuration, "PromptRuleIndex")
                suffix = string(configuration.PromptRuleIndex);
            end
            key = char(configuration.Id + "|" + suffix);
            if isKey(this.CredentialCache, key)
                value = this.CredentialCache(key);
                return
            end
            value = kssolv.services.remote.transport.RemoteCommandAccess. ...
                promptCredential(configuration);
            this.CredentialCache(key) = string(value);
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
end
