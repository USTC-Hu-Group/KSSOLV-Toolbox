function output = get_all_possible_basis_combinations(min_basis, max_basis)
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
%GET_ALL_POSSIBLE_BASIS_COMBINATIONS Enumerate valid basis supersets.
perElement = cell(1, numel(max_basis));
for index = 1:numel(max_basis)
    maximum = split(strtrim(string(max_basis{index})));
    minimum = split(strtrim(string(min_basis{index})));
    fixed = minimum(2:end);
    variable = setdiff(maximum(2:end), fixed, "stable");
    entries = cell(1, 2 ^ numel(variable));
    for mask = 0:2 ^ numel(variable) - 1
        selected = variable(logical(bitget(mask, 1:numel(variable))));
        entries{mask + 1} = char(strjoin([maximum(1); fixed; selected], " "));
    end
    perElement{index} = entries;
end
output = {{}};
for index = 1:numel(perElement)
    next = {};
    for prefix = output
        for entry = perElement{index}
            next{end + 1} = [prefix{1}, entry];
        end
    end
    output = next;
end
end
