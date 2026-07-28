function formula = disordered_formula(disordered_struct, symbols, fmt)
%DISORDERED_FORMULA Symbolic formula for one kind of disordered site.
% Compatible with pymatgen.util.string.disordered_formula.
if nargin < 2, symbols = ["x", "y", "z"]; end
if nargin < 3, fmt = "plain"; end
symbols = reshape(string(symbols), 1, []);
fmt = string(fmt);

if logical(disordered_struct.is_ordered)
    error("KSSOLV:Matgenlab:String:OrderedStructure", ...
        "Structure is not disordered, so disordered formula not defined.");
end
sites = disordered_struct.sites;
if ~iscell(sites), sites = num2cell(sites); end
signatures = strings(0, 1);
siteCompositions = cell(0, 1);
for idx = 1:numel(sites)
    site = sites{idx};
    if ~site.is_ordered
        signature = compositionSignature(site.species);
        if ~ismember(signature, signatures)
            signatures(end + 1) = signature; %#ok<AGROW>
            siteCompositions{end + 1} = site.species; %#ok<AGROW>
        end
    end
end
if numel(siteCompositions) > 1
    error("KSSOLV:Matgenlab:String:AmbiguousDisorder", ...
        "Ambiguous how to define disordered formula when more than one type of disordered site is present.");
elseif isempty(siteCompositions)
    error("KSSOLV:Matgenlab:String:MissingDisorderedSite", ...
        "Structure contains no disordered site.");
end

[siteSpecies, ~] = siteCompositions{1}.items();
disorderedSpecies = strings(1, numel(siteSpecies));
for idx = 1:numel(siteSpecies), disorderedSpecies(idx) = string(siteSpecies{idx}); end
if numel(disorderedSpecies) > numel(symbols)
    error("KSSOLV:Matgenlab:String:InsufficientSymbols", ...
        "Not enough symbols to describe disordered composition: %s", ...
        strjoin(symbols, ", "));
end
symbols = symbols(1:max(0, numel(disorderedSpecies) - 1));

elementMap = disordered_struct.composition.get_el_amt_dict();
names = string(fieldnames(elementMap)).';
amounts = zeros(size(names));
electronegativity = zeros(size(names));
for idx = 1:numel(names)
    amounts(idx) = elementMap.(names(idx));
    electronegativity(idx) = ...
        kssolv.analysis.matgenlab.core.getElSp(names(idx)).X;
end
[~, order] = sort(electronegativity);
names = names(order); amounts = amounts(order);
isDisordered = ismember(names, disorderedSpecies);
totalDisorderedOccupancy = sum(amounts(isDisordered));

factorAmounts = [amounts(~isDisordered), totalDisorderedOccupancy];
if all(abs(factorAmounts - round(factorAmounts)) < ...
        kssolv.analysis.matgenlab.core.Composition.amount_tolerance)
    integers = abs(round(factorAmounts));
    factor = integers(1);
    for idx = 2:numel(integers), factor = gcd(factor, integers(idx)); end
    if factor == 0, factor = 1; end
else
    % Composition.get_reduced_formula_and_factor deliberately does not
    % reduce non-integral compositions.
    factor = 1;
end
totalDisorderedOccupancy = totalDisorderedOccupancy / factor;
remainder = formatNumber(totalDisorderedOccupancy, false) + ...
    "-" + strjoin(symbols, "-");

pieces = strings(0, 1);
variableNames = strings(0, 1);
variableValues = zeros(0, 1);
symbolIndex = 1;
for idx = 1:numel(names)
    species = names(idx);
    if ~isDisordered(idx)
        occupancy = formatNumber(amounts(idx) / factor, true);
    elseif symbolIndex <= numel(symbols)
        occupancy = symbols(symbolIndex);
        variableNames(end + 1) = occupancy; %#ok<AGROW>
        variableValues(end + 1) = ...
            amounts(idx) / totalDisorderedOccupancy / factor; %#ok<AGROW>
        symbolIndex = symbolIndex + 1;
    else
        occupancy = remainder;
    end
    pieces(end + 1) = species + addSubscript(occupancy, fmt); %#ok<AGROW>
end
assignments = strings(1, numel(variableNames));
for idx = 1:numel(variableNames)
    assignments(idx) = variableNames(idx) + "=" + ...
        formatNumber(variableValues(idx), true);
end
formula = strjoin(pieces, "") + " " + strjoin(assignments, " ");
formula = strip(formula, "right");
end

function signature = compositionSignature(composition)
[species, amounts] = composition.items();
parts = strings(1, numel(species));
for idx = 1:numel(species)
    parts(idx) = string(species{idx}) + ":" + sprintf("%.16g", amounts(idx));
end
signature = strjoin(sort(parts), "|");
end

function text = formatNumber(value, ignoreOnes)
formatted = kssolv.analysis.matgenlab.util.formula_double_format( ...
    value, ignoreOnes);
text = string(formatted);
end

function text = addSubscript(occupancy, fmt)
if strlength(occupancy) == 0
    text = "";
elseif fmt == "LaTeX"
    text = "_{" + occupancy + "}";
elseif fmt == "HTML"
    text = "<sub>" + occupancy + "</sub>";
elseif fmt == "plain"
    text = occupancy;
else
    error("KSSOLV:Matgenlab:String:UnsupportedFormat", ...
        "Unsupported output format, choose from: LaTeX, HTML, plain");
end
end
