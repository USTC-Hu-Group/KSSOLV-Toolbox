classdef ICOOPLIST < kssolv.analysis.matgenlab.io.lobster.future.outputs.ICOXXLIST
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %ICOOPLIST Integrated COOP list reader.
    methods
        function obj = ICOOPLIST(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                ICOXXLIST(varargin{:});
            obj.icoxxlist_type = "COOP";
        end
        function name = get_default_filename(~), name = "ICOOPLIST.lobster"; end
    end
end
