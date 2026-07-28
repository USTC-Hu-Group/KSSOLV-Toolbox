classdef TransitionStateSet < kssolv.analysis.matgenlab.io.qchem.QChemDictSet
    methods
        function obj = TransitionStateSet(molecule, varargin)
            obj@kssolv.analysis.matgenlab.io.qchem.QChemDictSet( ...
                molecule, "ts", "def2-svpd", "diis", varargin{:});
        end
    end
end
