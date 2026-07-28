classdef PourbaixDiagram < kssolv.analysis.matgenlab.util.MSONable
    %POURBAIXDIAGRAM Stable electrochemical domains in pH-potential space.
    %#ok<*ALIGN>
    properties (Constant)
        elements_ho=["H","O"]
    end
    properties
        filter_solids (1,1) logical=true
        pbx_elts cell={}
        dim (1,1) double=0
        pourbaix_elements cell={}
        x_elt_comp
        x_conc_dict
        x_processed_entries cell={}
        x_unprocessed_entries cell={}
        x_filtered_entries cell={}
        x_stable_domains cell={}
        x_stable_domain_vertices cell={}
        x_multi_element (1,1) logical=false
    end
    properties (Dependent,SetAccess=private)
        stable_entries
        unstable_entries
        all_entries
        unprocessed_entries
    end
    methods
        function obj=PourbaixDiagram(entries,varargin)
            if nargin==0,return,end
            if ~iscell(entries),entries=num2cell(entries);end
            entries=reshape(entries,1,[]);
            if isempty(entries)
                error("KSSOLV:Matgenlab:Pourbaix:Empty", ...
                    "At least one Pourbaix entry is required.");
            end
            defaults=struct(comp_dict=[],conc_dict=[],filter_solids=true,nproc=[]);
            options=parseOptions(defaults,varargin);
            obj.filter_solids=logical(options.filter_solids);
            obj.pbx_elts=nonHOElements(entries);obj.dim=numel(obj.pbx_elts)-1;
            if isa(entries{1},"kssolv.analysis.matgenlab.analysis.MultiEntry")
                obj.x_processed_entries=entries;
                singles={};
                for item=entries,singles=[singles,item{1}.entry_list];end %#ok<AGROW>
                obj.x_unprocessed_entries=uniqueEntries(singles);
                obj.x_filtered_entries=obj.x_unprocessed_entries;
                obj.x_conc_dict=[];
                obj.x_elt_comp=compositionStruct( ...
                    nonHOComposition(entries{1}.composition));
                obj.x_multi_element=true;
            else
                comp=options.comp_dict;
                if isempty(comp)
                    comp=struct();
                    for element=obj.pbx_elts
                        comp.(char(element{1}.symbol))=1/numel(obj.pbx_elts);
                    end
                end
                comp=compositionStruct(stripHO(comp));
                if isempty(compNames(comp))
                    error("KSSOLV:Matgenlab:Pourbaix:Composition", ...
                        "comp_dict must contain at least one non-H/O element.");
                end
                conc=options.conc_dict;
                if isempty(conc)
                    conc=struct();
                    for element=obj.pbx_elts
                        conc.(char(element{1}.symbol))=1e-6;
                    end
                end
                obj.x_elt_comp=comp;obj.x_conc_dict=conc;
                obj.pourbaix_elements=obj.pbx_elts;
                solids={};ions={};
                for index=1:numel(entries)
                    entry=entries{index};
                    if entry.phase_type=="Solid",solids{end+1}=entry; %#ok<AGROW>
                    elseif entry.phase_type=="Ion"
                        ionElements=entry.elements;
                        ionElements=ionElements(~cellfun(@(x) ...
                            any(x.symbol==obj.elements_ho),ionElements));
                        if isscalar(ionElements)
                            entry.concentration=dictValue(conc, ...
                                ionElements{1}.symbol)*entry.normalization_factor;
                        elseif numel(ionElements)>1&&entry.concentration==0
                            error("KSSOLV:Matgenlab:Pourbaix:Concentration", ...
                                "Concentration is incompatible with a multi-element ion.");
                        end
                        ions{end+1}=entry; %#ok<AGROW>
                    else
                        error("KSSOLV:Matgenlab:Pourbaix:PhaseType", ...
                            "Every entry must be a Solid or Ion.");
                    end
                end
                obj.x_unprocessed_entries=[solids,ions];
                if obj.filter_solids&&~isempty(solids)
                    terminals={ ...
                        kssolv.analysis.matgenlab.core.ComputedEntry("H",0), ...
                        kssolv.analysis.matgenlab.core.ComputedEntry("O",2.46)};
                    phase=kssolv.analysis.matgenlab.analysis.PhaseDiagram( ...
                        [solids,terminals]);
                    stable=phase.stable_entries;
                    solids=stable(~cellfun(@(x)any(cellfun(@(t)x==t, ...
                        terminals)),stable));
                end
                obj.x_filtered_entries=[solids,ions];
                if numel(compNames(comp))>1
                    obj.x_multi_element=true;
                    obj.x_processed_entries=obj.preprocessEntries( ...
                        obj.x_filtered_entries,options.nproc);
                else
                    obj.x_multi_element=false;
                    obj.x_processed_entries=obj.x_filtered_entries;
                end
            end
            [obj.x_stable_domains,obj.x_stable_domain_vertices]= ...
                kssolv.analysis.matgenlab.analysis.PourbaixDiagram. ...
                get_pourbaix_domains(obj.x_processed_entries);
        end
        function value=find_stable_entry(obj,pH,V)
            value=obj.get_stable_entry(pH,V);
        end
        function value=get_decomposition_energy(obj,entry,pH,V)
            target=nonHOComposition(entry.composition);
            if target.fractional_composition~= ...
                    kssolv.analysis.matgenlab.core.Composition( ...
                    obj.x_elt_comp).fractional_composition
                error("KSSOLV:Matgenlab:Pourbaix:CompositionMismatch", ...
                    "Stability entry composition does not match the diagram.");
            end
            value=entry.normalized_energy_at_conditions(pH,V)- ...
                obj.get_hull_energy(pH,V);
            value=value/entry.normalization_factor/entry.composition.num_atoms;
        end
        function value=get_hull_energy(obj,pH,V)
            stable=obj.stable_entries;
            first=stable{1}.normalized_energy_at_conditions(pH,V);
            outputSize=size(first);energies=zeros(numel(stable),numel(first));
            for index=1:numel(stable)
                energies(index,:)=reshape(stable{index}. ...
                    normalized_energy_at_conditions(pH,V),1,[]);
            end
            value=reshape(min(energies,[],1),outputSize);
        end
        function value=get_stable_entry(obj,pH,V)
            stable=obj.stable_entries;energies=zeros(1,numel(stable));
            for index=1:numel(stable)
                energies(index)=stable{index}. ...
                    normalized_energy_at_conditions(pH,V);
            end
            [~,index]=min(energies);value=stable{index};
        end
        function value=get.stable_entries(obj)
            value=obj.x_stable_domains(:,1).';
        end
        function value=get.unstable_entries(obj)
            stable=obj.stable_entries;value={};
            for entry=obj.all_entries
                if ~containsEntry(stable,entry{1}),value{end+1}=entry{1};end %#ok<AGROW>
            end
        end
        function value=get.all_entries(obj),value=obj.x_processed_entries;end
        function value=get.unprocessed_entries(obj)
            value=obj.x_unprocessed_entries;
        end
        function value=asDict(obj)
            entries=cellfun(@(x)x.as_dict(),obj.x_unprocessed_entries, ...
                "UniformOutput",false);
            value=struct(x_module="pymatgen.analysis.pourbaix_diagram", ...
                x_class="PourbaixDiagram",entries={entries}, ...
                comp_dict=obj.x_elt_comp,conc_dict=obj.x_conc_dict, ...
                filter_solids=obj.filter_solids);
        end
        function value=as_dict(obj),value=obj.asDict();end
    end
    methods (Access=private)
        function result=preprocessEntries(obj,entries,nproc) %#ok<INUSD>
            % MATLAB execution is deterministic and in-process; nproc is an
            % accepted compatibility argument, not a numerical dependency.
            [minimum,facets]=hullCandidates(obj,entries);
            maxSize=obj.dim+1;keys=strings(1,0);combos={};
            for row=1:size(facets,1)
                facet=facets(row,:);
                for count=1:min(maxSize,numel(facet))
                    selections=nchoosek(facet,count);
                    for item=1:size(selections,1)
                        ids=sort(selections(item,:));
                        key=join(string(ids),",");
                        if ~any(keys==key)
                            keys(end+1)=key;combos{end+1}=ids; %#ok<AGROW>
                        end
                    end
                end
            end
            product=kssolv.analysis.matgenlab.core.Composition(obj.x_elt_comp);
            result={};
            for index=1:numel(combos)
                candidate=kssolv.analysis.matgenlab.analysis. ...
                    PourbaixDiagram.process_multientry(minimum(combos{index}), ...
                    product);
                if ~isempty(candidate),result{end+1}=candidate;end %#ok<AGROW>
            end
        end
    end
    methods (Static)
        function result=process_multientry(entryList,varargin)
            product=[];threshold=1e-4;
            if ~isempty(varargin)&&isOptionName(varargin{1}, ...
                    ["prod_comp","coeff_threshold"])
                for index=1:2:numel(varargin)
                    if index==numel(varargin)
                        error("KSSOLV:Matgenlab:Pourbaix:Arguments", ...
                            "A value is required after '%s'.",varargin{index});
                    end
                    switch lower(string(varargin{index}))
                        case "prod_comp",product=varargin{index+1};
                        case "coeff_threshold",threshold=varargin{index+1};
                    end
                end
            else
                if ~isempty(varargin),product=varargin{1};end
                if numel(varargin)>1,threshold=varargin{2};end
            end
            if isempty(product)
                error("KSSOLV:Matgenlab:Pourbaix:Arguments", ...
                    "prod_comp is required.");
            end
            if ~iscell(entryList),entryList=num2cell(entryList);end
            result=[];
            try
                compositions=cellfun(@(x)x.composition,entryList, ...
                    "UniformOutput",false);
                reaction=kssolv.analysis.matgenlab.analysis.Reaction( ...
                    [compositions,{ ...
                    kssolv.analysis.matgenlab.core.Composition("H"), ...
                    kssolv.analysis.matgenlab.core.Composition("O")}], ...
                    {product});
                weights=-reaction.coeffs(1:numel(entryList));
                allCoefficients=[weights,reaction.get_coeff(product)];
                if all(allCoefficients>threshold)
                    result=kssolv.analysis.matgenlab.analysis.MultiEntry( ...
                        entryList,weights);
                end
            catch exception
                if ~startsWith(exception.identifier, ...
                        "KSSOLV:Matgenlab:Reaction")
                    rethrow(exception);
                end
            end
        end
        function [domains,vertices]=get_pourbaix_domains(entries,limits)
            if nargin<2||isempty(limits),limits=[-2,16;-4,4];end
            if ~iscell(entries),entries=num2cell(entries);end
            domains=cell(0,2);vertices=cell(0,2);
            planes=zeros(numel(entries),3);
            for index=1:numel(entries)
                factor=entries{index}.normalization_factor;
                planes(index,:)=[.0591*entries{index}.npH, ...
                    entries{index}.nPhi,entries{index}.energy]*factor;
            end
            rectangle=[limits(1,1),limits(2,1);limits(1,2),limits(2,1); ...
                limits(1,2),limits(2,2);limits(1,1),limits(2,2)];
            for index=1:numel(entries)
                polygon=rectangle;
                for other=1:numel(entries)
                    if other==index,continue,end
                    normal=planes(index,1:2)-planes(other,1:2);
                    bound=planes(other,3)-planes(index,3);
                    polygon=clipPolygon(polygon,normal,bound);
                    if isempty(polygon),break,end
                end
                polygon=unique(round(polygon,12),"rows","stable");
                if size(polygon,1)<3,continue,end
                center=mean(polygon,1);
                [~,order]=sort(atan2(polygon(:,2)-center(2), ...
                    polygon(:,1)-center(1)));
                polygon=polygon(order,:);
                segments=cell(1,size(polygon,1));
                for edge=1:size(polygon,1)
                    next=mod(edge,size(polygon,1))+1;
                    segments{edge}=kssolv.analysis.matgenlab.util. ...
                        Simplex(polygon([edge,next],:));
                end
                domains(end+1,:)={entries{index},segments}; %#ok<AGROW>
                vertices(end+1,:)={entries{index},polygon}; %#ok<AGROW>
            end
        end
        function obj=from_dict(value)
            raw=value.entries;if isstruct(raw),raw=num2cell(raw);end
            entries=cell(1,numel(raw));
            for index=1:numel(raw)
                if isfield(raw{index},"x_class")&& ...
                        string(raw{index}.x_class)=="MultiEntry"
                    entries{index}=kssolv.analysis.matgenlab.analysis. ...
                        MultiEntry.from_dict(raw{index});
                else
                    entries{index}=kssolv.analysis.matgenlab.analysis. ...
                        PourbaixEntry.from_dict(raw{index});
                end
            end
            obj=kssolv.analysis.matgenlab.analysis.PourbaixDiagram(entries, ...
                "comp_dict",value.comp_dict,"conc_dict",value.conc_dict, ...
                "filter_solids",logical(value.filter_solids));
        end
        function obj=fromDict(value)
            obj=kssolv.analysis.matgenlab.analysis.PourbaixDiagram.from_dict(value);
        end
    end
