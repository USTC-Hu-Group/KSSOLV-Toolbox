classdef ICOBILIST < kssolv.analysis.matgenlab.io.lobster.future.outputs.ICOXXLIST
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %ICOBILIST Integrated COBI list reader.
    methods
        function obj = ICOBILIST(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                ICOXXLIST(varargin{:});
            obj.icoxxlist_type = "COBI";
        end
        function name = get_default_filename(obj)
            if obj.is_lcfo, name = "ICOBILIST.LCFO.lobster";
            else, name = "ICOBILIST.lobster"; end
        end
    end
end
