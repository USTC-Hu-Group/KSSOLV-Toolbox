function [species, occupancies] = get_z_ordered_elmap(composition)
%GET_Z_ORDERED_ELMAP Deterministically order a site's species mapping.
[species, occupancies] = composition.items();
ranks = zeros(numel(species), 3);
names = strings(numel(species), 1);
for index = 1:numel(species)
    ranks(index, 1) = species{index}.X;
    if isnan(ranks(index, 1)), ranks(index, 1) = Inf; end
    names(index) = species{index}.symbol;
    oxidation = 0;
    if isa(species{index}, "kssolv.analysis.matgenlab.core.Species") && ...
            ~isnan(species{index}.oxi_state)
        oxidation = species{index}.oxi_state;
    end
    ranks(index, 2) = double(sum(char(names(index))));
    ranks(index, 3) = oxidation;
end
[~, order] = sortrows(ranks, [1, 2, 3]);
species = species(order);
occupancies = occupancies(order);
end
