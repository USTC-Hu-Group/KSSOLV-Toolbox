classdef StructureMatcher < kssolv.analysis.matgenlab.util.MSONable
    %STRUCTUREMATCHER Periodic structure matching with species assignment.

    properties (SetAccess = private)
        ltol (1,1) double
        stol (1,1) double
        angle_tol (1,1) double
        comparator
        primitive_cell (1,1) logical
        scale (1,1) logical
        attempt_supercell (1,1) logical
        allow_subset (1,1) logical
        supercell_size
        ignored_species
    end

    methods
        function obj = StructureMatcher(ltol, stol, angle_tol, ...
                primitive_cell, scale, attempt_supercell, allow_subset, ...
                comparator, supercell_size, ignored_species)
            if nargin < 1, ltol = 0.2; end
            if nargin < 2, stol = 0.3; end
            if nargin < 3, angle_tol = 5; end
            if nargin < 4, primitive_cell = true; end
            if nargin < 5, scale = true; end
            if nargin < 6, attempt_supercell = false; end
            if nargin < 7, allow_subset = false; end
            if nargin < 8 || isempty(comparator)
                comparator = ...
                    kssolv.analysis.matgenlab.core.SpeciesComparator();
            end
            if nargin < 9, supercell_size = "num_sites"; end
            if nargin < 10, ignored_species = strings(1, 0); end
            obj.ltol = double(ltol);
            obj.stol = double(stol);
            obj.angle_tol = double(angle_tol);
            obj.primitive_cell = logical(primitive_cell);
            obj.scale = logical(scale);
            obj.attempt_supercell = logical(attempt_supercell);
            obj.allow_subset = logical(allow_subset);
            obj.comparator = comparator;
            obj.supercell_size = supercell_size;
            obj.ignored_species = reshape(string(ignored_species), 1, []);
        end

        function tf = fit(obj, first, second, symmetric, ...
                skip_structure_reduction)
            if nargin < 4, symmetric = false; end
            if nargin < 5, skip_structure_reduction = false; end
            first = obj.processSpecies(first);
            second = obj.processSpecies(second);
            if ~obj.allow_subset && ...
                    ~obj.hashesEqual(first.composition, second.composition)
                tf = false;
                return
            end
            result = obj.matchStructures(first, second, ...
                skip_structure_reduction);
            tf = ~isempty(result) && result.max_distance <= obj.stol;
            if symmetric && tf
                reverse = obj.matchStructures(second, first, ...
                    skip_structure_reduction);
                tf = ~isempty(reverse) && ...
                    reverse.max_distance <= obj.stol;
            end
        end

        function value = get_rms_dist(obj, first, second)
            first = obj.processSpecies(first);
            second = obj.processSpecies(second);
            result = obj.matchStructures(first, second, false);
            if isempty(result)
                value = [];
            else
                value = [result.rms, result.max_distance];
            end
        end

        function groups = group_structures(obj, structures, anonymous)
            if nargin < 3, anonymous = false; end
            if obj.allow_subset
                error("KSSOLV:Matgenlab:StructureMatcher:SubsetGrouping", ...
                    "allow_subset cannot be used with group_structures.");
            end
            if ~iscell(structures), structures = num2cell(structures); end
            structures = reshape(structures, 1, []);
            groups = cell(1, numel(structures));
            groupCount=0;
            for index = 1:numel(structures)
                placed = false;
                for group = 1:groupCount
                    if anonymous
                        matched = obj.fit_anonymous( ...
                            groups{group}{1}, structures{index});
                    else
                        matched = obj.fit(groups{group}{1}, ...
                            structures{index});
                    end
                    if matched
                        groups{group}{end + 1} = structures{index};
                        placed = true;
                        break
                    end
                end
                if ~placed
                    groupCount=groupCount+1;
                    groups{groupCount}=structures(index);
                end
            end
            groups=groups(1:groupCount);
        end

        function value = asDict(obj)
            value = struct( ...
                "version", "1.0", ...
                "x_module", "pymatgen.core.structure_matcher", ...
                "x_class", "StructureMatcher", ...
                "comparator", obj.comparator.as_dict(), ...
                "stol", obj.stol, "ltol", obj.ltol, ...
                "angle_tol", obj.angle_tol, ...
                "primitive_cell", obj.primitive_cell, ...
                "scale", obj.scale, ...
                "attempt_supercell", obj.attempt_supercell, ...
                "allow_subset", obj.allow_subset, ...
                "supercell_size", obj.supercell_size, ...
                "ignored_species", obj.ignored_species);
        end

        function value = as_dict(obj), value = obj.asDict(); end

        function [rms, mapping] = get_rms_anonymous(obj, first, second)
            matches = obj.anonymousMatches(first, second);
            if isempty(matches)
                rms = [];
                mapping = [];
                return
            end
            values = cellfun(@(item) item.rms, matches);
            [rms, index] = min(values);
            mapping = matches{index}.mapping;
        end

        function mapping = ...
                get_best_electronegativity_anonymous_mapping( ...
                obj, first, second)
            matches = obj.anonymousMatches(first, second);
            if isempty(matches), mapping = []; return; end
            scores = zeros(1, numel(matches));
            firstComposition = first.composition.element_composition;
            for index = 1:numel(matches)
                names = fieldnames(matches{index}.mapping);
                for nameIndex = 1:numel(names)
                    source = names{nameIndex};
                    target = matches{index}.mapping.(source);
                    sourceElement = ...
                        kssolv.analysis.matgenlab.core.getElSp(source);
                    targetElement = ...
                        kssolv.analysis.matgenlab.core.getElSp(target);
                    scores(index) = scores(index) + ...
                        firstComposition(source) * ...
                        (sourceElement.X - targetElement.X)^2;
                end
            end
            [~, best] = min(scores);
            mapping = matches{best}.mapping;
        end

        function mappings = get_all_anonymous_mappings( ...
                obj, first, second, niggli, include_dist)
            if nargin < 4, niggli = true; end
            if nargin < 5, include_dist = false; end
            matches = obj.anonymousMatches(first, second, niggli, false);
            if isempty(matches), mappings = []; return; end
            mappings = cell(1, numel(matches));
            for index = 1:numel(matches)
                if include_dist
                    mappings{index} = {matches{index}.mapping, ...
                        matches{index}.max_distance};
                else
                    mappings{index} = matches{index}.mapping;
                end
            end
        end

        function tf = fit_anonymous(obj, first, second, niggli, ...
                skip_structure_reduction)
            if nargin < 4, niggli = true; end
            if nargin < 5, skip_structure_reduction = false; end
            matches = obj.anonymousMatches(first, second, niggli, ...
                skip_structure_reduction);
            tf = ~isempty(matches);
        end

        function matrix = get_supercell_matrix(obj, supercell, structure)
            if obj.primitive_cell
                error("KSSOLV:Matgenlab:StructureMatcher:PrimitiveOption", ...
                    "get_supercell_matrix cannot be used with the "+ ...
                    "primitive cell option.");
            end
            structure = obj.processSpecies(structure);
            supercell = obj.processSpecies(supercell);
            [factor, structureSupercell] = ...
                obj.getSupercellSize(structure, supercell);
            if ~structureSupercell
                error("KSSOLV:Matgenlab:StructureMatcher:SupercellOrder", ...
                    "The non-supercell must be put onto the basis of the "+ ...
                    "supercell, not the other way around.");
            end
            matrix = obj.inferSupercellMatrix( ...
                structure, supercell, factor);
            if isempty(matrix), return; end
            expanded = structure * matrix;
            if ~obj.fit(expanded, supercell), matrix = []; end
        end

        function [matrix, translation, mapping] = ...
                get_transformation(obj, first, second)
            if obj.primitive_cell
                error("KSSOLV:Matgenlab:StructureMatcher:PrimitiveOption", ...
                    "get_transformation cannot be used with primitive_cell.");
            end
            first = obj.processSpecies(first);
            second = obj.processSpecies(second);
            matrix = eye(3);
            expanded = second;
            if obj.attempt_supercell
                [factor, firstSupercell] = ...
                    obj.getSupercellSize(first, second);
            else
                factor = 1;
                firstSupercell = true;
            end
            if firstSupercell && factor > 1
                error("KSSOLV:Matgenlab:StructureMatcher:TransformationOrder", ...
                    "Struct1 must be the supercell, not the other way around.");
            elseif ~firstSupercell && factor > 1
                matrix = obj.inferSupercellMatrix(second, first, factor);
                if isempty(matrix)
                    translation = [];
                    mapping = [];
                    matrix = [];
                    return
                end
                expanded = second * matrix;
            end
            if first.num_sites>=expanded.num_sites
                result=obj.directMatch(first,expanded);
                if isempty(result)
                    matrix=[];translation=[];mapping=[];return
                end
                translation=result.translation;
                mapping=nan(1,first.num_sites);
                for transformedIndex=1:numel(result.mapping)
                    mapping(result.mapping(transformedIndex))= ...
                        transformedIndex;
                end
            else
                result=obj.directMatch(expanded,first);
                if isempty(result)
                    matrix=[];translation=[];mapping=[];return
                end
                translation=-result.translation;
                unused=setdiff(1:expanded.num_sites, ...
                    result.mapping,"stable");
                mapping=[result.mapping,unused];
            end
        end

        function value = get_s2_like_s1( ...
                obj, first, second, include_ignored_species)
            if nargin < 4, include_ignored_species = true; end
            [matrix, translation, mapping] = ...
                obj.get_transformation(first, second);
            if isempty(matrix), value = []; return; end
            processedFirst = obj.processSpecies(first);
            processedSecond = obj.processSpecies(second);
            transformed = processedSecond * matrix;
            coordinates = transformed.frac_coords + translation;
            referenceCount=min(processedFirst.num_sites,numel(mapping));
            for referenceIndex=1:referenceCount
                transformedIndex=mapping(referenceIndex);
                if ~isnan(transformedIndex)
                    coordinates(transformedIndex,:)= ...
                        coordinates(transformedIndex,:)+round( ...
                        processedFirst.frac_coords(referenceIndex,:)- ...
                        coordinates(transformedIndex,:));
                end
            end
            mapping=mapping(~isnan(mapping));
            coordinates=coordinates(mapping,:);
            species=transformed.species_and_occu(mapping);
            if include_ignored_species && ~isempty(obj.ignored_species)
                ignored = obj.ignoredMask(second);
                if any(ignored)
                    ignoredStructure = ...
                        kssolv.analysis.matgenlab.core.Structure( ...
                        second.lattice, ...
                        second.species_and_occu(ignored), ...
                        second.frac_coords(ignored, :));
                    transformedIgnored = ignoredStructure * matrix;
                    species = [species, ...
                        transformedIgnored.species_and_occu];
                    coordinates = [coordinates; ...
                        transformedIgnored.frac_coords + ...
                        translation];
                end
            end
            value = kssolv.analysis.matgenlab.core.Structure( ...
                first.lattice, species, coordinates);
        end

        function mapping = get_mapping(obj, superset, subset)
            if obj.attempt_supercell
                error("KSSOLV:Matgenlab:StructureMatcher:MappingSupercell", ...
                    "cannot compute mapping to supercell.");
            end
            if obj.primitive_cell
                error("KSSOLV:Matgenlab:StructureMatcher:MappingPrimitive", ...
                    "cannot compute mapping with primitive cell option.");
            end
            if subset.num_sites > superset.num_sites
                error("KSSOLV:Matgenlab:StructureMatcher:MappingSubset", ...
                    "subset is larger than superset.");
            end
            result = obj.directMatch( ...
                obj.processSpecies(superset), ...
                obj.processSpecies(subset));
            if isempty(result) || result.max_distance > obj.stol
                mapping = [];
            else
                mapping = result.mapping;
            end
        end
    end

    methods (Static)
        function obj = from_dict(value)
            comparator = kssolv.analysis.matgenlab.core. ...
                AbstractComparator.from_dict(value.comparator);
            obj = kssolv.analysis.matgenlab.core.StructureMatcher( ...
                value.ltol, value.stol, value.angle_tol, ...
                value.primitive_cell, value.scale, ...
                value.attempt_supercell, value.allow_subset, ...
                comparator, value.supercell_size, ...
                value.ignored_species);
        end
    end

    methods (Access = private)
        function structure = processSpecies(obj, structure)
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                structure.lattice, structure.species_and_occu, ...
                structure.frac_coords, ...
                site_properties = structure.site_properties, ...
                labels = structure.labels, ...
                properties = structure.structure_properties);
            if isempty(obj.ignored_species), return; end
            remove = obj.ignoredMask(structure);
            structure = structure.remove_sites(find(remove));
        end

        function remove = ignoredMask(obj, structure)
            remove = false(1, structure.num_sites);
            for siteIndex = 1:structure.num_sites
                names = string(fieldnames(structure(siteIndex). ...
                    species.element_composition.get_el_amt_dict()));
                remove(siteIndex) = ...
                    any(ismember(names, obj.ignored_species));
            end
        end

        function tf = hashesEqual(obj, first, second)
            firstHash = obj.comparator.get_hash(first);
            secondHash = obj.comparator.get_hash(second);
            if isa(firstHash, "kssolv.analysis.matgenlab.core.Composition")
                tf = firstHash == secondHash;
            else
                tf = isequal(firstHash, secondHash);
            end
        end

        function [factor,firstSupercell]=getSupercellSize( ...
                obj,first,second)
            setting=string(obj.supercell_size);
            if isscalar(setting)&&setting=="num_sites"
                ratio=second.num_sites/first.num_sites;
            elseif isscalar(setting)&&setting=="num_atoms"
                ratio=second.composition.num_atoms/ ...
                    first.composition.num_atoms;
            elseif isscalar(setting)&&setting=="volume"
                ratio=second.volume/first.volume;
            else
                firstAmount=0;
                secondAmount=0;
                for index=1:numel(setting)
                    firstAmount=firstAmount+ ...
                        first.composition.amountOf(setting(index));
                    secondAmount=secondAmount+ ...
                        second.composition.amountOf(setting(index));
                end
                if firstAmount<=0||secondAmount<=0
                    error("KSSOLV:Matgenlab:StructureMatcher:SupercellSize", ...
                        "Invalid argument for supercell_size.");
                end
                ratio=secondAmount/firstAmount;
            end
            if ~isfinite(ratio)||ratio<=0
                error("KSSOLV:Matgenlab:StructureMatcher:SupercellSize", ...
                    "Invalid argument for supercell_size.");
            end
            if ratio<2/3
                factor=round(1/ratio);
                firstSupercell=false;
            else
                factor=round(ratio);
                firstSupercell=true;
            end
            factor=max(1,factor);
        end

        function result = matchStructures(obj, first, second, skipReduction)
            if ~skipReduction
                first = obj.reduceStructure(first);
                second = obj.reduceStructure(second);
            end
            if obj.attempt_supercell
                [factor, firstSupercell] = ...
                    obj.getSupercellSize(first, second);
                if factor > 1 && firstSupercell
                    candidates = obj.supercellCandidates( ...
                        first, second, factor);
                    result = [];
                    best = Inf;
                    for index = 1:numel(candidates)
                        trial = obj.alignedMatch( ...
                            first * candidates{index}, second);
                        if ~isempty(trial) && trial.rms < best
                            result = trial;
                            result.supercell_matrix = candidates{index};
                            best = trial.rms;
                        end
                    end
                    return
                elseif factor > 1
                    candidates = obj.supercellCandidates( ...
                        second, first, factor);
                    result = [];
                    best = Inf;
                    for index = 1:numel(candidates)
                        expanded=second*candidates{index};
                        if expanded.num_sites>=first.num_sites
                            trial=obj.alignedMatch(expanded,first);
                        else
                            trial=obj.alignedMatch(first,expanded);
                        end
                        if ~isempty(trial) && trial.rms < best
                            result = trial;
                            result.supercell_matrix = candidates{index};
                            best = trial.rms;
                        end
                    end
                    return
                end
            end
            if ~obj.allow_subset && first.num_sites ~= second.num_sites
                result = [];
                return
            end
            if obj.allow_subset && first.num_sites < second.num_sites
                temporary = first; first = second; second = temporary;
            end
            result = obj.directMatch(first, second);
        end

        function structure = reduceStructure(obj, structure, niggli)
            if nargin<3,niggli=true;end
            if niggli
                try
                    structure=structure.get_reduced_structure("niggli");
                catch
                end
            end
            if obj.primitive_cell
                try
                    primitive = structure.get_primitive_structure();
                    if primitive.num_sites < structure.num_sites
                        structure = primitive;
                    end
                catch
                end
            end
        end

        function result = directMatch(obj, first, second)
            firstLattice = first.lattice;
            secondLattice = second.lattice;
            if obj.scale
                targetVolume = sqrt(first.volume * second.volume);
                first = first.scale_lattice(targetVolume);
                second = second.scale_lattice(targetVolume);
                firstLattice = first.lattice;
                secondLattice = second.lattice;
            end
            mappings = secondLattice.find_all_mappings( ...
                firstLattice, obj.ltol, obj.angle_tol, true);
            result = [];
            bestValue = Inf;
            for transformIndex = 1:size(mappings, 1)
                candidateLattice = mappings{transformIndex, 1};
                basis = mappings{transformIndex, 3};
                if abs(abs(det(basis)) - 1) > 0.5
                    continue
                end
                coordinates = mod(second.cart_coords / ...
                    candidateLattice.matrix, 1);
                candidate = kssolv.analysis.matgenlab.core.Structure( ...
                    candidateLattice, second.species_and_occu, ...
                    coordinates, to_unit_cell = true);
                [comparisonFirst, comparisonSecond] = ...
                    obj.onAverageLattice(first, candidate);
                trial = obj.translatedAssignment( ...
                    comparisonFirst, comparisonSecond);
                if ~isempty(trial) && trial.rms < bestValue
                    result = trial;
                    result.basis = basis;
                    bestValue = trial.rms;
                end
            end
        end

        function result = alignedMatch(obj, first, second)
            if obj.scale
                targetVolume = sqrt(first.volume * second.volume);
                first = first.scale_lattice(targetVolume);
                second = second.scale_lattice(targetVolume);
            end
            if ~obj.latticesCompatible(first.lattice, second.lattice)
                result = [];
                return
            end
            [first, second] = obj.onAverageLattice(first, second);
            result = obj.translatedAssignment(first, second);
        end

        function [first, second] = onAverageLattice(~, first, second)
            parameters = ([first.lattice.abc, first.lattice.angles] + ...
                [second.lattice.abc, second.lattice.angles]) / 2;
            lattice = kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(parameters(1), parameters(2), ...
                parameters(3), parameters(4), parameters(5), ...
                parameters(6));
            first = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, first.species_and_occu, first.frac_coords);
            second = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, second.species_and_occu, second.frac_coords);
        end

        function tf = latticesCompatible(obj, first, second)
            firstLengths = first.abc;
            secondLengths = second.abc;
            tf = all(abs(firstLengths - secondLengths) ./ ...
                max(firstLengths, eps) <= obj.ltol) && ...
                all(abs(first.angles - second.angles) <= obj.angle_tol);
        end

        function result = translatedAssignment(obj, first, second)
            if second.num_sites > first.num_sites
                result = [];
                return
            end
            compatible = false(second.num_sites, first.num_sites);
            for secondIndex = 1:second.num_sites
                for firstIndex = 1:first.num_sites
                    compatible(secondIndex, firstIndex) = ...
                        obj.comparator.are_equal( ...
                        second(secondIndex).species, ...
                        first(firstIndex).species);
                end
            end
            if any(~any(compatible, 2))
                result = [];
                return
            end
            normalization = ...
                (first.num_sites / first.volume)^(1/3);
            result = [];
            best = Inf;
            anchor = find(sum(compatible, 2) == ...
                min(sum(compatible, 2)), 1);
            firstAnchors = find(compatible(anchor, :));
            for firstAnchor = firstAnchors
                translation = first(firstAnchor).frac_coords - ...
                    second(anchor).frac_coords;
                moved = second.frac_coords + translation;
                cost = inf(second.num_sites, first.num_sites);
                vectors = zeros(second.num_sites, first.num_sites, 3);
                for secondIndex = 1:second.num_sites
                    delta = first.frac_coords - moved(secondIndex, :);
                    [cartesian, distances] = ...
                        kssolv.analysis.matgenlab.core.StructureMatcher. ...
                        shortestVectors(delta, first.lattice.matrix, ...
                        first.lattice.pbc);
                    cost(secondIndex, compatible(secondIndex, :)) = ...
                        distances(compatible(secondIndex, :)).^2;
                    vectors(secondIndex, :, :) = cartesian;
                end
                try
                    [mapping, ~] = ...
                        kssolv.analysis.matgenlab.core. ...
                        get_linear_assignment_solution(cost);
                catch
                    continue
                end
                selectedCost = cost(sub2ind(size(cost), ...
                    1:second.num_sites, mapping));
                if any(~isfinite(selectedCost)), continue; end
                selectedVectors = zeros(second.num_sites, 3);
                for secondIndex = 1:second.num_sites
                    selectedVectors(secondIndex, :) = ...
                        vectors(secondIndex, mapping(secondIndex), :);
                end
                cartesianAdjustment = mean(selectedVectors, 1);
                residual = selectedVectors - cartesianAdjustment;
                normalized = vecnorm(residual, 2, 2).' * normalization;
                rmsValue = sqrt(mean(normalized.^2));
                maxValue = max(normalized);
                if rmsValue < best
                    best = rmsValue;
                    fractionalAdjustment = ...
                        cartesianAdjustment / first.lattice.matrix;
                    totalTranslation = translation + ...
                        fractionalAdjustment;
                    result = struct( ...
                        "rms", rmsValue, ...
                        "max_distance", maxValue, ...
                        "distances", normalized, ...
                        "translation", totalTranslation - ...
                            round(totalTranslation), ...
                        "mapping", mapping);
                end
            end
        end

        function matrix = inferSupercellMatrix( ...
                obj, structure, supercell, factor)
            if nargin < 4
                [factor, structureSupercell] = ...
                    obj.getSupercellSize(structure, supercell);
                if ~structureSupercell,matrix=[];return,end
            end
            candidates = obj.supercellCandidates( ...
                structure, supercell, factor);
            matrix = [];
            best = Inf;
            for index = 1:numel(candidates)
                expanded=structure*candidates{index};
                if supercell.num_sites>=expanded.num_sites
                    trial=obj.alignedMatch(supercell,expanded);
                else
                    trial=obj.alignedMatch(expanded,supercell);
                end
                if ~isempty(trial) && trial.rms < best
                    matrix = candidates{index};
                    best = trial.rms;
                end
            end
        end

        function candidates = supercellCandidates( ...
                obj, structure, supercell, target)
            if nargin < 4
                [target, structureSupercell] = ...
                    obj.getSupercellSize(structure, supercell);
                if ~structureSupercell,candidates=cell(1,0);return,end
            end
            if abs(target-round(target))>1e-6||target<1
                candidates = cell(1, 0);
                return
            end
            target=round(target);
            scaleFactor = (supercell.volume / ...
                (target * structure.volume))^(1/3);
            scaledLattice = ...
                kssolv.analysis.matgenlab.core.Lattice( ...
                    structure.lattice.matrix * scaleFactor, ...
                    structure.lattice.pbc);
            mappings = scaledLattice.find_all_mappings( ...
                supercell.lattice, obj.ltol, obj.angle_tol, true);
            candidates = cell(1, 0);
            for index = 1:size(mappings, 1)
                matrix = round(mappings{index, 3});
                if abs(abs(det(matrix)) - target) <= 0.5
                    duplicate = any(cellfun(@(item) ...
                        isequal(item, matrix), candidates));
                    if ~duplicate
                        candidates{end + 1} = matrix; %#ok<AGROW>
                    end
                end
            end
            if isempty(candidates)
                raw = supercell.lattice.matrix / ...
                    scaledLattice.matrix;
                rounded = round(raw);
                if max(abs(raw - rounded), [], "all") <= obj.ltol && ...
                        abs(abs(det(rounded)) - target) <= 0.5
                    candidates = {rounded};
                end
            end
        end

        function matches = anonymousMatches( ...
                obj, first, second, niggli, skipReduction)
            if nargin<4,niggli=true;end
            if nargin<5,skipReduction=false;end
            if ~isa(obj.comparator, ...
                    "kssolv.analysis.matgenlab.core.SpeciesComparator")
                error("KSSOLV:Matgenlab:StructureMatcher:AnonymousComparator", ...
                    "Anonymous fitting requires SpeciesComparator.");
            end
            first=obj.processSpecies(first);
            second=obj.processSpecies(second);
            firstNames = obj.elementNames(first);
            secondNames = obj.elementNames(second);
            if numel(firstNames) ~= numel(secondNames)
                matches = cell(1, 0);
                return
            end
            if ~skipReduction
                first=obj.reduceStructure(first,niggli);
                second=obj.reduceStructure(second,niggli);
            end
            firstAmounts = first.composition.element_composition. ...
                get_el_amt_dict();
            secondAmounts = second.composition.element_composition. ...
                get_el_amt_dict();
            permutations = perms(1:numel(secondNames));
            matches = cell(1, 0);
            for permutationIndex = 1:size(permutations, 1)
                mapping = struct();
                compatibleComposition = true;
                for nameIndex = 1:numel(firstNames)
                    sourceName = char(firstNames(nameIndex));
                    targetName = char(secondNames(permutations( ...
                        permutationIndex, nameIndex)));
                    mapping.(sourceName) = string(targetName);
                    if abs(firstAmounts.(sourceName) / first.num_sites - ...
                            secondAmounts.(targetName) / ...
                            second.num_sites) > 1e-8
                        compatibleComposition = false;
                        break
                    end
                end
                if ~compatibleComposition, continue; end
                mapped = first.copy();
                mapped = mapped.replace_species(mapping);
                if ~obj.allow_subset && ...
                        mapped.composition.fractional_composition ~= ...
                        second.composition.fractional_composition
                    continue
                end
                result = obj.matchStructures(mapped, second, true);
                if ~isempty(result) && result.max_distance <= obj.stol
                    result.mapping = mapping;
                    matches{end + 1} = result; %#ok<AGROW>
                end
            end
        end

        function names = elementNames(~, structure)
            elements = structure.composition.element_composition.elements;
            names = strings(1, numel(elements));
            for index = 1:numel(elements)
                names(index) = elements{index}.symbol;
            end
            names = sort(names);
        end
    end

    methods (Static, Access = private)
        function [vectors, distances] = ...
                shortestVectors(deltas, latticeMatrix, pbc)
            shifts = zeros(1, 3);
            for axis = 1:3
                if pbc(axis)
                    expanded = zeros(size(shifts, 1) * 3, 3);
                    for offsetIndex = 1:3
                        rows = (offsetIndex - 1) * size(shifts, 1) + ...
                            (1:size(shifts, 1));
                        expanded(rows, :) = shifts;
                        expanded(rows, axis) = ...
                            expanded(rows, axis) + offsetIndex - 2;
                    end
                    shifts = expanded;
                end
            end
            vectors = zeros(size(deltas));
            distances = zeros(size(deltas, 1), 1);
            for index = 1:size(deltas, 1)
                candidates = (deltas(index, :) + shifts) * latticeMatrix;
                squared = sum(candidates.^2, 2);
                [minimum, best] = min(squared);
                vectors(index, :) = candidates(best, :);
                distances(index) = sqrt(minimum);
            end
        end

        function values = signedPermutations()
            persistent cached
            if isempty(cached)
                permutations = perms(1:3);
                cached = cell(1, 48);
                cursor=0;
                signs = dec2bin(0:7, 3) - '0';
                signs(signs == 0) = -1;
                for permutationIndex = 1:size(permutations, 1)
                    permutation = eye(3);
                    permutation = permutation(permutations( ...
                        permutationIndex, :), :);
                    for signIndex = 1:size(signs, 1)
                        cursor=cursor+1;
                        cached{cursor} = ...
                            diag(signs(signIndex, :)) * permutation;
                    end
                end
            end
            values = cached;
        end
    end
end
