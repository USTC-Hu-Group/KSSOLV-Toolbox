function output = convert_spin_keys(value)
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
%CONVERT_SPIN_KEYS Recursively convert spin-keyed structs for JSON.
output = value;
if iscell(value)
    output = cellfun(@kssolv.analysis.matgenlab.io.lobster.future.utils.convert_spin_keys, ...
        value, "UniformOutput", false);
elseif isstruct(value)
    output = value;
    names = fieldnames(value);
    for item = 1:numel(value)
        for index = 1:numel(names)
            output(item).(names{index}) = ...
                kssolv.analysis.matgenlab.io.lobster.future.utils. ...
                convert_spin_keys(value(item).(names{index}));
        end
    end
end
end
