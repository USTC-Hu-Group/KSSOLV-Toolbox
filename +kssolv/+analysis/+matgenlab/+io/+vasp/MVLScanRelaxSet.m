classdef MVLScanRelaxSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MVLSCANRELAXSET Legacy SCAN relaxation inputs.
    methods
        function obj = MVLScanRelaxSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MPRelaxSet", ...
                "user_potcar_functional","PBE_52", varargin{:});
            obj.set_name = "MVLScanRelaxSet";
            obj.extra_incar_updates = struct("ADDGRID",true, ...
                "EDIFF",1e-5,"EDIFFG",-0.05,"LASPH",true, ...
                "LDAU",false,"METAGGA","SCAN","NELM",200);
        end
    end
end
