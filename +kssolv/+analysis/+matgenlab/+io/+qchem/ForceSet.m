classdef ForceSet < kssolv.analysis.matgenlab.io.qchem.QChemDictSet
    methods
        function obj = ForceSet(molecule, varargin)
            obj@kssolv.analysis.matgenlab.io.qchem.QChemDictSet( ...
                molecule, "force", "def2-tzvpd", "diis", varargin{:});
        end
    end
end
