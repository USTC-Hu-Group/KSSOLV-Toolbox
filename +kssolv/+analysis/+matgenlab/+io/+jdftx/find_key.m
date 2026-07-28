function index = find_key(key_input, text)
%FIND_KEY Return zero-based last line containing a key.
matches = find(contains(string(text), string(key_input)), 1, "last");
if isempty(matches)
    index = [];
else
    index = matches - 1;
end
end
