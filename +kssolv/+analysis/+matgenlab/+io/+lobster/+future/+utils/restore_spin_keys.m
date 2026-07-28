function output = restore_spin_keys(value)
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
%RESTORE_SPIN_KEYS Recursively restore JSON-compatible spin dictionaries.
output = kssolv.analysis.matgenlab.io.lobster.future.utils.convert_spin_keys(value);
end
