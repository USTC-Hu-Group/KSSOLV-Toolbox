function index = find_key_first(key_input, text)
%FIND_KEY_FIRST Return zero-based first line containing a key.
matches = find(contains(string(text), string(key_input)), 1);
if isempty(matches)
    index = [];
else
    index = matches - 1;
end
end
