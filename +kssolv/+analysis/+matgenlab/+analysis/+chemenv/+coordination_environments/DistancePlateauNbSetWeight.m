classdef DistancePlateauNbSetWeight < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.NbSetWeight
    properties
        distance_function struct=struct(type="normalized_distance")
        weight_function struct
        weight_rf
    end
    methods
        function obj=DistancePlateauNbSetWeight(varargin)
            opts=parseOptions(struct(distance_function=struct( ...
                type="normalized_distance"),weight_function=defaultWeight()), ...
                varargin{:});
            obj.distance_function=opts.distance_function;
            obj.weight_function=opts.weight_function;
            obj.weight_rf=kssolv.analysis.matgenlab.analysis.chemenv. ...
                utils.RatioFunction.from_dict(opts.weight_function);
        end
        function value=weight(obj,nbSet,varargin)
            value=obj.weight_rf.evaluate(nbSet.distance_plateau());
        end
        function value=as_dict(obj)
            value=makeDict("DistancePlateauNbSetWeight", ...
                obj.distance_function,obj.weight_function);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.DistancePlateauNbSetWeight( ...
                value.distance_function,value.weight_function);
        end
    end
end
function value=defaultWeight()
value=struct("function","inverse_smootherstep", ...
    options=struct(lower=.2,upper=.4));
end
function opts=parseOptions(opts,varargin)
names=fieldnames(opts);pos=1;
while pos<=numel(varargin)&&~(ischar(varargin{pos})||isstring(varargin{pos}))
    if ~isempty(varargin{pos}),opts.(names{pos})=varargin{pos};end;pos=pos+1;
end
for ii=pos:2:numel(varargin),if ~isempty(varargin{ii+1}), ...
        opts.(char(string(varargin{ii})))=varargin{ii+1};end,end
end
function value=makeDict(name,distance,weight)
value=struct(x_module="pymatgen.analysis.chemenv."+ ...
    "coordination_environments.chemenv_strategies",x_class=name, ...
    distance_function=distance,weight_function=weight);
end
