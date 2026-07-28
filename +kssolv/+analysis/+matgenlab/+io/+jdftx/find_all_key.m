function indices = find_all_key(key_input, text, options)
%FIND_ALL_KEY Return zero-based positions of every matching line.
arguments
    key_input
    text
    options.startline (1, 1) double = 0
end
lines = string(text);
matches = find(contains(lines(max(1, options.startline + 1):end), ...
    string(key_input)));
indices = reshape(matches + max(1, options.startline + 1) - 2, 1, []);
end
