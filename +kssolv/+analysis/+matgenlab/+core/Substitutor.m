classdef Substitutor
    %SUBSTITUTOR Data-mined ionic structure substitution predictor.

    properties (Constant)
        charge_balanced_tol = 1e-9
    end

    properties (SetAccess = protected)
        threshold (1,1) double = 1e-3
        symprec (1,1) double = 0.1
        probability (1,1) kssolv.analysis.matgenlab.core.SubstitutionProbability
        kwargs (1,1) struct = struct()
    end

    methods
        function obj = Substitutor(threshold, symprec, varargin)
            if nargin < 1 || isempty(threshold), threshold = 1e-3; end
            if nargin < 2 || isempty(symprec), symprec = 0.1; end
            options = struct("lambda_table", [], "alpha", -5);
            for index = 1:2:numel(varargin)
                if index + 1 > numel(varargin)
                    error("KSSOLV:Matgenlab:Substitutor:InvalidArguments", ...
                        "Name-value arguments must occur in pairs.");
                end
                name = char(lower(string(varargin{index})));
                if ~isfield(options, name)
                    error("KSSOLV:Matgenlab:Substitutor:InvalidOption", ...
                        "Unknown option '%s'.", name);
                end
                options.(name) = varargin{index + 1};
            end
            obj.threshold = double(threshold);
            obj.symprec = double(symprec);
            obj.kwargs = options;
            obj.probability = kssolv.analysis.matgenlab.core. ...
                SubstitutionProbability(options.lambda_table, options.alpha);
        end

        function species = get_allowed_species(obj)
            species = obj.probability.species;
        end

        function output = pred_from_list(obj, speciesList)
            speciesList = reshape(obj.toCell(speciesList), 1, []);
            for index = 1:numel(speciesList)
                speciesList{index} = ...
                    kssolv.analysis.matgenlab.core.getElSp(speciesList{index});
            end
            maxima = zeros(1, numel(speciesList));
            for index = 1:numel(speciesList)
                values = cellfun(@(candidate) ...
                    obj.probability.cond_prob(candidate, speciesList{index}), ...
                    obj.probability.species);
                maxima(index) = max(values);
            end
            output = struct("substitutions", {}, "probability", {});
            output = recurse(1, zeros(1, 0), cell(1, 0), output);

            function accumulated = recurse(position, probabilities, ...
                    selected, accumulated)
                best = maxima;
                if ~isempty(probabilities)
                    best(1:numel(probabilities)) = probabilities;
                end
                if prod(best) <= obj.threshold, return; end
                if position > numel(speciesList)
                    mapping = cell(numel(speciesList), 2);
                    for item = 1:numel(speciesList)
                        mapping(item, :) = {speciesList{item}, selected{item}};
                    end
                    accumulated(end + 1) = struct( ... %#ok<AGROW>
                        "substitutions", {mapping}, ...
                        "probability", prod(best));
                    return
                end
                for candidate = 1:numel(obj.probability.species)
                    next = obj.probability.species{candidate};
                    value = obj.probability.cond_prob( ...
                        next, speciesList{position});
                    accumulated = recurse(position + 1, ...
                        [probabilities, value], ... %#ok<AGROW>
                        [selected, {next}], accumulated);
                end
            end
        end

        function output = pred_from_comp(obj, composition)
            if ~isa(composition, "kssolv.analysis.matgenlab.core.Composition")
                composition = kssolv.analysis.matgenlab.core.Composition(composition);
            end
            predictions = obj.pred_from_list(composition.elements);
            keep = false(1, numel(predictions));
            for index = 1:numel(predictions)
                mapping = predictions(index).substitutions;
                charge = 0;
                for item = 1:size(mapping, 1)
                    charge = charge + mapping{item, 2}.oxi_state * ...
                        composition(mapping{item, 1});
                end
                keep(index) = abs(charge) < obj.charge_balanced_tol;
            end
            output = predictions(keep);
        end

        function result = pred_from_structures(obj, targetSpecies, ...
                structures, removeDuplicates, removeExisting)
            if nargin < 4, removeDuplicates = true; end
            if nargin < 5, removeExisting = false; end
            targetSpecies = reshape(obj.toCell(targetSpecies), 1, []);
            for index = 1:numel(targetSpecies)
                targetSpecies{index} = ...
                    kssolv.analysis.matgenlab.core.getElSp(targetSpecies{index});
            end
            allowed = string(cellfun(@string, obj.get_allowed_species(), ...
                "UniformOutput", false));
            targetNames = string(cellfun(@string, targetSpecies, ...
                "UniformOutput", false));
            if any(~ismember(targetNames, allowed))
                error("KSSOLV:Matgenlab:Substitutor:UnknownSpecies", ...
                    "target_species contains a species outside the model domain.");
            end
            structures = reshape(obj.toCell(structures), 1, []);
            permutations = obj.permutationIndices(numel(targetSpecies));
            result = struct("structure", {}, "formula", {}, ...
                "transformations", {}, "history", {}, "other_parameters", {});
            for permutationIndex = 1:size(permutations, 1)
                permutation = targetSpecies(permutations(permutationIndex, :));
                for structureIndex = 1:numel(structures)
                    record = structures{structureIndex};
                    structure = record.structure;
                    original = structure.elements;
                    if numel(original) ~= numel(permutation), continue; end
                    originalNames = string(cellfun(@string, original, ...
                        "UniformOutput", false));
                    if any(~ismember(originalNames, allowed)), continue; end
                    candidateProbability = obj.probability.cond_prob_list( ...
                        permutation, original);
                    if candidateProbability <= obj.threshold, continue; end
                    mapping = cell(0, 2);
                    for item = 1:numel(original)
                        if string(original{item}) ~= string(permutation{item})
                            mapping(end + 1, :) = ...
                                {original{item}, permutation{item}}; %#ok<AGROW>
                        end
                    end
                    if isempty(mapping), continue; end
                    transformed = structure.copy();
                    replacementMap = containers.Map( ...
                        "KeyType", "char", "ValueType", "any");
                    for item = 1:size(mapping, 1)
                        replacementMap(char(mapping{item, 1}.symbol)) = ...
                            mapping{item, 2};
                    end
                    transformed = transformed.replace_species(replacementMap);
                    if abs(transformed.charge) >= obj.charge_balanced_tol
                        continue
                    end
                    candidate = struct( ...
                        "structure", transformed, ...
                        "formula", transformed.formula, ...
                        "transformations", {{struct( ...
                            "name", "SubstitutionTransformation", ...
                            "mapping", {mapping})}}, ...
                        "history", {{struct("source", record.id)}}, ...
                        "other_parameters", struct( ...
                            "type", "structure_prediction", ...
                            "proba", candidateProbability));
                    if removeDuplicates && obj.containsStructure(result, transformed)
                        continue
                    end
                    if removeExisting && obj.matchesAnyExisting( ...
                            transformed, structures, targetSpecies)
                        continue
                    end
                    result(end + 1) = candidate; %#ok<AGROW>
                end
            end
        end

        function result = as_dict(obj)
            result = struct( ...
                "name", "Substitutor", ...
                "version", "1.2", ...
                "kwargs", obj.kwargs, ...
                "threshold", obj.threshold, ...
                "x_module", ...
                    "pymatgen.core.structure_prediction.substitutor", ...
                "x_class", "Substitutor");
        end
    end

    methods (Static)
        function obj = from_dict(dct)
            options = dct.kwargs;
            obj = kssolv.analysis.matgenlab.core.Substitutor( ...
                dct.threshold, 0.1, ...
                "lambda_table", options.lambda_table, ...
                "alpha", options.alpha);
        end
    end

    methods (Access = protected)
        function present = containsStructure(~, records, structure)
            present = false;
            for index = 1:numel(records)
                if records(index).structure == structure
                    present = true; return
                end
            end
        end

        function present = matchesAnyExisting(~, structure, records, targets)
            targetSymbols = sort(string(cellfun( ...
                @(item) item.symbol, targets, "UniformOutput", false)));
            present = false;
            for index = 1:numel(records)
                existing = records{index}.structure;
                symbols = sort(existing.symbol_set);
                if isequal(symbols, targetSymbols) && existing == structure
                    present = true; return
                end
            end
        end
    end

    methods (Static, Access = protected)
        function values = toCell(input)
            if iscell(input), values = input;
            elseif isstruct(input), values = num2cell(input);
            elseif isstring(input), values = cellstr(input);
            else, values = num2cell(input);
            end
        end

        function indices = permutationIndices(count)
            if count == 0, indices = zeros(1, 0);
            elseif count == 1, indices = 1;
            else, indices = perms(1:count);
            end
        end
    end
end
