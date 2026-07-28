classdef CSMFloat < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.StrategyOption
    methods
        function obj=CSMFloat(value)
            if double(value)<0||double(value)>100
                error("KSSOLV:Matgenlab:ChemEnv:CSMCutoff", ...
                    "Continuous symmetry measure limits should be between 0 and 100, got %g.",value);
            end
            obj@kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.StrategyOption(value);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.CSMFloat(value.value);
        end
    end
end
