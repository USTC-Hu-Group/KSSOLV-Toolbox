function result = check_for_structure_changes(molecule1, molecule2)
%#ok<*AGROW>
%CHECK_FOR_STRUCTURE_CHANGES Compare molecular connectivity without OpenBabel.
if molecule1.num_sites ~= molecule2.num_sites || ...
        ~isequal(sort(string(molecule1.species)), sort(string(molecule2.species)))
    error("KSSOLV:Matgenlab:QChem:Composition", ...
        "Molecules have different compositions.");
end
graph1 = connectivity(molecule1);
graph2 = connectivity(molecule2);
if isequal(graph1, graph2), result = "no_change"; return; end
if connected(graph1) && ~connected(graph2)
    result = "unconnected_fragments";
elseif nnz(triu(graph2)) < nnz(triu(graph1))
    result = "fewer_bonds";
elseif nnz(triu(graph2)) > nnz(triu(graph1))
    result = "more_bonds";
else
    result = "bond_change";
end
end

function graph = connectivity(molecule)
symbols = strings(molecule.num_sites, 1);
for index = 1:molecule.num_sites
    symbols(index) = molecule.sites{index}.species_string;
end
radii = arrayfun(@radius, symbols);
distances = squareform_local(molecule.cart_coords);
thresholds = 1.25 * (radii + radii.');
graph = distances > 1e-8 & distances <= thresholds;
graph(1:size(graph, 1) + 1:end) = false;
end

function value = radius(symbol)
names = ["H","B","C","N","O","F","Si","P","S","Cl","Br","I", ...
    "Li","Na","Mg","Ca","Zn"];
values = [0.31,0.85,0.76,0.71,0.66,0.57,1.11,1.07,1.05,1.02,1.20,1.39, ...
    1.28,1.66,1.41,1.76,1.22];
index = find(names == symbol, 1);
if isempty(index), value = 0.9; else, value = values(index); end
end

function distances = squareform_local(coordinates)
count = size(coordinates, 1);
distances = zeros(count);
for index = 1:count
    difference = coordinates - coordinates(index, :);
    distances(index, :) = sqrt(sum(difference .^ 2, 2));
end
end

function yes = connected(graph)
if isempty(graph), yes = true; return; end
seen = false(1, size(graph, 1)); queue = 1; seen(1) = true;
while ~isempty(queue)
    node = queue(1); queue(1) = [];
    neighbors = find(graph(node, :) & ~seen);
    seen(neighbors) = true;
    queue = [queue, neighbors];
end
yes = all(seen);
end
