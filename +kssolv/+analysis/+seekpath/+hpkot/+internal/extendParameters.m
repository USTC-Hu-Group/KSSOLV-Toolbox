function extendedParameters = extendParameters(parameters)
%EXTENDPARAMETERS Extends a dictionary of parameters with simple expressions.
%
% Input:
%   parameters - A struct where field names are parameter names
%                and values are numerical values.
%
% Output:
%   extendedParameters - A containers.Map with the original keys and
%                        additional extended keys for simple expressions.

% Initialize the extended parameters map
extendedParameters = containers.Map();

% Get the field names of the input parameters
parameterFields = fieldnames(parameters);
for i = 1:length(parameterFields)
    key = parameterFields{i};
    value = parameters.(key);

    % Add the original key-value pair
    extendedParameters(key) = value;

    % Add extended expressions
    extendedParameters(['-', key]) = -value;
    extendedParameters(['1-', key]) = 1.0 - value;
    extendedParameters(['-1+', key]) = -1.0 + value;
    extendedParameters(['1/2-', key]) = 0.5 - value;
    extendedParameters(['1/2+', key]) = 0.5 + value;
end
end
