classdef COHPCAR < kssolv.analysis.matgenlab.io.lobster.future.outputs.COXXCAR
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %COHPCAR Crystal orbital Hamilton population reader.
    properties
        is_lcfo (1,1) logical = false
    end
    methods
        function obj = COHPCAR(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.COXXCAR(varargin{:});
        end
        function name = get_default_filename(obj)
            if obj.is_lcfo, name = "COHPCAR.LCFO.lobster";
            else, name = "COHPCAR.lobster"; end
        end
    end
end
