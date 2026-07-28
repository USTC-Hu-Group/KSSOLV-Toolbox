classdef COBICAR < kssolv.analysis.matgenlab.io.lobster.future.outputs.COXXCAR
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %COBICAR Crystal orbital bond-index reader.
    properties
        is_lcfo (1,1) logical = false
    end
    methods
        function obj = COBICAR(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.COXXCAR(varargin{:});
        end
        function name = get_default_filename(obj)
            if obj.is_lcfo, name = "COBICAR.LCFO.lobster";
            else, name = "COBICAR.lobster"; end
        end
    end
end
