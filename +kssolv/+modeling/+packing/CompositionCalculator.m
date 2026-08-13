classdef CompositionCalculator
    %COMPOSITIONCALCULATOR Convert count/mole/mass specifications to counts.
    methods (Static)
        function counts=counts(components,values,mode,totalMolecules)
            if ~iscell(components), components={components}; end
            values=reshape(double(values),1,[]);
            if numel(values)~=numel(components) || any(values<0) || ...
                    sum(values)<=0
                error("KSSOLV:Modeling:PackingComposition", ...
                    "Composition values must align with components and be nonnegative.");
            end
            mode=lower(string(mode));
            switch mode
                case "count"
                    if any(values~=fix(values)) || any(values<1)
                        error("KSSOLV:Modeling:PackingComposition", ...
                            "Count composition requires positive integers.");
                    end
                    counts=values; return
                case "mole_fraction"
                    fractions=values/sum(values);
                case "mass_fraction"
                    masses=cellfun(@(item)item.composition.weight,components);
                    fractions=(values./masses)/sum(values./masses);
                otherwise
                    error("KSSOLV:Modeling:PackingCompositionMode", ...
                        "Composition mode must be count, mole_fraction, or mass_fraction.");
            end
            if nargin<4 || isempty(totalMolecules) || totalMolecules<1 || ...
                    totalMolecules~=fix(totalMolecules)
                error("KSSOLV:Modeling:PackingTotal", ...
                    "Fraction modes require a positive integer totalMolecules.");
            end
            raw=fractions*totalMolecules; counts=floor(raw);
            [~,order]=sort(raw-counts,"descend");
            counts(order(1:totalMolecules-sum(counts)))= ...
                counts(order(1:totalMolecules-sum(counts)))+1;
            if any(counts==0)
                error("KSSOLV:Modeling:PackingComposition", ...
                    "The requested total is too small to include every component.");
            end
        end
    end
end
