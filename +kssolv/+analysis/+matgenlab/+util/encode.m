function text = encode(value, options)
%ENCODE Encode a value as Monty-compatible JSON.

arguments
    value
    options.PrettyPrint (1,1) logical = false
end

value = kssolv.analysis.matgenlab.util.toDict(value);
text = jsonencode(value, PrettyPrint = options.PrettyPrint);

% jsondecode("@module") produces x_module. Restore the three MSON metadata
% keys only when they occur as object keys.
text = strrep(text, '"x_module":', '"@module":');
text = strrep(text, '"x_class":', '"@class":');
text = strrep(text, '"x_version":', '"@version":');
% jsondecode maps pymatgen's private Ewald cache keys to valid MATLAB
% identifiers. Restore those exact wire keys on output.
text = strrep(text, '"x_recip":', '"_recip":');
text = strrep(text, '"x_real":', '"_real":');
text = strrep(text, '"x_point":', '"_point":');
text = strrep(text, '"x_forces":', '"_forces":');
end
