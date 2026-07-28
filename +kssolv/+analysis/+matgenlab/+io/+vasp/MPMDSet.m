classdef MPMDSet < kssolv.analysis.matgenlab.io.vasp.MITMDSet
    %MPMDSET Materials Project molecular-dynamics inputs.
    methods
        function obj = MPMDSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.MITMDSet( ...
                structure, varargin{:});
            obj.set_name = "MPMDSet";
            obj.config_dict = obj.load_config("MPRelaxSet");
            obj.extra_incar_updates = obj.md_updates(1e-5, "Normal");
            obj.extra_incar_updates.ADDGRID = true;
            obj.extra_incar_updates.MAGMOM = [];
        end
    end
end
