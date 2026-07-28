function tables = parse_natural_populations(lines)
%#ok<*AGROW>
%PARSE_NATURAL_POPULATIONS Parse every NBO natural population table.
lines = string(lines(:));
headers = find(contains(lines, "Summary of Natural Population Analysis:"));
tables = cell(1, numel(headers));
for tableIndex = 1:numel(headers)
    start = headers(tableIndex) + 6;
    rows = {};
    while start <= numel(lines) && ~contains(lines(start), "=")
        tokens = split(strip(lines(start))); tokens(tokens == "") = [];
        if numel(tokens) >= 7 && ~isnan(str2double(tokens(2)))
            row = {char(tokens(1)), str2double(tokens(2)), ...
                str2double(tokens(3)), str2double(tokens(4)), ...
                str2double(tokens(5)), str2double(tokens(6)), str2double(tokens(7))};
            if numel(tokens) >= 8, row{8} = str2double(tokens(8)); end
            rows(end + 1, 1:numel(row)) = row;
        end
        start = start + 1;
    end
    if isempty(rows), tables{tableIndex} = table(); continue; end
    names = ["Atom", "No", "Charge", "Core", "Valence", "Rydberg", "Total"];
    if size(rows, 2) == 8, names(8) = "Density"; end
    tables{tableIndex} = cell2table(rows, "VariableNames", names);
end
end
