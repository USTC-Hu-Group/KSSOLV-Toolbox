classdef MVLNPTMDSet < kssolv.analysis.matgenlab.io.vasp.MITMDSet
    %MVLNPTMDSET Parrinello-Rahman NPT molecular-dynamics inputs.
    methods
        function obj = MVLNPTMDSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.MITMDSet( ...
                structure, varargin{:});
            obj.set_name = "MVLNPTMDSet";
            obj.extra_incar_updates = obj.md_updates(1e-6, "Low");
            obj.extra_incar_updates.MDIALGO = 3;
            obj.extra_incar_updates.ISIF = 3;
            obj.extra_incar_updates.LANGEVIN_GAMMA_L = 1;
            obj.extra_incar_updates.PMASS = 10;
        end
    end
end
