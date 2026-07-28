classdef MolGraphSplitError < MException
    %MOLGRAPHSPLITERROR Molecule remained connected after requested cuts.
    methods
        function obj=MolGraphSplitError(message)
            if nargin<1,message="Cannot split molecule; MoleculeGraph is still connected.";end
            obj@MException("KSSOLV:Matgenlab:MolGraphSplitError",message);
        end
    end
end
