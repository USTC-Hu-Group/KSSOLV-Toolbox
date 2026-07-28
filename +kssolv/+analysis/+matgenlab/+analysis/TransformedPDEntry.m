classdef TransformedPDEntry < kssolv.analysis.matgenlab.analysis.PDEntry
    %#ok<*ALIGN>
    %TRANSFORMEDPDENTRY Entry represented in compound-terminal coordinates.
    properties (Constant)
        amount_tol=1e-5
    end
    properties
        original_entry
        sp_mapping cell=cell(0,2)
        terminal_coefficients (1,:) double=[]
        normalization_scale (1,1) double=1
    end
    methods
        function obj=TransformedPDEntry(entry,spMapping,name)
            if nargin==0
                entry=kssolv.analysis.matgenlab.analysis.PDEntry( ...
                    kssolv.analysis.matgenlab.core.Composition(),0);
                spMapping=cell(0,2);name="";emptyConstruction=true;
            else
                emptyConstruction=false;
            end
            if nargin<3||strlength(string(name))==0,name=entryName(entry);end
            obj@kssolv.analysis.matgenlab.analysis.PDEntry( ...
                entry.composition,entry.energy,"name",name,"attribute",entryAttribute(entry));
            if emptyConstruction,return,end
            obj.original_entry=entry;
            obj.sp_mapping=normalizeMapping(spMapping);
            [matrix,target]=compositionSystem(obj.sp_mapping(:,1),entry.composition);
            coeff=pinv(matrix)*target;
            if norm(matrix*coeff-target)>1e-7||any(coeff < -obj.amount_tol)
                throw(kssolv.analysis.matgenlab.analysis.TransformedPDEntryError( ...
                    "Only reactions with positive amounts of reactants allowed"));
            end
            obj.terminal_coefficients=reshape(coeff,1,[]);
        end
        function value=effectiveComposition(obj)
            pairs=cell(0,2);
            for ii=1:numel(obj.terminal_coefficients)
                if obj.terminal_coefficients(ii)>obj.amount_tol
                    pairs(end+1,:)={obj.sp_mapping{ii,2}, ...
                        obj.terminal_coefficients(ii)*obj.normalization_scale}; %#ok<AGROW>
                end
            end
            value=kssolv.analysis.matgenlab.core.Composition(pairs);
        end
        function value=effectiveEnergy(obj)
            value=obj.original_entry.energy*obj.normalization_scale;
        end
        function value=normalize(obj,mode)
            if nargin<2,mode="formula_unit";end
            if string(mode)=="atom",factor=obj.composition.num_atoms;
            else,[~,factor]=obj.composition.get_reduced_composition_and_factor();end
            value=obj;value.normalization_scale=value.normalization_scale/factor;
        end
        function data=as_dict(obj)
            mapping=cell(size(obj.sp_mapping,1),2);
            for ii=1:size(mapping,1)
                mapping{ii,1}=obj.sp_mapping{ii,1}.as_dict();
                mapping{ii,2}=obj.sp_mapping{ii,2}.as_dict();
            end
            data=obj.original_entry.as_dict();
            data.sp_mapping=mapping;
            data.normalization_scale=obj.normalization_scale;
        end
        function data=asDict(obj),data=obj.as_dict();end
        function text=char(obj)
            text=sprintf("TransformedPDEntry %s with original composition %s, energy = %.4f", ...
                obj.composition.formula,obj.original_entry.composition.formula,obj.original_entry.energy);
        end
    end
    methods (Static)
        function obj=from_dict(data)
            mapping=data.sp_mapping;
            for ii=1:size(mapping,1)
                mapping{ii,1}=kssolv.analysis.matgenlab.core.Composition.from_dict(mapping{ii,1});
                mapping{ii,2}=kssolv.analysis.matgenlab.core.DummySpecies.from_dict(mapping{ii,2});
            end
            data=rmfield(data,"sp_mapping");
            scale=1;if isfield(data,"normalization_scale")
                scale=data.normalization_scale;data=rmfield(data,"normalization_scale");
            end
            obj=kssolv.analysis.matgenlab.analysis.TransformedPDEntry(decodeEntry(data),mapping);
            obj.normalization_scale=scale;
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab.analysis.TransformedPDEntry.from_dict(data);end
    end
end

function value=normalizeMapping(input)
if iscell(input),value=input;
elseif isstruct(input)
    fields=fieldnames(input);value=cell(numel(fields),2);
    for ii=1:numel(fields),value(ii,:)={fields{ii},input.(fields{ii})};end
else,error("KSSOLV:Matgenlab:TransformedPDEntry:Mapping","Unsupported species mapping.");end
for ii=1:size(value,1)
    value{ii,1}=kssolv.analysis.matgenlab.core.Composition(value{ii,1});
    if ~isa(value{ii,2},"kssolv.analysis.matgenlab.core.DummySpecies")
        value{ii,2}=kssolv.analysis.matgenlab.core.DummySpecies(value{ii,2});
    end
end
end
function [matrix,target]=compositionSystem(terminals,targetComp)
symbols=targetComp.chemical_system_set;
for ii=1:numel(terminals),symbols=union(symbols,terminals{ii}.chemical_system_set,"stable");end
matrix=zeros(numel(symbols),numel(terminals));target=zeros(numel(symbols),1);
for ii=1:numel(symbols)
    target(ii)=targetComp(symbols(ii));
    for jj=1:numel(terminals),matrix(ii,jj)=terminals{jj}(symbols(ii));end
end
end
function value=entryName(entry)
if isprop(entry,"name")&&strlength(string(entry.name))>0,value=entry.name;
else,value=entry.reduced_formula;end
end
function value=entryAttribute(entry)
if isprop(entry,"attribute"),value=entry.attribute;else,value=[];end
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
