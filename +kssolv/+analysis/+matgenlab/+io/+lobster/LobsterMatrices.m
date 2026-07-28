classdef LobsterMatrices < ...
        kssolv.analysis.matgenlab.io.lobster.future.outputs.LobsterMatrices
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERMATRICES Legacy matrix-reader interface.
    methods
        function obj = LobsterMatrices(e_fermi, filename)
            blank = nargin == 0;
            if blank, e_fermi = []; end
            if nargin < 1, e_fermi = []; end
            if nargin < 2 || isempty(filename), filename = "hamiltonMatrices.lobster"; end
            if blank, constructorArguments = {};
            else, constructorArguments = {filename, [], e_fermi}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                LobsterMatrices(constructorArguments{:});
        end
    end
end
