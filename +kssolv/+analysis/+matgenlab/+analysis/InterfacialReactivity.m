classdef InterfacialReactivity < handle
    %INTERFACIALREACTIVITY Tie-line reaction landscape between two solids.
    properties (Constant)
        EV_TO_KJ_PER_MOL=96.4853
    end
    properties
        c1
        c2
        pd
        norm (1,1) logical=true
        use_hull_energy (1,1) logical=false
        c1_original
        c2_original
        comp1
        comp2
        grand (1,1) logical=false
        factor1 (1,1) double=1
        factor2 (1,1) double=1
        e1 (1,1) double=0
        e2 (1,1) double=0
    end
    properties (Dependent,SetAccess=private)
        labels
        minimum
        products
    end
    methods
        function obj=InterfacialReactivity(c1,c2,pd,varargin)
            options=struct(norm=true,use_hull_energy=false,bypass_grand_warning=false);
            options=parseOptions(options,varargin);
            if isa(pd,"kssolv.analysis.matgenlab.analysis.GrandPotentialPhaseDiagram")&& ...
                    ~options.bypass_grand_warning
                error("KSSOLV:Matgenlab:InterfacialReactivity:Grand", ...
                    "Use GrandPotentialInterfacialReactivity for open elements.");
            end
            obj.c1_original=asComposition(c1);obj.c2_original=asComposition(c2);
            obj.c1=obj.c1_original;obj.c2=obj.c2_original;
            obj.comp1=obj.c1;obj.comp2=obj.c2;obj.pd=pd;
            obj.norm=logical(options.norm);obj.use_hull_energy=logical(options.use_hull_energy);
            if obj.norm
                obj.c1=obj.c1.fractional_composition;obj.c2=obj.c2.fractional_composition;
                obj.comp1=obj.comp1.fractional_composition;obj.comp2=obj.comp2.fractional_composition;
            end
            if ~options.bypass_grand_warning
                if obj.use_hull_energy
                    obj.e1=pd.get_hull_energy(obj.comp1);obj.e2=pd.get_hull_energy(obj.comp2);
                else
                    obj.e1=obj.get_entry_energy(pd,obj.comp1);
                    obj.e2=obj.get_entry_energy(pd,obj.comp2);
                end
            end
        end
        function kinks=get_kinks(obj)
            coord1=obj.pd.pd_coords(obj.comp1);coord2=obj.pd.pd_coords(obj.comp2);
            critical=obj.pd.get_critical_compositions(obj.comp1,obj.comp2);
            if isequal(coord1,coord2),ratios=[0,1];
            else
                ratios=zeros(1,numel(critical));
                reversed=fliplr(critical);
                for ii=1:numel(reversed)
                    coordinate=obj.pd.pd_coords(reversed{ii});
                    ratio=builtin("norm",coordinate-coord2)/ ...
                        builtin("norm",coord1-coord2);
                    n1=obj.comp1.num_atoms;n2=obj.comp2.num_atoms;
                    ratio=ratio*n2/(n1+ratio*(n2-n1));
                    ratios(ii)=obj.convert(ratio,obj.factor1,obj.factor2);
                end
            end
            kinks=repmat(struct(index=0,ratio=0,energy=0,reaction=[], ...
                energy_kj_per_mol=0),1,numel(ratios));
            for ii=1:numel(ratios)
                processed=obj.reverse_convert(ratios(ii),obj.factor1,obj.factor2);
                energy=obj.get_energy(processed);reaction=obj.get_reaction(processed);
                atoms=processed*obj.comp1.num_atoms+(1-processed)*obj.comp2.num_atoms;
                kj=energy*obj.get_elem_amt_in_rxn(reaction)/atoms*obj.EV_TO_KJ_PER_MOL;
                kinks(ii)=struct(index=ii,ratio=ratios(ii),energy=energy, ...
                    reaction=reaction,energy_kj_per_mol=kj);
            end
        end
        function axesHandle=plot(obj,backend) %#ok<INUSD>
            kinks=obj.get_kinks();figureHandle=figure("Visible","off");
            axesHandle=axes(figureHandle);
            plot(axesHandle,[kinks.ratio],[kinks.energy],"o-","LineWidth",2);
            hold(axesHandle,"on");minimum_=obj.minimum;
            scatter(axesHandle,minimum_(1),minimum_(2),160,"*","filled");hold(axesHandle,"off");
            xlabel(axesHandle,sprintf("x in x%s + (1-x)%s", ...
                obj.c1.reduced_formula,obj.c2.reduced_formula));
            ylabel(axesHandle,"Reaction energy (eV/atom)");
        end
        function value=get_dataframe(obj)
            kinks=obj.get_kinks();
            value=table(round([kinks.ratio].',3),{kinks.reaction}.', ...
                round([kinks.energy_kj_per_mol].',1),round([kinks.energy].',3), ...
                VariableNames=["Atomic fraction","Reaction", ...
                "E_rxn (kJ/mol)","E_rxn (eV/atom)"]);
        end
        function value=get_critical_original_kink_ratio(obj)
            if obj.c1_original==obj.c2_original,value=[0,1];return,end
            kinks=obj.get_kinks();value=zeros(1,numel(kinks));
            for ii=1:numel(kinks)
                value(ii)=abs(obj.get_original_composition_ratio(kinks(ii).reaction));
            end
        end
        function value=get_original_composition_ratio(obj,reaction)
            if obj.c1_original==obj.c2_original,value=1;return,end
            first=0;second=0;
            try
                first=reaction.get_coeff(obj.c1_original);
            catch
            end
            try
                second=reaction.get_coeff(obj.c2_original);
            catch
            end
            value=first/(first+second);
        end
        function value=get_energy(obj,x)
            value=obj.pd.get_hull_energy(obj.comp1*x+obj.comp2*(1-x))- ...
                obj.e1*x-obj.e2*(1-x);
        end
        function reactants=get_reactants(obj,x)
            if abs(x)<1e-8
                reactants={obj.c2_original};
            elseif abs(x-1)<1e-8
                reactants={obj.c1_original};
            elseif obj.c1_original==obj.c2_original
                reactants={obj.c1_original};
            else
                reactants={obj.c1_original,obj.c2_original};
            end
        end
        function reaction=get_reaction(obj,x)
            mixed=obj.comp1*x+obj.comp2*(1-x);
            decomposition=obj.pd.get_decomposition(mixed);
            productCompositions=cellfun(@(entry)entry.composition, ...
                decomposition(:,1),"UniformOutput",false);
            reaction=kssolv.analysis.matgenlab.analysis.Reaction( ...
                obj.get_reactants(x),productCompositions);
            originalRatio=obj.get_original_composition_ratio(reaction);
            if abs(originalRatio-1)<1e-8
                reaction.normalize_to(obj.c1_original,originalRatio);
            else
                reaction.normalize_to(obj.c2_original,1-originalRatio);
            end
        end
        function value=get_elem_amt_in_rxn(obj,reaction)
            value=0;
            for el=obj.pd.elements,value=value+reaction.get_el_amount(el{1});end
        end
        function value=get.labels(obj)
            kinks=obj.get_kinks();value=cell(numel(kinks),2);
            for ii=1:numel(kinks)
                value(ii,:)={kinks(ii).index,sprintf( ...
                    "x= %.4g energy in eV/atom = %.4g %s", ...
                    kinks(ii).ratio,kinks(ii).energy,char(kinks(ii).reaction))};
            end
        end
        function value=get.minimum(obj)
            kinks=obj.get_kinks();[~,where]=min([kinks.energy]);
            value=[kinks(where).ratio,kinks(where).energy];
        end
        function value=get.products(obj)
            kinks=obj.get_kinks();value=strings(1,0);
            for kink=kinks
                value=union(value,cellfun(@(x)x.reduced_formula, ...
                    kink.reaction.products));
            end
        end
        function data=as_dict(obj)
            data=struct(x_module="pymatgen.analysis.interface_reactions", ...
                x_class="InterfacialReactivity",c1=obj.c1_original.as_dict(), ...
                c2=obj.c2_original.as_dict(),pd=obj.pd.as_dict(), ...
                norm=obj.norm,use_hull_energy=obj.use_hull_energy);
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Static)
        function value=get_entry_energy(pd,composition)
            candidates=[];
            for entry=pd.qhull_entries
                if entry{1}.composition.fractional_composition== ...
                        composition.fractional_composition
                    candidates(end+1)=entry{1}.energy_per_atom; %#ok<AGROW>
                end
            end
            if isempty(candidates)
                warning("KSSOLV:Matgenlab:InterfacialReactivity:Reactant", ...
                    "Reactant has no negative-formation-energy entry; using hull energy.");
                value=pd.get_hull_energy(composition);
            else
                value=min(candidates)*composition.num_atoms;
            end
        end
        function value=convert(x,factor1,factor2)
            value=x*factor2/((1-x)*factor1+x*factor2);
        end
        function value=reverse_convert(x,factor1,factor2)
            value=x*factor1/((1-x)*factor2+x*factor1);
        end
        function value=get_chempot_correction(element,temperature,pressure)
            element=string(element);valid=["O","N","Cl","F","H"];
            if ~ismember(element,valid)
                warning("KSSOLV:Matgenlab:InterfacialReactivity:Gas", ...
                    "Element is not a supported diatomic gas.");value=0;return
            end
            cpValues=[29.376,29.124,33.949,31.302,28.836];
            entropyValues=[205.147,191.609,223.079,202.789,130.680];
            which=find(valid==element);cp=cpValues(which);entropy=entropyValues(which);
            standardTemperature=298.15;standardPressure=1e5;gasConstant=8.3144598;
            pressureCorrection=gasConstant*temperature*log(pressure/standardPressure);
            temperatureCorrection=-cp*(temperature*log(temperature)- ...
                standardTemperature*log(standardTemperature))+ ...
                cp*(temperature-standardTemperature)*(1+log(standardTemperature))- ...
                entropy*(temperature-standardTemperature);
            value=(pressureCorrection+temperatureCorrection)/ ...
                (1000*96.4853*2);
        end
        function obj=from_dict(data)
            c1=kssolv.analysis.matgenlab.core.Composition.from_dict(data.c1);
            c2=kssolv.analysis.matgenlab.core.Composition.from_dict(data.c2);
            pd=kssolv.analysis.matgenlab.analysis.PhaseDiagram.from_dict(data.pd);
            obj=kssolv.analysis.matgenlab.analysis.InterfacialReactivity( ...
                c1,c2,pd,"norm",data.norm,"use_hull_energy",data.use_hull_energy);
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab.analysis.InterfacialReactivity.from_dict(data);end
    end
end

function value=asComposition(input)
if isa(input,"kssolv.analysis.matgenlab.core.Composition")
    value=input;
else
    value=kssolv.analysis.matgenlab.core.Composition(input);
end
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
