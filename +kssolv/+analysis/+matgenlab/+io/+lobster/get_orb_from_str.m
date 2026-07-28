function [label, orbitals] = get_orb_from_str(values)
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
%GET_ORB_FROM_STR Legacy orbital conversion function.
[label, orbitals] = kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
    get_orb_from_str(values);
end
