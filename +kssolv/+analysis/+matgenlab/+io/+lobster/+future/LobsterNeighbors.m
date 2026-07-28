classdef LobsterNeighbors < kssolv.analysis.matgenlab.io.lobster.LobsterNeighbors
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERNEIGHBORS Future-namespace compatibility marker.
    methods
        function obj = LobsterNeighbors(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.LobsterNeighbors(varargin{:});
        end
    end
end
