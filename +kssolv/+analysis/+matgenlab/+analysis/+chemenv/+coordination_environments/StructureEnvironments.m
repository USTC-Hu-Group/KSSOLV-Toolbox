%#ok<*ALIGN,*INUSD>
classdef StructureEnvironments < handle
    %STRUCTUREENVIRONMENTS Detailed chemical environments for a structure.
    properties
        voronoi
        valences
        sites_map
        equivalent_sites cell={}
        ce_list cell={}
        structure
        neighbors_sets cell={}
        info struct=struct()
    end
    methods
        function obj=StructureEnvironments(voronoi,valences,sitesMap, ...
                equivalentSites,ceList,structure,varargin)
            if nargin==0,return,end
            opts=parseOptions(struct(neighbors_sets=[],info=struct()),varargin{:});
            obj.voronoi=voronoi;obj.valences=valences;obj.sites_map=sitesMap;
            obj.equivalent_sites=equivalentSites;obj.ce_list=ceList;
            obj.structure=structure;obj.info=opts.info;
            if isempty(opts.neighbors_sets)
                obj.neighbors_sets=cell(1,structure.num_sites);
            else,obj.neighbors_sets=opts.neighbors_sets;end
        end
        function init_neighbors_sets(obj,isite,varargin)
            opts=parseOptions(struct(additional_conditions=0:4,valences=[]), ...
                varargin{:});
            isite=normalizeSite(isite,obj.structure.num_sites);
            entries=obj.voronoi.voronoi_list2{isite};
            if isempty(entries),return,end
            for id=1:numel(obj.voronoi.neighbors_normalized_distances{isite})
                dp=obj.voronoi.neighbors_normalized_distances{isite}{id};
                for ia=1:numel(obj.voronoi.neighbors_normalized_angles{isite})
                    ap=obj.voronoi.neighbors_normalized_angles{isite}{ia};
                    for ac=reshape(opts.additional_conditions,1,[])
                        indices=intersect(dp.nb_indices,ap.nb_indices);
                        source=struct(origin="dist_ang_ac_voronoi",idp=id-1, ...
                            iap=ia-1,dp_dict=dp,ap_dict=ap,iac=ac,ac=ac, ...
                            ac_name="Additional condition "+ac);
                        nb=kssolv.analysis.matgenlab.analysis.chemenv. ...
                            coordination_environments. ...
                            StructureEnvironmentsNeighborsSet(obj.structure, ...
                            isite,obj.voronoi,indices,"sources",source);
                        obj.add_neighbors_set(isite,nb);
                    end
                end
            end
        end
        function add_neighbors_set(obj,isite,nbSet)
            isite=normalizeSite(isite,obj.structure.num_sites);cn=length(nbSet);
            if isempty(obj.neighbors_sets{isite})
                obj.neighbors_sets{isite}=containers.Map( ...
                    "KeyType","double","ValueType","any");
                obj.ce_list{isite}=containers.Map("KeyType","double", ...
                    "ValueType","any");
            end
            map=obj.neighbors_sets{isite};ces=obj.ce_list{isite};
            if ~isKey(map,cn),map(cn)={};ces(cn)={};end
            sets=map(cn);index=find(cellfun(@(x)sameSet(x,nbSet),sets),1);
            if isempty(index),sets{end+1}=nbSet;items=ces(cn);items{end+1}=[]; ...
                    ces(cn)=items;
            else,sets{index}.add_source(nbSet.source);end
            map(cn)=sets;obj.neighbors_sets{isite}=map;obj.ce_list{isite}=ces;
        end
        function update_coordination_environments(obj,isite,cn,nbSet,ce)
            isite=normalizeSite(isite,obj.structure.num_sites);
            sets=obj.neighbors_sets{isite}(cn);
            index=find(cellfun(@(x)sameSet(x,nbSet),sets),1);
            if isempty(index),error("KSSOLV:Matgenlab:ChemEnv:NeighborsSet", ...
                    "Neighbors set not found.");end
            values=obj.ce_list{isite}(cn);values{index}=ce;
            obj.ce_list{isite}(cn)=values;
        end
        function update_site_info(obj,isite,infoDict)
            isite=normalizeSite(isite,obj.structure.num_sites);
            if ~isfield(obj.info,"sites_info")
                obj.info.sites_info=repmat({struct()},1,obj.structure.num_sites);
            end
            names=fieldnames(infoDict);
            for ii=1:numel(names)
                obj.info.sites_info{isite}.(names{ii})=infoDict.(names{ii});
            end
        end
        function value=get_coordination_environments(obj,isite,cn,nbSet)
            isite=normalizeSite(isite,obj.structure.num_sites);
            if isempty(obj.ce_list{isite})||~isKey(obj.ce_list{isite},cn)
                value=[];return
            end
            sets=obj.neighbors_sets{isite}(cn);
            index=find(cellfun(@(x)sameSet(x,nbSet),sets),1);
            if isempty(index),value=[];else,items=obj.ce_list{isite}(cn); ...
                    value=items{index};end
        end
        function value=get_csm(obj,isite,mpSymbol)
            values=obj.get_csms(isite,mpSymbol);
            if numel(values)~=1,error("KSSOLV:Matgenlab:ChemEnv:CSM", ...
                    "Expected exactly one CSM.");end
            value=values{1};
        end
        function value=get_csms(obj,isite,mpSymbol)
            persistent mappings
            if isempty(mappings)
                registry=kssolv.analysis.matgenlab.analysis.chemenv. ...
                    coordination_environments.AllCoordinationGeometries();
                mappings=registry.get_symbol_cn_mapping();
            end
            cn=mappings(char(string(mpSymbol)));
            isite=normalizeSite(isite,obj.structure.num_sites);
            if isempty(obj.ce_list{isite})||~isKey(obj.ce_list{isite},cn)
                value={};return
            end
            envs=obj.ce_list{isite}(cn);value={};
            for ii=1:numel(envs)
                if ~isempty(envs{ii})&& ...
                        isKey(envs{ii}.coord_geoms,char(string(mpSymbol)))
                    value{end+1}=envs{ii}(mpSymbol); %#ok<AGROW>
                end
            end
        end
        function [fig,ax]=get_csm_and_maps(obj,isite,varargin)
            opts=parseOptions(struct(max_csm=8,figsize=[], ...
                symmetry_measure_type="csm_wcs_ctwcc"),varargin{:});
            isite=normalizeSite(isite,obj.structure.num_sites);
            fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");index=0;
            map=obj.ce_list{isite};
            for cn=sort(cell2mat(map.keys))
                envs=map(cn);
                for ii=1:numel(envs)
                    if isempty(envs{ii}),continue,end
                    mins=envs{ii}.minimum_geometries("max_csm",opts.max_csm);
                    for jj=1:numel(mins)
                        data=mins{jj}{2};plot(ax,index, ...
                            data.other_symmetry_measures.( ...
                            char(opts.symmetry_measure_type)),"ob");
                    end
                    index=index+1;
                end
            end
            xlabel(ax,"Coordination map");ylabel(ax,"Continuous symmetry measure");
        end
        function plot_csm_and_maps(obj,isite,varargin)
            [fig,~]=obj.get_csm_and_maps(isite,varargin{:});set(fig,"Visible","on");
        end
        function [fig,ax]=get_environments_figure(obj,isite,varargin)
            opts=parseOptions(struct(plot_type=[],title="Coordination numbers", ...
                max_dist=2,colormap=parula(256),figsize=[],strategy=[]), ...
                varargin{:});
            isite=normalizeSite(isite,obj.structure.num_sites);
            fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");
            map=obj.neighbors_sets{isite};
            for cn=sort(cell2mat(map.keys))
                sets=map(cn);envs=obj.ce_list{isite}(cn);
                for ii=1:numel(sets)
                    points=sets{ii}.voronoi_grid_surface_points();
                    if isempty(points),continue,end
                    if isempty(envs{ii}),csm=10;else
                        best=envs{ii}.minimum_geometry();
                        if isempty(best),csm=10;else,csm=best{2}.symmetry_measure;end
                    end
                    color=opts.colormap(1+round(min(csm,10)/10* ...
                        (size(opts.colormap,1)-1)),:);
                    patch(ax,points(:,1),points(:,2),color, ...
                        "EdgeColor","k","LineWidth",1.2);
                end
            end
            title(ax,opts.title);xlabel(ax,"Distance parameter");
            ylabel(ax,"Angle parameter");xlim(ax,[1 opts.max_dist]);ylim(ax,[0 1]);
            set(ax,"YDir","reverse");
        end
        function plot_environments(obj,isite,varargin)
            [fig,~]=obj.get_environments_figure(isite,varargin{:});
            set(fig,"Visible","on");
        end
        function save_environments_figure(obj,isite,varargin)
            opts=parseOptions(struct(imagename="image.png",plot_type=[], ...
                title="Coordination numbers",max_dist=2,figsize=[]),varargin{:});
            [fig,~]=obj.get_environments_figure(isite, ...
                "plot_type",opts.plot_type,"title",opts.title, ...
                "max_dist",opts.max_dist,"figsize",opts.figsize);
            exportgraphics(fig,opts.imagename);close(fig);
        end
        function value=differences_wrt(obj,other)
            if isequaln(obj.as_dict(),other.as_dict()),value={};
            else,value={struct(difference="structure_environments", ...
                    comparison="is_close_to")};end
        end
        function value=as_dict(obj)
            ces=cell(size(obj.ce_list));sets=cell(size(obj.neighbors_sets));
            for isite=1:numel(obj.ce_list)
                ces{isite}=mapToStruct(obj.ce_list{isite},true);
                sets{isite}=mapToStruct(obj.neighbors_sets{isite},false);
            end
            eq=cellfun(@(group)cellfun(@(site)site.as_dict(),group, ...
                "UniformOutput",false),obj.equivalent_sites, ...
                "UniformOutput",false);
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.structure_environments", ...
                x_class="StructureEnvironments",voronoi=obj.voronoi.as_dict(), ...
                valences=obj.valences,sites_map=obj.sites_map-1, ...
                equivalent_sites={eq},ce_list={ces}, ...
                structure=obj.structure.as_dict(),neighbors_sets={sets}, ...
                info=obj.info);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            voronoi=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.DetailedVoronoiContainer.from_dict( ...
                value.voronoi);
            structure=kssolv.analysis.matgenlab.core.Structure.from_dict( ...
                value.structure);
            ces=parseSiteMaps(value.ce_list,true,structure,voronoi);
            sets=parseSiteMaps(value.neighbors_sets,false,structure,voronoi);
            groups=cell(1,numel(value.equivalent_sites));
            for ii=1:numel(groups)
                if iscell(value.equivalent_sites)
                    raw=value.equivalent_sites{ii};
                else,raw=value.equivalent_sites(ii);end
                if isstruct(raw),raw=num2cell(raw(:)).';end
                groups{ii}=cellfun(@(x)kssolv.analysis.matgenlab.core. ...
                    PeriodicSite.from_dict(x),raw,"UniformOutput",false);
            end
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.StructureEnvironments(voronoi, ...
                value.valences,reshape(double(value.sites_map),1,[])+1, ...
                groups,ces,structure,"neighbors_sets",sets, ...
                "info",value.info);
        end
    end
