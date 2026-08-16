classdef CloudBackend < kssolv.services.remote.backend.StandardBackend
    %CLOUDBACKEND Cluster-profile-backed cloud execution.

    methods
        function this = CloudBackend(clusterFactory)
            arguments
                clusterFactory = kssolv.services.remote.cluster.ClusterFactory()
            end
            this@kssolv.services.remote.backend.StandardBackend( ...
                clusterFactory, "Cloud");
        end

        function report = validateConfiguration(~, configuration)
            provider = kssolv.services.remote.cloud.CloudProviderFactory. ...
                create(configuration.CloudProvider);
            report = provider.validateProfile(configuration);
        end

        function profiles = discoverProfiles(~, providerName)
            provider = kssolv.services.remote.cloud.CloudProviderFactory. ...
                create(providerName);
            profiles = provider.discoverProfiles();
        end

        function session = testConnection(this, configuration, bundleRoot)
            this.validateConfiguration(configuration);
            session = testConnection@kssolv.services.remote.backend. ...
                StandardBackend(this, configuration, bundleRoot);
        end

        function record = submitWorkflow(this, configuration, snapshot, ...
                record, bundleRoot)
            this.validateConfiguration(configuration);
            record = submitWorkflow@kssolv.services.remote.backend.StandardBackend( ...
                this, configuration, snapshot, record, bundleRoot);
        end

        function record = submitFunction(this, configuration, record, ...
                functionHandle, numberOfOutputs, inputs, options)
            arguments
                this
                configuration struct
                record struct
                functionHandle (1, 1) function_handle
                numberOfOutputs (1, 1) double
                inputs cell = {}
                options.PoolSize double = NaN
                options.AttachedFiles = strings(0, 1)
                options.AdditionalPaths = strings(0, 1)
            end
            this.validateConfiguration(configuration);
            record = submitFunction@kssolv.services.remote.backend.StandardBackend( ...
                this, configuration, record, functionHandle, ...
                numberOfOutputs, inputs, PoolSize=options.PoolSize, ...
                AttachedFiles=options.AttachedFiles, ...
                AdditionalPaths=options.AdditionalPaths);
        end
    end
end
