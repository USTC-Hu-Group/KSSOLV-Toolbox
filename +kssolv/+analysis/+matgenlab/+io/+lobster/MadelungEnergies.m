classdef MadelungEnergies < ...
        kssolv.analysis.matgenlab.io.lobster.future.outputs.MadelungEnergies
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %MADELUNGENERGIES Legacy Madelung-energy interface.
    properties (Dependent, SetAccess = private)
        madelungenergies_Loewdin
        madelungenergies_Mulliken
    end
    methods
        function obj = MadelungEnergies(filename, splitting, mulliken, loewdin)
            blank = nargin == 0;
            if blank, filename = []; end
            if nargin < 1 || isempty(filename), filename = "MadelungEnergies.lobster"; end
            useValues = nargin >= 2 && ~isempty(splitting);
            if blank, constructorArguments = {};
            else, constructorArguments = {filename, false}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                MadelungEnergies(constructorArguments{:});
            if blank, return; end
            if useValues
                obj.ewald_splitting = splitting;
                obj.madelung_energies_mulliken = mulliken;
                obj.madelung_energies_loewdin = loewdin;
            else, obj.parse_file(); end
        end
        function value = get.madelungenergies_Loewdin(obj)
            value = obj.madelung_energies_loewdin;
        end
        function value = get.madelungenergies_Mulliken(obj)
            value = obj.madelung_energies_mulliken;
        end
    end
end
