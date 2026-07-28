function result = sulfide_type(structure)
%SULFIDE_TYPE Classify S bonding as sulfide, polysulfide, or sulfate.
structure = structure.copy();
structure = structure.remove_oxidation_states();
composition = structure.composition;
if composition.is_element || ~composition.contains("S")
    result = missing; return
end

try
    analyzer = ...
        kssolv.analysis.matgenlab.symmetry.analyzer. ...
        SpacegroupAnalyzer(structure, 0.1);
    groups = analyzer.get_symmetrized_structure().equivalent_sites;
    sulfurSites = cell(1, 0);
    for index = 1:numel(groups)
        if groups{index}{1}.specie.symbol == "S"
            sulfurSites{end + 1} = groups{index}{1}; %#ok<AGROW>
        end
    end
catch
    sulfurSites = cell(1, 0);
    for index = 1:structure.num_sites
        if structure.get_site(index).specie.symbol == "S"
            sulfurSites{end + 1} = structure.get_site(index); %#ok<AGROW>
        end
    end
end

types = strings(1, numel(sulfurSites));
for index = 1:numel(sulfurSites)
    site = sulfurSites{index};
    radius = 4;
    neighbors = cell(1, 0);
    while isempty(neighbors)
        neighbors = structure.get_neighbors(site, radius);
        radius = radius * 2;
        if radius > max(structure.lattice.abc) * 2, break; end
    end
    if isempty(neighbors), types(index) = "sulfide"; continue; end
    distances = cellfun(@(item) item.nn_distance, neighbors);
    [distances, order] = sort(distances);
    neighbors = neighbors(order);
    selected = neighbors(distances < distances(1) + 0.4);
    selected = selected(1:min(4, numel(selected)));
    average = mean(cellfun(@(item) item.specie.X, selected));
    sulfurX = kssolv.analysis.matgenlab.core.Element("S").X;
    if average > sulfurX, types(index) = "sulfate";
    elseif abs(average - sulfurX) < 1e-12 && ...
            any(cellfun(@(item) item.specie.symbol == "S", selected))
        types(index) = "polysulfide";
    else, types(index) = "sulfide";
    end
end
if any(types == "sulfate"), result = missing;
elseif any(types == "polysulfide"), result = "polysulfide";
else, result = "sulfide";
end
end
