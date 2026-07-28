function value = subs(entry, mapping)
%SUBS Substitute a symbolic elasticity name using a MATLAB mapping.
name = char(string(entry));
if isa(mapping, "containers.Map")
    value = mapping(name);
elseif isa(mapping, "dictionary")
    value = mapping(string(name));
elseif isstruct(mapping)
    value = mapping.(matlab.lang.makeValidName(name));
else
    error("KSSOLV:Matgenlab:Elasticity:SubstitutionMap", ...
        "cmap must be a containers.Map, dictionary, or struct.");
end
end
