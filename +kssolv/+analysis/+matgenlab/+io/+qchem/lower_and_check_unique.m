function output = lower_and_check_unique(input)
%LOWER_AND_CHECK_UNIQUE Normalize Q-Chem dictionary keys and scalar values.
if isempty(input)
    output = input;
    return
end
if isa(input, "containers.Map")
    keys = input.keys;
    values = input.values;
elseif isstruct(input)
    keys = fieldnames(input);
    values = struct2cell(input);
else
    error("KSSOLV:Matgenlab:QChem:Dictionary", ...
        "Q-Chem dictionaries must be structures or containers.Map objects.");
end
output = struct();
for index = 1:numel(keys)
    key = lower(string(keys{index}));
    if key == "jobtype"
        key = "job_type";
    end
    field = matlab.lang.makeValidName(key);
    value = values{index};
    if ischar(value) || (isstring(value) && isscalar(value))
        value = char(lower(string(value)));
    elseif isnumeric(value) && isscalar(value)
        value = char(string(value));
    end
    if isfield(output, field) && ~isequal(output.(field), value)
        error("KSSOLV:Matgenlab:QChem:DuplicateKey", ...
            "Multiple instances of key %s found with different values!", key);
    end
    output.(field) = value;
end
end
