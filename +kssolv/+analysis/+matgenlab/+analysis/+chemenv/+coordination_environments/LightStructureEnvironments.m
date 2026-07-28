%#ok<*ALIGN,*ISCL>
classdef LightStructureEnvironments < handle
    %LIGHTSTRUCTUREENVIRONMENTS Strategy-selected local environments.
    properties (Constant)
        DELTA_MAX_OXIDATION_STATE=.1
        DEFAULT_STATISTICS_FIELDS=["anion_list","anion_atom_list", ...
            "cation_list","cation_atom_list","neutral_list", ...
            "neutral_atom_list","atom_coordination_environments_present", ...
            "ion_coordination_environments_present", ...
            "fraction_atom_coordination_environments_present", ...
            "fraction_ion_coordination_environments_present", ...
            "coordination_environments_atom_present", ...
            "coordination_environments_ion_present"]
    end
    properties
        strategy
        statistics_dict=[]
        coordination_environments cell={}
        all_nbs_sites cell={}
        neighbors_sets cell={}
        structure
        valences="undefined"
        valences_origin=[]
    end
    properties (Dependent)
        uniquely_determines_coordination_environments
    end
    methods
        function obj=LightStructureEnvironments(strategy,varargin)
            if nargin==0,return,end
            opts=parseOptions(struct(coordination_environments=[], ...
                all_nbs_sites=[],neighbors_sets=[],structure=[], ...
                valences=[],valences_origin=[]),varargin{:});
            obj.strategy=strategy;obj.coordination_environments= ...
                opts.coordination_environments;
            obj.all_nbs_sites=opts.all_nbs_sites;
            obj.neighbors_sets=opts.neighbors_sets;obj.structure=opts.structure;
            obj.valences=opts.valences;obj.valences_origin=opts.valences_origin;
        end
        function setup_statistic_lists(obj)
            atomStats=containers.Map("KeyType","char","ValueType","any");
            ceStats=containers.Map("KeyType","char","ValueType","any");
            atomCounts=containers.Map("KeyType","char","ValueType","double");
            for isite=1:obj.structure.num_sites
                [species,occupancies]=obj.structure.sites{isite}.species.items();
                envs=obj.coordination_environments{isite};
                if isempty(envs),continue,end
                for isp=1:numel(species)
                    atom=char(species{isp}.symbol);occ=occupancies(isp);
                    if ~isKey(atomStats,atom)
                        atomStats(atom)=containers.Map("KeyType","char", ...
                            "ValueType","double");atomCounts(atom)=0;
                    end
                    atomCounts(atom)=atomCounts(atom)+occ;
                    atomMap=atomStats(atom);
                    for ii=1:numel(envs)
                        if isempty(envs{ii}.ce_fraction),continue,end
                        symbol=char(envs{ii}.ce_symbol);
                        atomMap(symbol)=mapGet(atomMap,symbol)+ ...
                            occ*envs{ii}.ce_fraction;
                        if ~isKey(ceStats,symbol)
                            ceStats(symbol)=containers.Map("KeyType","char", ...
                                "ValueType","double");
                        end
                        ceMap=ceStats(symbol);
                        ceMap(atom)=mapGet(ceMap,atom)+occ*envs{ii}.ce_fraction;
                        ceStats(symbol)=ceMap;
                    end
                    atomStats(atom)=atomMap;
                end
            end
            fractions=containers.Map("KeyType","char","ValueType","any");
            for key=atomStats.keys
                source=atomStats(key{1});
                target=containers.Map("KeyType","char","ValueType","double");
                for env=source.keys
                    target(env{1})=source(env{1})/atomCounts(key{1});
                end
                fractions(key{1})=target;
            end
            empty=containers.Map("KeyType","char","ValueType","double");
            obj.statistics_dict=struct(valences_origin=obj.valences_origin, ...
                anion_list=empty,anion_atom_list=empty,cation_list=empty, ...
                cation_atom_list=empty,neutral_list=empty, ...
                neutral_atom_list=empty, ...
                atom_coordination_environments_present=atomStats, ...
                coordination_environments_atom_present=ceStats, ...
                fraction_atom_coordination_environments_present=fractions, ...
                ion_coordination_environments_present=empty, ...
                fraction_ion_coordination_environments_present=empty, ...
                coordination_environments_ion_present=empty);
        end
        function value=get_site_info_for_specie_ce(obj,specie,ceSymbol)
            result=obj.get_site_info_for_specie_allces(specie);
            key=char(string(ceSymbol));
            if isKey(result,key),value=result(key);
            else,value=struct(isites=[],fractions=[],csms=[]);end
        end
        function value=get_site_info_for_specie_allces(obj,specie,varargin)
            opts=parseOptions(struct(min_fraction=0),varargin{:});
            value=containers.Map("KeyType","char","ValueType","any");
            element=string(specie.symbol);
            for isite=1:obj.structure.num_sites
                [species,~]=obj.structure.sites{isite}.species.items();
                if ~any(cellfun(@(x)x.symbol==element,species)),continue,end
                envs=obj.coordination_environments{isite};
                for ii=1:numel(envs)
                    env=envs{ii};
                    if env.ce_fraction<opts.min_fraction,continue,end
                    key=char(env.ce_symbol);
                    if isKey(value,key),data=value(key);
                    else,data=struct(isites=[],fractions=[],csms=[]);end
                    data.isites(end+1)=isite;
                    data.fractions(end+1)=env.ce_fraction;
                    data.csms(end+1)=env.csm;value(key)=data;
                end
            end
        end
        function value=get_statistics(obj,varargin)
            opts=parseOptions(struct(statistics_fields= ...
                obj.DEFAULT_STATISTICS_FIELDS,bson_compatible=false),varargin{:});
            if isempty(obj.statistics_dict),obj.setup_statistic_lists();end
            if string(opts.statistics_fields)=="ALL"
                fields=fieldnames(obj.statistics_dict);
            else,fields=cellstr(string(opts.statistics_fields));end
            value=struct();
            for ii=1:numel(fields)
                value.(fields{ii})=obj.statistics_dict.(fields{ii});
            end
        end
        function value=contains_only_one_anion_atom(obj,anionAtom)
            if isempty(obj.statistics_dict),obj.setup_statistic_lists();end
            map=obj.statistics_dict.anion_atom_list;
            value=map.Count==1&&isKey(map,char(string(anionAtom)));
        end
        function value=contains_only_one_anion(obj,anion)
            if isempty(obj.statistics_dict),obj.setup_statistic_lists();end
            map=obj.statistics_dict.anion_list;
            value=map.Count==1&&isKey(map,char(string(anion)));
        end
        function value=site_contains_environment(obj,isite,ceSymbol)
            isite=normalizeSite(isite,obj.structure.num_sites);
            envs=obj.coordination_environments{isite};
            value=~isempty(envs)&&any(cellfun(@(x) ...
                string(x.ce_symbol)==string(ceSymbol),envs));
        end
        function value=site_has_clear_environment(obj,isite,varargin)
            opts=parseOptions(struct(conditions=[]),varargin{:});
            isite=normalizeSite(isite,obj.structure.num_sites);
            envs=obj.coordination_environments{isite};
            if isempty(opts.conditions),value=numel(envs)==1;return,end
            fractions=cellfun(@(x)x.ce_fraction,envs);[~,best]=max(fractions);
            ce=envs{best};value=true;conditions=toCell(opts.conditions);
            for ii=1:numel(conditions)
                condition=conditions{ii};target=string(condition.target);
                if target=="ce_fraction"&&ce.ce_fraction<condition.minvalue
                    value=false;return
                elseif target=="csm"&&ce.csm>condition.maxvalue
                    value=false;return
                elseif target=="number_of_ces"&&numel(envs)>condition.maxnumber
                    value=false;return
                end
            end
        end
        function value=structure_has_clear_environments(obj,varargin)
            opts=parseOptions(struct(conditions=[],skip_none=true, ...
                skip_empty=false),varargin{:});value=true;
            for isite=1:obj.structure.num_sites
                envs=obj.coordination_environments{isite};
                if isempty(envs)
                    if opts.skip_none||opts.skip_empty,continue,end
                    value=false;return
                end
                if ~obj.site_has_clear_environment(isite, ...
                        "conditions",opts.conditions),value=false;return,end
            end
        end
        function value=clear_environments(obj,varargin)
            opts=parseOptions(struct(conditions=[]),varargin{:});value=strings(0);
            for isite=1:obj.structure.num_sites
                envs=obj.coordination_environments{isite};
                if isempty(envs)||~obj.site_has_clear_environment(isite, ...
                        "conditions",opts.conditions),continue,end
                fractions=cellfun(@(x)x.ce_fraction,envs);[~,best]=max(fractions);
                value(end+1)=envs{best}.ce_symbol; %#ok<AGROW>
            end
            value=unique(value);
        end
        function value=structure_contains_atom_environment( ...
                obj,atomSymbol,ceSymbol)
            value=false;
            for isite=1:obj.structure.num_sites
                [species,~]=obj.structure.sites{isite}.species.items();
                if any(cellfun(@(x)x.symbol==string(atomSymbol),species))&& ...
                        obj.site_contains_environment(isite,ceSymbol)
                    value=true;return
                end
            end
        end
        function value=environments_identified(obj)
            value=strings(0);
            for envs=obj.coordination_environments
                if isempty(envs{1}),continue,end
                value=[value,string(cellfun(@(x)x.ce_symbol,envs{1}, ...
                    "UniformOutput",false))]; %#ok<AGROW>
            end
            value=unique(value);
        end
        function value=get.uniquely_determines_coordination_environments(obj)
            if isobject(obj.strategy)&& ...
                    isprop(obj.strategy,"uniquely_determines_coordination_environments")
                value=obj.strategy.uniquely_determines_coordination_environments;
            else,value=true;end
        end
        function value=as_dict(obj)
            sites=cell(1,numel(obj.all_nbs_sites));
            for ii=1:numel(sites)
                sites{ii}=struct(site=obj.all_nbs_sites{ii}.site.as_dict(), ...
                    index=obj.all_nbs_sites{ii}.index-1, ...
                    image_cell=obj.all_nbs_sites{ii}.image_cell);
            end
            sets=cell(size(obj.neighbors_sets));
            for isite=1:numel(sets)
                if isempty(obj.neighbors_sets{isite}),sets{isite}=[];else
                    sets{isite}=cellfun(@(x)x.as_dict(), ...
                        obj.neighbors_sets{isite},"UniformOutput",false);
                end
            end
            ces=obj.coordination_environments;
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.structure_environments", ...
                x_class="LightStructureEnvironments", ...
                strategy=serializeStrategy(obj.strategy), ...
                structure=obj.structure.as_dict(), ...
                coordination_environments={ces},all_nbs_sites={sites}, ...
                neighbors_sets={sets},valences=obj.valences);
        end
    end
    methods (Static)
        function obj=from_structure_environments( ...
                strategy,structureEnvironments,varargin)
            opts=parseOptions(struct(valences=[],valences_origin=[]),varargin{:});
            if ismethod(strategy,"set_structure_environments")
                strategy.set_structure_environments(structureEnvironments);
            end
            structure=structureEnvironments.structure;n=structure.num_sites;
            ces=cell(1,n);sets=cell(1,n);allSites={};
            for isite=1:n
                if ~ismethod(strategy,"get_site_ce_fractions_and_neighbors")
                    continue
                end
                results=strategy.get_site_ce_fractions_and_neighbors( ...
                    structure.sites{isite},"strategy_info",true);
                for ii=1:numel(results)
                    result=results{ii};ced=result.ce_dict;
                    if isempty(ced),csm=[];permutation=[];
                    else,csm=ced.other_symmetry_measures.( ...
                            char(strategy.symmetry_measure_type)); ...
                            permutation=ced.permutation;end
                    ces{isite}{ii}=struct(ce_symbol=result.ce_symbol, ...
                        ce_fraction=result.ce_fraction,csm=csm, ...
                        permutation=permutation);
                    indices=[];
                    for jj=1:numel(result.neighbors)
                        nb=result.neighbors{jj};image=round(nb.site.frac_coords- ...
                            structure.sites{nb.index}.frac_coords);
                        index=find(cellfun(@(x)x.index==nb.index&& ...
                            isequal(x.image_cell,image),allSites),1);
                        if isempty(index)
                            allSites{end+1}=struct(site=nb.site,index=nb.index, ...
                                image_cell=image);index=numel(allSites); %#ok<AGROW>
                        end
                        indices(end+1)=index; %#ok<AGROW>
                    end
                    sets{isite}{ii}=kssolv.analysis.matgenlab.analysis. ...
                        chemenv.coordination_environments. ...
                        LightStructureEnvironmentsNeighborsSet( ...
                        structure,isite,allSites,indices);
                end
            end
            if isempty(opts.valences),opts.valences=structureEnvironments.valences;end
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.LightStructureEnvironments( ...
                strategy,"coordination_environments",ces, ...
                "all_nbs_sites",allSites,"neighbors_sets",sets, ...
                "structure",structure,"valences",opts.valences, ...
                "valences_origin",opts.valences_origin);
        end
        function obj=from_dict(value)
            structure=kssolv.analysis.matgenlab.core.Structure.from_dict( ...
                value.structure);allSites=cell(1,numel(value.all_nbs_sites));
            for ii=1:numel(allSites)
                raw=value.all_nbs_sites{ii};
                allSites{ii}=struct(site=kssolv.analysis.matgenlab.core. ...
                    PeriodicSite.from_dict(raw.site),index=raw.index+1, ...
                    image_cell=reshape(double(raw.image_cell),1,3));
            end
            sets=cell(size(value.neighbors_sets));
            for isite=1:numel(sets)
                raw=value.neighbors_sets{isite};
                if isempty(raw),continue,end
                if isstruct(raw),raw=num2cell(raw(:)).';end
                sets{isite}=cellfun(@(x)kssolv.analysis.matgenlab.analysis. ...
                    chemenv.coordination_environments. ...
                    LightStructureEnvironmentsNeighborsSet.from_dict( ...
                    x,structure,allSites),raw,"UniformOutput",false);
            end
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.LightStructureEnvironments( ...
                value.strategy,"coordination_environments", ...
                normalizeCes(value.coordination_environments), ...
                "all_nbs_sites",allSites,"neighbors_sets",sets, ...
                "structure",structure,"valences",value.valences);
        end
    end
end
function opts=parseOptions(opts,varargin)
names=fieldnames(opts);pos=1;
while pos<=numel(varargin)&&~(ischar(varargin{pos})||isstring(varargin{pos}))
    opts.(names{pos})=varargin{pos};pos=pos+1;
end
for ii=pos:2:numel(varargin),opts.(char(string(varargin{ii})))=varargin{ii+1};end
end
function value=normalizeSite(value,n)
value=double(value);if value==0,value=1;end
if value<1||value>n,error("KSSOLV:Matgenlab:Index","Invalid site index.");end
end
function value=mapGet(map,key)
if isKey(map,key),value=map(key);else,value=0;end
end
function value=toCell(input)
if iscell(input),value=input(:).';elseif isstruct(input), ...
        value=num2cell(input(:)).';else,value={input};end
end
function value=serializeStrategy(strategy)
if isobject(strategy)&&ismethod(strategy,"as_dict"),value=strategy.as_dict();
else,value=strategy;end
end
function value=normalizeCes(raw)
value=cell(size(raw));
for ii=1:numel(raw)
    item=raw{ii};
    if isempty(item),value{ii}=[];elseif iscell(item),value{ii}=item(:).';
    elseif isstruct(item),value{ii}=num2cell(item(:)).';end
end
end
