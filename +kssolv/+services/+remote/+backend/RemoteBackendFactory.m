classdef RemoteBackendFactory < handle
    %REMOTEBACKENDFACTORY Resolve the durable backend for a configuration.

    properties (SetAccess = immutable)
        ClusterFactory
        Bridge
    end

    methods
        function this = RemoteBackendFactory(clusterFactory, bridge)
            arguments
                clusterFactory = kssolv.services.remote.cluster.ClusterFactory()
                bridge = kssolv.services.remote.bridge.RemoteMatlabBridge()
            end
            this.ClusterFactory = clusterFactory;
            this.Bridge = bridge;
        end

        function backend = create(this, configuration)
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            switch configuration.ExecutionMode
                case "Standard"
                    backend = kssolv.services.remote.backend.StandardBackend( ...
                        this.ClusterFactory);
                case "Bridge"
                    backend = kssolv.services.remote.backend.BridgeBackend( ...
                        this.Bridge);
                case "Mirror"
                    backend = kssolv.services.remote.backend.MirrorBackend( ...
                        this.Bridge);
                case "Cloud"
                    backend = kssolv.services.remote.backend.CloudBackend( ...
                        this.ClusterFactory);
                otherwise
                    error("KSSOLV:Remote:InvalidExecutionMode", ...
                        "Unsupported remote execution mode %s.", ...
                        configuration.ExecutionMode);
            end
        end
    end
end
