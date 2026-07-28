function matrix = process_parsed_fock_matrix(values)
%PROCESS_PARSED_FOCK_MATRIX Reassemble Q-Chem's six-column matrix chunks.
values = double(values(:));
dimension = round(sqrt(numel(values)));
if dimension ^ 2 ~= numel(values)
    error("KSSOLV:Matgenlab:QChem:FockMatrix", ...
        "The parsed Fock matrix does not contain a square number of values.");
end
matrix = zeros(dimension);
offset = 1;
firstColumn = 1;
while firstColumn <= dimension
    columns = min(6, dimension - firstColumn + 1);
    count = dimension * columns;
    chunk = reshape(values(offset:offset + count - 1), columns, dimension).';
    matrix(:, firstColumn:firstColumn + columns - 1) = chunk;
    offset = offset + count;
    firstColumn = firstColumn + columns;
end
end
