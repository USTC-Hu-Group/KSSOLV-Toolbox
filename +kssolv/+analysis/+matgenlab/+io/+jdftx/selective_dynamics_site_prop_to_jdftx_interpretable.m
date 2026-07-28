function value = selective_dynamics_site_prop_to_jdftx_interpretable(input)
%SELECTIVE_DYNAMICS_SITE_PROP_TO_JDFTX_INTERPRETABLE Collapse XYZ flags.
input = logical(input);
if isvector(input)
    value = double(input(:));
else
    value = double(all(input, 2));
end
end
