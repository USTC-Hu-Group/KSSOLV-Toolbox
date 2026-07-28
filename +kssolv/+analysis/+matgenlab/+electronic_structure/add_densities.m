function value = add_densities(density1, density2)
%ADD_DENSITIES Sum two spin-resolved density mappings.
value = struct();
names = fieldnames(density1);
for index = 1:numel(names)
    name = names{index};
    if ~isfield(density2, name)
        error("KSSOLV:Matgenlab:Dos:SpinMismatch", ...
            "Density mappings must contain identical spin channels.");
    end
    value.(name) = double(density1.(name)) + double(density2.(name));
end
end
