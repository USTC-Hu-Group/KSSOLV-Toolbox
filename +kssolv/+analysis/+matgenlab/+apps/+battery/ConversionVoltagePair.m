classdef ConversionVoltagePair < ...
        kssolv.analysis.matgenlab.apps.battery.AbstractVoltagePair
    %CONVERSIONVOLTAGEPAIR One equilibrium conversion-reaction step.
    properties
        rxn = []
        entries_charge cell = cell(1,0)
        entries_discharge cell = cell(1,0)
    end
    methods
        function obj=ConversionVoltagePair(varargin)
            if nargin==0
                options=parseOptions();emptyConstruction=true;
            else
                options=parseOptions(varargin{:});emptyConstruction=false;
            end
            obj@kssolv.analysis.matgenlab.apps.battery.AbstractVoltagePair( ...
                "voltage",options.voltage,"mAh",options.mAh, ...
                "mass_charge",options.mass_charge, ...
                "mass_discharge",options.mass_discharge, ...
                "vol_charge",options.vol_charge,"vol_discharge",options.vol_discharge, ...
                "frac_charge",options.frac_charge, ...
                "frac_discharge",options.frac_discharge, ...
                "working_ion_entry",options.working_ion_entry, ...
                "framework_formula",options.framework_formula);
            if emptyConstruction,return,end
            obj.rxn=options.rxn;obj.entries_charge=toCell(options.entries_charge);
            obj.entries_discharge=toCell(options.entries_discharge);
        end
        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.apps.battery. ...
                AbstractVoltagePair(obj);
            data.x_module="pymatgen.apps.battery.conversion_battery";
            data.x_class="ConversionVoltagePair";data.rxn=obj.rxn.as_dict();
            data.entries_charge=cellfun(@(x)x.as_dict(),obj.entries_charge, ...
                "UniformOutput",false);
            data.entries_discharge=cellfun(@(x)x.as_dict(),obj.entries_discharge, ...
                "UniformOutput",false);
        end
    end
    methods (Static)
        function obj=from_steps(first,second,normalizationElements,frameworkFormula)
            workingEntry=first.element_reference;
            ion=workingEntry.elements{1};valence=max(ion.oxidation_states);
            voltage=(-first.chempot+workingEntry.energy_per_atom)/valence;
            evolution=second.evolution-first.evolution;
            capacity=evolution*1.602176634e-19/3600* ...
                6.02214076e23*1000*valence;
            ionComp=kssolv.analysis.matgenlab.core.Composition(ion.symbol);
            previous=first.reaction;current=second.reaction;
            reactants=cell(0,2);
            for index=1:numel(previous.products)
                comp=previous.products{index};
                if comp~=ionComp
                    reactants(end+1,:)={comp,abs(previous.get_coeff(comp))}; %#ok<AGROW>
                end
            end
            products=cell(0,2);
            for index=1:numel(current.products)
                comp=current.products{index};
                if comp~=ionComp
                    products(end+1,:)={comp,abs(current.get_coeff(comp))}; %#ok<AGROW>
                end
            end
            reactants(end+1,:)={ionComp,evolution};
            reaction=kssolv.analysis.matgenlab.analysis. ...
                BalancedReaction(reactants,products);
            normalizationElements=normalizeElementMapping(normalizationElements);
            for index=1:size(normalizationElements,1)
                element=normalizationElements{index,1};
                amount=normalizationElements{index,2};
                if reaction.get_el_amount(element)>1e-6
                    reaction.normalize_to_element(element,amount);break
                end
            end
            previousMass=0;
            for index=1:numel(previous.all_comp)
                previousMass=previousMass+previous.all_comp{index}.weight* ...
                    abs(previous.coeffs(index));
            end
            previousMass=previousMass/2;
            currentMass=0;
            for index=1:numel(current.all_comp)
                currentMass=currentMass+current.all_comp{index}.weight* ...
                    abs(current.coeffs(index));
            end
            currentMass=currentMass/2;
            volumeCharge=compositeVolume(previous,first.entries,ion.symbol);
            volumeDischarge=compositeVolume(current,second.entries,ion.symbol);
            chargeComp=compositeComposition(previous,ion.symbol);
            dischargeComp=compositeComposition(current,ion.symbol);
            obj=kssolv.analysis.matgenlab.apps.battery.ConversionVoltagePair( ...
                "rxn",reaction,"voltage",voltage,"mAh",capacity, ...
                "vol_charge",volumeCharge,"vol_discharge",volumeDischarge, ...
                "mass_charge",previousMass,"mass_discharge",currentMass, ...
                "frac_charge",chargeComp.get_atomic_fraction(ion), ...
                "frac_discharge",dischargeComp.get_atomic_fraction(ion), ...
                "entries_charge",first.entries, ...
                "entries_discharge",second.entries, ...
                "working_ion_entry",workingEntry, ...
                "framework_formula",frameworkFormula);
        end
        function obj=from_dict(data)
            data.rxn=kssolv.analysis.matgenlab.analysis. ...
                BalancedReaction.from_dict(data.rxn);
            data.entries_charge=cellfun(@decodeEntry,toCell(data.entries_charge), ...
                "UniformOutput",false);
            data.entries_discharge=cellfun(@decodeEntry,toCell(data.entries_discharge), ...
                "UniformOutput",false);
            data.working_ion_entry=decodeEntry(data.working_ion_entry);
            pairs=structToPairs(data);
            obj=kssolv.analysis.matgenlab.apps.battery. ...
                ConversionVoltagePair(pairs{:});
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.apps.battery. ...
                ConversionVoltagePair.from_dict(data);
        end
    end
