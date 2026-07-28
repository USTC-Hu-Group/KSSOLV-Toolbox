function tables = parse_hybridization_character(lines)
%#ok<*AGROW,*ALIGN>
%PARSE_HYBRIDIZATION_CHARACTER Parse NBO lone-pair, bond, and 3-center entries.
lines = string(lines(:));
headers = find(contains(lines, "(Occupancy)") & contains(lines, "Coefficients"));
tables = {};
for headerIndex = 1:numel(headers)
    categories = {{}, {}, {}};
    index = headers(headerIndex) + 2;
    while index <= numel(lines)
        line = char(lines(index));
        if any(contains(string(line), ["NHO DIRECTIONALITY", "Archival summary:", ...
                "SECOND ORDER PERTURBATION THEORY", "Thank you very much"])), break; end
        if numel(line) >= 28
            kind = strtrim(safe_slice(line, 17, 19));
            if any(string(kind) == ["LP", "LV"]), category = 1;
            elseif startsWith(kind, "BD"), category = 2;
            elseif startsWith(kind, "3C"), category = 3;
            else, index = index + 1; continue; end
            entry = struct("bond_index", strtrim(safe_slice(line, 1, 4)), ...
                "occupancy", strtrim(safe_slice(line, 8, 14)), ...
                "type", kind, "orbital_index", strtrim(safe_slice(line, 21, 22)), ...
                "atom_1_symbol", strtrim(safe_slice(line, 24, 25)), ...
                "atom_1_number", strtrim(safe_slice(line, 26, 28)), ...
                "s", kssolv.analysis.matgenlab.io.qchem.get_percentage(line, "s"), ...
                "p", kssolv.analysis.matgenlab.io.qchem.get_percentage(line, "p"), ...
                "d", kssolv.analysis.matgenlab.io.qchem.get_percentage(line, "d"), ...
                "f", kssolv.analysis.matgenlab.io.qchem.get_percentage(line, "f"));
            if category >= 2
                entry.atom_2_symbol = strtrim(safe_slice(line, 30, 31));
                entry.atom_2_number = strtrim(safe_slice(line, 32, 34));
            end
            if category == 3
                entry.atom_3_symbol = strtrim(safe_slice(line, 36, 37));
                entry.atom_3_number = strtrim(safe_slice(line, 38, 40));
            end
            categories{category}{end + 1} = entry;
        end
        index = index + 1;
    end
    for category = 1:3
        if isempty(categories{category}), tables{end + 1} = table();
        else, tables{end + 1} = struct2table(vertcat(categories{category}{:})); end
    end
end
end

function output = safe_slice(input, first, last)
if numel(input) < first, output = ""; return; end
output = input(first:min(last, numel(input)));
end
