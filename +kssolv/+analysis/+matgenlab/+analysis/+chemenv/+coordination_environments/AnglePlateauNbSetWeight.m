classdef AnglePlateauNbSetWeight < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.NbSetWeight
    properties
        angle_function struct=struct(type="normalized_angle")
        weight_function struct
        weight_rf
    end
    methods
        function obj=AnglePlateauNbSetWeight(varargin)
            opts=parseOptions(struct(angle_function=struct( ...
                type="normalized_angle"),weight_function=struct( ...
                "function","inverse_smootherstep", ...
                options=struct(lower=.05,upper=.15))),varargin{:});
            obj.angle_function=opts.angle_function;
            obj.weight_function=opts.weight_function;
            obj.weight_rf=kssolv.analysis.matgenlab.analysis.chemenv. ...
                utils.RatioFunction.from_dict(opts.weight_function);
        end
        function value=weight(obj,nbSet,varargin)
            value=obj.weight_rf.evaluate(nbSet.angle_plateau());
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.chemenv_strategies", ...
                x_class="AnglePlateauNbSetWeight", ...
                angle_function=obj.angle_function, ...
                weight_function=obj.weight_function);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.AnglePlateauNbSetWeight( ...
                value.angle_function,value.weight_function);
        end
    end
end
function opts=parseOptions(opts,varargin)
names=fieldnames(opts);pos=1;
while pos<=numel(varargin)&&~(ischar(varargin{pos})||isstring(varargin{pos}))
    if ~isempty(varargin{pos}),opts.(names{pos})=varargin{pos};end;pos=pos+1;
end
for ii=pos:2:numel(varargin),if ~isempty(varargin{ii+1}), ...
        opts.(char(string(varargin{ii})))=varargin{ii+1};end,end
end
