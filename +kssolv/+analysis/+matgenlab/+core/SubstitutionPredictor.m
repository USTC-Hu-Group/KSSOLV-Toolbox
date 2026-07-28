classdef SubstitutionPredictor
    %SUBSTITUTIONPREDICTOR Enumerate likely ionic substitutions.

    properties (SetAccess = protected)
        p (1,1) kssolv.analysis.matgenlab.core.SubstitutionProbability
        threshold (1,1) double = 1e-3
    end

    methods
        function obj = SubstitutionPredictor(lambdaTable, alpha, threshold)
            if nargin < 1, lambdaTable = []; end
            if nargin < 2 || isempty(alpha), alpha = -5; end
            if nargin < 3 || isempty(threshold), threshold = 1e-3; end
            obj.p = kssolv.analysis.matgenlab.core. ...
                SubstitutionProbability(lambdaTable, alpha);
            obj.threshold = double(threshold);
        end

        function output = list_prediction(obj, species, toThisComposition)
            if nargin < 3, toThisComposition = true; end
            species = reshape(obj.toCell(species), 1, []);
            allowed = string(cellfun(@string, obj.p.species, ...
                "UniformOutput", false));
            normalized = cell(size(species));
            for index = 1:numel(species)
                normalized{index} = ...
                    kssolv.analysis.matgenlab.core.getElSp(species{index});
                if ~any(allowed == string(normalized{index}))
                    error("KSSOLV:Matgenlab:SubstitutionPredictor:UnknownSpecies", ...
                        "The species %s is not allowed for this probability model.", ...
                        string(normalized{index}));
                end
            end

            maxima = zeros(1, numel(normalized));
            for index = 1:numel(normalized)
                probabilities = zeros(1, numel(obj.p.species));
                for outerCandidateIndex = 1:numel(obj.p.species)
                    if toThisComposition
                        probabilities(outerCandidateIndex) = obj.p.cond_prob( ...
                            obj.p.species{outerCandidateIndex}, ...
                            normalized{index});
                    else
                        probabilities(outerCandidateIndex) = obj.p.cond_prob( ...
                            normalized{index}, ...
                            obj.p.species{outerCandidateIndex});
                    end
                end
                maxima(index) = max(probabilities);
            end

            output = struct("probability", {}, "substitutions", {});
            output = recurse(1, zeros(1, 0), cell(1, 0), output);

            function accumulated = recurse(position, probabilities, ...
                    selected, accumulated)
                best = maxima;
                if ~isempty(probabilities)
                    best(1:numel(probabilities)) = probabilities;
                end
                if prod(best) <= obj.threshold, return; end
                if position > numel(normalized)
                    names = string(cellfun(@string, selected, ...
                        "UniformOutput", false));
                    if numel(unique(names)) ~= numel(names), return; end
                    substitutions = cell(numel(names), 2);
                    for subIndex = 1:numel(names)
                        if toThisComposition
                            substitutions{subIndex, 1} = selected{subIndex};
                            substitutions{subIndex, 2} = normalized{subIndex};
                        else
                            substitutions{subIndex, 1} = normalized{subIndex};
                            substitutions{subIndex, 2} = selected{subIndex};
                        end
                    end
                    accumulated(end + 1) = struct( ... %#ok<AGROW>
                        "probability", prod(best), ...
                        "substitutions", {substitutions});
                    return
                end
                for nestedCandidateIndex = 1:numel(obj.p.species)
                    next = obj.p.species{nestedCandidateIndex};
                    if toThisComposition
                        probability = obj.p.cond_prob( ...
                            next, normalized{position});
                    else
                        probability = obj.p.cond_prob( ...
                            normalized{position}, next);
                    end
                    accumulated = recurse(position + 1, ...
                        [probabilities, probability], ... %#ok<AGROW>
                        [selected, {next}], accumulated);
                end
            end
        end

        function output = composition_prediction(obj, composition, ...
                toThisComposition)
            if nargin < 3, toThisComposition = true; end
            if ~isa(composition, "kssolv.analysis.matgenlab.core.Composition")
                composition = kssolv.analysis.matgenlab.core.Composition(composition);
            end
            [species, amounts] = composition.items();
            predictions = obj.list_prediction(species, toThisComposition);
            keep = false(1, numel(predictions));
            for index = 1:numel(predictions)
                substitutions = predictions(index).substitutions;
                charge = 0;
                for item = 1:size(substitutions, 1)
                    if toThisComposition
                        replacement = substitutions{item, 1};
                    else
                        replacement = substitutions{item, 2};
                    end
                    charge = charge + replacement.oxi_state * amounts(item);
                end
                keep(index) = abs(charge) < 1e-8;
            end
            output = predictions(keep);
        end
    end

    methods (Static, Access = protected)
        function values = toCell(input)
            if iscell(input), values = input;
            elseif isstring(input), values = cellstr(input);
            else, values = num2cell(input);
            end
        end
    end
end
