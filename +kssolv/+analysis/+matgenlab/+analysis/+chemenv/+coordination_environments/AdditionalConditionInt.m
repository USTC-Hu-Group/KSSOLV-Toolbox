classdef AdditionalConditionInt < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.StrategyOption
    methods
        function obj=AdditionalConditionInt(value)
            if double(value)~=fix(double(value))
                error("KSSOLV:Matgenlab:ChemEnv:AdditionalCondition", ...
                    "Additional condition %g is not an integer.",value);
            end
            if ~ismember(double(value),0:4)
                error("KSSOLV:Matgenlab:ChemEnv:AdditionalCondition", ...
                    "Additional condition %g is not allowed.",value);
            end
            obj@kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.StrategyOption(value);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.AdditionalConditionInt(value.value);
        end
    end
end
