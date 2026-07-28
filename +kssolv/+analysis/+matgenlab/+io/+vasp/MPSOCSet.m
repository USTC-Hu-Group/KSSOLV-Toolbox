classdef MPSOCSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MPSOCSET Spin-orbit-coupled Materials Project static inputs.
    methods
        function obj = MPSOCSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MPRelaxSet", "inherit_incar", true, ...
                "copy_chgcar", true, varargin{:});
            obj.set_name = "MPSOCSet";
            obj.extra_incar_updates = struct("ISYM",-1,"LSORBIT",true, ...
                "ICHARG",11,"SAXIS",obj.saxis,"NSW",0,"ISMEAR",-5, ...
                "LCHARG",true,"LORBIT",11,"LREAL",false);
            if ~isempty(obj.magmom)
                obj.extra_incar_updates.MAGMOM = obj.magmom;
            end
            obj.extra_kpoints_updates = struct( ...
                "reciprocal_density",obj.reciprocal_density);
        end
    end
end
