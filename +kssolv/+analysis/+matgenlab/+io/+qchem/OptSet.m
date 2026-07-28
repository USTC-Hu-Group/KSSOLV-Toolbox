classdef OptSet < kssolv.analysis.matgenlab.io.qchem.QChemDictSet
    methods
        function obj = OptSet(molecule, varargin)
            obj@kssolv.analysis.matgenlab.io.qchem.QChemDictSet( ...
                molecule, "opt", "def2-svpd", "diis", varargin{:});
        end
    end
end
