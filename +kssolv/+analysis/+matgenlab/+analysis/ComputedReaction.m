classdef ComputedReaction < kssolv.analysis.matgenlab.analysis.Reaction
    %COMPUTEDREACTION Reaction backed by ComputedEntry energies.

    properties (Access=private)
        reactant_entries cell
        product_entries cell
    end

    properties (Dependent,SetAccess=private)
        all_entries
        calculated_reaction_energy
        calculated_reaction_energy_uncertainty
    end

    methods
        function obj=ComputedReaction(reactants,products)
            reducedReactants=cellfun(@(entry) ...
                entry.composition.reduced_composition, ...
                reactants,UniformOutput=false);
            reducedProducts=cellfun(@(entry) ...
                entry.composition.reduced_composition, ...
                products,UniformOutput=false);
            obj@kssolv.analysis.matgenlab.analysis.Reaction( ...
                reducedReactants,reducedProducts);
            obj.reactant_entries=reshape(reactants,1,[]);
            obj.product_entries=reshape(products,1,[]);
        end

        function value=get.all_entries(obj)
            source=[obj.reactant_entries,obj.product_entries];
            value=cell(1,numel(obj.all_comp_));
            for index=1:numel(obj.all_comp_)
                match=find(cellfun(@(entry) ...
                    string(entry.reduced_formula)== ...
                    string(obj.all_comp_{index}.reduced_formula), ...
                    source),1);
                value{index}=source{match};
            end
        end

        function value=get.calculated_reaction_energy(obj)
            value=0;
            source=[obj.reactant_entries,obj.product_entries];
            for index=1:numel(obj.all_comp_)
                candidates=find(cellfun(@(entry) ...
                    entry.composition.reduced_composition== ...
                    obj.all_comp_{index},source));
                energies=zeros(1,numel(candidates));
                for candidateIndex=1:numel(candidates)
                    entry=source{candidates(candidateIndex)};
                    [~,factor]=entry.composition. ...
                        get_reduced_composition_and_factor();
                    energies(candidateIndex)=entry.energy/factor;
                end
                value=value+obj.coeffs_(index)*min(energies);
            end
        end

        function value=get.calculated_reaction_energy_uncertainty(obj)
            source=[obj.reactant_entries,obj.product_entries];
            variance=0; anyFinite=false;
            for index=1:numel(obj.all_comp_)
                candidates=find(cellfun(@(entry) ...
                    entry.composition.reduced_composition== ...
                    obj.all_comp_{index},source));
                energies=zeros(1,numel(candidates));
                factors=zeros(1,numel(candidates));
                for candidateIndex=1:numel(candidates)
                    entry=source{candidates(candidateIndex)};
                    [~,factors(candidateIndex)]=entry.composition. ...
                        get_reduced_composition_and_factor();
                    energies(candidateIndex)= ...
                        entry.energy/factors(candidateIndex);
                end
                [~,minimumIndex]=min(energies);
                entry=source{candidates(minimumIndex)};
                uncertainty=entry.correction_uncertainty;
                if isfinite(uncertainty) && uncertainty~=0
                    factor=factors(minimumIndex);
                    variance=variance+(obj.coeffs_(index)* ...
                        uncertainty/factor)^2;
                    anyFinite=true;
                end
            end
            if anyFinite,value=sqrt(variance);else,value=NaN;end
        end

        function value=as_dict(obj)
            reactants=cellfun(@(entry)entry.as_dict(), ...
                obj.reactant_entries,UniformOutput=false);
            products=cellfun(@(entry)entry.as_dict(), ...
                obj.product_entries,UniformOutput=false);
            value=struct( ...
                "x_module","pymatgen.analysis.reaction_calculator", ...
                "x_class","ComputedReaction","reactants",{reactants}, ...
                "products",{products});
        end
    end

    methods (Static)
        function obj=from_dict(value)
            reactants=cellfun(@(entry) ...
                kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(entry), ...
                value.reactants,UniformOutput=false);
            products=cellfun(@(entry) ...
                kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(entry), ...
                value.products,UniformOutput=false);
            obj=kssolv.analysis.matgenlab.analysis. ...
                ComputedReaction(reactants,products);
        end
    end
end
