classdef PESScanSet < kssolv.analysis.matgenlab.io.qchem.QChemDictSet
    methods
        function obj = PESScanSet(molecule, scanVariables, varargin)
            obj@kssolv.analysis.matgenlab.io.qchem.QChemDictSet( ...
                molecule, "pes_scan", "def2-svpd", "diis", ...
                "scan_variables", scanVariables, varargin{:});
        end
    end
end
