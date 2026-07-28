classdef NciCobiList < ...
        kssolv.analysis.matgenlab.io.lobster.future.outputs.NcICOBILIST
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %NCICOBILIST Legacy multi-center ICOBI reader.
    properties (Dependent, SetAccess = private)
        ncicobi_list
    end
    methods
        function obj = NciCobiList(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                NcICOBILIST(varargin{:});
        end
        function value = get.ncicobi_list(obj)
            value = struct();
            for index = 1:numel(obj.interactions)
                value.(matlab.lang.makeValidName("x" + string(index))) = ...
                    obj.interactions{index};
            end
        end
    end
end
