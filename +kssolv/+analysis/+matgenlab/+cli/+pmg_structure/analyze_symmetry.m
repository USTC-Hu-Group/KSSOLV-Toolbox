function rows = analyze_symmetry(args)
%ANALYZE_SYMMETRY Print crystallographic symmetry for structure files.

args = validateArgs(args, "symmetry");
filenames = normalizeFilenames(args.filenames);
tolerance = double(args.symmetry);
if ~isscalar(tolerance) || ~isfinite(tolerance) || tolerance <= 0
    error("KSSOLV:Matgenlab:PmgStructure:SymmetryTolerance", ...
        "symmetry must be a finite positive scalar.");
end

rows = repmat(struct("filename", "", "international", "", ...
    "number", 0, "hall", ""), 1, numel(filenames));
tableRows = cell(numel(filenames), 4);
for index = 1:numel(filenames)
    structure = readStructure(filenames(index));
    analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
        SpacegroupAnalyzer(structure, tolerance);
    dataset = analyzer.get_symmetry_dataset();
    rows(index) = struct("filename", filenames(index), ...
        "international", dataset.international, ...
        "number", dataset.number, "hall", dataset.hall);
    tableRows(index, :) = {filenames(index), dataset.international, ...
        dataset.number, dataset.hall};
end
fprintf("%s\n", simpleTable( ...
    ["Filename", "Int Symbol", "Int number", "Hall"], tableRows, 3));
end

function args = validateArgs(args, required)
if ~isstruct(args) || ~isscalar(args) || ...
        ~isfield(args, "filenames") || ~isfield(args, required)
    error("KSSOLV:Matgenlab:PmgStructure:Arguments", ...
        "args must contain filenames and %s.", required);
end
end

function filenames = normalizeFilenames(value)
filenames = reshape(string(value), 1, []);
if any(ismissing(filenames) | strlength(filenames) == 0)
    error("KSSOLV:Matgenlab:PmgStructure:Filename", ...
        "filenames must contain nonempty paths.");
end
end

function structure = readStructure(filename)
warningState = warning;
cleanup = onCleanup(@() warning(warningState));
warning("off", "all");
structure = kssolv.analysis.matgenlab.core.Structure.from_file( ...
    filename, "", "primitive", false);
clear cleanup
end

function text = simpleTable(headers, rows, numericColumns)
numberRows = size(rows, 1);
numberColumns = numel(headers);
values = strings(numberRows, numberColumns);
for row = 1:numberRows
    for column = 1:numberColumns
        if isnumeric(rows{row, column})
            values(row, column) = string(sprintf("%.15g", rows{row, column}));
        else
            values(row, column) = string(rows{row, column});
        end
    end
end
widths = strlength(headers) + 2;
if numberRows > 0
    widths = max(widths, max(strlength(values), [], 1));
end
lines = strings(numberRows + 2, 1);
lines(1) = renderRow(headers, widths, numericColumns);
lines(2) = strjoin(arrayfun(@(width) repmat('-', 1, width), ...
    widths, "UniformOutput", false), "  ");
for row = 1:numberRows
    lines(row + 2) = renderRow(values(row, :), widths, numericColumns);
end
text = strjoin(lines, newline);
end

function line = renderRow(values, widths, numericColumns)
pieces = strings(1, numel(values));
for column = 1:numel(values)
    value = char(values(column));
    padding = string(repmat(' ', 1, ...
        widths(column) - strlength(values(column))));
    if ismember(column, numericColumns)
        pieces(column) = padding + string(value);
    else
        pieces(column) = string(value) + padding;
    end
end
line = strjoin(pieces, "  ");
line = strip(line, "right");
end
