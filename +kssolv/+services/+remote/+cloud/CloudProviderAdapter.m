classdef CloudProviderAdapter < handle
    %CLOUDPROVIDERADAPTER Discover and validate profile-backed cloud targets.

    properties (SetAccess = immutable)
        Provider (1, 1) string
        ManagementUrl (1, 1) string
    end

    methods
        function this = CloudProviderAdapter(provider, managementUrl)
            arguments
                provider (1, 1) string
                managementUrl (1, 1) string = ""
            end
            if ~any(provider == ...
                    kssolv.services.remote.config.RemoteConfiguration.CloudProviders)
                error("KSSOLV:Remote:InvalidCloudProvider", ...
                    "Unsupported cloud provider %s.", provider);
            end
            this.Provider = provider;
            this.ManagementUrl = managementUrl;
        end

        function profiles = discoverProfiles(~)
            names = string(parallel.listProfiles());
            template = struct("Name", "", "ClusterClass", "", ...
                "NumWorkers", NaN, "Description", "", ...
                "Available", false, "ErrorSummary", "");
            profiles = repmat(template, numel(names), 1);
            for index = 1:numel(names)
                profiles(index).Name = names(index);
                try
                    cluster = parcluster(names(index));
                    profiles(index).ClusterClass = string(class(cluster));
                    if isprop(cluster, "NumWorkers")
                        profiles(index).NumWorkers = ...
                            double(cluster.NumWorkers);
                    end
                    if isprop(cluster, "Description")
                        profiles(index).Description = ...
                            string(cluster.Description);
                    end
                    profiles(index).Available = true;
                catch exception
                    profiles(index).ErrorSummary = ...
                        string(exception.message);
                end
            end
        end

        function report = validateProfile(this, configuration)
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            if configuration.ExecutionMode ~= "Cloud" || ...
                    configuration.CloudProvider ~= this.Provider
                error("KSSOLV:Remote:CloudProviderMismatch", ...
                    "Configuration provider %s does not match adapter %s.", ...
                    configuration.CloudProvider, this.Provider);
            end
            profiles = this.discoverProfiles();
            match = find(string({profiles.Name}) == ...
                configuration.ExistingProfileName, 1);
            if isempty(match)
                error("KSSOLV:Remote:CloudProfileNotFound", ...
                    "Cloud cluster profile %s was not found.", ...
                    configuration.ExistingProfileName);
            end
            item = profiles(match);
            if ~item.Available
                error("KSSOLV:Remote:CloudProfileUnavailable", ...
                    "Cloud cluster profile %s is unavailable: %s", ...
                    item.Name, item.ErrorSummary);
            end
            report = struct( ...
                "Provider", this.Provider, ...
                "ProfileName", item.Name, ...
                "ClusterClass", item.ClusterClass, ...
                "NumWorkers", item.NumWorkers, ...
                "ClientMatlabRelease", string(version("-release")), ...
                "CloudResourceName", configuration.CloudResourceName, ...
                "CloudRegion", configuration.CloudRegion, ...
                "ValidatedAt", nowText());
        end
    end
end

function value = nowText()
value = string(datetime("now", "TimeZone", "UTC", ...
    "Format", "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"));
end
