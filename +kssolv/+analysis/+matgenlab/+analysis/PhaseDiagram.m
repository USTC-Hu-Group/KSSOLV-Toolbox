classdef PhaseDiagram < handle
    %#ok<*MSNU,*PROP,*NASGU,*ASGLU,*ALIGN,*SPERR,*SPWRN>
    %PHASEDIAGRAM Convex-hull thermodynamic phase diagram.
    properties (Constant)
        formation_energy_tol=1e-11
        numerical_tol=1e-8
    end
    properties
        elements cell=cell(1,0)
        entries cell=cell(1,0)
        computed_data struct=struct()
        facets cell=cell(1,0)
        qhull_data double=zeros(0,0)
        simplexes cell=cell(1,0)
        all_entries cell=cell(1,0)
        el_refs cell=cell(0,2)
        qhull_entries cell=cell(1,0)
    end
    properties (Dependent,SetAccess=private)
        dim
        all_entries_hulldata
        unstable_entries
        stable_entries
    end
    properties (Access=protected)
        stable_indices (1,:) double=[]
    end
    methods
        function obj=PhaseDiagram(entries,elements,varargin)
            if nargin==0,return,end
            if isa(entries,"kssolv.analysis.matgenlab.core.EntrySet")
                entries=entries.entries;
            elseif ~iscell(entries)
                entries=num2cell(entries);
            end
            entries=reshape(entries,1,[]);
            if isempty(entries)
                error("KSSOLV:Matgenlab:PhaseDiagram:Empty", ...
                    "Unable to build phase diagram without entries.");
            end
            if nargin<2||isempty(elements)
                all={};
                for item=entries,all=[all,item{1}.elements];end %#ok<AGROW>
                elements=uniqueElements(all);
                [~,order]=sort(cellfun(@(x)x.X,elements));
                elements=elements(order);
            elseif ~iscell(elements)
                elements=num2cell(elements);
            end
            obj.elements=cellfun(@(x)kssolv.analysis.matgenlab.core.getElSp(x), ...
                reshape(elements,1,[]),"UniformOutput",false);
            obj.entries=entries;
            options=struct(computed_data=[]);options=parseOptions(options,varargin);
            if isempty(options.computed_data)
                obj.compute();
            else
                obj.restoreComputed(options.computed_data);
            end
        end
        function value=get.dim(obj),value=numel(obj.elements);end
        function value=get.stable_entries(obj)
            value=obj.qhull_entries(obj.stable_indices);
        end
        function value=get.unstable_entries(obj)
            stable=obj.stable_entries;value={};
            for item=obj.all_entries
                if ~containsEntry(stable,item{1}),value{end+1}=item{1};end %#ok<AGROW>
            end
        end
        function value=get.all_entries_hulldata(obj)
            value=zeros(numel(obj.all_entries),obj.dim);
            for ii=1:numel(obj.all_entries)
                for jj=2:obj.dim
                    value(ii,jj-1)=obj.all_entries{ii}.composition. ...
                        get_atomic_fraction(obj.elements{jj});
                end
                value(ii,end)=obj.all_entries{ii}.energy_per_atom;
            end
        end
        function value=pd_coords(obj,composition)
            composition=asComposition(composition);
            symbols=composition.chemical_system_set;
            allowed=cellfun(@(x)string(x.symbol),obj.elements);
            if any(~ismember(symbols,allowed))
                error("KSSOLV:Matgenlab:PhaseDiagram:CompositionSpace", ...
                    "%s has elements not in the phase diagram.",composition.formula);
            end
            value=zeros(1,max(0,obj.dim-1));
            for ii=2:obj.dim
                value(ii-1)=composition.get_atomic_fraction(obj.elements{ii});
            end
        end
        function value=get_reference_energy(obj,composition)
            composition=asComposition(composition);value=0;
            for el=composition.elements
                ref=getRef(obj.el_refs,el{1});
                value=value+composition(el{1})*ref.energy_per_atom;
            end
        end
        function value=get_reference_energy_per_atom(obj,composition)
            composition=asComposition(composition);
            value=obj.get_reference_energy(composition)/composition.num_atoms;
        end
        function value=get_form_energy(obj,entry)
            value=entry.energy-obj.get_reference_energy(entry.composition);
        end
        function value=get_form_energy_per_atom(obj,entry)
            value=obj.get_form_energy(entry)/entry.composition.num_atoms;
        end
        function decomposition=get_decomposition(obj,composition)
            composition=asComposition(composition);
            if obj.dim==1
                decomposition={obj.qhull_entries{obj.stable_indices(1)},1};
                return
            end
            coord=obj.pd_coords(composition);
            for ii=1:numel(obj.facets)
                simplex=obj.simplexes{ii};
                if simplex.in_simplex(coord,obj.numerical_tol/10)
                    amounts=simplex.bary_coords(coord);
                    decomposition=cell(0,2);
                    facet=obj.facets{ii};
                    for jj=1:numel(facet)
                        if abs(amounts(jj))>obj.numerical_tol
                            decomposition(end+1,:)={obj.qhull_entries{facet(jj)},amounts(jj)}; %#ok<AGROW>
                        end
                    end
                    return
                end
            end
            [decomposition,~]=minimumDecomposition(obj.stable_entries,composition,obj.elements);
            if isempty(decomposition)
                error("KSSOLV:Matgenlab:PhaseDiagram:NoFacet", ...
                    "No facet found for composition %s.",composition.formula);
            end
        end
        function [decomposition,energy]=get_decomp_and_hull_energy_per_atom(obj,composition)
            decomposition=obj.get_decomposition(composition);energy=0;
            for ii=1:size(decomposition,1)
                energy=energy+decomposition{ii,1}.energy_per_atom*decomposition{ii,2};
            end
        end
        function value=get_hull_energy_per_atom(obj,composition,varargin) %#ok<INUSD>
            [~,value]=obj.get_decomp_and_hull_energy_per_atom(composition);
        end
        function value=get_hull_energy(obj,composition)
            composition=asComposition(composition);
            value=composition.num_atoms*obj.get_hull_energy_per_atom(composition);
        end
        function [decomposition,eAbove]=get_decomp_and_e_above_hull(obj,entry,varargin)
            options=struct(allow_negative=false,check_stable=true,on_error="raise");
            options=parseOptions(options,varargin);
            if options.check_stable&&containsEntry(obj.stable_entries,entry)
                decomposition={entry,1};eAbove=0;return
            end
            try
                [decomposition,hull]=obj.get_decomp_and_hull_energy_per_atom(entry.composition);
            catch exception
                [decomposition,eAbove]=handleDecompError(entry,options.on_error, ...
                    "Unable to get decomposition",exception);return
            end
            eAbove=entry.energy_per_atom-hull;
            if ~options.allow_negative&&eAbove < -obj.numerical_tol
                [decomposition,eAbove]=handleDecompError(entry,options.on_error, ...
                    "No valid decomposition found",[]);return
            end
        end
        function value=get_e_above_hull(obj,entry,varargin)
            [~,value]=obj.get_decomp_and_e_above_hull(entry,varargin{:});
        end
        function value=get_equilibrium_reaction_energy(obj,entry)
            if ~containsEntry(obj.stable_entries,entry)
                error("KSSOLV:Matgenlab:PhaseDiagram:Unstable", ...
                    "Equilibrium reaction energy is available only for stable entries.");
            end
            if entry.is_element,value=0;return,end
            candidates=obj.stable_entries;
            candidates(cellfun(@(x)x==entry,candidates))=[];
            [~,alternative]=minimumDecomposition(candidates,entry.composition,obj.elements);
            if ~isfinite(alternative)
                error("KSSOLV:Matgenlab:PhaseDiagram:Decomposition", ...
                    "No alternative decomposition is available.");
            end
            value=entry.energy_per_atom-alternative;
        end
        function [decomposition,energy]=get_decomp_and_phase_separation_energy(obj,entry,varargin)
            options=struct(space_limit=200,stable_only=false,tols=1e-8, ...
                maxiter=1000,on_error="raise"); %#ok<NASGU>
            options=parseOptions(options,varargin);
            try
                obj.pd_coords(entry.composition);
            catch exception
                [decomposition,energy]=handleDecompError(entry,options.on_error, ...
                    "Unable to get decomposition",exception);
                return
            end
            if entry.is_element
                [decomposition,energy]=obj.get_decomp_and_e_above_hull( ...
                    entry,"allow_negative",true,"on_error",options.on_error);
                return
            end
            candidates=obj.qhull_entries;
            if options.stable_only,candidates=obj.stable_entries;end
            target=entry.composition.fractional_composition;
            keep=true(1,numel(candidates));
            for ii=1:numel(candidates)
                keep(ii)=~(candidates{ii}.composition.fractional_composition==target);
            end
            candidates=candidates(keep);
            [decomposition,alternative]=minimumDecomposition(candidates,entry.composition,obj.elements);
            if isempty(decomposition)
                [decomposition,energy]=obj.get_decomp_and_e_above_hull( ...
                    entry,"allow_negative",true,"on_error",options.on_error);
            else
                energy=entry.energy_per_atom-alternative;
            end
        end
        function value=get_phase_separation_energy(obj,entry,varargin)
            [~,value]=obj.get_decomp_and_phase_separation_energy(entry,varargin{:});
        end
        function value=get_composition_chempots(obj,composition)
            facets=obj.facetsContaining(composition);
            if isempty(facets)
                error("KSSOLV:Matgenlab:PhaseDiagram:NoFacet","No facet found.");
            end
            value=obj.facetChempots(facets{1});
        end
        function value=get_all_chempots(obj,composition)
            facets=obj.facetsContaining(composition);
            value=repmat(struct(name="",chempots=cell(0,2)),1,numel(facets));
            for ii=1:numel(facets)
                names=cellfun(@entryName,obj.qhull_entries(facets{ii}));
                value(ii)=struct(name=strjoin(names,"-"), ...
                    chempots={obj.facetChempots(facets{ii})});
            end
        end
        function value=get_transition_chempots(obj,element)
            element=kssolv.analysis.matgenlab.core.getElSp(element);
            index=find(cellfun(@(x)x.symbol==element.symbol,obj.elements),1);
            if isempty(index)
                error("KSSOLV:Matgenlab:PhaseDiagram:Element", ...
                    "Element is not in the phase diagram.");
            end
            values=zeros(1,numel(obj.facets));
            for ii=1:numel(obj.facets)
                pots=obj.facetChempots(obj.facets{ii});
                values(ii)=pots{index,2};
            end
            values=sort(values,"descend");value=[];
            for item=values
                if isempty(value)||abs(item-value(end))>obj.numerical_tol
                    value(end+1)=item; %#ok<AGROW>
                end
            end
        end
        function compositions=get_critical_compositions(obj,comp1,comp2)
            comp1=asComposition(comp1);comp2=asComposition(comp2);
            c1=obj.pd_coords(comp1);c2=obj.pd_coords(comp2);
            if isequal(c1,c2),compositions={comp1.copy(),comp2.copy()};return,end
            intersections=[c1;c2];
            for simplex=obj.simplexes
                points=simplex{1}.line_intersection(c1,c2);
                intersections=[intersections;points]; %#ok<AGROW>
            end
            direction=c2-c1;distance=norm(direction);unit=direction/distance;
            projection=(intersections-c1)*unit.';
            projection=projection(projection>=-obj.numerical_tol& ...
                projection<=distance+obj.numerical_tol);
            projection=sort(projection);projection=projection([true; ...
                diff(projection)>obj.numerical_tol]);
            x=max(0,min(1,projection/distance));
            n1=comp1.num_atoms;n2=comp2.num_atoms;
            xRaw=x*n1./(n2+x*(n1-n2));
            xRaw=max(0,min(1,xRaw));
            compositions=cell(1,numel(xRaw));
            for ii=1:numel(xRaw)
                compositions{ii}=comp1*(1-xRaw(ii))+comp2*xRaw(ii);
            end
        end
        function value=get_element_profile(obj,element,composition,compTol)
            if nargin<4,compTol=1e-5;end
            element=kssolv.analysis.matgenlab.core.getElSp(element);
            composition=asComposition(composition);
            other=composition-kssolv.analysis.matgenlab.core.Composition( ...
                {element,composition(element)});
            elementComp=kssolv.analysis.matgenlab.core.Composition(element.symbol);
            critical=obj.get_critical_compositions(elementComp,other);
            value=repmat(struct(chempot=0,evolution=0,element_reference=[], ...
                reaction=[],entries={{}},critical_composition=[]),1,max(0,numel(critical)-1));
            for ii=2:numel(critical)
                decomposition=obj.get_decomposition(critical{ii});
                entries=decomposition(:,1).';
                products=cellfun(@(x)x.composition,entries,"UniformOutput",false);
                reaction=kssolv.analysis.matgenlab.analysis.Reaction( ...
                    {composition},[products,{elementComp}]);
                reaction.normalize_to(composition);
                coeff=reaction.get_coeff(elementComp);
                probe=critical{ii}+elementComp*compTol;
                pots=obj.get_composition_chempots(probe);
                value(ii-1)=struct(chempot=getPot(pots,element), ...
                    evolution=-coeff,element_reference=getRef(obj.el_refs,element), ...
                    reaction=reaction,entries={entries},critical_composition=critical{ii});
            end
        end
        function ranges=get_chempot_range_map(obj,elements,referenced,joggle) %#ok<INUSD>
            if nargin<3,referenced=true;end
            if nargin<4,joggle=true;end
            if ~iscell(elements),elements=num2cell(elements);end
            elements=cellfun(@(x)kssolv.analysis.matgenlab.core.getElSp(x), ...
                elements,"UniformOutput",false);
            allPots=zeros(numel(obj.facets),obj.dim);
            for ii=1:numel(obj.facets)
                pots=obj.facetChempots(obj.facets{ii});
                allPots(ii,:)=cell2mat(pots(:,2)).';
            end
            indices=zeros(1,numel(elements));refs=zeros(1,numel(elements));
            for ii=1:numel(elements)
                indices(ii)=find(cellfun(@(x)x.symbol==elements{ii}.symbol,obj.elements),1);
                if referenced,refs(ii)=getRef(obj.el_refs,elements{ii}).energy_per_atom;end
            end
            ranges=cell(0,2);
            for aa=1:numel(obj.facets)
                for bb=aa+1:numel(obj.facets)
                    common=intersect(obj.facets{aa},obj.facets{bb});
                    if numel(common)==numel(elements)
                        coords=[allPots(aa,indices)-refs;allPots(bb,indices)-refs];
                        simplex=kssolv.analysis.matgenlab.util.Simplex(coords);
                        for index=common
                            row=find(cellfun(@(x)x==obj.qhull_entries{index},ranges(:,1)),1);
                            if isempty(row)
                                ranges(end+1,:)={obj.qhull_entries{index},{simplex}}; %#ok<AGROW>
                            else
                                ranges{row,2}{end+1}=simplex;
                            end
                        end
                    end
                end
            end
        end
        function value=getmu_vertices_stability_phase(obj,targetComp,dependent,tolerance)
            if nargin<4,tolerance=.01;end
            [value,~]=obj.stabilityVertices(targetComp,dependent,tolerance);
        end
        function value=get_chempot_range_stability_phase(obj,targetComp,openElement)
            [vertices,elements]=obj.stabilityVertices(targetComp,openElement,.01);
            if isempty(vertices)
                error("KSSOLV:Matgenlab:PhaseDiagram:Stability", ...
                    "Target phase has no chemical-potential range.");
            end
            value=cell(numel(obj.elements),2);
            for ii=1:numel(obj.elements)
                vals=zeros(1,numel(vertices));
                for jj=1:numel(vertices),vals(jj)=getPot(vertices{jj},obj.elements{ii});end
                value(ii,:)={obj.elements{ii},[min(vals),max(vals)]};
            end
        end
        function value=get_plot(obj,varargin)
            options=struct(show_unstable=.2,backend="plotly",ternary_style="2d", ...
                label_stable=true,label_unstable=true,ordering=[], ...
                energy_colormap=[],process_attributes=false,ax=[], ...
                label_uncertainties=false,fill=true);
            options=parseOptions(options,varargin);
            plotter=kssolv.analysis.matgenlab.analysis.PDPlotter(obj, ...
                "show_unstable",options.show_unstable,"backend",options.backend, ...
                "ternary_style",options.ternary_style);
            value=plotter.get_plot("label_stable",options.label_stable, ...
                "label_unstable",options.label_unstable,"ordering",options.ordering, ...
                "energy_colormap",options.energy_colormap, ...
                "process_attributes",options.process_attributes,"ax",options.ax, ...
                "label_uncertainties",options.label_uncertainties,"fill",options.fill);
        end
        function data=as_dict(obj)
            data=struct(x_module="pymatgen.analysis.phase_diagram", ...
                x_class=classLeaf(obj), ...
                elements={cellfun(@(x)char(x.symbol),obj.elements,"UniformOutput",false)}, ...
                all_entries={cellfun(@(x)x.as_dict(),obj.all_entries,"UniformOutput",false)}, ...
                computed_data=obj.serializableComputed());
        end
        function data=asDict(obj),data=obj.as_dict();end
        function text=toJSON(obj,varargin)
            pretty=false;
            if ~isempty(varargin),pretty=logical(varargin{end});end
            text=jsonencode(obj.as_dict(),PrettyPrint=pretty);
        end
        function text=char(obj)
            names=sort(cellfun(@entryName,obj.stable_entries));
            symbols=cellfun(@(x)x.symbol,obj.elements);
            text=sprintf("%s phase diagram\n%d stable phases: \n%s", ...
                strjoin(symbols,"-"),numel(names),strjoin(names,", "));
        end
    end
    methods (Static)
        function obj=from_dict(data)
            raw=data.all_entries;if isstruct(raw),raw=num2cell(raw);end
            entries=cellfun(@decodeEntry,raw,"UniformOutput",false);
            elements=cellfun(@(x)kssolv.analysis.matgenlab.core.getElSp(x), ...
                data.elements,"UniformOutput",false);
            obj=kssolv.analysis.matgenlab.analysis.PhaseDiagram(entries,elements);
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab.analysis.PhaseDiagram.from_dict(data);end
    end
    methods (Access=protected)
        function compute(obj)
            minEntries={};allEntries={};
            compositionKeys=cellfun(@(x)string(x.composition.reduced_formula),obj.entries);
            uniqueKeys=unique(compositionKeys,"stable");
            for key=uniqueKeys
                group=obj.entries(compositionKeys==key);
                [~,order]=sort(cellfun(@(x)x.energy_per_atom,group));
                group=group(order);minEntries{end+1}=group{1}; %#ok<AGROW>
                allEntries=[allEntries,group]; %#ok<AGROW>
            end
            obj.all_entries=allEntries;
            refs=cell(0,2);
            for entry=minEntries
                if entry{1}.composition.is_element
                    el=entry{1}.composition.elements{1};
                    row=find(cellfun(@(x)x.symbol==el.symbol,refs(:,1)),1);
                    if isempty(row),refs(end+1,:)={el,entry{1}}; %#ok<AGROW>
                    elseif entry{1}.energy_per_atom<refs{row,2}.energy_per_atom
                        refs{row,2}=entry{1};
                    end
                end
            end
            missing=cellfun(@(x)~any(cellfun(@(y)y.symbol==x.symbol,refs(:,1))),obj.elements);
            if any(missing)
                error("KSSOLV:Matgenlab:PhaseDiagram:MissingTerminals", ...
                    "Missing terminal entries for elements %s.", ...
                    strjoin(cellfun(@(x)x.symbol,obj.elements(missing)),"', '"));
            end
            obj.el_refs=refs;
            data=zeros(numel(minEntries),obj.dim+1);
            for ii=1:numel(minEntries)
                for jj=1:obj.dim
                    data(ii,jj)=minEntries{ii}.composition.get_atomic_fraction(obj.elements{jj});
                end
                data(ii,end)=minEntries{ii}.energy_per_atom;
            end
            form=zeros(size(data,1),1);
            for ii=1:size(data,1)
                refEnergy=0;
                for jj=1:obj.dim
                    refEnergy=refEnergy+data(ii,jj)*getRef(refs,obj.elements{jj}).energy_per_atom;
                end
                form(ii)=data(ii,end)-refEnergy;
            end
            selected=find(form < -obj.formation_energy_tol);
            for ii=1:size(refs,1)
                selected(end+1)=find(cellfun(@(x)samePhaseEntry(x,refs{ii,2}),minEntries),1); %#ok<AGROW>
            end
            selected=unique(selected,"stable");
            obj.qhull_entries=minEntries(selected);
            obj.qhull_data=[data(selected,2:obj.dim),data(selected,end)];
            extra=ones(1,obj.dim)/obj.dim;
            extra(end)=max(obj.qhull_data(:,end))+1;
            obj.qhull_data(end+1,:)=extra;
            if obj.dim==1
                [~,index]=min(obj.qhull_data(:,end));
                obj.facets={index};obj.stable_indices=index;obj.simplexes={};
            else
                raw=kssolv.analysis.matgenlab.analysis.get_facets(obj.qhull_data);
                obj.facets={};
                extraIndex=size(obj.qhull_data,1);
                for ii=1:size(raw,1)
                    facet=raw(ii,:);
                    if any(facet==extraIndex),continue,end
                    matrix=obj.qhull_data(facet,:);matrix(:,end)=1;
                    if abs(det(matrix))>1e-14
                        obj.facets{end+1}=facet; %#ok<AGROW>
                    end
                end
                if isempty(obj.facets)
                    % Coplanar terminal-only systems have one lower facet.
                    obj.facets={1:min(obj.dim,numel(obj.qhull_entries))};
                end
                obj.stable_indices=unique([obj.facets{:}]);
                obj.simplexes=cellfun(@(facet) ...
                    kssolv.analysis.matgenlab.util.Simplex( ...
                    obj.qhull_data(facet,1:end-1)),obj.facets,"UniformOutput",false);
            end
            obj.computed_data=struct(facets={obj.facets}, ...
                qhull_data=obj.qhull_data,all_entries={obj.all_entries}, ...
                el_refs={obj.el_refs},qhull_entries={obj.qhull_entries});
        end
        function restoreComputed(obj,data)
            % MATLAB serialization carries entries directly; recomputation also
            % validates old or partially serialized computed_data.
            if isfield(data,"all_entries")&&all(cellfun(@isobject,data.all_entries))
                obj.entries=data.all_entries;
            end
            obj.compute();
        end
        function facets=facetsContaining(obj,composition)
            if obj.dim==1,facets=obj.facets;return,end
            coord=obj.pd_coords(asComposition(composition));facets={};
            for ii=1:numel(obj.simplexes)
                if obj.simplexes{ii}.in_simplex(coord,obj.numerical_tol/10)
                    facets{end+1}=obj.facets{ii}; %#ok<AGROW>
                end
            end
        end
        function value=facetChempots(obj,facet)
            matrix=zeros(numel(facet),obj.dim);energies=zeros(numel(facet),1);
            for ii=1:numel(facet)
                entry=obj.qhull_entries{facet(ii)};
                for jj=1:obj.dim
                    matrix(ii,jj)=entry.composition.get_atomic_fraction(obj.elements{jj});
                end
                energies(ii)=entry.energy_per_atom;
            end
            potentials=matrix\energies;
            value=[obj.elements(:),num2cell(potentials)];
        end
        function [vertices,independent]=stabilityVertices(obj,targetComp,dependent,tolerance)
            targetComp=asComposition(targetComp);
            dependent=kssolv.analysis.matgenlab.core.getElSp(dependent);
            independent=obj.elements(~cellfun(@(x)x.symbol==dependent.symbol,obj.elements));
            ranges=obj.get_chempot_range_map(independent,true);
            row=find(cellfun(@(x)x.composition.reduced_composition== ...
                targetComp.reduced_composition,ranges(:,1)),1);
            vertices={};if isempty(row),return,end
            refs=cellfun(@(x)getRef(obj.el_refs,x).energy_per_atom,independent);
            targetEntry=ranges{row,1};
            multiplier=targetEntry.composition(dependent)/targetComp(dependent);
            energy=targetEntry.energy/multiplier;
            for simplex=ranges{row,2}
                for coordinate=simplex{1}.coords.'
                    pots=[independent(:),num2cell(coordinate(:)+refs(:))];
                    remainder=energy;
                    for ii=1:numel(independent)
                        remainder=remainder-targetComp(independent{ii})*pots{ii,2};
                    end
                    pots(end+1,:)={dependent,remainder/targetComp(dependent)}; %#ok<AGROW>
                    duplicate=false;
                    for old=vertices
                        duplicate=all(cellfun(@(el)abs(getPot(old{1},el)- ...
                            getPot(pots,el))<=tolerance,obj.elements));
                        if duplicate,break,end
                    end
                    if ~duplicate,vertices{end+1}=pots;end %#ok<AGROW>
                end
            end
        end
        function data=serializableComputed(obj)
            data=struct(facets={obj.facets},qhull_data=obj.qhull_data);
        end
    end
