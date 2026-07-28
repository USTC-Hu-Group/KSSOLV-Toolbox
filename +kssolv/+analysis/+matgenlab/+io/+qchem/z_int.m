function value = z_int(input)
%Z_INT Convert an NBO atomic-index token, using -1 for blank tokens.
value = str2double(string(input));
if isnan(value), value = -1; else, value = fix(value); end
end
