classdef LobsterNeighbors
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERNEIGHBORS Compatibility marker for the relocated analysis class.
    methods
        function obj = LobsterNeighbors(varargin) %#ok<INUSD>
            warning("KSSOLV:Matgenlab:Lobster:Deprecated", ...
                "LobsterNeighbors moved to analysis.lobster_env.");
        end
    end
end
