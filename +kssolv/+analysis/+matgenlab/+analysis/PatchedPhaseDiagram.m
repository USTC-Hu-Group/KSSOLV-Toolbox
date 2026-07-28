classdef PatchedPhaseDiagram < kssolv.analysis.matgenlab.analysis.PhaseDiagram
    %#ok<*MSNU,*ALIGN>
    %PATCHEDPHASEDIAGRAM Phase-diagram patches for sparse high-dimensional spaces.
    properties
        keep_all_spaces (1,1) logical=false
        spaces cell=cell(1,0)
        pds cell=cell(0,2)
    end
    methods
        function obj=PatchedPhaseDiagram(entries,elements,varargin)
            if nargin==0
                entries={kssolv.analysis.matgenlab.analysis.PDEntry("H",0)};
                elements={"H"};emptyConstruction=true;
            else
                emptyConstruction=false;
            end
            if nargin<2,elements=[];end
            options=struct(keep_all_spaces=false,verbose=false,computed_data=[]); %#ok<NASGU>
            options=parseOptions(options,varargin);
            obj@kssolv.analysis.matgenlab.analysis.PhaseDiagram(entries,elements);
            obj.keep_all_spaces=logical(options.keep_all_spaces);
            if emptyConstruction,return,end
            raw={};
            for entry=obj.qhull_entries
                symbols=entry{1}.composition.chemical_system_set;
                if numel(symbols)>1,raw{end+1}=symbols;end %#ok<AGROW>
            end
            obj.spaces=obj.remove_redundant_spaces(raw,obj.keep_all_spaces);
            obj.pds=cell(numel(obj.spaces),2);
            for ii=1:numel(obj.spaces)
                space=obj.spaces{ii};subset={};
                for entry=obj.qhull_entries
                    if all(ismember(entry{1}.composition.chemical_system_set,space))
                        subset{end+1}=entry{1}; %#ok<AGROW>
                    end
                end
                obj.pds(ii,:)={space,kssolv.analysis.matgenlab.analysis. ...
                    PhaseDiagram(subset,cellfun(@(x) ...
                    kssolv.analysis.matgenlab.core.getElSp(x),cellstr(space), ...
                    "UniformOutput",false))};
            end
        end
        function value=length(obj),value=numel(obj.spaces);end
        function text=char(obj)
            text=sprintf("PatchedPhaseDiagram covering %d sub-spaces",numel(obj.spaces));
        end
        function pd=get_pd_for_entry(obj,entry)
            if isa(entry,"kssolv.analysis.matgenlab.core.Composition")
                symbols=entry.chemical_system_set;
            else,symbols=entry.composition.chemical_system_set;end
            exact=find(cellfun(@(x)isequal(sort(x),sort(symbols)),obj.pds(:,1)),1);
            if isempty(exact)
                exact=find(cellfun(@(x)all(ismember(symbols,x)),obj.pds(:,1)),1);
            end
            if isempty(exact)
                error("KSSOLV:Matgenlab:PatchedPhaseDiagram:NoPatch", ...
                    "No suitable PhaseDiagrams found for the requested entry.");
            end
            pd=obj.pds{exact,2};
        end
        function decomposition=get_decomposition(obj,composition)
            % Full-hull fallback is mathematically identical and stitches
            % compositions that span more than one sparse patch.
            decomposition=get_decomposition@kssolv.analysis.matgenlab.analysis. ...
                PhaseDiagram(obj,composition);
        end
        function value=get_equilibrium_reaction_energy(obj,entry)
            value=get_equilibrium_reaction_energy@kssolv.analysis.matgenlab. ...
                analysis.PhaseDiagram(obj,entry);
        end
        function [decomposition,energy]=get_decomp_and_e_above_hull(obj,entry,varargin)
            if ~any(strcmpi(string(varargin(1:2:end)),"check_stable"))
                varargin=[varargin,{"check_stable",false}];
            end
            [decomposition,energy]=get_decomp_and_e_above_hull@ ...
                kssolv.analysis.matgenlab.analysis.PhaseDiagram(obj,entry,varargin{:});
        end
        function [newObj,info]=update(obj,newEntries,varargin)
            options=struct(verbose=false,return_info=false,on_new_el_ref="raise"); %#ok<NASGU>
            options=parseOptions(options,varargin);
            info=struct(updated_spaces={{}},new_spaces={{}}, ...
                new_stable_entries={{}},removed_stable_entries={{}});
            if isempty(newEntries),newObj=obj;return,end
            if ~iscell(newEntries),newEntries=num2cell(newEntries);end
            known=cellfun(@(x)x.symbol,obj.elements);
            keepNew=true(1,numel(newEntries));
            for index=1:numel(newEntries)
                entry=newEntries{index};
                symbols=cellfun(@(x)x.symbol,entry.elements);
                if any(~ismember(symbols,known))
                    error("KSSOLV:Matgenlab:PatchedPhaseDiagram:NewElement", ...
                        "update() does not support adding new elements.");
                end
                if entry.is_element
                    old=getRef(obj.el_refs,entry.composition.elements{1});
                    if entry.energy_per_atom<old.energy_per_atom
                        if string(options.on_new_el_ref)=="raise"
                            error("KSSOLV:Matgenlab:PatchedPhaseDiagram:ElementReference", ...
                                "New elemental entry is lower than current el_ref.");
                        elseif string(options.on_new_el_ref)=="ignore"
                            keepNew(index)=false;
                        end
                    end
                end
            end
            valid=newEntries(keepNew);
            merged=[obj.all_entries,valid];
            newObj=kssolv.analysis.matgenlab.analysis.PatchedPhaseDiagram( ...
                merged,obj.elements,"keep_all_spaces",obj.keep_all_spaces);
            oldStable=obj.stable_entries;newStable=newObj.stable_entries;
            info.new_stable_entries=setDifference(newStable,oldStable);
            info.removed_stable_entries=setDifference(oldStable,newStable);
            oldSpaces=cellfun(@spaceKey,obj.spaces);newSpaces=cellfun(@spaceKey,newObj.spaces);
            info.new_spaces=newObj.spaces(~ismember(newSpaces,oldSpaces));
            info.updated_spaces=newObj.spaces(ismember(newSpaces,oldSpaces));
        end
        function data=as_dict(obj)
            data=struct(x_module="pymatgen.analysis.phase_diagram", ...
                x_class="PatchedPhaseDiagram", ...
                elements={cellfun(@(x)char(x.symbol),obj.elements,"UniformOutput",false)}, ...
                keep_all_spaces=obj.keep_all_spaces, ...
                computed_data=struct(all_entries={cellfun(@(x)x.as_dict(), ...
                obj.all_entries,"UniformOutput",false)},spaces={obj.spaces}));
        end
        function data=asDict(obj),data=obj.as_dict();end
        function get_composition_chempots(varargin),notImplemented("get_composition_chempots");end
        function get_all_chempots(varargin),notImplemented("get_all_chempots");end
        function get_transition_chempots(varargin),notImplemented("get_transition_chempots");end
        function get_critical_compositions(varargin),notImplemented("get_critical_compositions");end
        function get_element_profile(varargin),notImplemented("get_element_profile");end
        function get_chempot_range_map(varargin),notImplemented("get_chempot_range_map");end
        function getmu_vertices_stability_phase(varargin),notImplemented("getmu_vertices_stability_phase");end
        function get_chempot_range_stability_phase(varargin),notImplemented("get_chempot_range_stability_phase");end
    end
    methods (Static)
        function spaces=remove_redundant_spaces(spaces,keepAll)
            if nargin<2,keepAll=false;end
            if isempty(spaces),spaces={};return,end
            keys=cellfun(@spaceKey,spaces);[~,indices]=unique(keys,"stable");spaces=spaces(indices);
            [~,order]=sort(cellfun(@numel,spaces),"descend");spaces=spaces(order);
            if keepAll,return,end
            keep=true(1,numel(spaces));
            for ii=1:numel(spaces)
                for jj=1:ii-1
                    if all(ismember(spaces{ii},spaces{jj})),keep(ii)=false;break,end
                end
            end
            spaces=spaces(keep);
        end
        function obj=from_dict(data)
            raw=data.computed_data.all_entries;if isstruct(raw),raw=num2cell(raw);end
            entries=cellfun(@decodeEntry,raw,"UniformOutput",false);
            obj=kssolv.analysis.matgenlab.analysis.PatchedPhaseDiagram( ...
                entries,data.elements,"keep_all_spaces",data.keep_all_spaces);
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab.analysis.PatchedPhaseDiagram.from_dict(data);end
    end
