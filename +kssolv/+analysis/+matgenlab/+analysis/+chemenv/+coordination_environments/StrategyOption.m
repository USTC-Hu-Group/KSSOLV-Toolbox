classdef StrategyOption
    %STRATEGYOPTION Validated scalar ChemEnv strategy option.
    properties (SetAccess=protected)
        value (1,1) double=0
    end
    methods
        function obj=StrategyOption(value),if nargin>0,obj.value=double(value);end,end
        function value=double(obj),value=obj.value;end
        function value=eq(a,b),value=double(a)==double(b);end
        function value=as_dict(obj)
            parts=split(string(class(obj)),".");
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.chemenv_strategies", ...
                x_class=parts(end),value=double(obj));
        end
    end
end
