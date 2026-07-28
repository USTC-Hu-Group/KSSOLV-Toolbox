%#ok<*ALIGN>
classdef SimpleAbundanceChemenvStrategy < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.AbstractChemenvStrategy
    %SIMPLEABUNDANCECHEMENVSTRATEGY Select the largest cutoff-grid map.
    properties
        additional_condition (1,1) double=1
        surface_calculation_type struct=struct( ...
            distance_parameter={{"initial_normalized",[]}}, ...
            angle_parameter={{"initial_normalized",[]}})
    end
    methods
        function obj=SimpleAbundanceChemenvStrategy(varargin)
            opts=parseNamed(struct(structure_environments=[], ...
                additional_condition=1, ...
                symmetry_measure_type="csm_wcs_ctwcc"),varargin{:});
            obj@kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.AbstractChemenvStrategy( ...
                "structure_environments",opts.structure_environments, ...
                "symmetry_measure_type",opts.symmetry_measure_type);
            obj.additional_condition=opts.additional_condition;
        end
        function value=get_site_neighbors(obj,site,varargin)
            [isite,~,~,~]=obj.equivalent_site_index_and_transform(site);
            if ~isempty(varargin)
                opts=parseNamed(struct(isite=isite),varargin{:});
                isite=opts.isite;
            end
            map=obj.getMap(isite);
            if isempty(map),value={};return,end
            sets=obj.structure_environments.neighbors_sets{isite}(map(1));
            value=sets{map(2)}.neighb_sites;
        end
        function value=get_site_coordination_environment( ...
                obj,site,varargin)
            opts=parseNamed(struct(isite=[],dequivsite=[],dthissite=[], ...
                mysym=[],return_map=false),varargin{:});
            if isempty(opts.isite)
                [opts.isite,~,~,~]= ...
                    obj.equivalent_site_index_and_transform(site);
            end
            map=obj.getMap(opts.isite);
            if isempty(map),value=[];return,end
            ce=obj.environmentForMap(opts.isite,map);
            if isempty(ce),answer=map(1);
            else,answer=ce.minimum_geometry( ...
                    "symmetry_measure_type",obj.symmetry_measure_type);end
            if opts.return_map,value={answer,map};else,value=answer;end
        end
        function value=get_site_coordination_environments( ...
                obj,site,varargin)
            value={obj.get_site_coordination_environment(site,varargin{:})};
        end
        function value=get_site_coordination_environments_fractions( ...
                obj,site,varargin)
            opts=parseNamed(struct(isite=[],return_maps=true, ...
                return_strategy_dict_info=false),varargin{:});
            result=obj.get_site_coordination_environment(site, ...
                "isite",opts.isite,"return_map",true);
            if isempty(result),value={};return,end
            answer=result{1};map=result{2};
            if isnumeric(answer)
                entry=struct(ce_symbol="UNKNOWN:"+answer, ...
                    ce_dict=[],ce_fraction=1);
            else
                entry=struct(ce_symbol=answer{1},ce_dict=answer{2}, ...
                    ce_fraction=1);
            end
            if opts.return_maps,entry.ce_map=map;end
            if opts.return_strategy_dict_info
                entry.strategy_info=struct(surface_map=map);
            end
            value={entry};
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.chemenv_strategies", ...
                x_class="SimpleAbundanceChemenvStrategy", ...
                additional_condition=obj.additional_condition);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.SimpleAbundanceChemenvStrategy( ...
                "additional_condition",value.additional_condition);
        end
    end
    methods (Access=protected)
        function value=getMap(obj,isite)
            entries=obj.structure_environments.voronoi.maps_and_surfaces( ...
                isite,"surface_calculation_type", ...
                obj.surface_calculation_type,"max_dist",2, ...
                "additional_conditions",obj.additional_condition);
            value=[];best=-Inf;
            for ii=1:numel(entries)
                params=entries{ii}.parameters_indices;
                accepted=any(cellfun(@(x)x(3)==obj.additional_condition, ...
                    params));
                if accepted&&entries{ii}.surface>best
                    best=entries{ii}.surface;value=entries{ii}.map;
                end
            end
        end
        function value=environmentForMap(obj,isite,map)
            mapped=obj.structure_environments.sites_map(isite);
            ceMap=obj.structure_environments.ce_list{mapped};
            if isempty(ceMap)||~isKey(ceMap,map(1)),value=[];return,end
            values=ceMap(map(1));
            if map(2)>numel(values),value=[];else,value=values{map(2)};end
        end
    end
end
function opts=parseNamed(opts,varargin)
names=fieldnames(opts);pos=1;
while pos<=numel(varargin)&&~(ischar(varargin{pos})||isstring(varargin{pos}))
    if ~isempty(varargin{pos}),opts.(names{pos})=varargin{pos};end
    pos=pos+1;
end
for ii=pos:2:numel(varargin)
    opts.(char(string(varargin{ii})))=varargin{ii+1};
end
end
