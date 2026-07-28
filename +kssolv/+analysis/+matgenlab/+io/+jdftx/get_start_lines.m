function indices = get_start_lines(text, options)
%GET_START_LINES Return zero-based JDFTx calculation start positions.
arguments
    text
    options.start_key (1, 1) string = "*************** JDFTx"
    options.add_end (1, 1) logical = false
end
text = string(text);
if isempty(text)
    error("KSSOLV:Matgenlab:JDFTX:EmptyOutfile", ...
        "Outfile parser received an empty file.");
end
indices = find(contains(text, options.start_key)) - 1;
if isempty(indices)
    error("KSSOLV:Matgenlab:JDFTX:NoCalculations", ...
        "No JDFTx calculations found in file.");
end
if options.add_end
    indices(end + 1) = numel(text);
end
indices = reshape(indices, 1, []);
end
