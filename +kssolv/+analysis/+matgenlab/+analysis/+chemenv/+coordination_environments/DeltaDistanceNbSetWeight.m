%#ok<*ISMT>
classdef DeltaDistanceNbSetWeight < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.DistanceNbSetWeight
    methods
        function obj=DeltaDistanceNbSetWeight(varargin)
            if isempty(varargin)
                varargin={struct("function","smootherstep", ...
                    options=struct(lower=.1,upper=.2)),"voronoi"};
            end
            obj@kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.DistanceNbSetWeight(varargin{:});
        end
        function value=weight(obj,nbSet,se,varargin)
            entries=se.voronoi.voronoi_list2{nbSet.isite};
            candidates=setdiff(1:numel(entries),nbSet.site_voronoi_indices);
            if isempty(candidates),value=1;return,end
            other=min(cellfun(@(i)entries{i}.normalized_distance, ...
                num2cell(candidates)));
            if length(nbSet)==0,value=0;return,end
            value=obj.weight_rf.evaluate(other-max(nbSet.normalized_distances));
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.chemenv_strategies", ...
                x_class="DeltaDistanceNbSetWeight", ...
                weight_function=obj.weight_function,nbs_source=obj.nbs_source);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.DeltaDistanceNbSetWeight( ...
                value.weight_function,value.nbs_source);
        end
    end
end
