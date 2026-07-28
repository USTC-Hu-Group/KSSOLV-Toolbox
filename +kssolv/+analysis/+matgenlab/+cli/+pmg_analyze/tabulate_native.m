function text = tabulate_native(rows, headers, format)
%TABULATE_NATIVE Native subset of Python tabulate used by pmg analyze.
%
% ROWS is a cell matrix and HEADERS is a string vector.  The formatter
% preserves tabulate's numeric-string coercion and column alignment for the
% table formats exposed most commonly by the pymatgen command line.

if nargin < 3 || isempty(format), format = "simple"; end
headers = reshape(string(headers), 1, []);
if isempty(rows)
    rows = cell(0, numel(headers));
end
if ~iscell(rows) || size(rows, 2) ~= numel(headers)
    error("KSSOLV:Matgenlab:PmgAnalyze:Table", ...
        "rows must be a cell matrix with one column per header.");
end

[values, numeric] = normalizeValues(rows);
% tabulate reserves two characters beyond each header before aligning data.
widths = strlength(headers) + 2;
if ~isempty(values)
    widths = max([widths; strlength(values)], [], 1);
end
format = lower(string(format));
switch format
    case "plain"
        lines = [formatLine(headers, widths, numeric, false); ...
            formatRows(values, widths, numeric, false)];
    case {"simple", "simple_outline"}
        lines = [formatLine(headers, widths, numeric, false); ...
            repeatedColumns(widths, "-", "  "); ...
            formatRows(values, widths, numeric, false)];
    case {"github", "pipe"}
        lines = pipeTable(values, headers, widths, numeric, format);
    case {"grid", "fancy_grid", "pretty", "outline", ...
            "rounded_outline", "heavy_outline", "mixed_outline", ...
            "fancy_outline"}
        lines = gridTable(values, headers, widths, numeric, format);
    case {"psql", "presto"}
        lines = psqlTable(values, headers, widths, numeric, format);
    case "tsv"
        lines = [formatLine(headers, widths, numeric, true); ...
            formatRows(values, widths, numeric, true)];
    case "rst"
        rule = repeatedColumns(widths, "=", "  ");
        lines = [rule; formatLine(headers, widths, numeric, false); ...
            rule; formatRows(values, widths, numeric, false); rule];
    case {"orgtbl", "jira", "youtrack"}
        lines = orgTable(values, headers, widths, numeric, format);
    case {"html", "unsafehtml"}
        lines = htmlTable(values, headers, widths, numeric);
    case {"latex", "latex_raw", "latex_booktabs", "latex_longtable"}
        lines = latexTable(values, headers, widths, numeric, format);
    case "mediawiki"
        lines = mediawikiTable(values, headers, numeric);
    case "asciidoc"
        lines = asciidocTable(values, headers);
    otherwise
        error("KSSOLV:Matgenlab:PmgAnalyze:TableFormat", ...
            "Unsupported table format '%s'.", format);
end
text = join(lines, newline);
end

function [values, numeric] = normalizeValues(rows)
values = strings(size(rows));
numeric = true(1, size(rows, 2));
if size(rows, 1) == 0, numeric(:) = false; end
for column = 1:size(rows, 2)
    for row = 1:size(rows, 1)
        value = rows{row, column};
        if isnumeric(value) && isscalar(value)
            values(row, column) = numericText(double(value));
        else
            values(row, column) = string(value);
        end
        if strlength(values(row, column)) > 0 && ...
                isnan(str2double(values(row, column)))
            numeric(column) = false;
        end
    end
end
for column = find(numeric)
    for row = 1:size(values, 1)
        if strlength(values(row, column)) > 0
            values(row, column) = ...
                numericText(str2double(values(row, column)));
        end
    end
end
end

function value = numericText(number)
value = string(sprintf("%.15g", number));
end

function lines = formatRows(values, widths, numeric, tabs)
lines = strings(size(values, 1), 1);
for row = 1:size(values, 1)
    lines(row) = formatLine(values(row, :), widths, numeric, tabs);
end
end

function line = formatLine(values, widths, numeric, tabs)
parts = strings(1, numel(widths));
for column = 1:numel(widths)
    padding = widths(column) - strlength(values(column));
    if numeric(column)
        parts(column) = repeatText(" ", padding) + values(column);
    else
        parts(column) = values(column) + repeatText(" ", padding);
    end