end

function elements=uniqueElements(input)
elements={};symbols=strings(1,0);
for item=input
    symbol=string(item{1}.symbol);
    if ~any(symbols==symbol),symbols(end+1)=symbol;elements{end+1}=item{1};end %#ok<AGROW>
end
end
function [decomposition,energy]=minimumDecomposition(entries,composition,elements)
decomposition={};energy=inf;if isempty(entries),return,end
target=zeros(numel(elements),1);
for ii=1:numel(elements),target(ii)=composition.get_atomic_fraction(elements{ii});end
matrix=zeros(numel(elements),numel(entries));cost=zeros(numel(entries),1);
for jj=1:numel(entries)
    for ii=1:numel(elements)
        matrix(ii,jj)=entries{jj}.composition.get_atomic_fraction(elements{ii});
    end
    cost(jj)=entries{jj}.energy_per_atom;
end
try
    opts=optimoptions("linprog","Display","none","Algorithm","dual-simplex-highs");
    [weights,value,flag]=linprog(cost,[],[],matrix,target, ...
        zeros(numel(entries),1),[],opts);
catch
    [weights,value,flag]=enumeratedLP(matrix,target,cost);
end
if flag<=0||isempty(weights),return,end
decomposition=cell(0,2);
for ii=1:numel(weights)
    if weights(ii)>1e-8,decomposition(end+1,:)={entries{ii},weights(ii)};end %#ok<AGROW>
