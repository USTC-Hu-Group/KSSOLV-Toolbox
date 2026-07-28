function result = toDict(value)
%TODICT Recursively convert Matgenlab values to JSON-compatible values.

% MATLAB string, datetime, table, and dictionary values are objects too,
% so built-in serializable values must be handled before the generic object
% branch.
if isnumeric(value) || islogical(value) || ischar(value) || isstring(value) || isempty(value)
    result = value;
    return
end

if isdatetime(value)
    result = string(value, "yyyy-MM-dd'T'HH:mm:ss.SSSXXX");
    return
end

if isa(value, "containers.Map")
    keys = value.keys();
    converted = cell(size(keys));
    for index = 1:numel(keys)
        converted{index} = ...
            kssolv.analysis.matgenlab.util.toDict(value(keys{index}));
    end
    % Keep the map until jsonencode so wire keys such as "1" and "-1"
    % are not irreversibly sanitized into MATLAB struct identifiers.
    result = containers.Map(keys, converted, "UniformValues", false);
    return
end

if isobject(value)
    if ismethod(value, "asDict")
        result = kssolv.analysis.matgenlab.util.toDict(value.asDict());
        return
    end
    if isenum(value)
        result = string(value);
        return
    end
    error("KSSOLV:Matgenlab:Serialization:UnsupportedObject", ...
        "Class '%s' does not implement asDict().", class(value));
end

if isstruct(value)
    if ~isscalar(value)
        result = cell(size(value));
        for index = 1:numel(value)
            result{index} = kssolv.analysis.matgenlab.util.toDict(value(index));
        end
        return
    end
    result = value;
    names = fieldnames(value);
    for index = 1:numel(names)
        name = names{index};
        result.(name) = kssolv.analysis.matgenlab.util.toDict(value.(name));
    end
    return
end

if iscell(value)
    result = cell(size(value));
    for index = 1:numel(value)
        result{index} = kssolv.analysis.matgenlab.util.toDict(value{index});
    end
    return
end

error("KSSOLV:Matgenlab:Serialization:UnsupportedType", ...
    "Values of class '%s' cannot be serialized.", class(value));
end
