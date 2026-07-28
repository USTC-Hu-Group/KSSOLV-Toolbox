function value=field_or(data,name,default)
%FIELD_OR Return a struct field or a default.
if isstruct(data)&&isfield(data,name)&&~isempty(data.(name))
    value=data.(name);
else
    value=default;
end
end