end

function [entries,facets]=hullCandidates(obj,input)
ions=input(cellfun(@(x)x.phase_type=="Ion",input));
solids=input(cellfun(@(x)x.phase_type=="Solid",input));
keys=string(cellfun(@(x)x.composition.reduced_formula,solids, ...
    "UniformOutput",false));
entries={};
for key=unique(keys,"stable")
    group=solids(keys==key);
    [~,index]=min(cellfun(@(x)x.entry.energy_per_atom,group));
    entries{end+1}=group{index}; %#ok<AGROW>
end
entries=[entries,ions];
points=zeros(numel(entries),3+max(0,numel(obj.pbx_elts)-1));
for index=1:numel(entries)
    entry=entries{index};factor=entry.normalization_factor;
    points(index,1:3)=[entry.npH,entry.nPhi,entry.energy]*factor;
    for element=1:numel(obj.pbx_elts)-1
        points(index,3+element)= ...
            entry.composition.amountOf(obj.pbx_elts{element})*factor;
    end
end
maximum=max(points(:,1:3),[],1);
extra=[maximum,ones(1,obj.dim)/max(obj.dim,1)];
extra(3)=extra(3)+1000;allPoints=[points;extra];
raw=convhulln(allPoints,{'QJ','i'});
raw=raw(~any(raw==size(allPoints,1),2),:);
if obj.dim>1
    keep=false(size(raw,1),1);
    for row=1:size(raw,1)
        comp=points(raw(row,:),4:end);
        full=[comp,1-sum(comp,2)];
        keep(row)=rank(full)>obj.dim;
    end
    raw=raw(keep,:);
