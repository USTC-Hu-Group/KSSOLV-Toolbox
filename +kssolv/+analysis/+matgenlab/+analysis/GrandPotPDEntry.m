classdef GrandPotPDEntry < kssolv.analysis.matgenlab.analysis.PDEntry
    %#ok<*ALIGN>
    %GRANDPOTPDENTRY Entry projected into a grand-potential composition space.
    properties
        original_entry
        original_comp
        chempots
        normalization_scale (1,1) double=1
    end
    properties (Dependent,SetAccess=private)
        chemical_energy
    end
    methods
        function obj=GrandPotPDEntry(entry,chempots,name)
            if nargin==0
                entry=kssolv.analysis.matgenlab.analysis.PDEntry( ...
                    kssolv.analysis.matgenlab.core.Composition(),0);
                chempots=cell(0,2);name="";emptyConstruction=true;
            else
                emptyConstruction=false;
            end
            if nargin<3||strlength(string(name))==0,name=entryName(entry);end
            obj@kssolv.analysis.matgenlab.analysis.PDEntry( ...
                entry.composition,entry.energy,"name",name, ...
                "attribute",entryAttribute(entry));
            if emptyConstruction,return,end
            obj.original_entry=entry;
            obj.original_comp=entry.composition;
            obj.chempots=normalizeChempots(chempots);
        end
        function value=get.chemical_energy(obj)
            value=0;
            for ii=1:size(obj.chempots,1)
                value=value+obj.original_comp(obj.chempots{ii,1})*obj.chempots{ii,2};
            end
        end
        function value=effectiveComposition(obj)
            pairs=cell(0,2);
            for el=obj.original_comp.elements
                if ~any(cellfun(@(x)string(x.symbol)==string(el{1}.symbol),obj.chempots(:,1)))
                    pairs(end+1,:)={el{1},obj.original_comp(el{1})}; %#ok<AGROW>
                end
            end
            value=kssolv.analysis.matgenlab.core.Composition(pairs)*obj.normalization_scale;
        end
        function value=effectiveEnergy(obj)
            value=(obj.original_entry.energy-obj.chemical_energy)*obj.normalization_scale;
        end
        function value=normalize(obj,mode)
            if nargin<2,mode="formula_unit";end
            if string(mode)=="atom",factor=obj.composition.num_atoms;
            else,[~,factor]=obj.composition.get_reduced_composition_and_factor();end
            value=obj;value.normalization_scale=value.normalization_scale/factor;
        end
        function data=as_dict(obj)
            pots=cell(size(obj.chempots,1),2);
            for ii=1:size(pots,1)
                pots{ii,1}=char(obj.chempots{ii,1}.symbol);pots{ii,2}=obj.chempots{ii,2};
            end
            data=struct(x_module="pymatgen.analysis.phase_diagram", ...
                x_class="GrandPotPDEntry",entry=obj.original_entry.as_dict(), ...
                chempots={pots},name=obj.name,normalization_scale=obj.normalization_scale);
        end
        function data=asDict(obj),data=obj.as_dict();end
        function text=char(obj)
            pieces=strings(1,size(obj.chempots,1));
            for ii=1:numel(pieces)
                pieces(ii)=sprintf("mu_%s = %.4f",obj.chempots{ii,1}.symbol,obj.chempots{ii,2});
            end
            text=sprintf("GrandPotPDEntry with original composition %s, energy = %.4f, chempots = %s", ...
                obj.original_entry.composition.formula,obj.original_entry.energy,strjoin(pieces,", "));
        end
    end
    methods (Static)
        function obj=from_dict(data)
            obj=kssolv.analysis.matgenlab.analysis.GrandPotPDEntry( ...
                decodeEntry(data.entry),data.chempots,data.name);
            if isfield(data,"normalization_scale"),obj.normalization_scale=data.normalization_scale;end
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab.analysis.GrandPotPDEntry.from_dict(data);end
    end
end

function value=entryName(entry)
if isprop(entry,"name")&&strlength(string(entry.name))>0,value=entry.name;
else,value=entry.reduced_formula;end
end
function value=entryAttribute(entry)
if isprop(entry,"attribute"),value=entry.attribute;else,value=[];end
end
function value=normalizeChempots(input)
if isa(input,"containers.Map")
    keys_=input.keys;value=cell(numel(keys_),2);
    for ii=1:numel(keys_),value(ii,:)={keys_{ii},input(keys_{ii})};end
elseif isstruct(input)
    keys_=fieldnames(input);value=cell(numel(keys_),2);
    for ii=1:numel(keys_),value(ii,:)={keys_{ii},input.(keys_{ii})};end
elseif iscell(input),value=input;
else,error("KSSOLV:Matgenlab:GrandPotPDEntry:Chempots","Unsupported chemical-potential mapping.");end
for ii=1:size(value,1)
    value{ii,1}=kssolv.analysis.matgenlab.core.getElSp(value{ii,1});
    value{ii,2}=double(value{ii,2});
end
end
function value=decodeEntry(data)
if isobject(data),value=data;return,end
cls="";if isfield(data,"x_class"),cls=string(data.x_class);end
switch cls
    case "ComputedEntry",value=kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(data);
    case "PDEntry",value=kssolv.analysis.matgenlab.analysis.PDEntry.from_dict(data);
    otherwise,value=kssolv.analysis.matgenlab.core.Entry.from_dict(data);
end
end
