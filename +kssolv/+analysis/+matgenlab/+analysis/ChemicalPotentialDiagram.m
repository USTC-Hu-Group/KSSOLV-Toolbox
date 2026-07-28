classdef ChemicalPotentialDiagram < handle
    %CHEMICALPOTENTIALDIAGRAM Dual chemical-potential stability polytopes.
    properties
        entries cell=cell(1,0)
        limits cell=cell(0,2)
        default_min_limit (1,1) double=-50
        elements cell=cell(1,0)
        dim (1,1) double=0
        formal_chempots (1,1) logical=true
    end
    properties (Access=private)
        min_entries_ cell=cell(1,0)
        el_refs_ cell=cell(0,2)
        entry_dict_ cell=cell(0,2)
        border_hyperplanes_ double=zeros(0,0)
        hyperplanes_ double=zeros(0,0)
        hyperplane_entries_ cell=cell(1,0)
        domains_ cell=cell(0,2)
    end
    properties (Dependent,SetAccess=private)
        domains
        lims
        entry_dict
        hyperplanes
        hyperplane_entries
        border_hyperplanes
        el_refs
        chemical_system
    end
    methods
        function obj=ChemicalPotentialDiagram(entries,varargin)
            if isa(entries,"kssolv.analysis.matgenlab.core.EntrySet"),entries=entries.entries;
            elseif ~iscell(entries),entries=num2cell(entries);end
            options=struct(limits=[],default_min_limit=-50,formal_chempots=true);
            options=parseOptions(options,varargin);
            obj.default_min_limit=options.default_min_limit;
            obj.formal_chempots=logical(options.formal_chempots);
            obj.limits=normalizeLimits(options.limits);
            [~,initialRefs]=minimumEntries(entries);
            if obj.formal_chempots
                normalized=cell(size(entries));
                for ii=1:numel(entries)
                    reference=0;
                    for el=entries{ii}.composition.elements
                        reference=reference+entries{ii}.composition(el{1})* ...
                            getRef(initialRefs,el{1}).energy_per_atom;
                    end
                    normalized{ii}=kssolv.analysis.matgenlab.analysis.PDEntry( ...
                        entries{ii}.composition,entries{ii}.energy-reference, ...
                        "name",entryName(entries{ii}), ...
                        "attribute",entryAttribute(entries{ii}));
                end
                entries=normalized;
            end
            obj.entries=entries;
            all={};for item=entries,all=[all,item{1}.elements];end %#ok<AGROW>
            obj.elements=uniqueElements(all);
            [~,order]=sort(cellfun(@(x)x.X,obj.elements));obj.elements=obj.elements(order);
            obj.dim=numel(obj.elements);
            if obj.dim<2
                error("KSSOLV:Matgenlab:ChemicalPotentialDiagram:Dimension", ...
                    "ChemicalPotentialDiagram requires two or more elements.");
            end
            [obj.min_entries_,obj.el_refs_]=minimumEntries(entries);
            if size(obj.el_refs_,1)~=obj.dim
                error("KSSOLV:Matgenlab:ChemicalPotentialDiagram:Terminals", ...
                    "There are no entries for one or more terminal elements.");
            end
            obj.entry_dict_=cellfun(@(x){x.reduced_formula,x},obj.min_entries_, ...
                "UniformOutput",false);obj.entry_dict_=vertcat(obj.entry_dict_{:});
            obj.border_hyperplanes_=obj.buildBorderHyperplanes();
            [obj.hyperplanes_,obj.hyperplane_entries_]=obj.buildHyperplanes();
            obj.domains_=obj.buildDomains();
        end
        function value=get.domains(obj),value=obj.domains_;end
        function value=get.entry_dict(obj),value=obj.entry_dict_;end
        function value=get.hyperplanes(obj),value=obj.hyperplanes_;end
        function value=get.hyperplane_entries(obj),value=obj.hyperplane_entries_;end
        function value=get.border_hyperplanes(obj),value=obj.border_hyperplanes_;end
        function value=get.el_refs(obj),value=obj.el_refs_;end
        function value=get.chemical_system(obj)
            value=strjoin(sort(cellfun(@(x)x.symbol,obj.elements)),"-");
        end
        function value=get.lims(obj)
            value=repmat([obj.default_min_limit,0],obj.dim,1);
            for ii=1:size(obj.limits,1)
                row=find(cellfun(@(x)x.symbol==obj.limits{ii,1}.symbol,obj.elements),1);
                if ~isempty(row),value(row,:)=obj.limits{ii,2};end
            end
        end
        function axesHandle=get_plot(obj,varargin)
            options=struct(elements={{}},label_stable=true,formulas_to_draw={{}}, ...
                draw_formula_meshes=true,draw_formula_lines=true, ...
                formula_colors={{}},element_padding=1);
            options=parseOptions(options,varargin);
            selected=options.elements;
            if isempty(selected),selected=obj.elements(1:min(3,obj.dim));
            elseif ~iscell(selected),selected=num2cell(selected);end
            selected=cellfun(@(x)kssolv.analysis.matgenlab.core.getElSp(x), ...
                selected,"UniformOutput",false);
            indices=cellfun(@(x)find(cellfun(@(y)y.symbol==x.symbol,obj.elements),1),selected);
            if numel(indices)==2&&obj.dim>2
                subset=obj.entries(cellfun(@(entry)all(ismember( ...
                    entry.composition.chemical_system_set,cellfun(@(x)x.symbol,selected))),obj.entries));
                reduced=kssolv.analysis.matgenlab.analysis.ChemicalPotentialDiagram( ...
                    subset,"limits",obj.limits,"default_min_limit",obj.default_min_limit, ...
                    "formal_chempots",obj.formal_chempots);
                axesHandle=reduced.get_plot("elements",selected,"label_stable",options.label_stable);
                return
            end
            figureHandle=figure("Visible","off");axesHandle=axes(figureHandle);hold(axesHandle,"on");
            for ii=1:size(obj.domains_,1)
                points=obj.domains_{ii,2}(:,indices);
                if numel(indices)==2
                    if size(points,1)>1
                        order=convhull(points(:,1),points(:,2));
                        plot(axesHandle,points(order,1),points(order,2),"-");
                    end
                    if options.label_stable,text(axesHandle,mean(points(:,1)),mean(points(:,2)),obj.domains_{ii,1});end
                else
                    if size(points,1)>=4
                        faces=convhulln(points);trisurf(faces,points(:,1),points(:,2), ...
                            points(:,3),"Parent",axesHandle,"FaceAlpha",.08);
                    end
                    if options.label_stable,text(axesHandle,mean(points(:,1)), ...
                            mean(points(:,2)),mean(points(:,3)),obj.domains_{ii,1});end
                end
            end
            hold(axesHandle,"off");
        end
        function data=as_dict(obj)
            data=struct(x_module="pymatgen.analysis.chempot_diagram", ...
                x_class="ChemicalPotentialDiagram", ...
                entries={cellfun(@(x)x.as_dict(),obj.entries,"UniformOutput",false)}, ...
                limits={serializeLimits(obj.limits)}, ...
                default_min_limit=obj.default_min_limit,formal_chempots=obj.formal_chempots);
        end
        function data=asDict(obj),data=obj.as_dict();end
        function text=char(obj)
            text=sprintf("ChemicalPotentialDiagram for %s with %d entries", ...
                obj.chemical_system,numel(obj.entries));
        end
    end
    methods (Static)
        function obj=from_dict(data)
            raw=data.entries;if isstruct(raw),raw=num2cell(raw);end
            entries=cellfun(@(x)kssolv.analysis.matgenlab.analysis.PDEntry.from_dict(x), ...
                raw,"UniformOutput",false);
            obj=kssolv.analysis.matgenlab.analysis.ChemicalPotentialDiagram( ...
                entries,"limits",data.limits, ...
                "default_min_limit",data.default_min_limit, ...
                "formal_chempots",false);
            obj.formal_chempots=data.formal_chempots;
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab.analysis.ChemicalPotentialDiagram.from_dict(data);end
    end
    methods (Access=private)
        function value=buildBorderHyperplanes(obj)
            value=zeros(2*obj.dim,obj.dim+1);limits_=obj.lims;
            for ii=1:obj.dim
                value(2*ii-1,ii)=-1;value(2*ii-1,end)=limits_(ii,1);
                value(2*ii,ii)=1;value(2*ii,end)=limits_(ii,2);
            end
        end
        function [planes,entries]=buildHyperplanes(obj)
            data=zeros(numel(obj.min_entries_),obj.dim+1);
            for ii=1:numel(obj.min_entries_)
                for jj=1:obj.dim
                    data(ii,jj)=obj.min_entries_{ii}.composition. ...
                        get_atomic_fraction(obj.elements{jj});
                end
                data(ii,end)=obj.min_entries_{ii}.energy_per_atom;
            end
            formation=zeros(size(data,1),1);
            for ii=1:size(data,1)
                reference=0;
                for jj=1:obj.dim
                    reference=reference+data(ii,jj)*getRef(obj.el_refs_,obj.elements{jj}).energy_per_atom;
                end
                formation(ii)=data(ii,end)-reference;
            end
            selected=find(formation < -kssolv.analysis.matgenlab.analysis. ...
                PhaseDiagram.formation_energy_tol);
            for ii=1:size(obj.el_refs_,1)
                selected(end+1)=find(cellfun(@(x)sameEntry(x,obj.el_refs_{ii,2}), ...
                    obj.min_entries_),1); %#ok<AGROW>
            end
            selected=unique(selected,"stable");planes=data(selected,:);planes(:,end)=-planes(:,end);
            entries=obj.min_entries_(selected);
        end
        function domains=buildDomains(obj)
            allPlanes=[obj.hyperplanes_;obj.border_hyperplanes_];
            pd=kssolv.analysis.matgenlab.analysis.PhaseDiagram(obj.entries,obj.elements);
            stable=pd.stable_entries;
            candidateRows=[];
            for ii=1:numel(obj.hyperplane_entries_)
                if any(cellfun(@(x)sameEntry(x,obj.hyperplane_entries_{ii}),stable))
                    candidateRows(end+1)=ii; %#ok<AGROW>
                end
            end
            candidateRows=[candidateRows,size(obj.hyperplanes_,1)+(1:size(obj.border_hyperplanes_,1))];
            combinations=nchoosek(candidateRows,obj.dim);
            vertices=zeros(0,obj.dim);active=cell(1,0);
            for ii=1:size(combinations,1)
                chosen=combinations(ii,:);matrix=allPlanes(chosen,1:obj.dim);
                if rcond(matrix)<1e-12,continue,end
                point=matrix\(-allPlanes(chosen,end));
                residual=allPlanes(:,1:obj.dim)*point+allPlanes(:,end);
                if all(residual<=1e-7)
                    duplicate=find(all(abs(vertices-point.')<=1e-7,2),1);
                    if isempty(duplicate)
                        vertices(end+1,:)=point.'; %#ok<AGROW>
                        active{end+1}=find(abs(residual)<=1e-6); %#ok<AGROW>
                    else
                        active{duplicate}=union(active{duplicate},find(abs(residual)<=1e-6));
                    end
                end
            end
            formulas=cellfun(@(x)x.reduced_formula,obj.hyperplane_entries_);
            domains=cell(0,2);
            for ii=1:numel(obj.hyperplane_entries_)
                rows=find(cellfun(@(set)ismember(ii,set),active));
                if isempty(rows),continue,end
                formula=formulas(ii);existing=find(string(domains(:,1))==formula,1);
                points=vertices(rows,:);
                if isempty(existing),domains(end+1,:)={formula,points}; %#ok<AGROW>
                else,domains{existing,2}=unique([domains{existing,2};points],"rows");end
            end
        end
    end
end

function [minimum,refs]=minimumEntries(entries)
keys=cellfun(@(x)x.composition.reduced_formula,entries);uniqueKeys=unique(keys,"stable");
minimum=cell(1,numel(uniqueKeys));refs=cell(0,2);
for ii=1:numel(uniqueKeys)
    group=entries(keys==uniqueKeys(ii));[~,which]=min(cellfun(@(x)x.energy_per_atom,group));
    minimum{ii}=group{which};
    if minimum{ii}.composition.is_element
        refs(end+1,:)={minimum{ii}.composition.elements{1},minimum{ii}}; %#ok<AGROW>
    end
end
end
function value=getRef(refs,element)
row=find(cellfun(@(x)x.symbol==element.symbol,refs(:,1)),1);value=refs{row,2};
end
function elements=uniqueElements(input)
elements={};symbols=strings(1,0);
for item=input
    if ~any(symbols==item{1}.symbol),symbols(end+1)=item{1}.symbol;elements{end+1}=item{1};end %#ok<AGROW>
end
end
function tf=sameEntry(a,b),tf=a.composition==b.composition&&abs(a.energy-b.energy)<=1e-12;end
function value=entryName(entry)
if isprop(entry,"name"),value=entry.name;else,value=entry.reduced_formula;end
end
function value=entryAttribute(entry)
if isprop(entry,"attribute"),value=entry.attribute;else,value=[];end
end
function value=normalizeLimits(input)
if isempty(input)
    value=cell(0,2);
elseif isstruct(input)
    fields=fieldnames(input);value=cell(numel(fields),2);
    for ii=1:numel(fields),value(ii,:)={fields{ii},input.(fields{ii})};end
elseif iscell(input)
    value=input;
else
    error("KSSOLV:Matgenlab:ChemicalPotentialDiagram:Limits", ...
        "Unsupported limits mapping.");
end
for ii=1:size(value,1)
    value{ii,1}=kssolv.analysis.matgenlab.core.getElSp(value{ii,1});
    value{ii,2}=reshape(double(value{ii,2}),1,2);
end
end
function value=serializeLimits(input)
value=cell(size(input));
for ii=1:size(input,1),value(ii,:)={char(input{ii,1}.symbol),input{ii,2}};end
end
function output=parseOptions(output,input)
names=fieldnames(output);position=1;ii=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii})) && ...
            any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};
        ii=ii+2;
    else
        output.(names{position})=input{ii};
        position=position+1;
        ii=ii+1;
    end
end
end
