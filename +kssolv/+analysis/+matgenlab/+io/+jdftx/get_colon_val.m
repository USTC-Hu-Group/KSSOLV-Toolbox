function value = get_colon_val(line_text, key)
%GET_COLON_VAL Read the first numeric token following a colon-key.
line_text = string(line_text);
key = string(key);
position = strfind(line_text, key);
if isempty(position)
    value = [];
    return
end
tail = extractAfter(line_text, position(1) + strlength(key) - 1);
token = regexp(strtrim(tail), "^(nan|[-+]?(?:\d*\.?\d+)(?:[Ee][-+]?\d+)?)", ...
    "tokens", "once");
if isempty(token)
    value = [];
elseif strcmpi(token{1}, "nan")
    value = NaN;
else
    value = str2double(token{1});
end
end
