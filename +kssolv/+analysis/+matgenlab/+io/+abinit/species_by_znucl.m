function species = species_by_znucl(structure)
%SPECIES_BY_ZNUCL Return species in first-site occurrence order.
species={};
for index=1:structure.num_sites
    current=structure.sites{index}.specie;
    if isempty(species) || ~any(cellfun(@(item) double(item.Z)==double(current.Z),species))
        species{end+1}=current; %#ok<AGROW>
    end
end
end
