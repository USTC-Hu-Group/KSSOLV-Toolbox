function [label, orbitals] = get_orb_from_str(values)
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
%GET_ORB_FROM_STR Convert LOBSTER orbital labels to quantum-number records.
values = string(values);
orbitals = repmat(struct("principal", 0, "orbital", ""), 1, numel(values));
for index = 1:numel(values)
    token = regexp(values(index), "^(\d+)(.+)$", "tokens", "once");
    orbitals(index).principal = str2double(token{1});
    orbitals(index).orbital = token{2};
end
label = char(strjoin(values, "-"));
end
