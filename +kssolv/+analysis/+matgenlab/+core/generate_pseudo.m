function [pseudoInverses, absentSymbols] = generate_pseudo(strainStates, order)
%GENERATE_PSEUDO Generate fitting pseudoinverses for elastic constants.
if nargin < 2, order = 3; end
states = double(strainStates);
if size(states, 2) ~= 6
    error("KSSOLV:Matgenlab:Elasticity:StrainStates", ...
        "strain_states must have six Voigt components.");
end
pseudoInverses = cell(1, order - 1);
absentSymbols = cell(1, order - 1);
for degree = 2:order
    [symbols, ~] = ...
        kssolv.analysis.matgenlab.core.get_symbol_list(degree, 6);
    combinations = symbolCombinations(symbols);
    matrix = zeros(size(states, 1) * 6, numel(symbols));
    tails = allTuples(6, degree - 1);
    for stateIndex = 1:size(states, 1)
        state = states(stateIndex, :);
        for stressIndex = 1:6
            row = (stateIndex - 1) * 6 + stressIndex;
            for tailIndex = 1:size(tails, 1)
                indices = [stressIndex, tails(tailIndex, :)];
                sorted = sort(indices);
                column = find(all(combinations == sorted, 2), 1);
                matrix(row, column) = matrix(row, column) + ...
                    prod(state(tails(tailIndex, :)));
            end
        end
    end
    present = any(abs(matrix) > 0, 1);
    absentSymbols{degree - 1} = symbols(~present);
    pseudoInverses{degree - 1} = pinv(matrix);
end
end

function combinations = symbolCombinations(symbols)
rank = strlength(symbols(1)) - 2;
combinations = zeros(numel(symbols), rank);
for index = 1:numel(symbols)
    digits = char(extractAfter(symbols(index), "c_"));
    combinations(index, :) = double(digits - '0') + 1;
end
end

function tuples = allTuples(dimension, rank)
grids = cell(1, rank);
[grids{:}] = ndgrid(1:dimension);
tuples = zeros(dimension^rank, rank);
for index = 1:rank
    tuples(:, index) = grids{index}(:);
end
end
