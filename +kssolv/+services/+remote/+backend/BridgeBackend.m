classdef BridgeBackend < kssolv.services.remote.backend.RemoteBackend
    %BRIDGEBACKEND Remote MATLAB owns the Parallel Server job.

    properties (SetAccess = immutable)
        Bridge
    end

    methods
        function this = BridgeBackend(bridge, executionMode)
            arguments
                bridge = kssolv.services.remote.bridge.RemoteMatlabBridge()
                executionMode (1, 1) string = "Bridge"
            end
            this@kssolv.services.remote.backend.RemoteBackend(executionMode);
            this.Bridge = bridge;
        end

        function record = submitWorkflow(this, configuration, snapshot, ...
                record, bundleRoot)
            bundlePath = "";
            bundleManifest = struct();
            if configuration.CodeDeploymentMode == "AttachCurrentToolbox"
                [bundlePath, bundleManifest] = ...
                    kssolv.services.remote.execution.CodeBundleBuilder( ...
                    bundleRoot).build();
            end
            record.BundlePath = bundlePath;
            if ~isempty(fieldnames(bundleManifest))
                record.BundleContentHash = ...
                    string(bundleManifest.ContentIndexSha256);
            end
            record.MatlabProfileName = ...
                configuration.RemoteBridgeProfileName;
            try
                record = this.Bridge.submitWorkflow(configuration, ...
                    snapshot, record, bundlePath);
            catch exception
                removeArtifact(bundlePath);
                rethrow(exception)
            end
        end

        function record = refresh(this, configuration, record)
            record = this.Bridge.refresh(configuration, record);
        end

        function record = cancel(this, configuration, record)
            record = this.Bridge.cancel(configuration, record);
        end

        function [outputs, record] = fetch(this, configuration, record)
            [outputs, record] = this.Bridge.fetch(configuration, record);
        end

        function cleanup(this, configuration, record)
            this.Bridge.cleanupRemote(configuration, record);
        end

        function session = testConnection(this, configuration, ~)
            session = kssolv.services.remote.diagnostics. ...
                RemoteBridgeConnectionTestSession( ...
                configuration, this.Bridge);
        end
    end
end

function removeArtifact(path)
if strlength(string(path)) == 0
    return
end
if isfolder(path)
    rmdir(path, "s");
elseif isfile(path)
    delete(path);
end
end
