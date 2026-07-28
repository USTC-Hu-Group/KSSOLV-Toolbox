classdef DistanceCutoffFloat < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.StrategyOption
    methods
        function obj=DistanceCutoffFloat(value)
            if double(value)<1,error("KSSOLV:Matgenlab:ChemEnv:DistanceCutoff", ...
                    "Distance cutoff should be between 1 and +infinity.");end
            obj@kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.StrategyOption(value);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.DistanceCutoffFloat(value.value);
        end
    end
end
