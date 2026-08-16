classdef RemoteJobStore < handle
    %REMOTEJOBSTORE Persistent, resumable remote job journal.

    properties (SetAccess = immutable)
        StorageRoot (1, 1) string
    end

    properties (Constant, Access = private)
        FileName = "jobs-v2.json"
        LegacyFileName = "jobs-v1.json"
        FormatVersion = 2
    end

    methods
        function this = RemoteJobStore(storageRoot)
            arguments
                storageRoot (1, 1) string = ...
                    fullfile(prefdir, "KSSOLV", "remote")
            end
            this.StorageRoot = storageRoot;
        end

        function records = list(this)
            empty = repmat( ...
                kssolv.services.remote.job.RemoteJobRecord.create("x"), 0, 1);
            if ~isfile(this.path()) && isfile(this.legacyPath())
                records = this.migrateLegacy();
                return
            end
            payload = kssolv.services.remote.internal.AtomicJsonFile.read( ...
                this.path(), struct("Version", this.FormatVersion, ...
                "Jobs", empty));
            if ~isstruct(payload) || ~isscalar(payload) || ...
                    ~all(isfield(payload, ["Version", "Jobs"])) || ...
                    double(payload.Version) ~= this.FormatVersion
                warning("KSSOLV:Remote:UnsupportedJobStore", ...
                    "Ignoring an unsupported remote job store.");
                records = empty;
                return
            end
            records = payload.Jobs;
            if isempty(records)
                records = empty;
                return
            end
            if iscell(records)
                records = [records{:}];
            end
            normalized = empty;
            for index = 1:numel(records)
                try
                    item = kssolv.services.remote.job.RemoteJobRecord. ...
                        normalize(records(index));
                    kssolv.services.remote.job.RemoteJobRecord.validate(item);
                    normalized(end + 1, 1) = item; %#ok<AGROW>
                catch exception
                    warning("KSSOLV:Remote:InvalidStoredJob", ...
                        "Skipping invalid remote job %d: %s", ...
                        index, exception.message);
                end
            end
            records = normalized;
        end

        function record = get(this, localJobId)
            localJobId = strip(string(localJobId));
            records = this.list();
            match = find(string({records.LocalJobId}) == localJobId, 1);
            if isempty(match)
                error("KSSOLV:Remote:JobNotFound", ...
                    "Remote job %s was not found.", localJobId);
            end
            record = records(match);
        end

        function upsert(this, record)
            record = kssolv.services.remote.job.RemoteJobRecord.normalize(record);
            kssolv.services.remote.job.RemoteJobRecord.validate(record);
            records = this.list();
            match = find(string({records.LocalJobId}) == ...
                record.LocalJobId, 1);
            if isempty(match)
                records(end + 1, 1) = record;
            else
                records(match) = record;
            end
            this.save(records);
        end

        function removed = remove(this, localJobId)
            localJobId = strip(string(localJobId));
            records = this.list();
            keep = string({records.LocalJobId}) ~= localJobId;
            removed = any(~keep);
            if removed
                this.save(records(keep));
            end
        end

        function save(this, records)
            if isempty(records)
                records = repmat( ...
                    kssolv.services.remote.job.RemoteJobRecord.create("x"), ...
                    0, 1);
            end
            if iscell(records)
                records = [records{:}];
            end
            normalized = repmat( ...
                kssolv.services.remote.job.RemoteJobRecord.create("x"), 0, 1);
            ids = strings(0, 1);
            for index = 1:numel(records)
                item = kssolv.services.remote.job.RemoteJobRecord. ...
                    normalize(records(index));
                kssolv.services.remote.job.RemoteJobRecord.validate(item);
                if any(ids == item.LocalJobId)
                    error("KSSOLV:Remote:DuplicateJobId", ...
                        "Remote job ID %s is duplicated.", item.LocalJobId);
                end
                ids(end + 1) = item.LocalJobId; %#ok<AGROW>
                normalized(end + 1, 1) = item; %#ok<AGROW>
            end
            persisted = stripCompatibilityAliases(normalized);
            kssolv.services.remote.internal.AtomicJsonFile.write( ...
                this.path(), struct("Version", this.FormatVersion, ...
                "Jobs", persisted));
        end

        function path = path(this)
            path = fullfile(this.StorageRoot, this.FileName);
        end
    end

    methods (Access = private)
        function records = migrateLegacy(this)
            empty = repmat( ...
                kssolv.services.remote.job.RemoteJobRecord.create("x"), 0, 1);
            payload = kssolv.services.remote.internal.AtomicJsonFile.read( ...
                this.legacyPath(), struct("Version", 1, "Jobs", empty));
            if ~isstruct(payload) || ~isscalar(payload) || ...
                    ~all(isfield(payload, ["Version", "Jobs"])) || ...
                    double(payload.Version) ~= 1
                warning("KSSOLV:Remote:UnsupportedJobStore", ...
                    "Ignoring an unsupported legacy remote job store.");
                records = empty;
                return
            end
            configurations = ...
                kssolv.services.remote.config.RemoteConfigurationStore( ...
                this.StorageRoot).list();
            raw = payload.Jobs;
            records = empty;
            if ~isempty(raw)
                if iscell(raw)
                    raw = [raw{:}];
                end
                for index = 1:numel(raw)
                    try
                        item = applyConfigurationMode( ...
                            raw(index), configurations);
                        item = kssolv.services.remote.job.RemoteJobRecord. ...
                            normalize(item);
                        kssolv.services.remote.job.RemoteJobRecord.validate(item);
                        records(end + 1, 1) = item; %#ok<AGROW>
                    catch exception
                        warning("KSSOLV:Remote:InvalidStoredJob", ...
                            "Skipping invalid legacy remote job %d: %s", ...
                            index, exception.message);
                    end
                end
            end
            this.save(records);
        end

        function path = legacyPath(this)
            path = fullfile(this.StorageRoot, this.LegacyFileName);
        end
    end
end

function item = applyConfigurationMode(item, configurations)
mode = "";
provider = "";
if isfield(item, "ConfigurationId") && ~isempty(configurations)
    matches = find(string({configurations.Id}) == ...
        string(item.ConfigurationId), 1);
    if ~isempty(matches)
        mode = configurations(matches).ExecutionMode;
        item.ConfigurationSnapshot = configurations(matches);
        if mode == "Cloud"
            provider = configurations(matches).CloudProvider;
        end
    end
end
if strlength(mode) == 0
    mode = "Standard";
    if isfield(item, "SubmissionMode") && ...
            string(item.SubmissionMode) == "RemoteMatlabBridge"
        mode = "Bridge";
    end
end
item.ExecutionMode = mode;
item.CloudProvider = provider;
item.BackendProtocolVersion = 1;
end

function values = stripCompatibilityAliases(values)
template = kssolv.services.remote.job.RemoteJobRecord.create("x");
persisted = repmat(template, 0, 1);
for index = 1:numel(values)
    item = values(index);
    item.ConfigurationSnapshot = stripConfigurationAliases( ...
        item.ConfigurationSnapshot);
    if isfield(item, "SubmissionMode")
        item = rmfield(item, "SubmissionMode");
    end
    persisted(end + 1, 1) = item; %#ok<AGROW>
end
values = persisted;
end

function value = stripConfigurationAliases(value)
if ~isstruct(value) || isempty(value)
    return
end
aliases = {'SubmissionMode', 'RemoteBridgeExecutionMode', ...
    'RemoteCommandTemplate', 'RemotePromptPattern', ...
    'RemoteCredentialLabel'};
present = aliases(isfield(value, aliases));
if ~isempty(present)
    value = rmfield(value, present);
end
end