end
if tabs
    line = join(parts, sprintf("\t"));
else
    line = join(parts, "  ");
end
line = strip(line, "right");
end

function lines = pipeTable(values, headers, widths, numeric, format)
lines = "|" + pipeLine(headers, widths, numeric) + "|";
markers = strings(1, numel(widths));
for column = 1:numel(widths)
    if format == "pipe"
        if numeric(column)
            markers(column) = repeatText("-", ...
                max(1, widths(column) + 1)) + ":";
        else
            markers(column) = ":" + repeatText("-", ...
                max(1, widths(column) + 1));
        end
    else
        markers(column) = repeatText("-", widths(column) + 2);
    end
end
lines(end + 1) = "|" + join(markers, "|") + "|";
for row = 1:size(values, 1)
    lines(end + 1) = "|" + ...
        pipeLine(values(row, :), widths, numeric) + "|"; %#ok<AGROW>
end
end

function line = pipeLine(values, widths, numeric)
parts = strings(1, numel(widths));
for column = 1:numel(widths)
    padding = widths(column) - strlength(values(column));
    if numeric(column)
        parts(column) = " " + repeatText(" ", padding) + ...
            values(column) + " ";
    else
        parts(column) = " " + values(column) + ...
            repeatText(" ", padding) + " ";
    end
end
line = join(parts, "|");
end

function lines = gridTable(values, headers, widths, numeric, format)
if contains(format, "fancy")
    horizontal = "═"; light = "─"; vertical = "│";
    corner = ["╒", "╤", "╕", "╞", "╪", "╡", "╘", "╧", "╛"];
elseif format == "rounded_outline"
    horizontal = "─"; light = "─"; vertical = "│";
    corner = ["╭", "┬", "╮", "├", "┼", "┤", "╰", "┴", "╯"];
else
    horizontal = "="; light = "-"; vertical = "|";
    corner = ["+", "+", "+", "+", "+", "+", "+", "+", "+"];
end
top = border(widths, light, corner(1:3));
middle = border(widths, horizontal, corner(4:6));
bottom = border(widths, light, corner(7:9));
lines = [top; vertical + pipeLine(headers, widths, numeric) + vertical; ...
    middle];
for row = 1:size(values, 1)
    lines(end + 1) = vertical + ...
        pipeLine(values(row, :), widths, numeric) + vertical; %#ok<AGROW>
    if row < size(values, 1) && contains(format, "grid")
        lines(end + 1) = border(widths, light, corner(4:6)); %#ok<AGROW>
    end
end
lines(end + 1) = bottom;
end

function line = border(widths, symbol, corners)
parts = strings(1, numel(widths));
for column = 1:numel(widths)
    parts(column) = repeatText(symbol, widths(column) + 2);
end
line = corners(1) + join(parts, corners(2)) + corners(3);
end

function lines = psqlTable(values, headers, widths, numeric, format)
line = border(widths, "-", ["+", "+", "+"]);
if format == "presto"
    rules = strings(1, numel(widths));
    for column = 1:numel(widths)
        rules(column) = repeatText("-", widths(column) + 2);
    end
    lines = [pipeLine(headers, widths, numeric); ...
        join(rules, "+")];
    for row = 1:size(values, 1)
        lines(end + 1) = pipeLine(values(row, :), widths, numeric); %#ok<AGROW>
    end
else
    lines = [line; "|" + pipeLine(headers, widths, numeric) + "|"; ...
        "|" + extractBetween(line, 2, strlength(line) - 1) + "|"];
    for row = 1:size(values, 1)
        lines(end + 1) = "|" + ...
            pipeLine(values(row, :), widths, numeric) + "|"; %#ok<AGROW>
    end
    lines(end + 1) = line;
end
end

function lines = orgTable(values, headers, widths, numeric, format)
if format == "jira"
    lines = "||" + join(headers, "||") + "||";
    for row = 1:size(values, 1)
        lines(end + 1) = "|" + join(values(row, :), "|") + "|"; %#ok<AGROW>
    end
    return
end
lines = "|" + pipeLine(headers, widths, numeric) + "|";
line = border(widths, "-", ["|", "+", "|"]);
lines(end + 1) = line;
for row = 1:size(values, 1)
    lines(end + 1) = "|" + ...
        pipeLine(values(row, :), widths, numeric) + "|"; %#ok<AGROW>