end
function maps=parseSiteMaps(raw,chemical,structure,voronoi)
maps=cell(size(raw));
for isite=1:numel(raw)
    if isempty(raw{isite}),maps{isite}=[];continue,end
    data=raw{isite};fields=fieldnames(data);
    map=containers.Map("KeyType","double","ValueType","any");
    for ii=1:numel(fields)
        cn=str2double(regexp(fields{ii},'\d+','match','once'));
        items=data.(fields{ii});
        if isstruct(items),items=num2cell(items(:)).'; ...
        elseif ~iscell(items),items={items};else,items=items(:).';end
        values=cell(size(items));
        for jj=1:numel(items)
            if isNull(items{jj}),values{jj}=[];
            elseif chemical
                values{jj}=kssolv.analysis.matgenlab.analysis.chemenv. ...
                    coordination_environments.ChemicalEnvironments. ...
                    from_dict(items{jj});
            else
                values{jj}=kssolv.analysis.matgenlab.analysis.chemenv. ...
                    coordination_environments. ...
                    StructureEnvironmentsNeighborsSet.from_dict( ...
                    items{jj},structure,voronoi);
            end
        end
        map(cn)=values;
    end
    maps{isite}=map;
end
end
function value=isNull(input)
value=isempty(input)||(isnumeric(input)&&isscalar(input)&&isnan(input))|| ...
    ((ischar(input)||isstring(input))&&string(input)=="None");
end
function value=mapToStruct(map,chemical)
if isempty(map),value=[];return,end
value=struct();
for key=map.keys
    items=map(key{1});encoded=cell(size(items));
    for ii=1:numel(items)
        if isempty(items{ii}),encoded{ii}=[];
        else,encoded{ii}=items{ii}.as_dict();end
    end
    value.("x"+string(key{1}))=encoded;
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
function value=sameSet(a,b)
value=a.isite==b.isite&&isequal(a.site_voronoi_indices,b.site_voronoi_indices);
end
