function indices = find_first_range_key(key_input, text, options)
%FIND_FIRST_RANGE_KEY Return first matching contiguous line range.
arguments
    key_input
    text
    options.startline (1, 1) double = 0
    options.endline (1, 1) double = -1
    options.skip_pound (1, 1) logical = false
end
lines = string(text);
first = max(1, options.startline + 1);
last = options.endline;
if last < 0
    last = numel(lines) + last + 1;
end
last = min(numel(lines), last);
hits = false(size(lines));
for idx = first:last
    candidate = strtrim(lines(idx));
    hits(idx) = contains(candidate, string(key_input)) && ...
        (~options.skip_pound || ~startsWith(candidate, "#"));
end
start = find(hits, 1);
if isempty(start)
    indices = [];
    return
end
stop = start;
while stop < numel(hits) && hits(stop + 1)
    stop = stop + 1;
end
indices = [start - 1, stop - 1];
end
