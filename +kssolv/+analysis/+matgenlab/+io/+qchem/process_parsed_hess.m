function values = process_parsed_hess(hessData)
%PROCESS_PARSED_HESS Convert a text HESS lower triangle to 132.0 ordering.
if ischar(hessData) || (isstring(hessData) && isscalar(hessData))
    lines = splitlines(string(hessData));
else
    lines = string(hessData(:));
end
dimensionTokens = regexp(lines(2), "\S+\s+(\d+)", "tokens", "once");
if isempty(dimensionTokens)
    error("KSSOLV:Matgenlab:QChem:Hessian", "Invalid HESS dimension line.");
end
dimension = str2double(dimensionTokens{1});
matrix = zeros(dimension);
row = 1;
column = 1;
for index = 3:numel(lines) - 1
    tokens = regexp(lines(index), ...
        "[-+]?(?:\d+\.?\d*|\.\d+)(?:[EeDd][-+]?\d+)?", "match");
    for token = tokens
        number = str2double(replace(token, ["D", "d"], ["E", "e"]));
        matrix(row, column) = number;
        matrix(column, row) = number;
        if row == column
            row = row + 1;
            column = 1;
        else
            column = column + 1;
        end
    end
end
values = reshape(matrix.', 1, []);
end