end

function notImplemented(name)
error("KSSOLV:Matgenlab:PatchedPhaseDiagram:NotImplemented", ...
    "%s() is not implemented for PatchedPhaseDiagram, matching frozen upstream.",name);
end
function value=spaceKey(space),value=strjoin(sort(string(space)),"-");end
function value=getRef(refs,element)
row=find(cellfun(@(x)x.symbol==element.symbol,refs(:,1)),1);value=refs{row,2};
end
function output=setDifference(first,second)
output={};
for item=first
    if ~any(cellfun(@(x)sameEntry(x,item{1}),second)),output{end+1}=item{1};end %#ok<AGROW>
end
end
function tf=sameEntry(a,b)
tf=a.composition==b.composition&&abs(a.energy-b.energy)<=1e-12;
end
function value=decodeEntry(data)
if isobject(data),value=data;return,end
cls="";if isfield(data,"x_class"),cls=string(data.x_class);end
if cls=="ComputedEntry",value=kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(data);
elseif cls=="PDEntry",value=kssolv.analysis.matgenlab.analysis.PDEntry.from_dict(data);
else,value=kssolv.analysis.matgenlab.core.Entry.from_dict(data);end
end
function output=parseOptions(output,input)
names=fieldnames(output);position=1;ii=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&&any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};output.(key)=input{ii+1};ii=ii+2;
    else
        if position>numel(names),break,end
        output.(names{position})=input{ii};position=position+1;ii=ii+1;
    end
end
end
