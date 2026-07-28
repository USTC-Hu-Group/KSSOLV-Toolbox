function data = bond_lengths_data()
%BOND_LENGTHS_DATA Frozen pymatgen bond-length database.
persistent cache
if isempty(cache)
    filename = fullfile(fileparts(mfilename("fullpath")), ...
        "+data", "bond_lengths.json");
    rows = jsondecode(fileread(filename));
    cache = containers.Map("KeyType", "char", "ValueType", "any");
    for index = 1:numel(rows)
        symbols = sort(string(rows(index).elements));
        key = char(strjoin(symbols, "|"));
        if isKey(cache, key)
            lengths = cache(key);
        else
            lengths = containers.Map("KeyType", "double", ...
                "ValueType", "double");
        end
        lengths(double(rows(index).bond_order)) = double(rows(index).length);
        cache(key) = lengths;
    end
end
data = cache;
end
