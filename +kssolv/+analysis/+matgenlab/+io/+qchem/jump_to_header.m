function output = jump_to_header(lines, header)
%JUMP_TO_HEADER Return the input line sequence beginning at a header.
lines = string(lines(:));
index = find(contains(strip(lines), string(header)), 1);
if isempty(index)
    error("KSSOLV:Matgenlab:QChem:Header", ...
        "Header '%s' could not be found in the lines.", header);
end
output = lines(index:end);
end
