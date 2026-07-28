function lines = read_file(file_name)
%READ_FILE Read a JDFTx text file as a column cell array of lines.
arguments
    file_name (1, 1) string
end
if ~isfile(file_name)
    error("KSSOLV:Matgenlab:JDFTX:MissingFile", ...
        "'%s' file does not exist.", file_name);
end
text = fileread(file_name);
lines = regexp(text, "\r\n|\n|\r", "split").';
if ~isempty(lines) && isempty(lines{end})
    lines(end) = [];
end
end
