function bounds = get_pseudo_read_section_bounds(text)
%GET_PSEUDO_READ_SECTION_BOUNDS Locate pseudopotential read sections.
lines = string(text);
starts = find(contains(lines, "Reading pseudopotential") | ...
    contains(lines, "Reading pseudopotentials"));
if isempty(starts)
    bounds = zeros(0, 2);
    return
end
bounds = zeros(numel(starts), 2);
for idx = 1:numel(starts)
    first = starts(idx);
    if idx < numel(starts)
        last = starts(idx + 1) - 1;
    else
        tail = find(strlength(strtrim(lines(first:end))) == 0, 1);
        if isempty(tail)
            last = numel(lines);
        else
            last = first + tail - 2;
        end
    end
    bounds(idx, :) = [first - 1, last - 1];
end
end
