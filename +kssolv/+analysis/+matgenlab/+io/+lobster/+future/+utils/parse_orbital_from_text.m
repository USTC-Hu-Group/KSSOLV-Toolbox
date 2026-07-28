function orbital = parse_orbital_from_text(text)
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
%PARSE_ORBITAL_FROM_TEXT Extract a LOBSTER orbital label.
match = regexp(char(string(text)), ...
    "\d+(?:s|p(?:_[xyz])?|d(?:_(?:xy|yz|xz|x\^2-y\^2|z\^2))?|f(?:_[A-Za-z0-9^+\-]+)?)", ...
    "match");
if isempty(match)
    orbital = [];
else
    orbital = string(match{end});
end
end
