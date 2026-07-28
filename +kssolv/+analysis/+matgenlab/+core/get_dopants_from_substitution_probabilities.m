function dopants = get_dopants_from_substitution_probabilities( ...
        structure, numDopants, threshold, matchOxiSign)
%GET_DOPANTS_FROM_SUBSTITUTION_PROBABILITIES Suggest aliovalent dopants.

if nargin < 2 || isempty(numDopants), numDopants = 5; end
if nargin < 3 || isempty(threshold), threshold = 1e-3; end
if nargin < 4 || isempty(matchOxiSign), matchOxiSign = false; end

species = structure.species;
if ~all(cellfun(@(item) ...
        isa(item, "kssolv.analysis.matgenlab.core.Species") && ...
        ~isnan(item.oxi_state), species))
    error("KSSOLV:Matgenlab:DopantPredictor:MissingOxidationStates", ...
        "All sites in structure must have oxidation states to predict dopants.");
end

names = string(cellfun(@string, species, "UniformOutput", false));
[~, uniqueIndices] = unique(names, "stable");
predictor = kssolv.analysis.matgenlab.core. ...
    SubstitutionPredictor([], -5, threshold);
substitutions = struct("probability", {}, "dopant_species", {}, ...
    "original_species", {});
for index = reshape(uniqueIndices, 1, [])
    predictions = predictor.list_prediction(species(index));
    for prediction = reshape(predictions, 1, [])
        mapping = prediction.substitutions;
        substitutions(end + 1) = struct( ...
            "probability", prediction.probability, ...
            "dopant_species", mapping{1, 1}, ...
            "original_species", mapping{1, 2}); %#ok<AGROW>
    end
end
if ~isempty(substitutions)
    [~, order] = sort([substitutions.probability], "descend");
    substitutions = substitutions(order);
end
dopants = localSelect(substitutions, numDopants, matchOxiSign);
end

function output = localSelect(substitutions, count, matchSign)
empty = struct("probability", {}, "dopant_species", {}, ...
    "original_species", {});
output = struct("n_type", empty, "p_type", empty);
for kind = ["n_type", "p_type"]
    selected = empty;
    for index = 1:numel(substitutions)
        candidate = substitutions(index);
        dopant = candidate.dopant_species.oxi_state;
        original = candidate.original_species.oxi_state;
        if kind == "n_type", valid = dopant > original;
        else, valid = dopant < original;
        end
        valid = valid && (~matchSign || sign(dopant) == sign(original));
        if valid, selected(end + 1) = candidate; end %#ok<AGROW>
        if numel(selected) == count, break; end
    end
    output.(kind) = selected;
end
end
