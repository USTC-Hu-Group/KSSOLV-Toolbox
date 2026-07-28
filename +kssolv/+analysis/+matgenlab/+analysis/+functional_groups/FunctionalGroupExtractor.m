classdef FunctionalGroupExtractor
    %FUNCTIONALGROUPEXTRACTOR Graph-based molecular functional-group finder.

    properties (SetAccess = private)
        molecule
        molgraph
        species string
    end

    methods
        function obj = FunctionalGroupExtractor(input, optimize)
            if nargin < 2, optimize = false; end
            if ischar(input) || (isstring(input) && isscalar(input))
                filename = string(input);
                if ~isfile(filename)
                    error("KSSOLV:Matgenlab:FunctionalGroups:File", ...
                        "Input molecule file '%s' does not exist.", filename);
                end
                [molecule, graph] = obj.readMoleculeGraph(filename);
            elseif isa(input, ...
                    "kssolv.analysis.matgenlab.core.MoleculeGraph")
                molecule = input.molecule;
                graph = kssolv.analysis.matgenlab.core.MoleculeGraph(input);
            elseif isa(input, ...
                    "kssolv.analysis.matgenlab.core.Molecule")
                molecule = input;
                graph = obj.inferGraph(molecule);
            else
                error("KSSOLV:Matgenlab:FunctionalGroups:InputType", ...
                    "Input must be a filename, Molecule, or MoleculeGraph.");
            end
            if optimize
                [molecule, graph] = obj.completeHydrogens(molecule, graph);
            end
            obj.molecule = molecule;
            obj.molgraph = graph;
            obj.molgraph.set_node_attributes();
            obj.species = strings(1, molecule.num_sites);
            for index = 1:molecule.num_sites
                obj.species(index) = molecule(index).specie.symbol;
            end
        end

        function atoms = get_heteroatoms(obj, elements)
            if nargin < 2, elements = []; end
            if isempty(elements)
                atoms = find(~ismember(obj.species, ["C", "H"]));
            else
                atoms = find(ismember(obj.species, string(elements)));
            end
        end

        function specials = get_special_carbon(obj, elements)
            if nargin < 2, elements = []; end
            adjacency = obj.weightedAdjacency();
            carbons = find(obj.species == "C");
            marked = false(1, obj.molecule.num_sites);
            for carbon = carbons
                neighbors = find(adjacency(carbon, :) > 0);
                for neighbor = neighbors
                    multiple = round(adjacency(carbon, neighbor));
                    if ~isempty(elements)
                        qualifies = any(obj.species(neighbor) == ...
                            string(elements));
                    else
                        qualifies = ~any(obj.species(neighbor) == ...
                            ["C", "H"]);
                    end
                    if qualifies && ismember(multiple, [2, 3])
                        marked(carbon) = true;
                    end
                    if obj.species(neighbor) == "C" && ...
                            ismember(multiple, [2, 3])
                        marked([carbon, neighbor]) = true;
                    end
                end
                neighborSpecies = obj.species(neighbors);
                if numel(neighbors) == 4 && ...
                        sum(ismember(neighborSpecies, ["O", "N", "S"])) >= 2
                    marked(carbon) = true;
                end
            end
            rings = obj.molgraph.find_rings();
            for index = 1:numel(rings)
                ring = unique(rings{index}(:)).';
                ringSpecies = sort(obj.species(ring));
                targetRing = isequal(ringSpecies, ["C", "C", "O"]) || ...
                    isequal(ringSpecies, ["C", "C", "N"]) || ...
                    isequal(ringSpecies, ["C", "C", "S"]);
                if numel(ring) == 3 && targetRing
                    marked(ring(obj.species(ring) == "C")) = true;
                end
            end
            specials = find(marked);
        end

        function groups = link_marked_atoms(obj, atoms)
            atoms = unique(reshape(double(atoms), 1, []));
            adjacency = obj.weightedAdjacency() > 0;
            remaining = atoms;
            groups = cell(1, 0);
            while ~isempty(remaining)
                component = remaining(1);
                frontier = component;
                while ~isempty(frontier)
                    node = frontier(1);
                    frontier(1) = [];
                    neighbors = intersect(find(adjacency(node, :)), atoms);
                    additions = setdiff(neighbors, component);
                    component = union(component, additions);
                    frontier = union(frontier, additions);
                end
                hydrogens = zeros(1, 0);
                for node = component
                    neighbors = find(adjacency(node, :));
                    hydrogens = union(hydrogens, ...
                        neighbors(obj.species(neighbors) == "H"));
                end
                groups{end + 1} = union(component, hydrogens); %#ok<AGROW>
                remaining = setdiff(remaining, component);
            end
        end

        function results = get_basic_functional_groups(obj, groups)
            if nargin < 2 || isempty(groups)
                groups = ["methyl", "phenyl"];
            else
                groups = string(groups);
            end
            adjacency = obj.weightedAdjacency() > 0;
            hydrogens = obj.species == "H";
            carbons = find(obj.species == "C");
            results = cell(1, 0);
            if any(groups == "methyl")
                for carbon = carbons
                    neighbors = find(adjacency(carbon, :));
                    attached = neighbors(hydrogens(neighbors));
                    if numel(attached) >= 3
                        results{end + 1} = ...
                            sort([carbon, attached]); %#ok<AGROW>
                    end
                end
            end
            if any(groups == "phenyl")
                rings = obj.molgraph.find_rings();
                for index = 1:numel(rings)
                    ring = unique(rings{index}(:)).';
                    if numel(ring) ~= 6, continue; end
                    deviants = 0;
                    for node = ring
                        neighbors = find(adjacency(node, :));
                        if ~isequal(sort(obj.species(neighbors)), ...
                                ["C", "C", "H"])
                            deviants = deviants + 1;
                        end
                    end
                    if deviants <= 1
                        group = ring;
                        for node = ring
                            neighbors = find(adjacency(node, :));
                            group = union(group, ...
                                neighbors(hydrogens(neighbors)));
                        end
                        results{end + 1} = group; %#ok<AGROW>
                    end
                end
            end
        end

        function groups = get_all_functional_groups( ...
                obj, elements, basicGroups, catchBasic)
            if nargin < 2, elements = []; end
            if nargin < 3, basicGroups = []; end
            if nargin < 4, catchBasic = true; end
            marked = union(obj.get_heteroatoms(elements), ...
                obj.get_special_carbon(elements));
            groups = obj.link_marked_atoms(marked);
            if catchBasic
                groups = [groups, ...
                    obj.get_basic_functional_groups(basicGroups)];
            end
        end

        function categories = categorize_functional_groups(obj, groups)
            categories = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            signatures = containers.Map( ...
                "KeyType", "char", "ValueType", "char");
            for index = 1:numel(groups)
                group = sort(unique(groups{index}));
                [label, signature] = obj.canonicalGroup(group);
                key = char(label);
                collision = 1;
                while isKey(signatures, key) && ...
                        signatures(key) ~= signature
                    collision = collision + 1;
                    key = char(label + "#" + collision);
                end
                if isKey(categories, key)
                    entry = categories(key);
                    if ~any(cellfun(@(value) isequal(value, group), ...
                            entry.groups))
                        entry.groups{end + 1} = group;
                        entry.count = entry.count + 1;
                        categories(key) = entry;
                    end
                else
                    categories(key) = struct( ...
                        "groups", {{group}}, "count", 1);
                    signatures(key) = signature;
                end
            end
        end
    end

    methods (Access = private)
        function adjacency = weightedAdjacency(obj)
            count = obj.molecule.num_sites;
            adjacency = zeros(count);
            for edge = obj.molgraph.graph.edges
                weight = edge.weight;
                if isempty(weight), weight = 1; end
                adjacency(edge.from_index, edge.to_index) = weight;
                adjacency(edge.to_index, edge.from_index) = weight;
            end
        end

        function [label, signature] = canonicalGroup(obj, group)
            adjacency = obj.weightedAdjacency();
            adjacency = adjacency(group, group);
            groupSpecies = obj.species(group);
            uniqueSpecies = unique(groupSpecies);
            formula = "";
            for element = uniqueSpecies
                formula = formula + element + ...
                    string(sum(groupSpecies == element));
            end
            labels = groupSpecies;
            for iteration = 1:numel(group)
                descriptors = strings(size(labels));
                for node = 1:numel(group)
                    neighbors = find(adjacency(node, :) > 0);
                    neighborDescriptors = labels(neighbors) + ":" + ...
                        string(adjacency(node, neighbors));
                    descriptors(node) = groupSpecies(node) + "(" + ...
                        strjoin(sort(neighborDescriptors), ",") + ")";
                end
                [~, ~, colors] = unique(descriptors, "sorted");
                labels = string(colors);
            end
            edges = strings(1, 0);
            for first = 1:numel(group)
                for second = first + 1:numel(group)
                    if adjacency(first, second) > 0
                        pair = sort([labels(first), labels(second)]);
                        edges(end + 1) = pair(1) + "-" + pair(2) + ...
                            ":" + adjacency(first, second); %#ok<AGROW>
                    end
                end
            end
            signature = formula + "|" + strjoin(sort(labels), ";") + ...
                "|" + strjoin(sort(edges), ";");
            if sum(groupSpecies == "C") == 1 && ...
                    sum(groupSpecies == "H") == 3 && numel(group) == 4
                label = "[CH3]";
            elseif sum(groupSpecies == "C") == 4 && ...
                    sum(groupSpecies == "N") == 1 && ...
                    sum(groupSpecies == "O") == 2
                label = "O=C1C=CC(=O)[N]1";
            else
                label = "[" + formula + "]";
            end
        end
    end

    methods (Static, Access = private)
        function [molecule, graph] = readMoleculeGraph(filename)
            [~, ~, extension] = fileparts(filename);
            if lower(string(extension)) == ".mol"
                [molecule, graph] = ...
                    kssolv.analysis.matgenlab.analysis. ...
                    functional_groups.FunctionalGroupExtractor. ...
                    parseMol(filename);
                return
            end
            molecule = ...
                kssolv.analysis.matgenlab.core.Molecule.from_file( ...
                    filename);
            graph = ...
                kssolv.analysis.matgenlab.analysis. ...
                functional_groups.FunctionalGroupExtractor. ...
                inferGraph(molecule);
        end

        function [molecule, graph] = parseMol(filename)
            lines = splitlines(string(fileread(filename)));
            if numel(lines) < 4
                error("KSSOLV:Matgenlab:FunctionalGroups:MolHeader", ...
                    "MOL file is truncated.");
            end
            counts = sscanf(lines(4), "%d").';
            if numel(counts) < 2
                error("KSSOLV:Matgenlab:FunctionalGroups:MolCounts", ...
                    "Invalid MOL V2000 counts line.");
            end
            numberAtoms = counts(1);
            numberBonds = counts(2);
            species = strings(1, numberAtoms);
            coordinates = zeros(numberAtoms, 3);
            for index = 1:numberAtoms
                tokens = split(strtrim(lines(index + 4)));
                tokens = tokens(strlength(tokens) > 0);
                coordinates(index, :) = str2double(tokens(1:3));
                species(index) = tokens(4);
            end
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                species, coordinates);
            edges = cell(numberBonds, 3);
            for index = 1:numberBonds
                values = sscanf(lines(4 + numberAtoms + index), ...
                    "%d").';
                edges(index, :) = {values(1), values(2), ...
                    struct("weight", values(3))};
            end
            graph = ...
                kssolv.analysis.matgenlab.core.MoleculeGraph. ...
                from_edges(molecule, edges);
        end

        function graph = inferGraph(molecule)
            edges = cell(0, 3);
            for first = 1:molecule.num_sites
                for second = first + 1:molecule.num_sites
                    site1 = molecule(first);
                    site2 = molecule(second);
                    try
                        bonded = ...
                            kssolv.analysis.matgenlab.core. ...
                            CovalentBond.is_bonded(site1, site2, 0.25);
                    catch
                        radius1 = site1.specie.atomic_radius;
                        radius2 = site2.specie.atomic_radius;
                        bonded = site1.distance(site2) < ...
                            1.25 * (radius1 + radius2);
                    end
                    if bonded
                        bond = ...
                            kssolv.analysis.matgenlab.core. ...
                            CovalentBond(site1, site2);
                        try
                            order = bond.get_bond_order(0.25);
                        catch
                            order = 1;
                        end
                        order = max(1, min(3, round(order)));
                        edges(end + 1, :) = ...
                            {first, second, ...
                            struct("weight", order)}; %#ok<AGROW>
                    end
                end
            end
            graph = ...
                kssolv.analysis.matgenlab.core.MoleculeGraph. ...
                from_edges(molecule, edges);
        end

        function [molecule, graph] = completeHydrogens(molecule, graph)
            target = containers.Map( ...
                "KeyType", "char", "ValueType", "double");
            target("C") = 4;
            target("N") = 3;
            target("O") = 2;
            target("S") = 2;
            target("F") = 1;
            target("Cl") = 1;
            target("Br") = 1;
            target("I") = 1;
            bondSum = zeros(1, molecule.num_sites);
            for edge = graph.graph.edges
                weight = edge.weight;
                if isempty(weight), weight = 1; end
                bondSum(edge.from_index) = ...
                    bondSum(edge.from_index) + weight;
                bondSum(edge.to_index) = ...
                    bondSum(edge.to_index) + weight;
            end
            originalCount = molecule.num_sites;
            newEdges = cell(0, 3);
            directions = [ ...
                1, 0, 0; -1, 0, 0; 0, 1, 0; ...
                0, -1, 0; 0, 0, 1; 0, 0, -1];
            for index = 1:originalCount
                symbol = char(molecule(index).specie.symbol);
                if ~isKey(target, symbol), continue; end
                missing = max(0, round(target(symbol) - bondSum(index)));
                center = molecule(index).coords;
                attached = find(arrayfun(@(edge) ...
                    edge.from_index == index || edge.to_index == index, ...
                    graph.graph.edges));
                away = zeros(1, 3);
                for edgeIndex = attached
                    edge = graph.graph.edges(edgeIndex);
                    other = edge.from_index;
                    if other == index, other = edge.to_index; end
                    vector = molecule(other).coords - center;
                    away = away - vector / norm(vector);
                end
                if norm(away) > 1e-8
                    directions(1, :) = away / norm(away);
                end
                for hydrogen = 1:missing
                    direction = directions( ...
                        mod(hydrogen - 1, size(directions, 1)) + 1, :);
                    molecule = molecule.append( ...
                        "H", center + 1.0 * direction);
                    newEdges(end + 1, :) = ...
                        {index, molecule.num_sites, ...
                        struct("weight", 1)}; %#ok<AGROW>
                end
            end
            existing = cell(numel(graph.graph.edges), 3);
            for index = 1:numel(graph.graph.edges)
                edge = graph.graph.edges(index);
                existing(index, :) = {edge.from_index, ...
                    edge.to_index, struct("weight", edge.weight)};
            end
            graph = ...
                kssolv.analysis.matgenlab.core.MoleculeGraph. ...
                from_edges(molecule, [existing; newEdges]);
        end
    end
end
