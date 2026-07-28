classdef COOPCAR < kssolv.analysis.matgenlab.io.lobster.future.outputs.COXXCAR
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %COOPCAR Crystal orbital overlap population reader.
    methods
        function obj = COOPCAR(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.COXXCAR(varargin{:});
        end
        function name = get_default_filename(~), name = "COOPCAR.lobster"; end
    end
end
