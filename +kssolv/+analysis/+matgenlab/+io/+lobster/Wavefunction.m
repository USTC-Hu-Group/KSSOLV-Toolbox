classdef Wavefunction < ...
        kssolv.analysis.matgenlab.io.lobster.future.outputs.Wavefunction
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %WAVEFUNCTION Legacy wave-function reader.
    methods
        function obj = Wavefunction(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                Wavefunction(varargin{:});
        end
    end
end
