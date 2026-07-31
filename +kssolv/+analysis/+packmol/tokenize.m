function tokens = tokenize(line)
%TOKENIZE Split one Packmol input line while preserving quoted paths.

line = char(string(line));
tokens = strings(1, 0);
current = "";
quote = char(0);
i = 1;
while i <= numel(line)
    ch = line(i);
    if quote ~= char(0)
        if ch == quote
            quote = char(0);
        else
            current = current + string(ch);
        end
    elseif ch == '#'
        break
    elseif ch == '"' || ch == ''''
        quote = ch;
    elseif isspace(ch)
        if strlength(current) > 0
            tokens(end + 1) = current; %#ok<AGROW>
            current = "";
        end
    else
        current = current + string(ch);
    end
    i = i + 1;
end
if quote ~= char(0)
    error("KSSOLV:Packmol:Input", "Unterminated quoted string.");
end
if strlength(current) > 0
    tokens(end + 1) = current;
end
end