end
facets=raw;
end
function polygon=clipPolygon(polygon,normal,bound)
if isempty(polygon),return,end
output=zeros(0,2);tolerance=1e-10;
for index=1:size(polygon,1)
    current=polygon(index,:);previous=polygon(mod(index-2,size(polygon,1))+1,:);
    currentInside=dot(normal,current)<=bound+tolerance;
    previousInside=dot(normal,previous)<=bound+tolerance;
    if currentInside~=previousInside
        direction=current-previous;denominator=dot(normal,direction);
        if abs(denominator)>1e-14
            parameter=(bound-dot(normal,previous))/denominator;
            output(end+1,:)=previous+parameter*direction; %#ok<AGROW>
        end
    end
    if currentInside,output(end+1,:)=current;end %#ok<AGROW>
end
polygon=output;
end
function elements=nonHOElements(entries)
elements={};symbols=strings(1,0);
for entry=entries
    for element=entry{1}.composition.elements
        symbol=element{1}.symbol;
        if ~any(symbol==["H","O"])&&~any(symbols==symbol)
            symbols(end+1)=symbol;elements{end+1}=element{1}; %#ok<AGROW>
        end
    end
end
[~,order]=sort(symbols);elements=elements(order);
end
function value=nonHOComposition(composition)
pairs=cell(0,2);
for element=composition.elements
    if ~any(element{1}.symbol==["H","O"])
        pairs(end+1,:)={element{1},composition.amountOf(element{1})}; %#ok<AGROW>
    end
