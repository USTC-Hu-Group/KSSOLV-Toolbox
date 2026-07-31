classdef ParameterUtils
    %PARAMETERUTILS Validation helpers shared by modeling commands.

    methods (Static)
        function value = get(parameters, name, defaultValue)
            name = char(string(name));
            if isstruct(parameters) && isfield(parameters, name)
                value = parameters.(name);
            else
                value = defaultValue;
            end
        end

        function value = vector(parameters, name, lengthValue, defaultValue)
            value = double(kssolv.modeling.ParameterUtils.get( ...
                parameters, name, defaultValue));
            value = reshape(value, 1, []);
            if numel(value) ~= lengthValue || any(~isfinite(value))
                error("KSSOLV:Modeling:InvalidVector", ...
                    "Parameter '%s' must contain %d finite values.", ...
                    name, lengthValue);
            end
        end

        function value = matrix(parameters, name, rows, columns, defaultValue)
            value = double(kssolv.modeling.ParameterUtils.get( ...
                parameters, name, defaultValue));
            if ~isequal(size(value), [rows, columns]) || ...
                    any(~isfinite(value), "all")
                error("KSSOLV:Modeling:InvalidMatrix", ...
                    "Parameter '%s' must be a %d-by-%d finite matrix.", ...
                    name, rows, columns);
            end
        end

        function indices = indices(parameters, siteCount, defaultValue)
            indices = kssolv.modeling.ParameterUtils.get( ...
                parameters, "indices", defaultValue);
            indices = unique(reshape(double(indices), 1, []), "stable");
            if isempty(indices) || any(~isfinite(indices)) || ...
                    any(indices ~= fix(indices)) || ...
                    any(indices < 1) || any(indices > siteCount)
                error("KSSOLV:Modeling:InvalidSiteIndices", ...
                    "Site indices must be integers between 1 and %d.", ...
                    siteCount);
            end
        end

        function value = logical(parameters, name, defaultValue)
            value = kssolv.modeling.ParameterUtils.get( ...
                parameters, name, defaultValue);
            if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                error("KSSOLV:Modeling:InvalidLogical", ...
                    "Parameter '%s' must be a logical scalar.", name);
            end
            value = logical(value);
        end
    end
end
