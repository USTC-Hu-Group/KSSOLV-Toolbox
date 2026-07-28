classdef FreqSet < kssolv.analysis.matgenlab.io.qchem.QChemDictSet
    methods
        function obj = FreqSet(molecule, varargin)
            obj@kssolv.analysis.matgenlab.io.qchem.QChemDictSet( ...
                molecule, "freq", "def2-tzvpd", "diis", varargin{:});
        end
    end
end
