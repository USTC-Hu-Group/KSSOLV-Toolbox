classdef RemoteConfigurationStore < handle
    %REMOTECONFIGURATIONSTORE Persistent collection of remote clusters.

    properties (SetAccess = immutable)
        StorageRoot (1, 1) string
    end

    properties (Constant, Access = private)
        FileName = "configurations-v2.json"
        LegacyFileName = "configurations-v1.json"
        FormatVersion = 2
    end

    methods
        function this = RemoteConfigurationStore(storageRoot)
            arguments
                storageRoot (1, 1) string = ...
                    fullfile(prefdir, "KSSOLV", "remote")
            end
            this.StorageRoot = storageRoot;
        end

        function configurations = list(this)
            empty = repmat( ...
                kssolv.services.remote.config.RemoteConfiguration.defaults(), ...
                0, 1);
            if ~isfile(this.path()) && isfile(this.legacyPath())
                configurations = this.migrateLegacy();
                return
            end
            payload = kssolv.services.remote.internal.AtomicJsonFile.read( ...
                this.path(), struct("Version", this.FormatVersion, ...
                "Configurations", empty));
            if ~isstruct(payload) || ~isscalar(payload) || ...
                    ~all(isfield(payload, ["Version", "Configurations"])) || ...
                    double(payload.Version) ~= this.FormatVersion
                warning("KSSOLV:Remote:UnsupportedConfigurationStore", ...
                    "Ignoring an unsupported remote configuration store.");
                configurations = empty;
                return
            end
            configurations = payload.Configurations;
            if isempty(configurations)
                configurations = empty;
                return
            end
            if iscell(configurations)
                configurations = [configurations{:}];
            end
            normalized = empty;
            for index = 1:numel(configurations)
                try
                    item = kssolv.services.remote.config.RemoteConfiguration. ...
                        sanitized(configurations(index));
                    normalized(end + 1, 1) = item; %#ok<AGROW>
                catch exception
                    warning("KSSOLV:Remote:InvalidStoredConfiguration", ...
                        "Skipping invalid remote configuration %d: %s", ...
                        index, exception.message);
                end
            end
            configurations = normalized;
        end

        function configuration = get(this, id)
            id = strip(string(id));
            configurations = this.list();
            matches = find(string({configurations.Id}) == id, 1);
            if isempty(matches)
                error("KSSOLV:Remote:ConfigurationNotFound", ...
                    "Remote configuration %s was not found.", id);
            end
            configuration = configurations(matches);
        end

        function save(this, configurations)
            if isempty(configurations)
                configurations = repmat( ...
                    kssolv.services.remote.config.RemoteConfiguration.defaults(), ...
                    0, 1);
            end
            if iscell(configurations)
                configurations = [configurations{:}];
            end
            normalized = repmat( ...
                kssolv.services.remote.config.RemoteConfiguration.defaults(), ...
                0, 1);
            ids = strings(0, 1);
            managedProfiles = strings(0, 1);
            for index = 1:numel(configurations)
                item = kssolv.services.remote.config.RemoteConfiguration. ...
                    sanitized(configurations(index));
                if any(ids == item.Id)
                    error("KSSOLV:Remote:DuplicateConfigurationId", ...
                        "Remote configuration ID %s is duplicated.", item.Id);
                end
                if item.ExecutionMode == "Standard" && ...
                        item.ProfileSource == "ManagedSlurm" && ...
                        any(managedProfiles == item.ManagedProfileName)
                    error("KSSOLV:Remote:DuplicateManagedProfile", ...
                        "Managed MATLAB profile %s is duplicated.", ...
                        item.ManagedProfileName);
                end
                ids(end + 1) = item.Id; %#ok<AGROW>
                if item.ExecutionMode == "Standard" && ...
                        item.ProfileSource == "ManagedSlurm"
                    managedProfiles(end + 1) = item.ManagedProfileName; %#ok<AGROW>
                end
                normalized(end + 1, 1) = item; %#ok<AGROW>
            end
            persisted = stripCompatibilityAliases(normalized);
            payload = struct("Version", this.FormatVersion, ...
                "Configurations", persisted);
            kssolv.services.remote.internal.AtomicJsonFile.write( ...
                this.path(), payload);
        end

        function configuration = upsert(this, configuration)
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            configurations = this.list();
            matches = find(string({configurations.Id}) == ...
                configuration.Id, 1);
            if isempty(matches)
                configurations(end + 1, 1) = configuration;
            else
                configurations(matches) = configuration;
            end
            this.save(configurations);
        end

        function configuration = duplicate(this, id)
            configuration = this.get(id);
            configuration.Id = ...
                kssolv.services.remote.config.RemoteConfiguration.newId();
            configuration.DisplayName = configuration.DisplayName + " Copy";
            configuration.ManagedProfileName = "";
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                create(configuration);
            this.upsert(configuration);
        end

        function removed = remove(this, id)
            id = strip(string(id));
            configurations = this.list();
            keep = string({configurations.Id}) ~= id;
            removed = any(~keep);
            if removed
                this.save(configurations(keep));
            end
        end

        function path = path(this)
            path = fullfile(this.StorageRoot, this.FileName);
        end
    end

    methods (Access = private)
        function configurations = migrateLegacy(this)
            empty = repmat( ...
                kssolv.services.remote.config.RemoteConfiguration.defaults(), ...
                0, 1);
            payload = kssolv.services.remote.internal.AtomicJsonFile.read( ...
                this.legacyPath(), ...
                struct("Version", 1, "Configurations", empty));
            if ~isstruct(payload) || ~isscalar(payload) || ...
                    ~all(isfield(payload, ["Version", "Configurations"])) || ...
                    double(payload.Version) ~= 1
                warning("KSSOLV:Remote:UnsupportedConfigurationStore", ...
                    "Ignoring an unsupported legacy remote " + ...
                    "configuration store.");
                configurations = empty;
                return
            end
            raw = payload.Configurations;
            if isempty(raw)
                configurations = empty;
            else
                if iscell(raw)
                    raw = [raw{:}];
                end
                configurations = empty;
                for index = 1:numel(raw)
                    try
                        item = kssolv.services.remote.config.RemoteConfiguration. ...
                            sanitized(raw(index));
                        configurations(end + 1, 1) = item; %#ok<AGROW>
                    catch exception
                        warning( ...
                            "KSSOLV:Remote:InvalidStoredConfiguration", ...
                            "Skipping invalid legacy remote " + ...
                            "configuration %d: %s", ...
                            index, exception.message);
                    end
                end
            end
            % save writes and verifies the v2 payload while leaving the v1
            % file untouched as the rollback copy.
            this.save(configurations);
        end

        function path = legacyPath(this)
            path = fullfile(this.StorageRoot, this.LegacyFileName);
        end
    end
end

function values = stripCompatibilityAliases(values)
aliases = {'SubmissionMode', 'RemoteBridgeExecutionMode', ...
    'RemoteCommandTemplate', 'RemotePromptPattern', ...
    'RemoteCredentialLabel'};
template = kssolv.services.remote.config.RemoteConfiguration.defaults();
persisted = repmat(template, 0, 1);
for index = 1:numel(values)
    item = values(index);
    present = aliases(isfield(item, aliases));
    if ~isempty(present)
        item = rmfield(item, present);
    end
    persisted(end + 1, 1) = item; %#ok<AGROW>
end
values = persisted;
end
