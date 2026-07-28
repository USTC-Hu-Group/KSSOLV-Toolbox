function [solution, minimumCost] = get_linear_assignment_solution(costMatrix)
%GET_LINEAR_ASSIGNMENT_SOLUTION Rectangular Hungarian assignment.
costMatrix = double(costMatrix);
if ~ismatrix(costMatrix) || isempty(costMatrix)
    error("KSSOLV:Matgenlab:LinearAssignment:Shape", ...
        "cost_matrix must be a nonempty two-dimensional matrix.");
end
[numberRows, numberColumns] = size(costMatrix);
if numberRows > numberColumns
    error("KSSOLV:Matgenlab:LinearAssignment:Rectangular", ...
        "cost matrix must have at least as many columns as rows.");
end
if any(isnan(costMatrix), "all")
    error("KSSOLV:Matgenlab:LinearAssignment:NaN", ...
        "cost matrix cannot contain NaN.");
end
finiteValues = costMatrix(isfinite(costMatrix));
if isempty(finiteValues)
    error("KSSOLV:Matgenlab:LinearAssignment:Infeasible", ...
        "cost matrix has no finite assignment.");
end
large = max(abs(finiteValues), [], "all") * ...
    (numberRows + numberColumns + 1) + 1;
originalCostMatrix = costMatrix;
costMatrix(~isfinite(costMatrix)) = large;

rowPotential = zeros(1, numberRows);
columnPotential = zeros(1, numberColumns + 1);
matchedRow = zeros(1, numberColumns + 1);
predecessor = zeros(1, numberColumns + 1);
for row = 1:numberRows
    matchedRow(1) = row;
    currentColumn = 1;
    minimum = inf(1, numberColumns + 1);
    used = false(1, numberColumns + 1);
    while true
        used(currentColumn) = true;
        currentRow = matchedRow(currentColumn);
        delta = inf;
        nextColumn = 0;
        for columnSlot = 2:numberColumns + 1
            if used(columnSlot), continue; end
            reduced = costMatrix(currentRow, columnSlot - 1) - ...
                rowPotential(currentRow) - ...
                columnPotential(columnSlot);
            if reduced < minimum(columnSlot)
                minimum(columnSlot) = reduced;
                predecessor(columnSlot) = currentColumn;
            end
            if minimum(columnSlot) < delta
                delta = minimum(columnSlot);
                nextColumn = columnSlot;
            end
        end
        if ~isfinite(delta)
            error("KSSOLV:Matgenlab:LinearAssignment:Infeasible", ...
                "No complete finite assignment exists.");
        end
        for columnSlot = 1:numberColumns + 1
            if used(columnSlot)
                if matchedRow(columnSlot) ~= 0
                    rowPotential(matchedRow(columnSlot)) = ...
                        rowPotential(matchedRow(columnSlot)) + delta;
                end
                columnPotential(columnSlot) = ...
                    columnPotential(columnSlot) - delta;
            else
                minimum(columnSlot) = minimum(columnSlot) - delta;
            end
        end
        currentColumn = nextColumn;
        if matchedRow(currentColumn) == 0, break; end
    end
    while true
        previous = predecessor(currentColumn);
        matchedRow(currentColumn) = matchedRow(previous);
        currentColumn = previous;
        if currentColumn == 1, break; end
    end
end
solution = zeros(1, numberRows);
for columnSlot = 2:numberColumns + 1
    if matchedRow(columnSlot) ~= 0
        solution(matchedRow(columnSlot)) = columnSlot - 1;
    end
end
indices = sub2ind(size(costMatrix), 1:numberRows, solution);
selected = originalCostMatrix(indices);
if any(~isfinite(selected))
    error("KSSOLV:Matgenlab:LinearAssignment:Infeasible", ...
        "No complete finite assignment exists.");
end
minimumCost = sum(selected);
end
