function equal = is_np_dict_equal(first, second)
%IS_NP_DICT_EQUAL Compare mappings whose values may be numeric arrays.

if isa(first, "containers.Map") && isa(second, "containers.Map")
    firstKeys = sort(string(keys(first)));
    secondKeys = sort(string(keys(second)));
    if ~isequal(firstKeys, secondKeys)
        equal = false;
        return
    end
    equal = true;
    for index = 1:numel(firstKeys)
        key = char(firstKeys(index));
        if ~isequaln(first(key), second(key))
            equal = false;
            return
        end
    end
    return
end

if isstruct(first) && isstruct(second) && isscalar(first) && isscalar(second)
    firstKeys = sort(string(fieldnames(first)));
    secondKeys = sort(string(fieldnames(second)));
    if ~isequal(firstKeys, secondKeys)
        equal = false;
        return
    end
    equal = true;
    for index = 1:numel(firstKeys)
        key = char(firstKeys(index));
        if ~isequaln(first.(key), second.(key))
            equal = false;
            return
        end
    end
    return
end

error("KSSOLV:Matgenlab:Util:MappingRequired", ...
    "Inputs must both be scalar structures or containers.Map instances.");
end
