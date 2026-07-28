classdef SimplestChemenvStrategy < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.AbstractChemenvStrategy
    %SIMPLESTCHEMENVSTRATEGY Fixed distance/angle cutoff strategy.
    properties (Constant)
        DEFAULT_DISTANCE_CUTOFF=1.4
        DEFAULT_ANGLE_CUTOFF=.3
        DEFAULT_CONTINUOUS_SYMMETRY_MEASURE_CUTOFF=10
        DEFAULT_ADDITIONAL_CONDITION=1
    end
    properties (Dependent)
        distance_cutoff
        angle_cutoff
        additional_condition
        continuous_symmetry_measure_cutoff
    end
    properties (Access=private)
        distance_cutoff_value
        angle_cutoff_value
        additional_condition_value
        csm_cutoff_value
    end
    methods
        function obj=SimplestChemenvStrategy(varargin)
            opts=parseOptions(varargin{:});
            obj@kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.AbstractChemenvStrategy( ...
                opts.structure_environments,"symmetry_measure_type", ...
                opts.symmetry_measure_type);
            obj.distance_cutoff=opts.distance_cutoff;
            obj.angle_cutoff=opts.angle_cutoff;
            obj.additional_condition=opts.additional_condition;
            obj.continuous_symmetry_measure_cutoff= ...
                opts.continuous_symmetry_measure_cutoff;
        end
        function value=get.distance_cutoff(obj)
            value=double(obj.distance_cutoff_value);
        end
        function set.distance_cutoff(obj,value)
            obj.distance_cutoff_value=kssolv.analysis.matgenlab.analysis. ...
                chemenv.coordination_environments.DistanceCutoffFloat(value);
        end
        function value=get.angle_cutoff(obj)
            value=double(obj.angle_cutoff_value);
        end
        function set.angle_cutoff(obj,value)
            obj.angle_cutoff_value=kssolv.analysis.matgenlab.analysis. ...
                chemenv.coordination_environments.AngleCutoffFloat(value);
        end
        function value=get.additional_condition(obj)
            value=double(obj.additional_condition_value);
        end
        function set.additional_condition(obj,value)
            obj.additional_condition_value=kssolv.analysis.matgenlab.analysis. ...
                chemenv.coordination_environments.AdditionalConditionInt(value);
        end
        function value=get.continuous_symmetry_measure_cutoff(obj)
            value=double(obj.csm_cutoff_value);
        end
        function set.continuous_symmetry_measure_cutoff(obj,value)
            obj.csm_cutoff_value=kssolv.analysis.matgenlab.analysis. ...
                chemenv.coordination_environments.CSMFloat(value);
        end
        function value=get_site_coordination_environment(obj,site,varargin)
            opts=parseNamed(struct(isite=[],dequivsite=[],dthissite=[], ...
                mysym=[],return_map=false),varargin{:});
            if isempty(opts.isite)
                [opts.isite,opts.dequivsite,opts.dthissite,opts.mysym]= ...
                    obj.equivalent_site_index_and_transform(site);
            end
            isite=opts.isite;v=obj.structure_environments.voronoi;
            dgroups=v.neighbors_normalized_distances{isite};
            agroups=v.neighbors_normalized_angles{isite};
            if ~iscell(dgroups)||~iscell(agroups)|| ...
                    isempty(dgroups)||isempty(agroups)
                value=[];return
            end
            id=find(cellfun(@(x)obj.distance_cutoff>=x.min,dgroups),1,"last");
            ia=find(cellfun(@(x)obj.angle_cutoff<=x.max,agroups),1,"last");
            if isempty(id)||isempty(ia)
                error("KSSOLV:Matgenlab:ChemEnv:StrategyParameter", ...
                    "Distance or angle parameter not found.");
            end
            cnMap=[];
            nbMaps=obj.structure_environments.neighbors_sets{isite};
            if isempty(nbMaps),value=[];return,end
            for cn=nbMaps.keys
                sets=nbMaps(cn{1});
                for inb=1:numel(sets)
                    for source=sets{inb}.sources
                        src=source{1};
                        if string(src.origin)=="dist_ang_ac_voronoi"&& ...
                                src.ac==obj.additional_condition&& ...
                                src.idp==id-1&&src.iap==ia-1
                            cnMap=[cn{1},inb];break
                        end
                    end
                    if ~isempty(cnMap),break,end
                end
                if ~isempty(cnMap),break,end
            end
            if isempty(cnMap),value=[];return,end
            mapped=obj.structure_environments.sites_map(isite);
            ceMap=obj.structure_environments.ce_list{mapped};
            if ~isKey(ceMap,cnMap(1)),value=[];return,end
            envs=ceMap(cnMap(1));
            if cnMap(2)>numel(envs)||isempty(envs{cnMap(2)})
                value=[];return
            end
            geom=envs{cnMap(2)}.minimum_geometry( ...
                "symmetry_measure_type",obj.symmetry_measure_type, ...
                "max_csm",obj.continuous_symmetry_measure_cutoff);
            if opts.return_map,value={geom,cnMap};else,value=geom;end
        end
        function value=get_site_coordination_environments_fractions( ...
                obj,site,varargin)
            opts=parseNamed(struct(isite=[],dequivsite=[],dthissite=[], ...
                mysym=[],ordered=true,min_fraction=0,return_maps=true, ...
                return_strategy_dict_info=false),varargin{:});
            if isempty(opts.isite)
                [opts.isite,opts.dequivsite,opts.dthissite,opts.mysym]= ...
                    obj.equivalent_site_index_and_transform(site);
            end
            pair=obj.get_site_coordination_environment(site, ...
                "isite",opts.isite,"dequivsite",opts.dequivsite, ...
                "dthissite",opts.dthissite,"mysym",opts.mysym, ...
                "return_map",true);
            if isempty(pair),value=[];return,end
            geometry=pair{1};map=pair{2};
            if isempty(geometry)
                entry=struct(ce_symbol="UNKNOWN:"+map(1), ...
                    ce_dict=[],ce_fraction=1);
            else
                entry=struct(ce_symbol=geometry{1}, ...
                    ce_dict=geometry{2},ce_fraction=1);
            end
            if opts.return_maps,entry.ce_map=map;end
            if opts.return_strategy_dict_info,entry.strategy_info=struct();end
            value={entry};
        end
        function value=get_site_coordination_environments(obj,site,varargin)
            value={obj.get_site_coordination_environment(site,varargin{:})};
        end
        function value=get_site_neighbors(obj,site,varargin)
            opts=parseNamed(struct(isite=[],dequivsite=[],dthissite=[], ...
                mysym=[]),varargin{:});
            if isempty(opts.isite)
                [opts.isite,opts.dequivsite,opts.dthissite,opts.mysym]= ...
                    obj.equivalent_site_index_and_transform(site);
            end
            pair=obj.get_site_coordination_environment(site, ...
                "isite",opts.isite,"dequivsite",opts.dequivsite, ...
                "dthissite",opts.dthissite,"mysym",opts.mysym, ...
                "return_map",true);
            if isempty(pair),value={};return,end
            map=pair{2};sets=obj.structure_environments. ...
                neighbors_sets{opts.isite}(map(1));
            sites=sets{map(2)}.neighb_sites;value=cell(size(sites));
            for ii=1:numel(sites)
                frac=opts.mysym.operate(sites{ii}.frac_coords+ ...
                    opts.dequivsite)+opts.dthissite;
                value{ii}=kssolv.analysis.matgenlab.core.PeriodicSite( ...
                    sites{ii}.species,frac,sites{ii}.lattice);
            end
        end
        function add_strategy_visualization_to_subplot(obj,subplot,varargin)
            plot(subplot,obj.distance_cutoff,obj.angle_cutoff,"ow", ...
                "MarkerSize",12);plot(subplot,obj.distance_cutoff, ...
                obj.angle_cutoff,"x","LineWidth",2,"MarkerSize",12);
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.chemenv_strategies", ...
                x_class="SimplestChemenvStrategy", ...
                distance_cutoff=obj.distance_cutoff, ...
                angle_cutoff=obj.angle_cutoff, ...
                additional_condition=obj.additional_condition, ...
                continuous_symmetry_measure_cutoff= ...
                obj.continuous_symmetry_measure_cutoff, ...
                symmetry_measure_type=obj.symmetry_measure_type);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.SimplestChemenvStrategy( ...
                "distance_cutoff",value.distance_cutoff, ...
                "angle_cutoff",value.angle_cutoff, ...
                "additional_condition",value.additional_condition, ...
                "continuous_symmetry_measure_cutoff", ...
                value.continuous_symmetry_measure_cutoff, ...
                "symmetry_measure_type",value.symmetry_measure_type);
        end
    end
end
function opts=parseOptions(varargin)
opts=struct(structure_environments=[],distance_cutoff=1.4, ...
    angle_cutoff=.3,additional_condition=1, ...
    continuous_symmetry_measure_cutoff=10, ...
    symmetry_measure_type="csm_wcs_ctwcc");
opts=parseNamed(opts,varargin{:});
end
function opts=parseNamed(opts,varargin)
names=fieldnames(opts);pos=1;
while pos<=numel(varargin)&&~(ischar(varargin{pos})||isstring(varargin{pos}))
    opts.(names{pos})=varargin{pos};pos=pos+1;
end
for ii=pos:2:numel(varargin),opts.(char(string(varargin{ii})))=varargin{ii+1};end
end
