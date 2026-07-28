classdef BWDFCOHP < kssolv.analysis.matgenlab.io.lobster.future.outputs.BWDF
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %BWDFCOHP COHP-weighted bond-distribution reader.
    methods
        function obj = BWDFCOHP(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.BWDF(varargin{:});
        end
        function name = get_default_filename(~), name = "BWDFCOHP.lobster"; end
    end
end
