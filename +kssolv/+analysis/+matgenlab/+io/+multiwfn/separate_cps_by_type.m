function organized = separate_cps_by_type(descriptors)
%SEPARATE_CPS_BY_TYPE Partition a descriptor map into CP categories.
organized = struct( ...
    "atom", emptyMap(), "bond", emptyMap(), ...
    "ring", emptyMap(), "cage", emptyMap());
keys = descriptors.keys;
for index = 1:numel(keys)
    key = string(keys{index});
    if contains(key, "bond")
        category = "bond";
    elseif contains(key, "ring")
        category = "ring";
    elseif contains(key, "cage")
        category = "cage";
    elseif ~contains(key, "Unknown")
        category = "atom";
    else
        continue
    end
    organized.(category)(char(key)) = descriptors(char(key));
end
end

function value = emptyMap()
value = containers.Map("KeyType", "char", "ValueType", "any");
end
