classdef DistanceNbSetWeight < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.NbSetWeight
    properties
        weight_function struct
        nbs_source (1,1) string="voronoi"
        weight_rf
    end
    methods
        function obj=DistanceNbSetWeight(varargin)
            opts=parseOptions(varargin{:});
            if ~ismember(string(opts.nbs_source),["nb_sets","voronoi"])
                error("KSSOLV:Matgenlab:ChemEnv:NeighborSource", ...
                    "nbs_source must be nb_sets or voronoi.");
            end
            obj.weight_function=opts.weight_function;
            obj.nbs_source=string(opts.nbs_source);
            obj.weight_rf=kssolv.analysis.matgenlab.analysis.chemenv. ...
                utils.RatioFunction.from_dict(opts.weight_function);
        end
        function value=weight(obj,nbSet,se,varargin)
            opts=parseNamed(struct(cn_map=[],additional_info=[]),varargin{:}); %#ok<NASGU>
            entries=se.voronoi.voronoi_list2{nbSet.isite};
            candidates=setdiff(1:numel(entries),nbSet.site_voronoi_indices);
            if isempty(candidates),value=1;return,end
            distance=min(cellfun(@(i)entries{i}.normalized_distance, ...
                num2cell(candidates)));
            value=obj.weight_rf.evaluate(distance);
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.chemenv_strategies", ...
                x_class="DistanceNbSetWeight", ...
                weight_function=obj.weight_function,nbs_source=obj.nbs_source);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.DistanceNbSetWeight( ...
                value.weight_function,value.nbs_source);
        end
    end
end
function opts=parseOptions(varargin)
opts=struct(weight_function=struct("function","smootherstep", ...
    options=struct(lower=1.2,upper=1.3)),nbs_source="voronoi");
opts=parseNamed(opts,varargin{:});
end
function opts=parseNamed(opts,varargin)
names=fieldnames(opts);pos=1;
while pos<=numel(varargin)&&~(ischar(varargin{pos})||isstring(varargin{pos}))
    if ~isempty(varargin{pos}),opts.(names{pos})=varargin{pos};end;pos=pos+1;
end
for ii=pos:2:numel(varargin),opts.(char(string(varargin{ii})))=varargin{ii+1};end
end
