classdef RemoteSelectionStore < handle
    %REMOTESELECTIONSTORE Persist the selected KSSOLV remote target.

    properties (SetAccess = immutable)
        StorageRoot (1, 1) string
    end

    properties (Constant, Access = private)
        FileName = "selection-v1.json"
        FormatVersion = 1
    end

    methods
        function this = RemoteSelectionStore(storageRoot)
            arguments
                storageRoot (1, 1) string = ...
                    fullfile(prefdir, "KSSOLV", "remote")
            end
            this.StorageRoot = storageRoot;
        end

        function id = get(this, configurationStore)
            arguments
                this
                configurationStore = []
            end
            payload = kssolv.services.remote.internal.AtomicJsonFile.read( ...
                this.path(), struct("Version", this.FormatVersion, ...
                "ConfigurationId", ""));
            id = "";
            if isstruct(payload) && isscalar(payload) && ...
                    all(isfield(payload, ["Version", "ConfigurationId"])) && ...
                    double(payload.Version) == this.FormatVersion
                id = strip(string(payload.ConfigurationId));
            end
            if strlength(id) > 0 && ~isempty(configurationStore)
                try
                    configuration = configurationStore.get(id);
                    if ~configuration.Enabled
                        id = "";
                    end
                catch
                    id = "";
                end
                if strlength(id) == 0
                    this.set("");
                end
            end
        end

        function set(this, id)
            id = strip(string(id));
            if ~isscalar(id)
                error("KSSOLV:Remote:InvalidSelection", ...
                    "The selected remote configuration ID must be scalar.");
            end
            kssolv.services.remote.internal.AtomicJsonFile.write( ...
                this.path(), struct("Version", this.FormatVersion, ...
                "ConfigurationId", id));
        end

        function path = path(this)
            path = fullfile(this.StorageRoot, this.FileName);
        end
    end
end
