classdef MITNEBSet < kssolv.analysis.matgenlab.io.vasp.NEBSet
    %MITNEBSET MIT-configured nudged elastic band inputs.
    methods
        function obj = MITNEBSet(structures, varargin)
            obj@kssolv.analysis.matgenlab.io.vasp.NEBSet( ...
                structures, "parent_set", "MITRelaxSet", varargin{:});
            obj.set_name = "MITNEBSet";
            obj.config_dict = obj.load_config("MITRelaxSet");
        end
    end
end
