classdef Utils
    %UTILS Shared deterministic helpers for transformation algorithms.

    methods (Static)
        function count = rankedCount(value)
            if islogical(value)
                if value, count = 1; else, count = 0; end
            elseif isempty(value) || value == 0
                count = 0;
            else
                count = max(1, fix(double(value)));
            end
        end

        function indices = validateIndices(indices, siteCount)
            indices = reshape(double(indices), 1, []);
            if any(indices ~= fix(indices)) || any(indices < 1) || ...
                    any(indices > siteCount)
                error("KSSOLV:Matgenlab:Transformation:SiteIndex", ...
                    "Site indices use MATLAB one-based values and must " + ...
                    "lie between 1 and the number of sites.");
            end
        end

        function output = choose(values, count)
            values = reshape(values, 1, []);
            if count == 0
                output = zeros(1, 0);
            elseif count == numel(values)
                output = values;
            else
                selected = nchoosek(1:numel(values), count);
                output = reshape(values(selected), size(selected));
            end
        end

        function combinations = productChoices(groups)
            combinations = {zeros(1, 0)};
            for group = 1:numel(groups)
                next = cell(1, 0);
                for first = 1:numel(combinations)
                    for second = 1:size(groups{group}, 1)
                        next{end + 1} = [combinations{first}, ...
                            groups{group}(second, :)]; %#ok<AGROW>
                    end
                end
                combinations = next;
            end
        end

        function result = addSiteProperties(structure, siteProperties)
            result = structure.copy();
            names = string(fieldnames(siteProperties));
            for name = names.'
                values = siteProperties.(name);
                if numel(values) ~= result.num_sites && ...
                        ~(iscell(values) && numel(values) == result.num_sites)
                    error("KSSOLV:Matgenlab:Transformation:SiteProperties", ...
                        "Each site property must have one value per site.");
                end
                for index = 1:result.num_sites
                    site = result(index);
                    props = site.site_properties;
                    if iscell(values)
                        props.(name) = values{index};
                    elseif size(values, 1) == result.num_sites
                        props.(name) = values(index, :);
                    else
                        props.(name) = values(index);
                    end
                    result = result.replace(index, [], [], ...
                        properties = props);
                end
            end
        end

        function result = sorted(structure)
            result = structure.get_sorted_structure();
        end

        function map = normalizeMap(input)
            if isa(input, "containers.Map")
                map = input;
                return
            end
            map = containers.Map("KeyType", "char", "ValueType", "any");
            if isstruct(input)
                names = fieldnames(input);
                for index = 1:numel(names)
                    map(names{index}) = input.(names{index});
                end
            elseif iscell(input)
                if size(input, 2) ~= 2
                    error("KSSOLV:Matgenlab:Transformation:Map", ...
                        "Mapping cell arrays must have two columns.");
                end
                for index = 1:size(input, 1)
                    map(char(string(input{index, 1}))) = input{index, 2};
                end
            else
                error("KSSOLV:Matgenlab:Transformation:Map", ...
                    "Expected a struct, containers.Map, or two-column cell array.");
            end
        end

        function value = mapAsStruct(map)
            if isstruct(map), value = map; return; end
            value = struct();
            keys_ = map.keys();
            for index = 1:numel(keys_)
                value.(matlab.lang.makeValidName(keys_{index})) = ...
                    map(keys_{index});
            end
        end
    end
end