end
value=kssolv.analysis.matgenlab.core.Composition(pairs);
end
function value=stripHO(input)
if isa(input,"containers.Map")
    value=containers.Map(keys(input),values(input));
    for key={"H","O"},if isKey(value,key{1}),remove(value,key{1});end,end
elseif isa(input,"kssolv.analysis.matgenlab.core.Composition")
    value=nonHOComposition(input);
else
    value=input;
    for key={"H","O"},if isfield(value,key{1}),value=rmfield(value,key{1});end,end
end
end
function value=compositionStruct(input)
if isstruct(input),value=input;return,end
if isa(input,"containers.Map")
    value=struct();
    for key=string(keys(input))
        value.(char(key))=input(char(key));
    end
    return
end
value=struct();
for element=input.elements
    symbol=char(element{1}.symbol);
    value.(symbol)=input.amountOf(element{1});
end
end
function names=compNames(input)
if isa(input,"containers.Map"),names=string(keys(input));
elseif isa(input,"kssolv.analysis.matgenlab.core.Composition")
    names=string(cellfun(@(x)x.symbol,input.elements));
else,names=string(fieldnames(input));end
end
function value=dictValue(input,key)
key=char(string(key));
if isa(input,"containers.Map"),value=input(key);else,value=input.(key);end
end
function tf=containsEntry(entries,target)
tf=any(cellfun(@(x)x==target,entries));
end
function output=parseOptions(output,input)
names=fieldnames(output);position=1;index=1;
while index<=numel(input)
    if (ischar(input{index})||isstring(input{index}))&& ...
            any(strcmpi(string(input{index}),string(names)))
        key=names{strcmpi(string(input{index}),string(names))};
        output.(key)=input{index+1};index=index+2;
    else
        output.(names{position})=input{index};
        position=position+1;index=index+1;
    end
end
end
function entries=uniqueEntries(input)
entries={};
for item=input
    if ~containsEntry(entries,item{1}),entries{end+1}=item{1};end %#ok<AGROW>
end
end
function tf=isOptionName(value,names)
tf=(ischar(value)||isstring(value))&&isscalar(string(value))&& ...
    any(strcmpi(string(value),names));
end
