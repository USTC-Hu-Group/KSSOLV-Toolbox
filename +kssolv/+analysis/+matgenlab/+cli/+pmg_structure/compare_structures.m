function groups = compare_structures(args)
%COMPARE_STRUCTURES Group structure files by species or elemental identity.

args = validateArgs(args);
filenames = normalizeFilenames(args.filenames);
if numel(filenames) < 2
    error("KSSOLV:Matgenlab:PmgStructure:ComparisonCount", ...
        "You need more than one structure to compare!");
end

structures = cell(1, numel(filenames));
try
    for index = 1:numel(filenames)
        structures{index} = readStructure(filenames(index));
    end
catch exception
    fprintf("Error converting file. Are they in the right format?\n");
    converted = MException( ...
        "KSSOLV:Matgenlab:PmgStructure:FileConversion", ...
        "%s", exception.message);
    converted = addCause(converted, exception);
    throwAsCaller(converted);
end

if lower(string(args.group)) == "species"
    matcher = kssolv.analysis.matgenlab.core.StructureMatcher();
    useElements = false;
else
    matcher = kssolv.analysis.matgenlab.core.StructureMatcher( ...
        0.2, 0.3, 5, true, true, false, false, ...
        kssolv.analysis.matgenlab.core.ElementComparator());
    useElements = true;
end
[structures, filenames] = sortByComposition( ...
    structures, filenames, useElements);
matched = matcher.group_structures(structures);
groups = cell(1, numel(matched));
for groupIndex = 1:numel(matched)
    members = repmat(struct("filename", "", "formula", ""), ...
        1, numel(matched{groupIndex}));
    fprintf("Group %d: \n", groupIndex - 1);
    for memberIndex = 1:numel(matched{groupIndex})
        structure = matched{groupIndex}{memberIndex};
        originalIndex = find(cellfun(@(candidate) ...
            candidate == structure, structures), 1);
        if isempty(originalIndex)
            error("KSSOLV:Matgenlab:PmgStructure:InternalMapping", ...
                "A grouped structure could not be mapped to its filename.");
        end
        members(memberIndex) = struct( ...
            "filename", filenames(originalIndex), ...
            "formula", structure.formula);
        fprintf("- %s (%s)\n", filenames(originalIndex), structure.formula);
    end
    fprintf("\n");
    groups{groupIndex} = members;
end
end

function args = validateArgs(args)
if ~isstruct(args) || ~isscalar(args) || ...
        ~isfield(args, "filenames") || ~isfield(args, "group")
    error("KSSOLV:Matgenlab:PmgStructure:Arguments", ...
        "args must contain filenames and group.");
end
group = lower(string(args.group));
if ~isscalar(group) || ~any(group == ["species", "element"])
    error("KSSOLV:Matgenlab:PmgStructure:Group", ...
        "group must be 'species' or 'element'.");
end
end

function filenames = normalizeFilenames(value)
filenames = reshape(string(value), 1, []);
if any(ismissing(filenames) | strlength(filenames) == 0)
    error("KSSOLV:Matgenlab:PmgStructure:Filename", ...
        "filenames must contain nonempty paths.");
end
end

function structure = readStructure(filename)
warningState = warning;
cleanup = onCleanup(@() warning(warningState));
warning("off", "all");
structure = kssolv.analysis.matgenlab.core.Structure.from_file(filename);
clear cleanup
end

function [structures, filenames] = sortByComposition( ...
        structures, filenames, useElements)
% Python's StructureMatcher pre-sorts by comparator composition hash.
for outer = 1:numel(structures) - 1
    for inner = outer + 1:numel(structures)
        if compositionLess(structures{inner}, structures{outer}, useElements)
            temporary = structures{outer};
            structures{outer} = structures{inner};
            structures{inner} = temporary;
            temporaryName = filenames(outer);
            filenames(outer) = filenames(inner);
            filenames(inner) = temporaryName;
        end
    end
end
end

function value = compositionLess(first, second, useElements)
firstComposition = first.composition;
secondComposition = second.composition;
if useElements
    firstComposition = firstComposition.element_composition;
    secondComposition = secondComposition.element_composition;
end
firstComposition = firstComposition.fractional_composition;
secondComposition = secondComposition.fractional_composition;
[firstSpecies, firstAmounts] = firstComposition.items();
[secondSpecies, secondAmounts] = secondComposition.items();
species = [reshape(firstSpecies, 1, []), reshape(secondSpecies, 1, [])];
species = uniqueSpecies(species);
species = sortSpecies(species);
value = false;
for index = 1:numel(species)
    firstAmount = amountFor( ...
        firstSpecies, firstAmounts, species{index});
    secondAmount = amountFor( ...
        secondSpecies, secondAmounts, species{index});
    if secondAmount - firstAmount >= 1e-8
        value = true;
        return
    end
    if firstAmount - secondAmount >= 1e-8
        return
    end
end
end

function output = uniqueSpecies(input)
output = cell(1, 0);
for index = 1:numel(input)
    duplicate = false;
    for prior = 1:numel(output)
        if sameSpecies(input{index}, output{prior})
            duplicate = true;
            break
        end
    end
    if ~duplicate
        output{end + 1} = input{index}; %#ok<AGROW>
    end
end
end

function output = sortSpecies(input)
x = zeros(numel(input), 1);
symbols = strings(numel(input), 1);
types = zeros(numel(input), 1);
oxidation = zeros(numel(input), 1);
for index = 1:numel(input)
    x(index) = input{index}.X;
    if isnan(x(index)), x(index) = Inf; end
    symbols(index) = input{index}.symbol;
    if isa(input{index}, "kssolv.analysis.matgenlab.core.Species")
        types(index) = 0;
        oxidation(index) = input{index}.oxi_state;
        if isnan(oxidation(index)), oxidation(index) = 0; end
    else
        types(index) = 1;
    end
end
[~, order] = sortrows(table(x, symbols, types, oxidation), ...
    ["x", "symbols", "types", "oxidation"]);
output = input(order);
end

function value = amountFor(species, amounts, requested)
value = 0;
for index = 1:numel(species)
    if sameSpecies(species{index}, requested)
        value = amounts(index);
        return
    end
end
end

function value = sameSpecies(first, second)
value = strcmp(class(first), class(second)) && first == second;
end
