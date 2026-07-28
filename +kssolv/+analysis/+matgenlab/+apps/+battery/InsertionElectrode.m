classdef InsertionElectrode < ...
        kssolv.analysis.matgenlab.apps.battery.AbstractElectrode
    %INSERTIONELECTRODE Topotactically related insertion states.
    properties
        stable_entries cell = cell(1,0)
        unstable_entries cell = cell(1,0)
    end
    properties (Dependent,SetAccess=private)
        fully_charged_entry
        fully_discharged_entry
    end
    methods
        function obj=InsertionElectrode(voltagePairs,workingIonEntry, ...
                frameworkFormula,stableEntries,unstableEntries)
            if nargin==0
                voltagePairs={};workingIonEntry=[];frameworkFormula="";
                stableEntries={};unstableEntries={};emptyConstruction=true;
            else
                emptyConstruction=false;
            end
            obj@kssolv.analysis.matgenlab.apps.battery.AbstractElectrode( ...
                voltagePairs,workingIonEntry,frameworkFormula);
            if emptyConstruction,return,end
            obj.stable_entries=reshape(stableEntries,1,[]);
            obj.unstable_entries=reshape(unstableEntries,1,[]);
        end
        function entries=get_stable_entries(obj,chargeToDischarge)
            if nargin<2,chargeToDischarge=true;end
            entries=obj.stable_entries;if ~chargeToDischarge,entries=fliplr(entries);end
        end
        function entries=get_unstable_entries(obj,chargeToDischarge)
            if nargin<2,chargeToDischarge=true;end
            entries=obj.unstable_entries;if ~chargeToDischarge,entries=fliplr(entries);end
        end
        function entries=get_all_entries(obj,chargeToDischarge)
            if nargin<2,chargeToDischarge=true;end
            entries=[obj.stable_entries,obj.unstable_entries];ion=obj.working_ion;
            fractions=cellfun(@(x)x.composition.get_atomic_fraction(ion),entries);
            [~,order]=sort(fractions);entries=entries(order);
            if ~chargeToDischarge,entries=fliplr(entries);end
        end
        function value=get.fully_charged_entry(obj),value=obj.stable_entries{1};end
        function value=get.fully_discharged_entry(obj),value=obj.stable_entries{end};end
        function value=get_max_instability(obj,minVoltage,maxVoltage)
            if nargin<2,minVoltage=[];end
            if nargin<3,maxVoltage=[];end
            values=obj.instabilityValues(minVoltage,maxVoltage);
            if isempty(values),value=[];else,value=max(values);end
        end
        function value=get_min_instability(obj,minVoltage,maxVoltage)
            if nargin<2,minVoltage=[];end
            if nargin<3,maxVoltage=[];end
            values=obj.instabilityValues(minVoltage,maxVoltage);
            if isempty(values),value=[];else,value=min(values);end
        end
        function value=get_max_muO2(obj,minVoltage,maxVoltage)
            if nargin<2,minVoltage=[];end
            if nargin<3,maxVoltage=[];end
            values=obj.muO2Values(minVoltage,maxVoltage);
            if isempty(values),value=[];else,value=max(values);end
        end
        function value=get_min_muO2(obj,minVoltage,maxVoltage)
            if nargin<2,minVoltage=[];end
            if nargin<3,maxVoltage=[];end
            values=obj.muO2Values(minVoltage,maxVoltage);
            if isempty(values),value=[];else,value=min(values);end
        end
        function batteries=get_sub_electrodes(obj,adjacentOnly,includeMyself)
            if nargin<2,adjacentOnly=true;end
            if nargin<3,includeMyself=true;end
            count=numel(obj.stable_entries);ranges=zeros(0,2);
            if adjacentOnly
                ranges=[(1:count-1).',(2:count).'];
            else
                for first=1:count-1
                    for last=first+1:count
                        ranges(end+1,:)=[first,last]; %#ok<AGROW>
                    end
                end
            end
            batteries={};ion=obj.working_ion;
            for index=1:size(ranges,1)
                first=ranges(index,1);last=ranges(index,2);
                if ~includeMyself&&first==1&&last==count,continue,end
                low=obj.stable_entries{first}.composition.get_atomic_fraction(ion);
                high=obj.stable_entries{last}.composition.get_atomic_fraction(ion);
                all=obj.get_all_entries();
                keep=cellfun(@(x)inRange( ...
                    x.composition.get_atomic_fraction(ion),low,high),all);
                batteries{end+1}=kssolv.analysis.matgenlab.apps.battery. ...
                    InsertionElectrode.from_entries(all(keep), ...
                    obj.working_ion_entry); %#ok<AGROW>
            end
        end
        function data=get_summary_dict(obj,printSubelectrodes)
            if nargin<2,printSubelectrodes=true;end
            data=get_summary_dict@kssolv.analysis.matgenlab.apps.battery. ...
                AbstractElectrode(obj,printSubelectrodes);
            charged=obj.fully_charged_entry;discharged=obj.fully_discharged_entry;
            data.id_charge=charged.entry_id;data.formula_charge=charged.reduced_formula;
            data.id_discharge=discharged.entry_id;
            data.formula_discharge=discharged.reduced_formula;
            data.max_instability=obj.get_max_instability();
            data.min_instability=obj.get_min_instability();
            allEntries=obj.get_all_entries();stable=obj.get_stable_entries();
            unstable=obj.get_unstable_entries();
            data.material_ids=cellfun(@(x)x.entry_id,allEntries, ...
                "UniformOutput",false);
            data.stable_material_ids=cellfun(@(x)x.entry_id,stable,"UniformOutput",false);
            data.unstable_material_ids=cellfun(@(x)x.entry_id,unstable,"UniformOutput",false);
            if all(cellfun(@(x)isfield(x.data,"decomposition_energy"),allEntries))
                data.stability_charge=charged.data.decomposition_energy;
                data.stability_discharge=discharged.data.decomposition_energy;
                data.stability_data=keyedData(allEntries,"decomposition_energy");
            end
            if all(cellfun(@(x)isfield(x.data,"muO2"),allEntries))
                data.muO2_data=keyedData(allEntries,"muO2");
            end
        end
        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.apps.battery.AbstractElectrode(obj);
            data.x_module="pymatgen.apps.battery.insertion_battery";
            data.x_class="InsertionElectrode";
            data.stable_entries=cellfun(@(x)x.as_dict(),obj.stable_entries, ...
                "UniformOutput",false);
            data.unstable_entries=cellfun(@(x)x.as_dict(),obj.unstable_entries, ...
                "UniformOutput",false);
        end
        function data=as_dict_legacy(obj)
            data=struct("x_module","pymatgen.apps.battery.insertion_battery", ...
                "x_class","InsertionElectrode","entries", ...
                {cellfun(@(x)x.as_dict(),obj.get_all_entries(), ...
                "UniformOutput",false)},"working_ion_entry", ...
                obj.working_ion_entry.as_dict());
        end
    end
    methods (Static)
        function obj=from_entries(entries,workingIonEntry,stripStructures)
            if nargin<3,stripStructures=false;end
            if ~iscell(entries),entries=num2cell(entries);end
            entries=reshape(entries,1,[]);
            if stripStructures
                converted=cell(size(entries));
                for index=1:numel(entries)
                    converted{index}=kssolv.analysis.matgenlab.core. ...
                        ComputedEntry.from_dict(entries{index}.as_dict());
                    converted{index}.data.volume=entries{index}.structure.volume;
                end
                entries=converted;
            end
            elements={};
            for entry=entries,elements=[elements,entry{1}.elements];end %#ok<AGROW>
            symbols=cellfun(@(x)x.symbol,elements);
            [~,uniqueIndex]=unique(symbols,"stable");elements=elements(uniqueIndex);
            high=max(cellfun(@(x)x.energy_per_atom,entries))+10;
            pdEntries=entries;
            for index=1:numel(elements)
                pdEntries{end+1}=kssolv.analysis.matgenlab.analysis.PDEntry( ...
                    kssolv.analysis.matgenlab.core.Composition(elements{index}.symbol), ...
                    high); %#ok<AGROW>
            end
            diagram=kssolv.analysis.matgenlab.analysis.PhaseDiagram(pdEntries);
            ion=workingIonEntry.elements{1};
            stable=filterOriginal(diagram.stable_entries,entries);
            unstable=filterOriginal(diagram.unstable_entries,entries);
            stable=sortEntries(stable,ion);unstable=sortEntries(unstable,ion);
            pairs=cell(1,numel(stable)-1);
            for index=1:numel(pairs)
                pairs{index}=kssolv.analysis.matgenlab.apps.battery. ...
                    InsertionVoltagePair.from_entries(stable{index}, ...
                    stable{index+1},workingIonEntry);
            end
            obj=kssolv.analysis.matgenlab.apps.battery.InsertionElectrode( ...
                pairs,workingIonEntry,pairs{1}.framework.reduced_formula, ...
                stable,unstable);
        end
        function obj=from_dict(data)
            pairs=cellfun(@(x) ...
                kssolv.analysis.matgenlab.apps.battery. ...
                InsertionVoltagePair.from_dict(x),toCell(data.voltage_pairs), ...
                "UniformOutput",false);
            stable=cellfun(@decodeEntry,toCell(data.stable_entries), ...
                "UniformOutput",false);
            unstable=cellfun(@decodeEntry,toCell(data.unstable_entries), ...
                "UniformOutput",false);
            obj=kssolv.analysis.matgenlab.apps.battery.InsertionElectrode( ...
                pairs,decodeEntry(data.working_ion_entry), ...
                data.framework_formula,stable,unstable);
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.apps.battery. ...
                InsertionElectrode.from_dict(data);
        end
        function obj=from_dict_legacy(data)
            entries=cellfun(@decodeEntry,toCell(data.entries),"UniformOutput",false);
            obj=kssolv.analysis.matgenlab.apps.battery.InsertionElectrode. ...
                from_entries(entries,decodeEntry(data.working_ion_entry));
        end
    end
    methods (Access=private)
        function values=instabilityValues(obj,minVoltage,maxVoltage)
            pairs=obj.selectVoltage(minVoltage,maxVoltage);values=[];
            for index=1:numel(pairs)
                values=[values,pairs{index}.decomp_e_charge, ...
                    pairs{index}.decomp_e_discharge]; %#ok<AGROW>
            end
        end
        function values=muO2Values(obj,minVoltage,maxVoltage)
            pairs=obj.selectVoltage(minVoltage,maxVoltage);values=[];
            for index=1:numel(pairs)
                values=[values,extractChempots(pairs{index}.muO2_charge), ...
                    extractChempots(pairs{index}.muO2_discharge)]; %#ok<AGROW>
            end
        end
    end
