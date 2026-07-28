classdef AngleCutoffFloat < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.StrategyOption
    methods
        function obj=AngleCutoffFloat(value)
            if double(value)<0||double(value)>1
                error("KSSOLV:Matgenlab:ChemEnv:AngleCutoff", ...
                    "Angle cutoff should be between 0 and 1, got %g.",value);
            end
            obj@kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.StrategyOption(value);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.AngleCutoffFloat(value.value);
        end
    end
end
