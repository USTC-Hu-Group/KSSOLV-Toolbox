classdef MPStaticSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MPSTATICSET Materials Project static calculation inputs.
    methods
        function obj = MPStaticSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MPRelaxSet", "inherit_incar", true, ...
                varargin{:});
            obj.set_name = "MPStaticSet";
            obj.extra_incar_updates = struct("NSW",0,"ISMEAR",-5, ...
                "LCHARG",true,"LORBIT",11,"LREAL",false);
            obj.extra_kpoints_updates = struct( ...
                "reciprocal_density", obj.reciprocal_density);
        end
    end
end
