function text = str_delimited(results, header, delimiter)
%STR_DELIMITED Render a two-dimensional sequence as delimited text.
if nargin < 2, header = []; end
if nargin < 3, delimiter = sprintf('\t'); end
delimiter = string(delimiter);
lines = strings(0, 1);
if ~isempty(header)
    lines(end + 1) = strjoin(toStrings(header), delimiter);
end
if iscell(results)
    if isvector(results), results = reshape(results, 1, []); end
    for row = 1:size(results, 1)
        lines(end + 1) = strjoin(toStrings(results(row, :)), delimiter); %#ok<AGROW>
    end
elseif isstring(results) || isnumeric(results) || islogical(results)
    if isvector(results), results = reshape(results, 1, []); end
    for row = 1:size(results, 1)
        lines(end + 1) = strjoin(string(results(row, :)), delimiter); %#ok<AGROW>
    end
else
    error("KSSOLV:Matgenlab:String:InvalidResults", ...
        "results must be a two-dimensional sequence.");
end
text = strjoin(lines, newline);
end

function values = toStrings(values)
if ~iscell(values), values = cellstr(string(values)); end
out = strings(size(values));
for idx = 1:numel(values)
    value = values{idx};
    out(idx) = string(value);
end
values = out;
end
