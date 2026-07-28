classdef MPNonSCFSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MPNONSCFSET Non-self-consistent DOS or band-structure inputs.
    methods
        function obj = MPNonSCFSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MPRelaxSet", "inherit_incar", true, ...
                "mode", "line", "copy_chgcar", true, varargin{:});
            obj.set_name = "MPNonSCFSet";
            obj.extra_incar_updates = struct("LCHARG",false,"LORBIT",11, ...
                "LWAVE",false,"NSW",0,"ISYM",0,"ICHARG",11, ...
                "ISMEAR",0,"SIGMA",0.2,"MAGMOM",[]);
            if lower(obj.mode) == "uniform"
                obj.extra_kpoints_updates = struct( ...
                    "reciprocal_density",obj.reciprocal_density);
            else
                obj.extra_kpoints_updates = struct( ...
                    "line_density",obj.kpoints_line_density);
            end
        end
    end
end