end
energy=value;
end
function [best,bestEnergy,flag]=enumeratedLP(matrix,target,cost)
n=size(matrix,2);dim=size(matrix,1);best=[];bestEnergy=inf;flag=-1;
for count=1:min(dim,n)
    combos=nchoosek(1:n,count);
    for ii=1:size(combos,1)
        which=combos(ii,:);weights=pinv(matrix(:,which))*target;
        if all(weights>=-1e-9)&&norm(matrix(:,which)*weights-target)<1e-7
            value=cost(which).'*weights;
            if value<bestEnergy
                best=zeros(n,1);best(which)=weights;bestEnergy=value;flag=1;
            end
        end
    end
end
end
function [decomposition,energy]=handleDecompError(entry,mode,prefix,exception)
mode=string(mode);message=sprintf("%s for %s.",prefix,char(entry));
if mode=="raise"
    if isempty(exception),error("KSSOLV:Matgenlab:PhaseDiagram:Decomposition",message);
    else,throw(addCause(MException( ...
            "KSSOLV:Matgenlab:PhaseDiagram:Decomposition",message),exception));end
elseif mode=="warn",warning("KSSOLV:Matgenlab:PhaseDiagram:Decomposition",message);
end
decomposition=[];energy=[];
end
function value=getRef(refs,element)
row=find(cellfun(@(x)x.symbol==element.symbol,refs(:,1)),1);
if isempty(row),error("KSSOLV:Matgenlab:PhaseDiagram:Reference","Missing elemental reference.");end
value=refs{row,2};
end
function value=getPot(pots,element)
row=find(cellfun(@(x)x.symbol==element.symbol,pots(:,1)),1);value=pots{row,2};
end
function value=entryName(entry)
if isprop(entry,"name"),value=string(entry.name);else,value=entry.reduced_formula;end
end
function tf=containsEntry(entries,entry)
tf=any(cellfun(@(x)samePhaseEntry(x,entry),entries));
end
function tf=samePhaseEntry(first,second)
tf=isobject(first)&&isobject(second)&&isprop(first,"composition")&& ...
    isprop(second,"composition")&&isprop(first,"energy")&& ...
    isprop(second,"energy")&&first.composition==second.composition&& ...
    abs(first.energy-second.energy)<=1e-12;
