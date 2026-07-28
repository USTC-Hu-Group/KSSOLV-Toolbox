function value = correct_geom_opt_type(opt_type)
%CORRECT_GEOM_OPT_TYPE Normalize geometry optimization type names.
if isempty(opt_type)
    value = [];
    return
end
text = lower(string(opt_type));
if contains(text, "lattice")
    value = "LatticeMinimize";
elseif contains(text, "ionic")
    if contains(text, "dyn")
        value = "IonicDynamics";
    else
        value = "IonicMinimize";
    end
else
    value = [];
end
end
