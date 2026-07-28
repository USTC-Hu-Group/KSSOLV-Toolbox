function [symbols, tensor] = get_symbol_list(rank, dimension)
%GET_SYMBOL_LIST Symbol names for a fully permutation-symmetric tensor.
if nargin < 2, dimension = 6; end
if rank < 1 || rank ~= fix(rank) || dimension < 1
    error("KSSOLV:Matgenlab:Elasticity:SymbolShape", ...
        "rank and dimension must be positive integers.");
end
combinations = combinationsWithReplacement(dimension, rank);
symbols = strings(size(combinations, 1), 1);
shape = repmat(dimension, 1, rank);
if rank == 1, shape = [1, dimension]; end
tensor = strings(shape);
allIndices = allTuples(dimension, rank);
for index = 1:size(combinations, 1)
    symbols(index) = "c_" + join(string(combinations(index, :) - 1), "");
end
for index = 1:size(allIndices, 1)
    sorted = sort(allIndices(index, :));
    location = find(all(combinations == sorted, 2), 1);
    subs = num2cell(allIndices(index, :));
    tensor(subs{:}) = symbols(location);
end
end

function values = combinationsWithReplacement(dimension, rank)
tuples = allTuples(dimension, rank);
values = unique(sort(tuples, 2), "rows", "stable");
end

function tuples = allTuples(dimension, rank)
grids = cell(1, rank);
[grids{:}] = ndgrid(1:dimension);
tuples = zeros(dimension^rank, rank);
for index = 1:rank
    tuples(:, index) = grids{index}(:);
end
end
