function output = clean_lines(stringList, options)
%CLEAN_LINES Remove comments and surrounding whitespace from text lines.

arguments
    stringList
    options.remove_empty_lines (1,1) logical = true
    options.rstrip_only (1,1) logical = false
end

lines = string(stringList);
output = strings(size(lines));
keep = true(size(lines));
for index = 1:numel(lines)
    line = lines(index);
    comment = strfind(line, "#");
    if ~isempty(comment)
        line = extractBefore(line, comment(1));
    end
    if options.rstrip_only
        line = regexprep(line, "\s+$", "");
    else
        line = strtrim(line);
    end
    output(index) = line;
    if options.remove_empty_lines && line == ""
        keep(index) = false;
    end
end
output = output(keep);
end
