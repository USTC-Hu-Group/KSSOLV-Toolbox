function dopants = get_dopants_from_shannon_radii( ...
        bondedStructure, numDopants, matchOxiSign)
%GET_DOPANTS_FROM_SHANNON_RADII Suggest aliovalent dopants by ionic radius.

if nargin < 2 || isempty(numDopants), numDopants = 5; end
if nargin < 3 || isempty(matchOxiSign), matchOxiSign = false; end
structure = bondedStructure.structure;

allSpecies = cell(1, 0);
elements = kssolv.analysis.matgenlab.core.Element.all();
for index = 1:numel(elements)
    states = elements{index}.common_oxidation_states;
    for state = reshape(states, 1, [])
        allSpecies{end + 1} = ...
            kssolv.analysis.matgenlab.core.Species( ...
            elements{index}.symbol, state); %#ok<AGROW>
    end
end

siteKeys = strings(1, 0);
coordination = zeros(1, 0);
siteSpecies = cell(1, 0);
for index = 1:structure.num_sites
    cn = bondedStructure.get_coordination_of_site(index);
    species = structure.get_site(index).specie;
    key = string(cn) + "|" + string(species);
    if ~any(siteKeys == key)
        siteKeys(end + 1) = key; %#ok<AGROW>
        coordination(end + 1) = cn; %#ok<AGROW>
        siteSpecies{end + 1} = species; %#ok<AGROW>
    end
end

possible = struct("radii_diff", {}, "dopant_species", {}, ...
    "original_species", {});
for index = 1:numel(siteSpecies)
    cn = coordination(index);
    original = siteSpecies{index};
    roman = localRoman(cn);
    try
        referenceRadius = original.get_shannon_radius(roman);
    catch err
        if startsWith(err.identifier, "KSSOLV:Matgenlab:Species:")
            continue
        end
        rethrow(err)
    end
    for candidateIndex = 1:numel(allSpecies)
        candidate = allSpecies{candidateIndex};
        try
            radius = candidate.get_shannon_radius(roman);
        catch err
            if startsWith(err.identifier, "KSSOLV:Matgenlab:Species:")
                continue
            end
            rethrow(err)
        end
        possible(end + 1) = struct( ...
            "radii_diff", radius - referenceRadius, ...
            "dopant_species", candidate, ...
            "original_species", original); %#ok<AGROW>
    end
end
if ~isempty(possible)
    [~, order] = sort(abs([possible.radii_diff]), "ascend");
    possible = possible(order);
end

empty = struct("radii_diff", {}, "dopant_species", {}, ...
    "original_species", {});
dopants = struct("n_type", empty, "p_type", empty);
for kind = ["n_type", "p_type"]
    selected = empty;
    for index = 1:numel(possible)
        candidate = possible(index);
        dopant = candidate.dopant_species.oxi_state;
        original = candidate.original_species.oxi_state;
        if kind == "n_type", valid = dopant > original;
        else, valid = dopant < original;
        end
        valid = valid && (~matchOxiSign || sign(dopant) == sign(original));
        if valid, selected(end + 1) = candidate; end %#ok<AGROW>
        if numel(selected) == numDopants, break; end
    end
    dopants.(kind) = selected;
end
end

function result = localRoman(number)
if number < 1 || number >= 20 || number ~= fix(number)
    error("KSSOLV:Matgenlab:DopantPredictor:CoordinationNumber", ...
        "Coordination number must be an integer from 1 to 19.");
end
values = [10, 9, 5, 4, 1];
symbols = ["X", "IX", "V", "IV", "I"];
result = "";
for index = 1:numel(values)
    factor = floor(number / values(index));
    number = rem(number, values(index));
    result = result + repmat(symbols(index), 1, factor);
    if number == 0, break; end
end
end
