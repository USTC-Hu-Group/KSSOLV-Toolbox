function alpha = get_warren_cowley_parameters(structure, radius, width)
%GET_WARREN_COWLEY_PARAMETERS Warren-Cowley short-range order values.
composition = structure.composition;
[species, ~] = composition.items();
pairCounts = containers.Map("KeyType", "char", "ValueType", "double");
neighborCounts = containers.Map("KeyType", "char", "ValueType", "double");

for siteIndex = 1:structure.num_sites
    site = structure.sites{siteIndex};
    first = char(site.specie.symbol);
    neighbors = structure.get_neighbors_in_shell( ...
        site.coords, radius, width);
    for neighborIndex = 1:numel(neighbors)
        second = char(neighbors{neighborIndex}.specie.symbol);
        key = first + "|" + second;
        increment(pairCounts, key);
        increment(neighborCounts, first);
    end
end

alpha = containers.Map("KeyType", "char", "ValueType", "double");
for firstIndex = 1:numel(species)
    first = char(species{firstIndex}.symbol);
    if ~isKey(neighborCounts, first) || neighborCounts(first) == 0
        error("KSSOLV:Matgenlab:Disorder:EmptyShell", ...
            "No neighbors were found for species %s.", first);
    end
    for secondIndex = 1:numel(species)
        second = char(species{secondIndex}.symbol);
        key = first + "|" + second;
        count = 0;
        if isKey(pairCounts, key), count = pairCounts(key); end
        probability = count / neighborCounts(first);
        concentration = composition.get_atomic_fraction(species{secondIndex});
        kronecker = double(firstIndex == secondIndex);
        alpha(key) = (probability - concentration) / ...
            (kronecker - concentration);
    end
end
end

function increment(mapping, key)
key = char(key);
if isKey(mapping, key)
    mapping(key) = mapping(key) + 1; %#ok<NASGU>
else
    mapping(key) = 1; %#ok<NASGU>
end
end
