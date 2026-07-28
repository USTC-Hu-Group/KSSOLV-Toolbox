classdef Lobsterin < kssolv.analysis.matgenlab.io.lobster.future.LobsterIn
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERIN Legacy spelling of LobsterIn.
    methods
        function obj = Lobsterin(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterIn(varargin{:});
        end
    end
    methods (Static)
        function obj = from_file(path)
            modern = kssolv.analysis.matgenlab.io.lobster.future.LobsterIn.from_file(path);
            obj = kssolv.analysis.matgenlab.io.lobster.Lobsterin(modern.data);
        end
        function obj = from_dict(value)
            modern = kssolv.analysis.matgenlab.io.lobster.future.LobsterIn.from_dict(value);
            obj = kssolv.analysis.matgenlab.io.lobster.Lobsterin(modern.data);
        end
    end
end
