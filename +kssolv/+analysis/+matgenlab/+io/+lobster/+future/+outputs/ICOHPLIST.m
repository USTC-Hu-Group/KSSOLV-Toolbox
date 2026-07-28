classdef ICOHPLIST < kssolv.analysis.matgenlab.io.lobster.future.outputs.ICOXXLIST
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %ICOHPLIST Integrated COHP list reader.
    methods
        function obj = ICOHPLIST(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                ICOXXLIST(varargin{:});
            obj.icoxxlist_type = "COHP";
        end
        function name = get_default_filename(obj)
            if obj.is_lcfo, name = "ICOHPLIST.LCFO.lobster";
            else, name = "ICOHPLIST.lobster"; end
        end
    end
end
