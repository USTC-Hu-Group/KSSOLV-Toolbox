function value = key_exists(key_input, text)
%KEY_EXISTS Return true when a key occurs in any line.
value = any(contains(string(text), string(key_input)));
end
