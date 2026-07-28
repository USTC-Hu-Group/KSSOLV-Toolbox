function value = calculate_bv_sum(site, neighbors, scaleFactor)
%CALCULATE_BV_SUM Calculate the ordered-site bond-valence sum.
if nargin < 3, scaleFactor = 1; end
parameters = kssolv.analysis.matgenlab.core.BondValenceData.parameters();
electronegative = ["H","B","C","Si","N","P","As","Sb", ...
    "O","S","Se","Te","F","Cl","Br","I"];
element1 = kssolv.analysis.matgenlab.core.Element(site.specie.symbol);
value = 0;
if ~iscell(neighbors), neighbors = num2cell(neighbors); end
for index = 1:numel(neighbors)
    neighbor = neighbors{index};
    element2 = kssolv.analysis.matgenlab.core.Element(neighbor.specie.symbol);
    if ~(ismember(element1.symbol, electronegative) || ...
            ismember(element2.symbol, electronegative)) || ...
            element1.symbol == element2.symbol
        continue
    end
    first = parameters(char(element1.symbol));
    second = parameters(char(element2.symbol));
    radius = first.r + second.r - first.r * second.r * ...
        (sqrt(first.c) - sqrt(second.c))^2 / ...
        (first.c * first.r + second.c * second.r);
    contribution = exp((radius - neighbor.nn_distance * scaleFactor) / 0.31);
    if element1.X < element2.X, value = value + contribution;
    else, value = value - contribution;
    end
end
end
