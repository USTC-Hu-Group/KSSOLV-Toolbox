classdef ConversionElectrode < ...
        kssolv.analysis.matgenlab.apps.battery.AbstractElectrode
    %CONVERSIONELECTRODE Equilibrium conversion path from a phase diagram.
    properties
        initial_comp_formula (1,1) string = ""
    end
    properties (Dependent,SetAccess=private)
        initial_comp
    end
    methods
        function obj=ConversionElectrode(voltagePairs,workingIonEntry, ...
                initialCompFormula,frameworkFormula)
            if nargin==0
                voltagePairs={};workingIonEntry=[];initialCompFormula="";
                frameworkFormula="";emptyConstruction=true;
            else
                emptyConstruction=false;
            end
            obj@kssolv.analysis.matgenlab.apps.battery.AbstractElectrode( ...
                voltagePairs,workingIonEntry,frameworkFormula);
            if emptyConstruction,return,end
            obj.initial_comp_formula=string(initialCompFormula);
        end
        function value=get.initial_comp(obj)
            value=kssolv.analysis.matgenlab.core.Composition(obj.initial_comp_formula);
        end
        function electrodes=get_sub_electrodes(obj,adjacentOnly)
            if nargin<2,adjacentOnly=true;end
            electrodes={};count=obj.num_steps;
            if adjacentOnly
                ranges=[(1:count).',(1:count).'];
            else
                ranges=zeros(0,2);
                for first=1:count
                    for last=first:count
                        ranges(end+1,:)=[first,last]; %#ok<AGROW>
                    end
                end
            end
            for index=1:size(ranges,1)
                pairs=obj.voltage_pairs(ranges(index,1):ranges(index,2));
                electrodes{end+1}=kssolv.analysis.matgenlab.apps.battery. ...
                    ConversionElectrode(pairs,obj.working_ion_entry, ...
                    obj.initial_comp_formula,obj.framework_formula); %#ok<AGROW>
            end
        end
        function tf=is_super_electrode(obj,other)
            tf=true;
            for index=1:numel(other.voltage_pairs)
                target=reactionFormulaSet(other.voltage_pairs{index}.rxn);
                if ~any(cellfun(@(x)isequal(reactionFormulaSet(x.rxn),target), ...
                        obj.voltage_pairs))
                    tf=false;return
                end
            end
        end
        function tf=eq(obj,other)
            tf=isa(other,class(obj))&&obj.num_steps==other.num_steps&& ...
                obj.is_super_electrode(other);
        end
        function data=get_summary_dict(obj,printSubelectrodes)
            if nargin<2,printSubelectrodes=true;end
            data=get_summary_dict@kssolv.analysis.matgenlab.apps.battery. ...
                AbstractElectrode(obj,printSubelectrodes);
            data.reactions=cell(1,obj.num_steps);
            data.reactant_compositions={};seen=strings(1,0);
            for pair=1:obj.num_steps
                reaction=obj.voltage_pairs{pair}.rxn;
                data.reactions{pair}=char(reaction);
                for index=1:numel(reaction.all_comp)
                    comp=reaction.all_comp{index};
                    if abs(reaction.coeffs(index))>1e-5&& ...
                            comp.reduced_formula~=data.working_ion
                        key=string(comp.reduced_composition);
                        if ~any(seen==key)
                            seen(end+1)=key; %#ok<AGROW>
                            reduced=comp.reduced_composition;
                            data.reactant_compositions{end+1}= ...
                                reduced.as_dict();
                        end
                    end
                end
            end
        end
        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.apps.battery.AbstractElectrode(obj);
            data.x_module="pymatgen.apps.battery.conversion_battery";
            data.x_class="ConversionElectrode";
            data.initial_comp_formula=obj.initial_comp_formula;
        end
    end
    methods (Static)
        function obj=from_composition_and_pd(comp,diagram,workingIonSymbol,allowUnstable)
            if nargin<3,workingIonSymbol="Li";end
            if nargin<4,allowUnstable=false;end
            if ~isa(comp,"kssolv.analysis.matgenlab.core.Composition")
                comp=kssolv.analysis.matgenlab.core.Composition(comp);
            end
            entry=[];workingEntry=[];
            for index=1:numel(diagram.stable_entries)
                candidate=diagram.stable_entries{index};
                if candidate.reduced_formula==comp.reduced_formula,entry=candidate;
                elseif candidate.is_element&& ...
                        candidate.reduced_formula==workingIonSymbol
                    workingEntry=candidate;
                end
            end
            if ~allowUnstable&&isempty(entry)
                error("KSSOLV:Matgenlab:Battery:UnstableComposition", ...
                    "No stable compound at the requested composition.");
            end
            profile=fliplr(diagram.get_element_profile( ...
                kssolv.analysis.matgenlab.core.Element(workingIonSymbol),comp));
            if numel(profile)<2,obj=[];return,end
            if isempty(workingEntry)
                error("KSSOLV:Matgenlab:Battery:WorkingIonEntry", ...
                    "The phase diagram lacks a working-ion reference.");
            end
            [species,amounts]=comp.items();normalization=cell(0,2);
            frameworkPairs=cell(0,2);
            for index=1:numel(species)
                if species{index}.symbol~=workingIonSymbol
                    normalization(end+1,:)={species{index},amounts(index)}; %#ok<AGROW>
                    frameworkPairs(end+1,:)={species{index},amounts(index)}; %#ok<AGROW>
                end
            end
            framework=kssolv.analysis.matgenlab.core.Composition(frameworkPairs);
            pairs=cell(1,numel(profile)-1);
            for index=1:numel(pairs)
                pairs{index}=kssolv.analysis.matgenlab.apps.battery. ...
                    ConversionVoltagePair.from_steps(profile(index), ...
                    profile(index+1),normalization,framework.reduced_formula);
            end
            obj=kssolv.analysis.matgenlab.apps.battery.ConversionElectrode( ...
                pairs,workingEntry,comp.reduced_formula,framework.reduced_formula);
        end
        function obj=from_composition_and_entries(comp,entries,workingIonSymbol,allowUnstable)
            if nargin<3,workingIonSymbol="Li";end
            if nargin<4,allowUnstable=false;end
            diagram=kssolv.analysis.matgenlab.analysis.PhaseDiagram(entries);
            obj=kssolv.analysis.matgenlab.apps.battery.ConversionElectrode. ...
                from_composition_and_pd(comp,diagram,workingIonSymbol,allowUnstable);
        end
        function obj=from_dict(data)
            raw=data.voltage_pairs;if ~iscell(raw),raw=num2cell(raw);end
            pairs=cellfun(@(x)kssolv.analysis.matgenlab.apps.battery. ...
                ConversionVoltagePair.from_dict(x),raw,"UniformOutput",false);
            obj=kssolv.analysis.matgenlab.apps.battery.ConversionElectrode( ...
                pairs,decodeEntry(data.working_ion_entry), ...
                data.initial_comp_formula,data.framework_formula);
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.apps.battery. ...
                ConversionElectrode.from_dict(data);
        end
    end
end
function formulas=reactionFormulaSet(reaction)
formulas=strings(1,0);
for index=1:numel(reaction.all_comp)
    if abs(reaction.coeffs(index))>1e-5
        formulas(end+1)=reaction.all_comp{index}.reduced_formula; %#ok<AGROW>
    end
end
formulas=sort(unique(formulas));
end
function entry=decodeEntry(data)
if isa(data,"kssolv.analysis.matgenlab.core.Entry"),entry=data;
elseif isfield(data,"structure")
    entry=kssolv.analysis.matgenlab.core.ComputedStructureEntry.from_dict(data);
elseif isfield(data,"x_class")&&string(data.x_class)=="PDEntry"
    entry=kssolv.analysis.matgenlab.analysis.PDEntry.from_dict(data);
else
    entry=kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(data);
end
end
