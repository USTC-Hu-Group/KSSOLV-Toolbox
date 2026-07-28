classdef MPNMRSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MPNMRSET Materials Project chemical-shift or EFG inputs.
    methods
        function obj = MPNMRSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MPRelaxSet", "inherit_incar", true, ...
                "mode", "cs", varargin{:});
            obj.set_name = "MPNMRSet";
            common = struct("NSW",0,"ISMEAR",-5,"LCHARG",false, ...
                "LORBIT",11,"LREAL",false,"EDIFF",-1e-10,"ISYM",0, ...
                "NELMIN",10,"PREC","ACCURATE","SIGMA",0.01);
            if lower(obj.mode) == "efg"
                common.LEFG = true;
            else
                common.LCHIMAG = true;
                common.LNMR_SYM_RED = true;
                common.NLSPLINE = true;
            end
            obj.extra_incar_updates = common;
            obj.extra_kpoints_updates = struct( ...
                "reciprocal_density",obj.reciprocal_density);
        end
    end
end
