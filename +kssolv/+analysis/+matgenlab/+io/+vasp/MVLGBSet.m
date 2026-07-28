classdef MVLGBSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MVLGBSET Grain-boundary relaxation inputs.
    methods
        function obj = MVLGBSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MPRelaxSet", varargin{:});
            obj.set_name = "MVLGBSet";
            obj.extra_incar_updates = struct("LCHARG",false,"NELM",60, ...
                "PREC","Normal","EDIFFG",-0.02,"ICHARG",0,"NSW",200, ...
                "EDIFF",1e-4,"ISMEAR",double(obj.is_metal),"LDAU",false);
            obj.extra_kpoints_updates = struct( ...
                "reciprocal_density",obj.k_product);
        end
    end
end
