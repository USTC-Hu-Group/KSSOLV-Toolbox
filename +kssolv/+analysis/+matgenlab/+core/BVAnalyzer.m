classdef BVAnalyzer
    %BVANALYZER Maximum-a-posteriori bond-valence oxidation assignment.

    properties (Constant)
        CHARGE_NEUTRALITY_TOLERANCE = 1e-5
    end

    properties (SetAccess = protected)
        symm_tol (1,1) double = 0.1
        max_radius (1,1) double = 4
        max_permutations (1,1) double = 100000
        dist_scale_factor (1,1) double = 1.015
        charge_neutrality_tolerance (1,1) double = 1e-5
        forbidden_species string = strings(1, 0)
    end

    methods
        function obj = BVAnalyzer(symmTol, maxRadius, maxPermutations, ...
                distanceScaleFactor, chargeTolerance, forbiddenSpecies)
            if nargin >= 1 && ~isempty(symmTol), obj.symm_tol = symmTol; end
            if nargin >= 2 && ~isempty(maxRadius), obj.max_radius = maxRadius; end
            if nargin >= 3 && ~isempty(maxPermutations)
                obj.max_permutations = maxPermutations;
            end
            if nargin >= 4 && ~isempty(distanceScaleFactor)
                obj.dist_scale_factor = distanceScaleFactor;
            end
            if nargin >= 5 && ~isempty(chargeTolerance)
                obj.charge_neutrality_tolerance = chargeTolerance;
            end
            if nargin >= 6 && ~isempty(forbiddenSpecies)
                if iscell(forbiddenSpecies)
                    obj.forbidden_species = string(cellfun(@(item) ...
                        string(kssolv.analysis.matgenlab.core.getElSp(item)), ...
                        forbiddenSpecies, "UniformOutput", false));
                else
                    obj.forbidden_species = string(forbiddenSpecies);
                end
            end
        end

        function valences = get_valences(obj, structure)
            parameters = ...
                kssolv.analysis.matgenlab.core.BondValenceData.parameters();
            symbols = structure.symbol_set;
            missing = symbols(~cellfun(@(name) isKey(parameters, char(name)), ...
                cellstr(symbols)));
            if ~isempty(missing)
                error("KSSOLV:Matgenlab:BVAnalyzer:UnsupportedElement", ...
                    "Structure contains elements without bond-valence parameters: %s.", ...
                    strjoin(missing, ", "));
            end

            if obj.symm_tol > 0
                analyzer = ...
                    kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SpacegroupAnalyzer(structure, obj.symm_tol);
                equivalentSites = ...
                    analyzer.get_symmetrized_structure().equivalent_sites;
            else
                equivalentSites = cell(1, structure.num_sites);
                for index = 1:structure.num_sites
                    equivalentSites{index} = {structure.get_site(index)};
                end
            end
            electronegativities = cellfun(@(sites) ...
                sites{1}.species.average_electroneg, equivalentSites);
            [~, order] = sort(electronegativities, "descend");
            equivalentSites = equivalentSites(order);

            if structure.is_ordered
                valences = obj.orderedValences(structure, equivalentSites);
            else
                valences = obj.unorderedValences(structure, equivalentSites);
            end
        end

        function structure = get_oxi_state_decorated_structure(obj, structure)
            structure = structure.copy();
            valences = obj.get_valences(structure);
            if structure.is_ordered
                structure = structure.add_oxidation_state_by_site(valences);
            else
                structure = kssolv.analysis.matgenlab.core. ...
                    add_oxidation_state_by_site_fraction(structure, valences);
            end
        end
    end

    methods (Access = protected)
        function result = orderedValences(obj, structure, groups)
            count = numel(groups);
            candidates = cell(1, count);
            probabilities = cell(1, count);
            for index = 1:count
                site = groups{index}{1};
                neighbors = structure.get_neighbors(site, obj.max_radius);
                probabilities{index} = obj.siteProbabilities(site, neighbors);
                states = cell2mat(keys(probabilities{index}));
                likelihoods = cell2mat(values(probabilities{index}));
                [likelihoods, order] = sort(likelihoods, "descend");
                states = states(order);
                states = states(likelihoods > 0.01 * likelihoods(1));
                if isempty(states)
                    error("KSSOLV:Matgenlab:BVAnalyzer:NoCandidates", ...
                        "No nonzero oxidation-state candidates for %s.", ...
                        site.species_string);
                end
                candidates{index} = states;
            end
            multiplicities = cellfun(@numel, groups);
            minima = cellfun(@min, candidates);
            maxima = cellfun(@max, candidates);
            bestScore = 0;
            best = [];
            attempts = 0;
            recurse(1, zeros(1, count));
            if isempty(best)
                error("KSSOLV:Matgenlab:BVAnalyzer:Assignment", ...
                    "Valences cannot be assigned.");
            end

            result = zeros(1, structure.num_sites);
            for group = 1:count
                for siteIndex = 1:structure.num_sites
                    if any(cellfun(@(site) ...
                            site == structure.get_site(siteIndex), ...
                            groups{group}))
                        result(siteIndex) = best(group);
                    end
                end
            end

            function recurse(position, assigned)
                if attempts > obj.max_permutations, return; end
                highest = maxima;
                lowest = minima;
                if position > 1
                    highest(1:position-1) = assigned(1:position-1);
                    lowest(1:position-1) = assigned(1:position-1);
                end
                if sum(highest .* multiplicities) < 0 || ...
                        sum(lowest .* multiplicities) > 0
                    attempts = attempts + 1;
                    return
                end
                if position > count
                    attempts = attempts + 1;
                    byElement = containers.Map("KeyType", "char", ...
                        "ValueType", "any");
                    for item = 1:count
                        key = char(groups{item}{1}.specie.symbol);
                        if isKey(byElement, key)
                            byElement(key) = [byElement(key), assigned(item)];
                        else
                            byElement(key) = assigned(item);
                        end
                    end
                    names = keys(byElement);
                    for nameIndex = 1:numel(names)
                        values_ = byElement(names{nameIndex});
                        if max(values_) - min(values_) > 1, return; end
                    end
                    score = 1;
                    for item = 1:count
                        score = score * probabilities{item}(assigned(item));
                    end
                    if score > bestScore
                        bestScore = score;
                        best = assigned;
                    end
                    return
                end
                for state = reshape(candidates{position}, 1, [])
                    assigned(position) = state;
                    recurse(position + 1, assigned);
                end
            end
        end

        function result = unorderedValences(obj, structure, groups)
            numberGroups = numel(groups);
            groupSpecies = cell(1, numberGroups);
            groupOccupancies = cell(1, numberGroups);
            probabilityMaps = cell(1, numberGroups);
            candidates = cell(1, 0);
            variableGroup = zeros(1, 0);
            variableElement = strings(1, 0);
            variableFraction = zeros(1, 0);
            variableMultiplicity = zeros(1, 0);
            for groupIndex = 1:numberGroups
                site = groups{groupIndex}{1};
                neighbors = structure.get_neighbors(site, obj.max_radius);
                [groupSpecies{groupIndex}, groupOccupancies{groupIndex}] = ...
                    kssolv.analysis.matgenlab.core. ...
                    get_z_ordered_elmap(site.species);
                probabilityMaps{groupIndex} = obj.unorderedSiteProbabilities( ...
                    site, neighbors, groupSpecies{groupIndex});
                for speciesIndex = 1:numel(groupSpecies{groupIndex})
                    map = probabilityMaps{groupIndex}{speciesIndex};
                    states = cell2mat(keys(map));
                    values_ = cell2mat(values(map));
                    [values_, order] = sort(values_, "descend");
                    states = states(order);
                    states = states(values_ > 1e-3 * values_(1));
                    candidates{end + 1} = states; %#ok<AGROW>
                    variableGroup(end + 1) = groupIndex; %#ok<AGROW>
                    variableElement(end + 1) = ...
                        groupSpecies{groupIndex}{speciesIndex}.symbol; %#ok<AGROW>
                    variableFraction(end + 1) = ...
                        groupOccupancies{groupIndex}(speciesIndex); %#ok<AGROW>
                    variableMultiplicity(end + 1) = ...
                        numel(groups{groupIndex}); %#ok<AGROW>
                end
            end
            minima = cellfun(@min, candidates);
            maxima = cellfun(@max, candidates);
            numberVariables = numel(candidates);
            bestScore = 0;
            best = [];
            attempts = 0;
            recurse(1, zeros(1, numberVariables));
            if isempty(best)
                error("KSSOLV:Matgenlab:BVAnalyzer:Assignment", ...
                    "Valences cannot be assigned.");
            end

            byGroup = cell(1, numberGroups);
            for groupIndex = 1:numberGroups
                byGroup{groupIndex} = best(variableGroup == groupIndex);
            end
            result = cell(1, structure.num_sites);
            for groupIndex = 1:numberGroups
                for siteIndex = 1:structure.num_sites
                    if any(cellfun(@(site) ...
                            site == structure.get_site(siteIndex), ...
                            groups{groupIndex}))
                        result{siteIndex} = byGroup{groupIndex};
                    end
                end
            end

            function recurse(position, assigned)
                if attempts > obj.max_permutations, return; end
                highest = maxima;
                lowest = minima;
                if position > 1
                    highest(1:position-1) = assigned(1:position-1);
                    lowest(1:position-1) = assigned(1:position-1);
                end
                weights = variableFraction .* variableMultiplicity;
                if sum(highest .* weights) < ...
                        -obj.charge_neutrality_tolerance || ...
                        sum(lowest .* weights) > ...
                        obj.charge_neutrality_tolerance
                    attempts = attempts + 1;
                    return
                end
                if position > numberVariables
                    attempts = attempts + 1;
                    for symbol = unique(variableElement)
                        values_ = assigned(variableElement == symbol);
                        if max(values_) - min(values_) > 2, return; end
                    end
                    score = 1;
                    for variable = 1:numberVariables
                        group = variableGroup(variable);
                        localIndex = sum(variableGroup(1:variable) == group);
                        score = score * ...
                            probabilityMaps{group}{localIndex}(assigned(variable));
                    end
                    if score > bestScore
                        bestScore = score;
                        best = assigned;
                    end
                    return
                end
                for state = reshape(candidates{position}, 1, [])
                    assigned(position) = state;
                    recurse(position + 1, assigned);
                end
            end
        end

        function probability = siteProbabilities(obj, site, neighbors)
            bondValence = kssolv.analysis.matgenlab.core.calculate_bv_sum( ...
                site, neighbors, obj.dist_scale_factor);
            probability = obj.elementProbabilities( ...
                site.specie.symbol, bondValence);
        end

        function result = unorderedSiteProbabilities( ...
                obj, site, neighbors, species)
            bondValence = kssolv.analysis.matgenlab.core. ...
                calculate_bv_sum_unordered( ...
                    site, neighbors, obj.dist_scale_factor);
            result = cell(1, numel(species));
            for index = 1:numel(species)
                result{index} = obj.elementProbabilities( ...
                    species{index}.symbol, bondValence);
            end
        end

        function probability = elementProbabilities(obj, symbol, bondValence)
            [data, occurrence] = ...
                kssolv.analysis.matgenlab.core.BondValenceData.icsd();
            probability = containers.Map("KeyType", "double", ...
                "ValueType", "double");
            names = keys(data);
            total = 0;
            for index = 1:numel(names)
                name = names{index};
                if any(obj.forbidden_species == string(name)), continue; end
                species = ...
                    kssolv.analysis.matgenlab.core.Species.from_str(name);
                row = data(name);
                if species.symbol ~= string(symbol) || ...
                        species.oxi_state == 0 || row.std <= 0
                    continue
                end
                value = exp(-((bondValence - row.mean)^2) / ...
                    (2 * row.std^2)) / row.std * occurrence(name);
                probability(species.oxi_state) = value;
                total = total + value;
            end
            states = keys(probability);
            if total > 0
                for index = 1:numel(states)
                    probability(states{index}) = ...
                        probability(states{index}) / total;
                end
            else
                for index = 1:numel(states)
                    probability(states{index}) = 0;
                end
            end
        end
    end
end
