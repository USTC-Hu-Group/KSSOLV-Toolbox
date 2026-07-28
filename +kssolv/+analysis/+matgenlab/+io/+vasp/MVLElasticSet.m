classdef MVLElasticSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MVLELASTICSET Finite-difference elastic tensor inputs.
    methods
        function obj = MVLElasticSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MPRelaxSet", varargin{:});
            obj.set_name = "MVLElasticSet";
            obj.extra_incar_updates = struct( ...
                "IBRION",6,"NFREE",2,"POTIM",0.015,"NPAR",[]);
        end
    end
end
