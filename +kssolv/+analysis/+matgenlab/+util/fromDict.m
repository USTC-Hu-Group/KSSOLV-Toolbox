function result = fromDict(value, options)
%FROMDICT Recursively rehydrate MATLAB objects from an MSON structure.

arguments
    value
    options.Strict (1,1) logical = true
end

if iscell(value)
    result = cell(size(value));
    for index = 1:numel(value)
        result{index} = kssolv.analysis.matgenlab.util.fromDict( ...
            value{index}, Strict = options.Strict);
    end
    return
end

if ~isstruct(value)
    result = value;
    return
end

if ~isscalar(value)
    result = cell(size(value));
    for index = 1:numel(value)
        result{index} = kssolv.analysis.matgenlab.util.fromDict( ...
            value(index), Strict = options.Strict);
    end
    return
end

decoded = value;
names = fieldnames(value);
for index = 1:numel(names)
    name = names{index};
    if ~any(string(name) == ["x_module", "x_class", "x_version"])
        deferStructure = isfield(value,"x_class") && strcmp(name,"structure") && ...
            any(string(value.x_class)== ...
            ["EwaldSummation","ComputedStructureEntry"]);
        deferHistory = isfield(value,"x_class") && ...
            string(value.x_class) == "TransformedStructure" && ...
            strcmp(name, "history");
        deferMatcherComparator = isfield(value, "x_class") && ...
            string(value.x_class) == "StructureMatcher" && ...
            strcmp(name, "comparator");
        if ~(deferStructure || deferHistory || deferMatcherComparator)
            decoded.(name) = kssolv.analysis.matgenlab.util.fromDict( ...
                value.(name), Strict = options.Strict);
        end
    end
end

if ~(isfield(decoded, "x_module") && isfield(decoded, "x_class"))
    result = decoded;
    return
end

matlabClass = kssolv.analysis.matgenlab.internal.TypeRegistry.resolve( ...
    string(decoded.x_module), string(decoded.x_class));
if matlabClass == ""
    if options.Strict
        error("KSSOLV:Matgenlab:Serialization:UnknownType", ...
            "No MATLAB class is registered for '%s.%s'.", ...
            string(decoded.x_module), string(decoded.x_class));
    end
    result = decoded;
    return
end

availableMethods = string(methods(char(matlabClass)));
if any(availableMethods == "fromDict")
    factory = str2func(matlabClass + ".fromDict");
else
    factory = str2func(matlabClass + ".from_dict");
end
try
    result = factory(decoded);
catch exception
    if options.Strict
        wrapped = MException( ...
            "KSSOLV:Matgenlab:Serialization:ConstructionFailed", ...
            "Failed to construct '%s' from MSON data.", matlabClass);
        wrapped = addCause(wrapped, exception);
        throw(wrapped);
    end
    result = decoded;
end
end
