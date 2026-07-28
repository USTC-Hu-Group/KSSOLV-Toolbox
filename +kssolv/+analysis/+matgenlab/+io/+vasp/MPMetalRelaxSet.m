classdef MPMetalRelaxSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MPMETALRELAXSET Dense-k-mesh MP relaxation inputs for metals.
    methods
        function obj = MPMetalRelaxSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MPRelaxSet", varargin{:});
            obj.set_name = "MPMetalRelaxSet";
            obj.extra_incar_updates = struct("ISMEAR",1,"SIGMA",0.2);
            obj.extra_kpoints_updates = struct("reciprocal_density",200);
        end
    end
end
