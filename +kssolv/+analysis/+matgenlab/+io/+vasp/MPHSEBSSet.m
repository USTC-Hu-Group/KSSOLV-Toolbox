classdef MPHSEBSSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MPHSEBSSET HSE band-structure calculation inputs.
    methods
        function obj = MPHSEBSSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MPHSERelaxSet", "mode", "gap", ...
                "copy_chgcar", true, "reciprocal_density", 50, ...
                varargin{:});
            obj.set_name = "MPHSEBSSet";
            obj.extra_incar_updates = struct("NSW",0,"ISMEAR",0, ...
                "SIGMA",0.01,"ISYM",3,"LCHARG",false,"NELMIN",5);
            obj.extra_kpoints_updates = struct( ...
                "reciprocal_density",obj.reciprocal_density);
        end
    end
end
