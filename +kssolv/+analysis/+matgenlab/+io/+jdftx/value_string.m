function text = value_string(value)
%VALUE_STRING Compact deterministic representation for diagnostics.
if isstring(value) || ischar(value)
    text = string(value);
elseif isnumeric(value) || islogical(value)
    text = string(mat2str(value));
elseif iscell(value) || isstruct(value)
    text = string(jsonencode(value));
else
    text = string(class(value));
end
end
