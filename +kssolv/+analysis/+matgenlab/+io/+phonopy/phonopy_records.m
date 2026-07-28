function value=phonopy_records(input)
%PHONOPY_RECORDS Normalize decoded YAML sequences to a row cell array.
if isempty(input),value=cell(1,0);
elseif iscell(input),value=reshape(input,1,[]);
elseif isstruct(input),value=num2cell(reshape(input,1,[]));
else
    error("KSSOLV:Matgenlab:Phonopy:Records", ...
        "Expected a YAML sequence of mappings.");
end
end
