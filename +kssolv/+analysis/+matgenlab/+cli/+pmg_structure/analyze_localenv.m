function result = analyze_localenv(args)
%ANALYZE_LOCALENV Print requested center-ligand neighbor distances.

args = validateArgs(args);
filenames = normalizeStrings(args.filenames, "filenames");
bondSpecs = normalizeStrings(args.localenv, "localenv");
bonds = parseBonds(bondSpecs);
result = repmat(struct("filename", "", "rows", []), 1, numel(filenames));

for fileIndex = 1:numel(filenames)
    filename = filenames(fileIndex);
    fprintf("Analyzing %s...\n", filename);
    structure = readStructure(filename);
    data = repmat(struct("index", 0, "center", "", "ligand", "", ...
        "distances", zeros(1, 0)), 1, 0);
    tableRows = cell(0, 4);
    for siteIndex = 1:structure.num_sites
        site = structure.sites{siteIndex};
        centerSymbols = siteSymbols(site);
        for bondIndex = 1:numel(bonds)
            bond = bonds(bondIndex);
            if ~any(centerSymbols == bond.center)
                continue
            end
            if bond.distance < 0
                neighbors = cell(1, 0);
            else
                neighbors = structure.get_neighbors(site, bond.distance);
            end
            distances = zeros(1, 0);
            for neighborIndex = 1:numel(neighbors)
                if any(siteSymbols(neighbors{neighborIndex}) == bond.ligand)
                    neighbor = neighbors{neighborIndex};
                    distances(end + 1) = neighbor.nn_distance; %#ok<AGROW>
                end
            end
            distances = sort(distances);
            if isempty(distances)
                formatted = "";
            else
                formatted = strjoin(string(arrayfun( ...
                    @(value) sprintf("%.3f", value), distances, ...
                    "UniformOutput", false)), ", ");
            end
            entry = struct("index", siteIndex - 1, ...
                "center", bond.center, "ligand", bond.ligand, ...
                "distances", distances);
            data(end + 1) = entry; %#ok<AGROW>
            row = {siteIndex - 1, bond.center, bond.ligand, formatted};
            tableRows(end + 1, :) = row; %#ok<AGROW>
        end
    end
    fprintf("%s\n", simpleTable( ...
        ["#", "Center", "Ligand", "Dists"], tableRows, 1));
    result(fileIndex) = struct("filename", filename, "rows", data);
end
end

function args = validateArgs(args)
if ~isstruct(args) || ~isscalar(args) || ...
        ~isfield(args, "filenames") || ~isfield(args, "localenv")
    error("KSSOLV:Matgenlab:PmgStructure:Arguments", ...
        "args must contain filenames and localenv.");
end
end

function values = normalizeStrings(value, name)
values = reshape(string(value), 1, []);
if any(ismissing(values) | strlength(values) == 0)
    error("KSSOLV:Matgenlab:PmgStructure:Arguments", ...
        "%s must contain nonempty strings.", name);
end
end

function bonds = parseBonds(specifications)
bonds = repmat(struct("center", "", "ligand", "", "distance", 0), ...
    1, numel(specifications));
numberBonds = 0;
for index = 1:numel(specifications)
    tokens = split(specifications(index), "=");
    if numel(tokens) < 2
        error("KSSOLV:Matgenlab:PmgStructure:LocalEnvironment", ...
            "Invalid bond specification '%s'; expected Center-Ligand=radius.", ...
            specifications(index));
    end
    species = split(tokens(1), "-");
    radius = str2double(tokens(2));
    if numel(species) < 2 || any(strlength(species(1:2)) == 0) || ...
            ~isscalar(radius) || ~isfinite(radius)
        error("KSSOLV:Matgenlab:PmgStructure:LocalEnvironment", ...
            "Invalid bond specification '%s'; expected Center-Ligand=radius.", ...
            specifications(index));
    end
    existing = find(arrayfun(@(bond) ...
        bond.center == species(1) && bond.ligand == species(2), ...
        bonds(1:numberBonds)), 1);
    if isempty(existing)
        numberBonds = numberBonds + 1;
        existing = numberBonds;
    end
    bonds(existing) = struct("center", species(1), ...
        "ligand", species(2), "distance", radius);
end
bonds = bonds(1:numberBonds);
end

function symbols = siteSymbols(site)
[species, ~] = site.species.items();
symbols = cellfun(@(item) item.symbol, species);
symbols = reshape(string(symbols), 1, []);
end

function structure = readStructure(filename)
warningState = warning;
cleanup = onCleanup(@() warning(warningState));
warning("off", "all");
structure = kssolv.analysis.matgenlab.core.Structure.from_file(filename);
clear cleanup
end

function text = simpleTable(headers, rows, numericColumns)
numberRows = size(rows, 1);
values = strings(numberRows, numel(headers));
for row = 1:numberRows
    for column = 1:numel(headers)
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
    padding = string(repmat(' ', 1, ...
        widths(column) - strlength(values(column))));
    if ismember(column, numericColumns)
        pieces(column) = padding + values(column);
    else
        pieces(column) = values(column) + padding;
    end
end
line = strip(strjoin(pieces, "  "), "right");
end
