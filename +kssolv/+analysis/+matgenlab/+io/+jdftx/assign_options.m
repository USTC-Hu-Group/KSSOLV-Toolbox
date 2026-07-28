function obj = assign_options(obj, varargin)
%ASSIGN_OPTIONS Apply a struct or name-value pairs to public properties.
if isempty(varargin)
    return
end
if isscalar(varargin) && isstruct(varargin{1})
    options = varargin{1};
    names = fieldnames(options);
    values = struct2cell(options);
else
    if mod(numel(varargin), 2) ~= 0
        error("KSSOLV:Matgenlab:JDFTX:InvalidOptions", ...
            "Options must be a struct or name-value pairs.");
    end
    names = string(varargin(1:2:end));
    values = varargin(2:2:end);
end
for idx = 1:numel(names)
    name = char(names(idx));
    if isprop(obj, name)
        obj.(name) = values{idx};
    else
        error("KSSOLV:Matgenlab:JDFTX:UnknownOption", ...
            "Unknown option '%s' for %s.", name, class(obj));
    end
end
end
