function values = read_matrix_pattern(headerPattern, footerPattern, ...
        elementsPattern, text, postprocess)
%READ_MATRIX_PATTERN Parse values between a matrix header and footer.
if nargin < 5 || isempty(postprocess), postprocess = @(value) value; end
source = char(text);
[headerStart, headerEnd] = regexp(source, headerPattern, "once");
footerStart = regexp(source, footerPattern, "once");
if isempty(headerStart) || isempty(footerStart) || footerStart <= headerEnd
    error("KSSOLV:Matgenlab:QChem:MatrixPattern", ...
        "Matrix header or footer was not found in the expected order.");
end
tokens = regexp(source(headerEnd + 1:footerStart - 1), elementsPattern, "match");
values = cellfun(postprocess, tokens, "UniformOutput", false);
end
