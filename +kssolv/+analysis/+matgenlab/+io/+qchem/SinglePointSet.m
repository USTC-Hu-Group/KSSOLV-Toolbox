classdef SinglePointSet < kssolv.analysis.matgenlab.io.qchem.QChemDictSet
    methods
        function obj = SinglePointSet(molecule, varargin)
            obj@kssolv.analysis.matgenlab.io.qchem.QChemDictSet( ...
                molecule, "sp", "def2-tzvpd", "diis", varargin{:});
        end
    end
end
