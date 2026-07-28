function key = natural_sort(value)
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
%NATURAL_SORT Produce a natural-sort key for a string.
parts = regexp(char(string(value)), "(\d+)", "split");
numbers = regexp(char(string(value)), "(\d+)", "tokens");
key = strings(1, numel(parts) + numel(numbers));
for index = 1:numel(parts)
    key(2 * index - 1) = lower(string(parts{index}));
    if index <= numel(numbers)
        key(2 * index) = compose("%020d", str2double(numbers{index}{1}));
    end
end
key = cellstr(key);
end
