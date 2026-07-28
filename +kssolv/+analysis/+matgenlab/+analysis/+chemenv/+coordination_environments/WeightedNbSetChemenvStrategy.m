classdef WeightedNbSetChemenvStrategy < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.AbstractChemenvStrategy
    %WEIGHTEDNBSETCHEMENVSTRATEGY Cascaded neighbor-set weights.
    properties
        additional_condition (1,1) double=1
        nb_set_weights cell={}
        ce_estimator struct
        ce_estimator_ratio_function
    end
    methods
        function obj=WeightedNbSetChemenvStrategy(varargin)
            opts=parseOptions(varargin{:});
            obj@kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.AbstractChemenvStrategy( ...
                opts.structure_environments,"symmetry_measure_type", ...
                opts.symmetry_measure_type);
            if isempty(opts.nb_set_weights)
                error("KSSOLV:Matgenlab:ChemEnv:Weights", ...
                    "nb_set_weights must be provided.");
            end
            obj.unique_value=false;
            obj.additional_condition=opts.additional_condition;
            obj.nb_set_weights=toCell(opts.nb_set_weights);
            obj.ce_estimator=opts.ce_estimator;
            obj.ce_estimator_ratio_function=kssolv.analysis.matgenlab. ...
                analysis.chemenv.utils.CSMInfiniteRatioFunction( ...
                opts.ce_estimator.("function"),opts.ce_estimator.options);
        end
        function value=get_site_coordination_environments_fractions( ...
                obj,site,varargin)
            opts=parseNamed(struct(isite=[],dequivsite=[],dthissite=[], ...
                mysym=[],ordered=true,min_fraction=0,return_maps=true, ...
                return_strategy_dict_info=false,return_all=false),varargin{:});
            if isempty(opts.isite)
                [opts.isite,opts.dequivsite,opts.dthissite,opts.mysym]= ...
                    obj.equivalent_site_index_and_transform(site);
            end
            maps=obj.structure_environments.neighbors_sets{opts.isite};
            if isempty(maps),value=[];return,end
            candidates={};products=[];details={};
            for cn=maps.keys
                sets=maps(cn{1});
                for ii=1:numel(sets)
                    product=1;info=struct();
                    for iw=1:numel(obj.nb_set_weights)
                        weight=obj.nb_set_weights{iw}.weight(sets{ii}, ...
                            obj.structure_environments,"cn_map",[cn{1},ii], ...
                            "additional_info",[]);
                        product=product*weight;
                        info.("weight_"+iw)=weight;
                        if product==0&&~opts.return_all,break,end
                    end
                    if product>0||opts.return_all
                        candidates{end+1}=[cn{1},ii]; %#ok<AGROW>
                        products(end+1)=product;details{end+1}=info; %#ok<AGROW>
                    end
                end
            end
            total=sum(products);if total==0,value={};return,end
            nbFractions=products/total;value={};
            for ic=1:numel(candidates)
                map=candidates{ic};envs=obj.structure_environments. ...
                    ce_list{opts.isite}(map(1));
                if map(2)>numel(envs)||isempty(envs{map(2)}),continue,end
                geoms=envs{map(2)}.minimum_geometries( ...
                    "symmetry_measure_type",obj.symmetry_measure_type);
                if isempty(geoms),continue,end
                csms=cellfun(@(x)x{2}.other_symmetry_measures. ...
                    (char(obj.symmetry_measure_type)),geoms);
                fractions=obj.ce_estimator_ratio_function.fractions(csms);
                for ig=1:numel(geoms)
                    fraction=nbFractions(ic)*fractions(ig);
                    if fraction<opts.min_fraction,continue,end
                    entry=struct(ce_symbol=geoms{ig}{1}, ...
                        ce_dict=geoms{ig}{2},ce_fraction=fraction);
                    if opts.return_maps,entry.ce_map=map;end
                    if opts.return_strategy_dict_info
                        info=details{ic};info.NbSetFraction=nbFractions(ic);
                        info.CEFraction=fractions(ig);info.Fraction=fraction;
                        entry.strategy_info=info;
                    end
                    value{end+1}=entry; %#ok<AGROW>
                end
            end
            if opts.ordered&&~isempty(value)
                [~,order]=sort(cellfun(@(x)x.ce_fraction,value),"descend");
                value=value(order);
            end
        end
        function value=get_site_coordination_environment(obj,site,varargin)
            values=obj.get_site_coordination_environments_fractions( ...
                site,varargin{:});
            if isempty(values),value=[];else,value={values{1}.ce_symbol, ...
                    values{1}.ce_dict};end
        end
        function value=get_site_neighbors(obj,site,varargin)
            opts=parseNamed(struct(isite=[]),varargin{:});
            if isempty(opts.isite),[opts.isite,~,~,~]= ...
                    obj.equivalent_site_index_and_transform(site);end
            values=obj.get_site_coordination_environments_fractions( ...
                site,"isite",opts.isite,"return_maps",true);
            if isempty(values),value={};return,end
            map=values{1}.ce_map;sets=obj.structure_environments. ...
                neighbors_sets{opts.isite}(map(1));
            value=sets{map(2)}.neighb_sites;
        end
        function value=get_site_coordination_environments(obj,site,varargin)
            fractions=obj.get_site_coordination_environments_fractions( ...
                site,varargin{:});
            value=cellfun(@(x){x.ce_symbol,x.ce_dict},fractions, ...
                "UniformOutput",false);
        end
        function value=as_dict(obj)
            weights=cellfun(@(x)x.as_dict(),obj.nb_set_weights, ...
                "UniformOutput",false);
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.chemenv_strategies", ...
                x_class="WeightedNbSetChemenvStrategy", ...
                additional_condition=obj.additional_condition, ...
                symmetry_measure_type=obj.symmetry_measure_type, ...
                nb_set_weights={weights},ce_estimator=obj.ce_estimator);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            weights=cellfun(@decodeWeight,toCell(value.nb_set_weights), ...
                "UniformOutput",false);
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.WeightedNbSetChemenvStrategy( ...
                "additional_condition",value.additional_condition, ...
                "symmetry_measure_type",value.symmetry_measure_type, ...
                "nb_set_weights",weights,"ce_estimator",value.ce_estimator);
        end
    end
end
function opts=parseOptions(varargin)
opts=struct(structure_environments=[],additional_condition=1, ...
    symmetry_measure_type="csm_wcs_ctwcc",nb_set_weights=[], ...
    ce_estimator=struct("function","power2_inverse_power2_decreasing", ...
    options=struct(max_csm=8)));
opts=parseNamed(opts,varargin{:});
end
function opts=parseNamed(opts,varargin)
names=fieldnames(opts);pos=1;
while pos<=numel(varargin)&&~(ischar(varargin{pos})||isstring(varargin{pos}))
    if ~isempty(varargin{pos}),opts.(names{pos})=varargin{pos};end;pos=pos+1;
end
for ii=pos:2:numel(varargin),opts.(char(string(varargin{ii})))=varargin{ii+1};end
end
function value=toCell(input)
if iscell(input),value=input(:).';elseif isstruct(input),value=num2cell(input(:)).';
else,value={input};end
end
function value=decodeWeight(data)
name=char(data.x_class);constructor=str2func("kssolv.analysis.matgenlab."+ ...
    "analysis.chemenv.coordination_environments."+name+".from_dict");
value=constructor(data);
end
