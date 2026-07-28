classdef GrandPotentialInterfacialReactivity < ...
        kssolv.analysis.matgenlab.analysis.InterfacialReactivity
    %GRANDPOTENTIALINTERFACIALREACTIVITY Interface reactions with open reservoirs.
    properties
        pd_non_grand
        include_no_mixing_energy (1,1) logical=false
    end
    methods
        function obj=GrandPotentialInterfacialReactivity(c1,c2,grandPd,pdNonGrand,varargin)
            options=struct(include_no_mixing_energy=false,norm=true,use_hull_energy=true);
            options=parseOptions(options,varargin);
            if ~isa(grandPd,"kssolv.analysis.matgenlab.analysis.GrandPotentialPhaseDiagram")
                error("KSSOLV:Matgenlab:GrandPotentialInterfacialReactivity:Diagram", ...
                    "grandPd must be a GrandPotentialPhaseDiagram.");
            end
            if ~isa(pdNonGrand,"kssolv.analysis.matgenlab.analysis.PhaseDiagram")|| ...
                    isa(pdNonGrand,"kssolv.analysis.matgenlab.analysis.GrandPotentialPhaseDiagram")
                error("KSSOLV:Matgenlab:GrandPotentialInterfacialReactivity:NonGrand", ...
                    "A non-grand phase diagram is required.");
            end
            obj@kssolv.analysis.matgenlab.analysis.InterfacialReactivity( ...
                c1,c2,grandPd,"norm",options.norm, ...
                "use_hull_energy",options.use_hull_energy, ...
                "bypass_grand_warning",true);
            obj.pd_non_grand=pdNonGrand;obj.grand=true;
            obj.include_no_mixing_energy=logical(options.include_no_mixing_energy);
            obj.comp1=removeOpen(obj.c1_original,grandPd.chempots);
            obj.comp2=removeOpen(obj.c2_original,grandPd.chempots);
            if obj.norm
                obj.factor1=obj.comp1.num_atoms/obj.c1_original.num_atoms;
                obj.factor2=obj.comp2.num_atoms/obj.c2_original.num_atoms;
                obj.comp1=obj.comp1.fractional_composition;
                obj.comp2=obj.comp2.fractional_composition;
            end
            if obj.include_no_mixing_energy
                obj.e1=obj.get_grand_potential(obj.c1);
                obj.e2=obj.get_grand_potential(obj.c2);
            else
                obj.e1=grandPd.get_hull_energy(obj.comp1);
                obj.e2=grandPd.get_hull_energy(obj.comp2);
            end
        end
        function value=get_no_mixing_energy(obj)
            first=obj.pd.get_hull_energy(obj.comp1)-obj.get_grand_potential(obj.c1);
            second=obj.pd.get_hull_energy(obj.comp2)-obj.get_grand_potential(obj.c2);
            if obj.norm,unit="eV/atom";else,unit="eV/f.u.";end
            value={obj.c1_original.reduced_formula+" ("+unit+")",first; ...
                obj.c2_original.reduced_formula+" ("+unit+")",second};
        end
        function reactants=get_reactants(obj,x)
            reactants=get_reactants@kssolv.analysis.matgenlab.analysis. ...
                InterfacialReactivity(obj,x);
            for ii=1:size(obj.pd.chempots,1)
                reactants{end+1}=kssolv.analysis.matgenlab.core. ...
                    Composition(obj.pd.chempots{ii,1}.symbol); %#ok<AGROW>
            end
        end
        function value=get_grand_potential(obj,composition)
            if obj.use_hull_energy
                value=obj.pd_non_grand.get_hull_energy(composition);
            else
                value=obj.get_entry_energy(obj.pd_non_grand,composition);
            end
            for ii=1:size(obj.pd.chempots,1)
                value=value-composition(obj.pd.chempots{ii,1})*obj.pd.chempots{ii,2};
            end
            if obj.norm
                nonOpen=removeOpen(composition,obj.pd.chempots);
                value=value/nonOpen.num_atoms;
            end
        end
        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.analysis.InterfacialReactivity(obj);
            data.x_class="GrandPotentialInterfacialReactivity";
            data.grand_pd=obj.pd.as_dict();data.pd_non_grand=obj.pd_non_grand.as_dict();
            data.include_no_mixing_energy=obj.include_no_mixing_energy;
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(data)
            c1=kssolv.analysis.matgenlab.core.Composition.from_dict(data.c1);
            c2=kssolv.analysis.matgenlab.core.Composition.from_dict(data.c2);
            grand=kssolv.analysis.matgenlab.analysis.GrandPotentialPhaseDiagram. ...
                from_dict(data.grand_pd);
            regular=kssolv.analysis.matgenlab.analysis.PhaseDiagram. ...
                from_dict(data.pd_non_grand);
            obj=kssolv.analysis.matgenlab.analysis. ...
                GrandPotentialInterfacialReactivity(c1,c2,grand,regular, ...
                "include_no_mixing_energy",data.include_no_mixing_energy, ...
                "norm",data.norm,"use_hull_energy",data.use_hull_energy);
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.analysis. ...
                GrandPotentialInterfacialReactivity.from_dict(data);
        end
    end
end

function value=removeOpen(composition,chempots)
pairs=cell(0,2);open=cellfun(@(x)x.symbol,chempots(:,1));
for el=composition.elements
    if ~any(open==el{1}.symbol),pairs(end+1,:)={el{1},composition(el{1})};end %#ok<AGROW>
end
value=kssolv.analysis.matgenlab.core.Composition(pairs);
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
