classdef CNBiasNbSetWeight < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.NbSetWeight
    properties
        cn_weights
        initialization_options struct=struct()
    end
    methods
        function obj=CNBiasNbSetWeight(weights,options)
            obj.cn_weights=normalizeMap(weights);
            if nargin>1,obj.initialization_options=options;end
        end
        function value=weight(obj,nbSet,varargin)
            value=obj.cn_weights(length(nbSet));
        end
        function value=as_dict(obj)
            weights=struct();
            for key=obj.cn_weights.keys,weights.("x"+string(key{1}))= ...
                    obj.cn_weights(key{1});end
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.chemenv_strategies", ...
                x_class="CNBiasNbSetWeight",cn_weights=weights, ...
                initialization_options=obj.initialization_options);
        end
    end
    methods (Static)
        function obj=linearly_equidistant(first,last)
            values=linspace(first,last,13);
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.CNBiasNbSetWeight(values, ...
                struct(type="linearly_equidistant",weight_cn1=first, ...
                weight_cn13=last));
        end
        function obj=geometrically_equidistant(first,last)
            values=first*(last/first).^((0:12)/12);
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.CNBiasNbSetWeight(values, ...
                struct(type="geometrically_equidistant",weight_cn1=first, ...
                weight_cn13=last));
        end
        function obj=explicit(values)
            map=normalizeMap(values);
            if ~isequal(sort(cell2mat(map.keys)),1:13)
                error("KSSOLV:Matgenlab:ChemEnv:CNWeights", ...
                    "Weights must be provided for CN 1 through 13.");
            end
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.CNBiasNbSetWeight(map, ...
                struct(type="explicit"));
        end
        function obj=from_description(value)
            switch string(value.type)
                case "linearly_equidistant"
                    obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                        coordination_environments.CNBiasNbSetWeight. ...
                        linearly_equidistant(value.weight_cn1,value.weight_cn13);
                case "geometrically_equidistant"
                    obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                        coordination_environments.CNBiasNbSetWeight. ...
                        geometrically_equidistant(value.weight_cn1,value.weight_cn13);
                otherwise
                    obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                        coordination_environments.CNBiasNbSetWeight. ...
                        explicit(value.cn_weights);
            end
        end
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.CNBiasNbSetWeight( ...
                value.cn_weights,value.initialization_options);
        end
    end
end
function value=normalizeMap(input)
if isa(input,"containers.Map"),value=input;return,end
value=containers.Map("KeyType","double","ValueType","double");
if isnumeric(input)
    for ii=1:numel(input),value(ii)=input(ii);end
else
    names=fieldnames(input);
    for ii=1:numel(names)
        key=str2double(regexp(names{ii},'\d+','match','once'));
        value(key)=input.(names{ii});
    end
end
end
