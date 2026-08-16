classdef MirrorBackend < kssolv.services.remote.backend.BridgeBackend
    %MIRRORBACKEND Single-node execution in an ordinary remote MATLAB.

    methods
        function this = MirrorBackend(bridge)
            arguments
                bridge = kssolv.services.remote.bridge.RemoteMatlabBridge()
            end
            this@kssolv.services.remote.backend.BridgeBackend(bridge, "Mirror");
        end
    end
end