end
function tf=inRange(value,low,high),tf=value>=low-1e-12&&value<=high+1e-12;end
function entries=filterOriginal(candidates,original)
entries={};
for index=1:numel(candidates)
    match=find(cellfun(@(x)x==candidates{index},original),1);
    if ~isempty(match),entries{end+1}=original{match};end %#ok<AGROW>
end
end
function entries=sortEntries(entries,ion)
fractions=cellfun(@(x)x.composition.get_atomic_fraction(ion),entries);
[~,order]=sort(fractions);entries=entries(order);
end
function data=keyedData(entries,field)
data=struct();
for index=1:numel(entries)
    key=matlab.lang.makeValidName(string(entries{index}.entry_id));
    data.(key)=entries{index}.data.(field);
end
end
function values=extractChempots(data)
values=[];
if isempty(data),return,end
if isstruct(data)
    for index=1:numel(data)
        if isfield(data(index),"chempot"),values(end+1)=data(index).chempot;end %#ok<AGROW>
    end
elseif iscell(data)
    values=cellfun(@(x)x.chempot,data);
end
values=reshape(values,1,[]);
end
function values=toCell(input)
if iscell(input),values=input;elseif isstruct(input),values=num2cell(input);
else,values={input};end
end
function entry=decodeEntry(data)
if isa(data,"kssolv.analysis.matgenlab.core.Entry"),entry=data;return,end
if isfield(data,"structure")
    entry=kssolv.analysis.matgenlab.core.ComputedStructureEntry.from_dict(data);
else
    entry=kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(data);
end
end
