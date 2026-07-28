classdef BatteryAnalyzer
    %BATTERYANALYZER Oxidation-state capacity limits for a structure.
    properties
        struct_oxid
        oxi_override = struct()
        comp
        working_ion
        working_ion_charge (1,1) double
    end
    properties (Dependent,SetAccess=private)
        max_ion_removal
        max_ion_insertion
    end
    methods
        function obj=BatteryAnalyzer(structure,workingIon,oxidationOverride)
            if nargin<2,workingIon="Li";end
            if nargin<3||isempty(oxidationOverride),oxidationOverride=struct();end
            species=structure.types_of_species;
            if any(cellfun(@(x)~isa(x,"kssolv.analysis.matgenlab.core.Species")|| ...
                    isnan(x.oxi_state),species))
                error("KSSOLV:Matgenlab:BatteryAnalyzer:OxidationStates", ...
                    "BatteryAnalyzer requires oxidation states on every species.");
            end
            obj.struct_oxid=structure;obj.comp=structure.composition;
            obj.oxi_override=oxidationOverride;
            obj.working_ion=kssolv.analysis.matgenlab.core.Element(workingIon);
            [found,value]=mapValue(oxidationOverride,obj.working_ion.symbol);
            if found,obj.working_ion_charge=value;
            elseif any(obj.working_ion.symbol== ...
                    ["H","C","N","O","F","S","Cl","Se","Br","Te","I"])
                obj.working_ion_charge=obj.working_ion.min_oxidation_state;
            else
                obj.working_ion_charge=obj.working_ion.max_oxidation_state;
            end
        end
        function value=get.max_ion_removal(obj)
            [species,amounts]=obj.comp.items();potential=0;
            for index=1:numel(species)
                spec=species{index};
                if ~kssolv.analysis.matgenlab.apps.battery. ...
                        is_redox_active_intercalation(spec),continue,end
                element=kssolv.analysis.matgenlab.core.Element(spec.symbol);
                if obj.working_ion_charge<0
                    lower=2;if spec.symbol=="Cu",lower=1;end
                    allowed=element.oxidation_states;
                    target=min(allowed(allowed>=lower));
                    potential=potential+(target-spec.oxi_state)*amounts(index);
                else
                    potential=potential+(element.max_oxidation_state- ...
                        spec.oxi_state)*amounts(index);
                end
            end
            limit=potential/obj.working_ion_charge;
            ion=kssolv.analysis.matgenlab.core.Species( ...
                obj.working_ion.symbol,obj.working_ion_charge);
            value=min(limit,obj.comp(ion));
        end
        function value=get.max_ion_insertion(obj)
            [species,amounts]=obj.comp.items();potential=0;
            for index=1:numel(species)
                spec=species{index};
                if ~kssolv.analysis.matgenlab.apps.battery. ...
                        is_redox_active_intercalation(spec),continue,end
                element=kssolv.analysis.matgenlab.core.Element(spec.symbol);
                if obj.working_ion_charge<0
                    potential=potential+(spec.oxi_state- ...
                        element.max_oxidation_state)*amounts(index);
                else
                    lower=2;if spec.symbol=="Cu",lower=1;end
                    allowed=element.oxidation_states;
                    target=min(allowed(allowed>=lower));
                    potential=potential+(spec.oxi_state-target)*amounts(index);
                end
            end
            value=potential/obj.working_ion_charge;
        end
        function value=get_max_capgrav(obj,remove,insert)
            if nargin<2,remove=true;end
            if nargin<3,insert=true;end
            weight=obj.comp.weight;
            if insert
                weight=weight+obj.max_ion_insertion*obj.working_ion.atomic_mass;
            end
            value=obj.maxCapacityAh(remove,insert)/(weight/1000);
        end
        function value=get_max_capvol(obj,remove,insert,volume)
            if nargin<2,remove=true;end
            if nargin<3,insert=true;end
            if nargin<4||isempty(volume),volume=obj.struct_oxid.volume;end
            value=obj.maxCapacityAh(remove,insert)*1000*1e24/ ...
                (volume*6.02214076e23);
        end
        function removals=get_removals_int_oxid(obj)
            [species,~]=obj.comp.items();symbols=strings(1,0);
            for index=1:numel(species)
                if kssolv.analysis.matgenlab.apps.battery. ...
                        is_redox_active_intercalation(species{index})
                    symbols(end+1)=species{index}.symbol; %#ok<AGROW>
                end
            end
            symbols=unique(symbols,"stable");numbers=[];
            for index=1:numel(symbols)
                numbers=[numbers,obj.integerRemovalHelper( ...
                    obj.comp,symbols(index),symbols,[])]; %#ok<AGROW>
            end
            ion=kssolv.analysis.matgenlab.core.Species( ...
                obj.working_ion.symbol,obj.working_ion_charge);
            removals=unique(obj.comp(ion)-numbers);
        end
    end
    methods (Access=private)
        function value=maxCapacityAh(obj,remove,insert)
            count=0;if remove,count=count+obj.max_ion_removal;end
            if insert,count=count+obj.max_ion_insertion;end
            value=count*abs(obj.working_ion_charge)* ...
                1.602176634e-19*6.02214076e23/3600;
        end
        function numbers=integerRemovalHelper(obj,composition,redoxSymbol, ...
                redoxSymbols,numbers)
            [species,amounts]=composition.items();
            matching=find(cellfun(@(x)x.symbol==redoxSymbol,species));
            if isempty(matching),return,end
            states=cellfun(@(x)x.oxi_state,species(matching));
            element=kssolv.analysis.matgenlab.core.Element(redoxSymbol);
            if obj.working_ion_charge<0
                old=max(states);new=ceil(old-1);lower=2;
                if redoxSymbol=="Cu",lower=1;end
                valid=element.oxidation_states;
                if new<min(valid(valid>=lower)),return,end
            else
                old=min(states);new=floor(old+1);
                if new>element.max_oxidation_state,return,end
            end
            oldSpec=kssolv.analysis.matgenlab.core.Species(redoxSymbol,old);
            amount=composition(oldSpec);pairs=cell(0,2);
            for index=1:numel(species)
                if ~(species{index}==oldSpec)
                    pairs(end+1,:)={species{index},amounts(index)}; %#ok<AGROW>
                end
            end
            pairs(end+1,:)={kssolv.analysis.matgenlab.core. ...
                Species(redoxSymbol,new),amount};
            updated=kssolv.analysis.matgenlab.core.Composition(pairs);
            [updatedSpecies,updatedAmounts]=updated.items();charge=0;
            for index=1:numel(updatedSpecies)
                if updatedSpecies{index}.symbol~=obj.working_ion.symbol
                    charge=charge+updatedSpecies{index}.oxi_state* ...
                        updatedAmounts(index);
                end
            end
            a=max(0,-charge/obj.working_ion_charge);
            numbers=unique([numbers,a]);
            if a==0,return,end
            for symbol=redoxSymbols
                numbers=obj.integerRemovalHelper(updated,symbol, ...
                    redoxSymbols,numbers);
            end
        end
    end
end
function [found,value]=mapValue(mapping,key)
found=false;value=[];
if isa(mapping,"containers.Map")
    if isKey(mapping,char(key)),found=true;value=mapping(char(key));end
elseif isstruct(mapping)
    field=matlab.lang.makeValidName(key);
    if isfield(mapping,field),found=true;value=mapping.(field);end
end
end