end
function options=parseOptions(varargin)
options=struct("rxn",[],"voltage",0,"mAh",0,"mass_charge",0, ...
    "mass_discharge",0,"vol_charge",NaN,"vol_discharge",NaN, ...
    "frac_charge",0,"frac_discharge",0,"entries_charge",{{}}, ...
    "entries_discharge",{{}},"working_ion_entry",[], ...
    "framework_formula","");
names=fieldnames(options);
for index=1:2:numel(varargin)
    match=find(strcmpi(string(varargin{index}),string(names)),1);
    if ~isempty(match),options.(names{match})=varargin{index+1};end
end
end
function value=compositeVolume(reaction,entries,ionSymbol)
value=0;entries=toCell(entries);
for index=1:numel(entries)
    entry=entries{index};
    if entry.reduced_formula~=ionSymbol
        value=value+abs(reaction.get_coeff(entry.composition))* ...
            entry.structure.volume;
    end
end
end
function value=compositeComposition(reaction,ionSymbol)
value=kssolv.analysis.matgenlab.core.Composition();
for index=1:numel(reaction.products)
    comp=reaction.products{index};
    if comp.reduced_formula~=ionSymbol
        value=value+comp*abs(reaction.get_coeff(comp));
    end
end
end
function mapping=normalizeElementMapping(input)
if iscell(input)
    mapping=input;return
end
if isa(input,"containers.Map")
    keys=input.keys;mapping=cell(numel(keys),2);
    for index=1:numel(keys)
        mapping(index,:)={keys{index},input(keys{index})};
    end
elseif isstruct(input)
    names=fieldnames(input);mapping=cell(numel(names),2);
    for index=1:numel(names)
        mapping(index,:)={names{index},input.(names{index})};
    end
else
    error("KSSOLV:Matgenlab:Battery:Mapping","Unsupported mapping.");
end
end
function values=toCell(input)
if iscell(input),values=input;elseif isstruct(input),values=num2cell(input);
else,values={input};end
end
function entry=decodeEntry(data)
if isa(data,"kssolv.analysis.matgenlab.core.Entry"),entry=data;return,end
if isfield(data,"structure")
    entry=kssolv.analysis.matgenlab.core.ComputedStructureEntry.from_dict(data);
elseif isfield(data,"x_class")&&string(data.x_class)=="PDEntry"
    entry=kssolv.analysis.matgenlab.analysis.PDEntry.from_dict(data);
else
    entry=kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(data);
end
end
function pairs=structToPairs(data)
ignore=["x_module","x_class","module","class"];
names=string(fieldnames(data));names=names(~ismember(names,ignore));
pairs=cell(1,2*numel(names));
for index=1:numel(names)
    pairs{2*index-1}=names(index);pairs{2*index}=data.(names(index));
end
end
