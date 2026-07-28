classdef MPScanRelaxSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MPSCANRELAXSET Materials Project r2SCAN relaxation inputs.
    methods
        function obj = MPScanRelaxSet(structure, varargin)
            if nargin < 1, structure = []; end
            defaults = {"user_potcar_functional","PBE_54", ...
                "auto_kspacing",true,"auto_ismear",true};
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MPSCANRelaxSet", defaults{:}, varargin{:});
            obj.set_name = "MPScanRelaxSet";
        end
    end
end
