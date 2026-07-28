classdef InsertionVoltagePair < ...
        kssolv.analysis.matgenlab.apps.battery.AbstractVoltagePair
    %INSERTIONVOLTAGEPAIR One topotactic insertion voltage step.
    properties
        entry_charge = []
        entry_discharge = []
        decomp_e_charge = []
        decomp_e_discharge = []
        muO2_charge = []
        muO2_discharge = []
    end
    methods
        function obj=InsertionVoltagePair(varargin)
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
            obj.entry_charge=options.entry_charge;
            obj.entry_discharge=options.entry_discharge;
            obj.decomp_e_charge=options.decomp_e_charge;
            obj.decomp_e_discharge=options.decomp_e_discharge;
            obj.muO2_charge=options.muO2_charge;
            obj.muO2_discharge=options.muO2_discharge;
        end
        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.apps.battery. ...
                AbstractVoltagePair(obj);
            data.x_module="pymatgen.apps.battery.insertion_battery";
            data.x_class="InsertionVoltagePair";
            data.entry_charge=obj.entry_charge.as_dict();
            data.entry_discharge=obj.entry_discharge.as_dict();
            data.decomp_e_charge=obj.decomp_e_charge;
            data.decomp_e_discharge=obj.decomp_e_discharge;
            data.muO2_charge=obj.muO2_charge;data.muO2_discharge=obj.muO2_discharge;
        end
    end
    methods (Static)
        function obj=from_entries(entry1,entry2,workingIonEntry)
            ion=workingIonEntry.elements{1};
            first=entry1;second=entry2;
            if first.composition.get_atomic_fraction(ion)> ...
                    second.composition.get_atomic_fraction(ion)
                first=entry2;second=entry1;
            end
            compCharge=first.composition;compDischarge=second.composition;
            if ~workingIonEntry.composition.is_element
                error("KSSOLV:Matgenlab:Battery:WorkingIon", ...
                    "The working ion must be an element.");
            end
            if compCharge.get_atomic_fraction(ion)<=0&& ...
                    compDischarge.get_atomic_fraction(ion)<=0
                error("KSSOLV:Matgenlab:Battery:MissingWorkingIon", ...
                    "The working ion must occur in an endpoint.");
            end
            if abs(compCharge.get_atomic_fraction(ion)- ...
                    compDischarge.get_atomic_fraction(ion))<1e-14
                error("KSSOLV:Matgenlab:Battery:EqualWorkingIon", ...
                    "Endpoint working-ion fractions must differ.");
            end
            frameCharge=withoutElement(compCharge,ion.symbol);
            frameDischarge=withoutElement(compDischarge,ion.symbol);
            if frameCharge.reduced_formula~=frameDischarge.reduced_formula
                error("KSSOLV:Matgenlab:Battery:Framework", ...
                    "Endpoints must share a compositional framework.");
            end
            valence=abs(max(ion.oxidation_states));
            [framework,normCharge]= ...
                frameCharge.get_reduced_composition_and_factor();
            [~,normDischarge]= ...
                frameDischarge.get_reduced_composition_and_factor();
            volumeCharge=entryVolume(first)/normCharge;
            volumeDischarge=entryVolume(second)/normDischarge;
            massCharge=compCharge.weight/normCharge;
            massDischarge=compDischarge.weight/normDischarge;
            transferred=compDischarge(ion)/normDischarge- ...
                compCharge(ion)/normCharge;
            voltage=((first.energy/normCharge-second.energy/normDischarge)/ ...
                transferred+workingIonEntry.energy_per_atom)/valence;
            capacity=transferred*1.602176634e-19/3600* ...
                6.02214076e23*1000*valence;
            obj=kssolv.analysis.matgenlab.apps.battery.InsertionVoltagePair( ...
                "voltage",voltage,"mAh",capacity,"mass_charge",massCharge, ...
                "mass_discharge",massDischarge,"vol_charge",volumeCharge, ...
                "vol_discharge",volumeDischarge, ...
                "frac_charge",compCharge.get_atomic_fraction(ion), ...
                "frac_discharge",compDischarge.get_atomic_fraction(ion), ...
                "working_ion_entry",workingIonEntry, ...
                "framework_formula",framework.reduced_formula, ...
                "entry_charge",first,"entry_discharge",second, ...
                "decomp_e_charge",fieldOr(first.data,"decomposition_energy",[]), ...
                "decomp_e_discharge",fieldOr(second.data,"decomposition_energy",[]), ...
                "muO2_charge",fieldOr(first.data,"muO2",[]), ...
                "muO2_discharge",fieldOr(second.data,"muO2",[]));
        end
        function obj=from_dict(data)
            data.entry_charge=decodeEntry(data.entry_charge);
            data.entry_discharge=decodeEntry(data.entry_discharge);
            data.working_ion_entry=decodeEntry(data.working_ion_entry);
            pairs=structToPairs(data);
            obj=kssolv.analysis.matgenlab.apps.battery. ...
                InsertionVoltagePair(pairs{:});
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.apps.battery. ...
                InsertionVoltagePair.from_dict(data);
        end
    end
end
function options=parseOptions(varargin)
options=struct("voltage",0,"mAh",0,"mass_charge",0,"mass_discharge",0, ...
    "vol_charge",NaN,"vol_discharge",NaN,"frac_charge",0, ...
    "frac_discharge",0,"working_ion_entry",[],"framework_formula","", ...
    "entry_charge",[],"entry_discharge",[],"decomp_e_charge",[], ...
    "decomp_e_discharge",[],"muO2_charge",[],"muO2_discharge",[]);
names=fieldnames(options);
for index=1:2:numel(varargin)
    match=find(strcmpi(string(varargin{index}),string(names)),1);
    if ~isempty(match),options.(names{match})=varargin{index+1};end
end
end
function comp=withoutElement(input,symbol)
[species,amounts]=input.items();pairs=cell(0,2);
for index=1:numel(species)
    if species{index}.symbol~=symbol
        pairs(end+1,:)={species{index},amounts(index)}; %#ok<AGROW>
    end
end
comp=kssolv.analysis.matgenlab.core.Composition(pairs);
end
function value=entryVolume(entry)
if isprop(entry,"structure")
    value=entry.structure.volume;
elseif isfield(entry.data,"volume")
    value=entry.data.volume;
else
    value=NaN;
end
end
function value=fieldOr(data,name,default)
if isfield(data,name),value=data.(name);else,value=default;end
end
function entry=decodeEntry(data)
if isa(data,"kssolv.analysis.matgenlab.core.Entry"),entry=data;return,end
cls=string(fieldOr(data,"x_class","ComputedEntry"));
if cls=="ComputedStructureEntry"
    entry=kssolv.analysis.matgenlab.core.ComputedStructureEntry.from_dict(data);
elseif cls=="PDEntry"
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