end
function value=asComposition(input)
if isa(input,"kssolv.analysis.matgenlab.core.Composition"),value=input;
else,value=kssolv.analysis.matgenlab.core.Composition(input);end
end
function value=decodeEntry(data)
if isobject(data),value=data;return,end
cls="";if isfield(data,"x_class"),cls=string(data.x_class);end
switch cls
    case "ComputedEntry",value=kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(data);
    case "ComputedStructureEntry",value=kssolv.analysis.matgenlab.core.ComputedStructureEntry.from_dict(data);
    case "PDEntry",value=kssolv.analysis.matgenlab.analysis.PDEntry.from_dict(data);
    case "GrandPotPDEntry",value=kssolv.analysis.matgenlab.analysis.GrandPotPDEntry.from_dict(data);
    case "TransformedPDEntry",value=kssolv.analysis.matgenlab.analysis.TransformedPDEntry.from_dict(data);
    otherwise,value=kssolv.analysis.matgenlab.core.Entry.from_dict(data);
end
end
function output=parseOptions(output,input)
names=fieldnames(output);position=1;ii=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&& ...
            any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};ii=ii+2;
    else
        if position>numel(names),break,end
        output.(names{position})=input{ii};position=position+1;ii=ii+1;
    end
end
end
function name=classLeaf(obj)
parts=split(string(class(obj)),".");name=parts(end);
end
