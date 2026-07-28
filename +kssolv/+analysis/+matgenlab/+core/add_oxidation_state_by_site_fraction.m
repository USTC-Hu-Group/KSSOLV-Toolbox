function structure = add_oxidation_state_by_site_fraction( ...
        structure, oxidationStates)
%ADD_OXIDATION_STATE_BY_SITE_FRACTION Decorate every fractional site species.
if ~iscell(oxidationStates) || numel(oxidationStates) ~= structure.num_sites
    error("KSSOLV:Matgenlab:BondValence:OxidationStateLength", ...
        "Oxidation state of all sites must be specified in the list.");
end
for index = 1:structure.num_sites
    site = structure.get_site(index);
    [species, occupancies] = ...
        kssolv.analysis.matgenlab.core.get_z_ordered_elmap(site.species);
    states = oxidationStates{index};
    if numel(states) ~= numel(species)
        error("KSSOLV:Matgenlab:BondValence:OxidationStateLength", ...
            "Oxidation state of all sites must be specified in the list.");
    end
    pairs = cell(numel(species), 2);
    for speciesIndex = 1:numel(species)
        pairs(speciesIndex, :) = { ...
            kssolv.analysis.matgenlab.core.Species( ...
                species{speciesIndex}.symbol, states(speciesIndex)), ...
            occupancies(speciesIndex)};
    end
    structure = structure.replace(index, ...
        kssolv.analysis.matgenlab.core.Composition(pairs));
end
end