end
end

function lines = htmlTable(values, headers, widths, numeric)
lines = ["<table>"; "<thead>"];
head = strings(1, numel(headers));
for column = 1:numel(headers)
    value = htmlEscape(padValue(headers(column), widths(column), ...
        numeric(column)));
    if numeric(column)
        head(column) = '<th style="text-align: right;">' + value + "</th>";
    else
        head(column) = "<th>" + value + "</th>";
    end
end
lines(end + 1) = "<tr>" + join(head, "") + "</tr>";
lines(end + 1:end + 2) = ["</thead>"; "<tbody>"];
for row = 1:size(values, 1)
    cells = strings(1, numel(headers));
    for column = 1:numel(headers)
        value = htmlEscape(padValue(values(row, column), ...
            widths(column), numeric(column)));
        if numeric(column)
            cells(column) = '<td style="text-align: right;">' + ...
                value + "</td>";
        else
            cells(column) = "<td>" + value + "</td>";
        end
    end
    lines(end + 1) = "<tr>" + join(cells, "") + "</tr>"; %#ok<AGROW>
end
lines(end + 1:end + 2) = ["</tbody>"; "</table>"];
end

function value = htmlEscape(value)
value = replace(value, "&", "&amp;");
value = replace(value, "<", "&lt;");
value = replace(value, ">", "&gt;");
end

function value = padValue(value, width, numeric)
padding = width - strlength(value);
if numeric
    value = repeatText(" ", padding) + value;
else
    value = value + repeatText(" ", padding);
end
end

function lines = latexTable(values, headers, widths, numeric, format) %#ok<INUSD>
alignmentParts = repmat("l", 1, numel(numeric));
alignmentParts(numeric) = "r";
alignment = join(alignmentParts, "");
environment = "tabular";
if format == "latex_longtable", environment = "longtable"; end
lines = "\begin{" + environment + "}{" + alignment + "}";
if format == "latex_booktabs"
    lines(end + 1) = "\toprule";
else
    lines(end + 1) = "\hline";
end
lines(end + 1) = " " + join(latexEscape(headers, format), " & ") + " \\";
if format == "latex_booktabs"
    lines(end + 1) = "\midrule";
else
    lines(end + 1) = "\hline";
end
for row = 1:size(values, 1)
    lines(end + 1) = " " + ...
        join(latexEscape(values(row, :), format), " & ") + " \\"; %#ok<AGROW>
end
if format == "latex_booktabs"
    lines(end + 1) = "\bottomrule";
else
    lines(end + 1) = "\hline";
end
lines(end + 1) = "\end{" + environment + "}";
end

function value = latexEscape(value, format)
if format == "latex_raw", return; end
value = replace(value, "\", "\textbackslash{}");
for pair = ["&", "\&"; "%", "\%"; "$", "\$"; "#", "\#"; ...
        "_", "\_"; "{", "\{"; "}", "\}"]
    value = replace(value, pair(1), pair(2));
end
end

function lines = mediawikiTable(values, headers, numeric)
lines = "{| class=""wikitable"" style=""text-align: left;""";
for column = 1:numel(headers)
    alignment = "left";
    if numeric(column), alignment = "right"; end
    lines(end + 1) = "|-"; %#ok<AGROW>
    lines(end + 1) = "! style=""text-align: " + alignment + ...
        ";""|" + headers(column); %#ok<AGROW>
end
for row = 1:size(values, 1)
    lines(end + 1) = "|-"; %#ok<AGROW>
    for column = 1:size(values, 2)
        lines(end + 1) = "|" + values(row, column); %#ok<AGROW>
    end
end
lines(end + 1) = "|}";
end

function lines = asciidocTable(values, headers)
lines = ["[cols=""" + join(repmat("1", 1, numel(headers)), ",") + ...
    """, options=""header""]"; "|==="; "|" + join(headers, " |")];
for row = 1:size(values, 1)
    lines(end + 1) = "|" + join(values(row, :), " |"); %#ok<AGROW>
end
lines(end + 1) = "|===";
end

function value = repeatedColumns(widths, symbol, separator)
parts = strings(1, numel(widths));
for column = 1:numel(widths)
    parts(column) = repeatText(symbol, widths(column));
end
value = join(parts, separator);
end

function value = repeatText(symbol, count)
value = string(repmat(char(symbol), 1, double(count)));
end
