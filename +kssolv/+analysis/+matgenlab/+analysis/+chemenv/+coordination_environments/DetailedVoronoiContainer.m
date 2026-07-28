%#ok<*AGROW,*ALIGN,*CCAT1>
classdef DetailedVoronoiContainer < handle
    %DETAILEDVORONOICONTAINER Distance/solid-angle neighbor plateaus.
    properties (Constant)
        default_voronoi_cutoff=10.0
        default_normalized_distance_tolerance=1e-5
        default_normalized_angle_tolerance=1e-3
    end
    properties
        normalized_distance_tolerance (1,1) double=1e-5
        normalized_angle_tolerance (1,1) double=1e-3
        additional_conditions=[0 1]
        valences="undefined"
        maximum_distance_factor=[]
        minimum_angle_factor=[]
        structure
        voronoi_list2 cell={}
        voronoi_list_coords cell={}
        neighbors_distances cell={}
        neighbors_normalized_distances cell={}
        neighbors_angles cell={}
        neighbors_normalized_angles cell={}
    end
    methods
        function obj=DetailedVoronoiContainer(varargin)
            opts=parseOptions(varargin{:});
            if isempty(opts.structure),return,end
            obj.structure=opts.structure;
            obj.normalized_distance_tolerance= ...
                opts.normalized_distance_tolerance;
            obj.normalized_angle_tolerance=opts.normalized_angle_tolerance;
            obj.additional_conditions=opts.additional_conditions;
            obj.valences=opts.valences;
            obj.maximum_distance_factor=opts.maximum_distance_factor;
            obj.minimum_angle_factor=opts.minimum_angle_factor;
            if isempty(opts.voronoi_list2)
                if isempty(opts.isites),indices=1:obj.structure.num_sites;
                else,indices=normalizeIndices(opts.isites,obj.structure.num_sites);end
                obj.setup_voronoi_list(indices,opts.voronoi_cutoff);
            else,obj.voronoi_list2=opts.voronoi_list2; ...
                    obj.buildCoordinateCache();indices=reshape( ...
                    find(~cellfun(@isempty,obj.voronoi_list2)),1,[]);
            end
            obj.setup_neighbors_distances_and_angles(indices);
        end
        function setup_voronoi_list(obj,indices,voronoiCutoff)
            obj.voronoi_list2=cell(1,obj.structure.num_sites);
            finder=kssolv.analysis.matgenlab.core.VoronoiNN( ...
                "cutoff",voronoiCutoff,"extra_nn_info",true);
            for isite=indices
                poly=finder.get_voronoi_polyhedra(obj.structure,isite);
                angles=cellfun(@(x)x.solid_angle,poly);
                distances=cellfun(@(x)norm(x.site.coords- ...
                    obj.structure.sites{isite}.coords),poly);
                maxAngle=max(angles);minDistance=min(distances);
                entries=cell(1,numel(poly));
                for ii=1:numel(poly)
                    entries{ii}=struct(site=poly{ii}.site,angle=angles(ii), ...
                        distance=distances(ii),index=poly{ii}.site.index, ...
                        normalized_angle=angles(ii)/maxAngle, ...
                        normalized_distance=distances(ii)/minDistance);
                end
                obj.voronoi_list2{isite}=entries;
            end
            obj.buildCoordinateCache();
        end
        function setup_neighbors_distances_and_angles(obj,indices)
            n=obj.structure.num_sites;
            obj.neighbors_distances=cell(1,n);
            obj.neighbors_normalized_distances=cell(1,n);
            obj.neighbors_angles=cell(1,n);
            obj.neighbors_normalized_angles=cell(1,n);
            for isite=indices
                entries=obj.voronoi_list2{isite};
                if isempty(entries),continue,end
                nd=cellfun(@(x)x.normalized_distance,entries);
                dd=cellfun(@(x)x.distance,entries);
                na=cellfun(@(x)x.normalized_angle,entries);
                aa=cellfun(@(x)x.angle,entries);
                [normalizedDistanceGroups,distanceGroups]=groupPlateaus(nd,dd, ...
                    obj.normalized_distance_tolerance,true, ...
                    obj.maximum_distance_factor,obj.default_voronoi_cutoff);
                obj.neighbors_normalized_distances{isite}= ...
                    normalizedDistanceGroups;
                obj.neighbors_distances{isite}=distanceGroups;
                [normalizedAngleGroups,angleGroups]=groupPlateaus(na,aa, ...
                    obj.normalized_angle_tolerance,false, ...
                    obj.minimum_angle_factor,0);
                obj.neighbors_normalized_angles{isite}=normalizedAngleGroups;
                obj.neighbors_angles{isite}=angleGroups;
            end
        end
        function value=neighbors(obj,isite,distfactor,angfactor,varargin)
            isite=normalizeSite(isite,obj.structure.num_sites);
            dgroups=obj.neighbors_normalized_distances{isite};
            agroups=obj.neighbors_normalized_angles{isite};
            id=[];ia=[];
            for ii=1:numel(dgroups)
                if distfactor>=dgroups{ii}.min,id=ii;else,break,end
            end
            for ii=1:numel(agroups)
                if angfactor<=agroups{ii}.max,ia=ii;else,break,end
            end
            if isempty(id)||isempty(ia)
                error("KSSOLV:Matgenlab:ChemEnv:VoronoiParameter", ...
                    "Distance or angle parameter not found.");
            end
            dmax=dgroups{id}.max;amin=agroups{ia}.min;
            entries=obj.voronoi_list2{isite};keep=false(1,numel(entries));
            for ii=1:numel(entries)
                keep(ii)=entries{ii}.normalized_distance<=dmax&& ...
                    entries{ii}.normalized_angle>=amin;
            end
            value=entries(keep);
        end
        function value=voronoi_parameters_bounds_and_limits( ...
                obj,isite,plotType,maxDist)
            isite=normalizeSite(isite,obj.structure.num_sites);
            if nargin<3||isempty(plotType)
                plotType=struct(distance_parameter={{ ...
                    "initial_inverse_opposite",[]}}, ...
                    angle_parameter={{"initial_opposite",[]}});
            end
            if nargin<4,maxDist=2;end
            distances=cellfun(@(x)x.min, ...
                obj.neighbors_normalized_distances{isite});
            distances(1)=1;
            dtype=string(plotType.distance_parameter{1});
            if dtype=="initial_normalized"
                dbounds=[distances,maxDist];dlimits=[1 maxDist];
            elseif dtype=="initial_inverse_opposite"
                dbounds=1-1./[distances,Inf];dlimits=[0 1];
            elseif dtype=="initial_inverse3_opposite"
                dbounds=1-1./[distances.^3,Inf];dlimits=[0 1];
            else,error("KSSOLV:Matgenlab:NotImplemented", ...
                    "Unsupported distance plot type.");end
            angles=cellfun(@(x)x.max,obj.neighbors_normalized_angles{isite});
            atype=string(plotType.angle_parameter{1});
            if atype=="initial_normalized",abounds=[0 angles];
            elseif atype=="initial_opposite",abounds=1-[0 angles];
            else,error("KSSOLV:Matgenlab:NotImplemented", ...
                    "Unsupported angle plot type.");end
            value=struct(distance_bounds=dbounds,distance_limits=dlimits, ...
                angle_bounds=abounds,angle_limits=[0 1]);
        end
        function value=neighbors_surfaces(obj,isite,varargin)
            opts=parseNamed(struct(surface_calculation_type=[],max_dist=2), ...
                varargin{:});
            bounds=obj.voronoi_parameters_bounds_and_limits(isite, ...
                opts.surface_calculation_type,opts.max_dist);
            value=abs(diff(bounds.distance_bounds(:))* ...
                diff(bounds.angle_bounds(:)).');
            value(end+1,end+1)=0;
        end
        function value=neighbors_surfaces_bounded(obj,isite,varargin)
            opts=parseNamed(struct(surface_calculation_options=[]),varargin{:});
            if isempty(opts.surface_calculation_options)
                options=struct(type="standard_elliptic", ...
                    distance_bounds=struct(lower=1.2,upper=1.8), ...
                    angle_bounds=struct(lower=.1,upper=.8));
            else,options=opts.surface_calculation_options;end
            plotType=struct(distance_parameter={{"initial_normalized",[]}}, ...
                angle_parameter={{"initial_normalized",[]}});
            bounds=obj.voronoi_parameters_bounds_and_limits( ...
                isite,plotType,options.distance_bounds.upper+.1);
            db=bounds.distance_bounds;ab=bounds.angle_bounds;
            value=zeros(numel(db),numel(ab));
            funcs=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                get_lower_and_upper_f(options);
            for id=1:numel(db)-1
                for ia=1:numel(ab)-1
                    rect=[max(db(id),options.distance_bounds.lower), ...
                        min(db(id+1),options.distance_bounds.upper); ...
                        max(min(ab(ia:ia+1)),options.angle_bounds.lower), ...
                        min(max(ab(ia:ia+1)),options.angle_bounds.upper)];
                    if rect(1,1)<=rect(1,2)&&rect(2,1)<=rect(2,2)
                        area=kssolv.analysis.matgenlab.analysis. ...
                            chemenv.utils.rectangle_surface_intersection( ...
                            rect,funcs.lower,funcs.upper, ...
                            "bounds_lower",[options.distance_bounds.lower, ...
                            options.distance_bounds.upper], ...
                            "bounds_upper",[options.distance_bounds.lower, ...
                            options.distance_bounds.upper],"check",false);
                        value(id,ia)=area(1);
                    end
                end
            end
        end
        function value=maps_and_surfaces(obj,isite,varargin)
            surfaces=obj.neighbors_surfaces(isite,varargin{:});
            value=surfaceMaps(obj,isite,surfaces,varargin{:});
        end
        function value=maps_and_surfaces_bounded(obj,isite,varargin)
            surfaces=obj.neighbors_surfaces_bounded(isite,varargin{:});
            value=surfaceMaps(obj,isite,surfaces,varargin{:});
        end
        function value=is_close_to(obj,other,varargin)
            opts=parseNamed(struct(rtol=0,atol=1e-8),varargin{:});
            value=abs(obj.normalized_angle_tolerance- ...
                other.normalized_angle_tolerance)<=opts.atol+ ...
                opts.rtol*abs(other.normalized_angle_tolerance)&& ...
                abs(obj.normalized_distance_tolerance- ...
                other.normalized_distance_tolerance)<=opts.atol+ ...
                opts.rtol*abs(other.normalized_distance_tolerance)&& ...
                isequal(obj.additional_conditions,other.additional_conditions)&& ...
                isequal(obj.valences,other.valences);
            if ~value||numel(obj.voronoi_list2)~=numel(other.voronoi_list2),return,end
            for isite=1:numel(obj.voronoi_list2)
                a=obj.voronoi_list2{isite};b=other.voronoi_list2{isite};
                if numel(a)~=numel(b),value=false;return,end
                for ii=1:numel(a)
                    match=ii;
                    if b{match}.index~=a{ii}.index
                        value=false;return
                    end
                    names=["distance","angle","normalized_distance", ...
                        "normalized_angle"];
                    for name=names
                        x=a{ii}.(name);y=b{match}.(name);
                        if abs(x-y)>opts.atol+opts.rtol*abs(y)
                            value=false;return
                        end
                    end
                end
            end
        end
        function value=get_rdf_figure(obj,isite,varargin)
            opts=parseNamed(struct(normalized=true,figsize=[], ...
                step_function=[]),varargin{:});
            if opts.normalized,groups=obj.neighbors_normalized_distances{ ...
                    normalizeSite(isite,obj.structure.num_sites)};
            else,groups=obj.neighbors_distances{normalizeSite( ...
                    isite,obj.structure.num_sites)};end
            [xx,yy]=distributionCurve(groups,false,opts.step_function);
            value=figure("Visible","off");plot(xx,yy);
        end
        function value=get_sadf_figure(obj,isite,varargin)
            opts=parseNamed(struct(normalized=true,figsize=[], ...
                step_function=[]),varargin{:});
            if opts.normalized,groups=obj.neighbors_normalized_angles{ ...
                    normalizeSite(isite,obj.structure.num_sites)};
            else,groups=obj.neighbors_angles{normalizeSite( ...
                    isite,obj.structure.num_sites)};end
            [xx,yy]=distributionCurve(groups,true,opts.step_function);
            value=figure("Visible","off");plot(xx,yy);
        end
        function value=to_bson_voronoi_list2(obj)
            value=cell(size(obj.voronoi_list2));
            for isite=1:numel(obj.voronoi_list2)
                entries=obj.voronoi_list2{isite};
                if isempty(entries),value{isite}=[];continue,end
                encoded=cell(numel(entries),1);
                for ii=1:numel(entries)
                    data=rmfield(entries{ii},"site");
                    data.index=data.index-1;
                    image=entries{ii}.site.frac_coords- ...
                        obj.structure.sites{entries{ii}.index}.frac_coords;
                    encoded{ii}={{data.index,reshape(image,[],1)},data};
                end
                value{isite}=encoded;
            end
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.voronoi", ...
                x_class="DetailedVoronoiContainer", ...
                bson_nb_voro_list2={obj.to_bson_voronoi_list2()}, ...
                structure=obj.structure.as_dict(), ...
                normalized_angle_tolerance=obj.normalized_angle_tolerance, ...
                normalized_distance_tolerance=obj.normalized_distance_tolerance, ...
                additional_conditions=obj.additional_conditions, ...
                valences=obj.valences, ...
                maximum_distance_factor=obj.maximum_distance_factor, ...
                minimum_angle_factor=obj.minimum_angle_factor);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            structure=kssolv.analysis.matgenlab.core.Structure.from_dict( ...
                value.structure);
            voronoi=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.from_bson_voronoi_list2( ...
                value.bson_nb_voro_list2,structure);
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.DetailedVoronoiContainer( ...
                "structure",structure,"voronoi_list2",voronoi, ...
                "normalized_angle_tolerance", ...
                value.normalized_angle_tolerance, ...
                "normalized_distance_tolerance", ...
                value.normalized_distance_tolerance, ...
                "additional_conditions",value.additional_conditions, ...
                "valences",value.valences, ...
                "maximum_distance_factor",fieldOr(value, ...
                "maximum_distance_factor",[]), ...
                "minimum_angle_factor",fieldOr(value, ...
                "minimum_angle_factor",[]));
        end
    end
    methods (Access=private)
        function buildCoordinateCache(obj)
            obj.voronoi_list_coords=cell(size(obj.voronoi_list2));
            for ii=1:numel(obj.voronoi_list2)
                entries=obj.voronoi_list2{ii};
                if isempty(entries),continue,end
                obj.voronoi_list_coords{ii}=cell2mat(cellfun( ...
                    @(x)x.site.coords,entries,"UniformOutput",false).');
            end
        end
    end
end
function opts=parseOptions(varargin)
opts=struct(structure=[],voronoi_list2=[],voronoi_cutoff=10, ...
    isites=[],normalized_distance_tolerance=1e-5, ...
    normalized_angle_tolerance=1e-3,additional_conditions=[0 1], ...
    valences="undefined",maximum_distance_factor=[],minimum_angle_factor=[]);
opts=parseNamed(opts,varargin{:});
end
function opts=parseNamed(opts,varargin)
names=fieldnames(opts);pos=1;
while pos<=numel(varargin)&&~(ischar(varargin{pos})||isstring(varargin{pos}))
    opts.(names{pos})=varargin{pos};pos=pos+1;
end
for ii=pos:2:numel(varargin),opts.(char(string(varargin{ii})))=varargin{ii+1};end
end
function indices=normalizeIndices(value,n)
indices=reshape(double(value),1,[]);if any(indices==0),indices=indices+1;end
if any(indices<1|indices>n),error("KSSOLV:Matgenlab:Index","Invalid site index.");end
end
function value=normalizeSite(value,n)
value=double(value);if value==0,value=1;end
if value<1||value>n,error("KSSOLV:Matgenlab:Index","Invalid site index.");end
end
function [normalized,realGroups]=groupPlateaus(nvalues,rvalues,tol,ascending,limit,tail)
if ascending,[~,order]=sort(nvalues);else,[~,order]=sort(nvalues,"descend");end
normalized={};realGroups={};cumulative=[];group=[];last=nvalues(order(1));
for index=order
    current=nvalues(index);
    if ~isempty(limit)&&((ascending&&current>limit)||(~ascending&&current<limit))
        break
    end
    if abs(current-last)>tol&&~isempty(group)
        [normalized,realGroups]=addGroup(normalized,realGroups,nvalues,rvalues, ...
            cumulative,group,ascending);
        group=[];last=current;
    end
    cumulative=unique([cumulative,index]);group(end+1)=index;
end
if ~isempty(group)
    [normalized,realGroups]=addGroup(normalized,realGroups,nvalues,rvalues, ...
        cumulative,group,ascending);
end
for ii=1:numel(normalized)-1
    if ascending
        normalized{ii}.next=normalized{ii+1}.min;
        realGroups{ii}.next=realGroups{ii+1}.min;
    else
        normalized{ii}.next=normalized{ii+1}.max;
        realGroups{ii}.next=realGroups{ii+1}.max;
    end
end
if ascending
    if isempty(limit),factor=tail/realGroups{1}.min;else,factor=limit;end
    normalized{end}.next=factor;
    realGroups{end}.next=factor*realGroups{1}.min;
else
    if isempty(limit),factor=0;else,factor=limit;end
    normalized{end}.next=factor;
    realGroups{end}.next=factor*realGroups{1}.max;
end
end
function [ng,rg]=addGroup(ng,rg,nv,rv,cumulative,group,ascending)
if ascending
    ng{end+1}=struct(min=min(nv(group)),max=max(nv(group)), ...
        nb_indices=cumulative,dnb_indices=group);
    rg{end+1}=struct(min=min(rv(group)),max=max(rv(group)), ...
        nb_indices=cumulative,dnb_indices=group);
else
    ng{end+1}=struct(max=max(nv(group)),min=min(nv(group)), ...
        nb_indices=cumulative,dnb_indices=group);
    rg{end+1}=struct(max=max(rv(group)),min=min(rv(group)), ...
        nb_indices=cumulative,dnb_indices=group);
end
end
function value=fieldOr(data,name,default)
if isfield(data,name),value=data.(name);else,value=default;end
end
function value=surfaceMaps(obj,isite,surfaces,varargin)
opts=parseNamed(struct(additional_conditions=1),varargin{:});
isite=normalizeSite(isite,obj.structure.num_sites);
dgroups=obj.neighbors_normalized_distances{isite};
agroups=obj.neighbors_normalized_angles{isite};
conditions=reshape(double(opts.additional_conditions),1,[]);
keys={};params={};areas=[];
for id=1:numel(dgroups)
    for ia=1:numel(agroups)
        indices=sort(intersect(dgroups{id}.nb_indices, ...
            agroups{ia}.nb_indices));
        key=sprintf("%d,",indices);
        index=find(string(keys)==string(key),1);
        if isempty(index)
            keys{end+1}=key;params{end+1}={};areas(end+1)=0;
            index=numel(keys);
        end
        for ac=conditions
            params{index}{end+1}=[id-1,ia-1,ac];
            areas(index)=areas(index)+surfaces(id,ia);
        end
    end
end
coordination=cellfun(@(x)count(string(x),","),keys);
mapIndices=zeros(size(coordination));
for cn=unique(coordination)
    positions=find(coordination==cn);
    mapIndices(positions)=0:numel(positions)-1;
end
value=cell(1,numel(keys));
for ii=1:numel(keys)
    value{ii}=struct(map=[coordination(ii),mapIndices(ii)+1], ...
        surface=areas(ii),parameters_indices={params{ii}});
end
end
function [xx,yy]=distributionCurve(groups,angles,step)
if isempty(step)
    if angles,step=struct(type="step_function",scale=1e-4);
    else,step=struct(type="normal_cdf",scale=1e-4);end
end
values=cellfun(@(x)x.min,groups);
counts=cellfun(@(x)numel(x.dnb_indices),groups);
if angles,values=values.^(-.1);end
if string(step.type)=="step_function"
    [values,order]=sort(values);counts=counts(order);
    xx=0;yy=0;
    for ii=1:numel(values)
        xx=[xx,values(ii),values(ii)];
        yy=[yy,yy(end),yy(end)+counts(ii)];
    end
    xx(end+1)=1.1*xx(end);yy(end+1)=yy(end);
else
    xx=linspace(0,1.1*max(values),500);yy=zeros(size(xx));
    for ii=1:numel(values)
        yy=yy+counts(ii)*kssolv.analysis.matgenlab.analysis. ...
            chemenv.utils.normal_cdf_step(xx,"mean",values(ii), ...
            "scale",step.scale);
    end
end
end
