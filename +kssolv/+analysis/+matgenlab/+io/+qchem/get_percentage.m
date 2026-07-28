function value = get_percentage(line, orbital)
%GET_PERCENTAGE Extract an NBO orbital percentage from fixed-width text.
source = char(line);
index = strfind(source, char(orbital));
if isempty(index), value = ""; return; end
tail = source(index(1):end);
opening = strfind(tail, "(");
if isempty(opening), value = ""; return; end
first = opening(1) + 1;
last = min(numel(tail), first + 5);
value = strtrim(tail(first:last));
end
