function value = msonDict(moduleName, className, properties)
%MSONDICT Construct a MATLAB-safe MSON dictionary structure.
%
% MATLAB's JSON decoder maps reserved MSON keys @module and @class to
% x_module and x_class. Matgenlab uses those safe names internally and the
% encoder restores the original JSON keys.

arguments
    moduleName (1,1) string
    className (1,1) string
    properties (1,1) struct = struct()
end

value = struct("x_module", moduleName, "x_class", className);
names = fieldnames(properties);
for index = 1:numel(names)
    name = names{index};
    value.(name) = properties.(name);
end
end
