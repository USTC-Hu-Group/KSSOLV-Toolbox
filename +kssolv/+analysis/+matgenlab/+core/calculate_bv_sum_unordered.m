function value = calculate_bv_sum_unordered(site, neighbors, scaleFactor)
%CALCULATE_BV_SUM_UNORDERED Occupancy-weighted bond-valence sum.
if nargin < 3, scaleFactor = 1; end
parameters = kssolv.analysis.matgenlab.core.BondValenceData.parameters();
electronegative = ["H","B","C","Si","N","P","As","Sb", ...
    "O","S","Se","Te","F","Cl","Br","I"];
if ~iscell(neighbors), neighbors = num2cell(neighbors); end
[centralSpecies, centralOccupancies] = site.species.items();
value = 0;
for firstIndex = 1:numel(centralSpecies)
    element1 = kssolv.analysis.matgenlab.core.Element( ...
        centralSpecies{firstIndex}.symbol);
    for neighborIndex = 1:numel(neighbors)
        neighbor = neighbors{neighborIndex};
        [neighborSpecies, neighborOccupancies] = neighbor.species.items();
        for secondIndex = 1:numel(neighborSpecies)
            element2 = kssolv.analysis.matgenlab.core.Element( ...
                neighborSpecies{secondIndex}.symbol);
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
            contribution = exp((radius - ...
                neighbor.nn_distance * scaleFactor) / 0.31) * ...
                centralOccupancies(firstIndex) * ...
                neighborOccupancies(secondIndex);
            if element1.X < element2.X, value = value + contribution;
            else, value = value - contribution;
            end
        end
    end
end
end
