function value=phonopy_field(record,name,default)
%PHONOPY_FIELD Access a YAML key after jsondecode name normalization.
if nargin<3,hasDefault=false;else,hasDefault=true;end
candidate=matlab.lang.makeValidName(char(string(name)));
if isfield(record,candidate)
    value=record.(candidate);
elseif hasDefault
    value=default;
else
    error("KSSOLV:Matgenlab:Phonopy:Field", ...
        "Required phonopy field '%s' is absent.",name);
end
end
