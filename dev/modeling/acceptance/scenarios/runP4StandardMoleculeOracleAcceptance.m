function report = runP4StandardMoleculeOracleAcceptance(outputDirectory)
%RUNP4STANDARDMOLECULEORACLEACCEPTANCE P4 200-molecule scientific gate.

arguments
    outputDirectory string = ""
end
root = string(workingTreeRoot());
addpath(fullfile(root, "+kssolv", "+core", "kssolv-3o"));
KSSOLV.startup();
if outputDirectory == ""
    stamp = string(datetime("now", "TimeZone", "local", ...
        "Format", "yyyyMMdd-HHmmss"));
    outputDirectory = fullfile(root, "dev", "modeling", ...
        "acceptance", "reports", "p4-standard-molecules-" + stamp);
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end

entries = kssolv.modeling.test.StandardMoleculeOracleCatalog.entries();
rows = repmat(struct("id", "", "family", "", "expectedFormula", "", ...
    "actualFormula", "", "formulaPassed", false, ...
    "expectedHydrogens", 0, "actualHydrogens", 0, ...
    "atomIssueCount", 0, "heavyTopologyPreserved", false, ...
    "hydrogenTopologyPassed", false, "removeRoundTripPassed", false, ...
    "passed", false, "error", ""), numel(entries), 1);
started = tic;
for index = 1:numel(entries)
    entry = entries(index);
    row = rows(index);
    row.id = entry.id;
    row.family = entry.family;
    row.expectedFormula = entry.expectedFormula;
    row.expectedHydrogens = entry.expectedHydrogens;
    try
        heavy = kssolv.modeling.test. ...
            StandardMoleculeOracleCatalog.molecule(entry);
        hydrated = execute(heavy, "add_hydrogens", ...
            struct("indices", 1:heavy.num_sites));
        symbols = siteSymbols(hydrated);
        actualCounts = elementCounts(symbols);
        row.actualFormula = formulaText(actualCounts);
        row.formulaPassed = isequal(actualCounts, entry.expectedCounts);
        row.actualHydrogens = sum(symbols == "H");
        diagnostics = kssolv.modeling.chemistry. ...
            MoleculeDiagnostics.inspect(hydrated);
        row.atomIssueCount = numel(diagnostics.atomIssues);
        heavyBonds = hydrated.properties.topology.bonds;
        heavyBonds = heavyBonds(all( ...
            heavyBonds(:, 1:2) <= heavy.num_sites, 2), :);
        row.heavyTopologyPreserved = isequal( ...
            sortrows(heavyBonds), sortrows(entry.bonds));
        row.hydrogenTopologyPassed = hydrogenTopologyPassed( ...
            hydrated, heavy.num_sites);
        restored = execute(hydrated, "remove_hydrogens", ...
            struct("indices", 1:heavy.num_sites));
        row.removeRoundTripPassed = ...
            isequal(siteSymbols(restored), siteSymbols(heavy)) && ...
            isequal(restored.properties.topology.bonds, ...
            heavy.properties.topology.bonds);
        row.passed = row.formulaPassed && ...
            row.actualHydrogens == row.expectedHydrogens && ...
            row.atomIssueCount == 0 && row.heavyTopologyPreserved && ...
            row.hydrogenTopologyPassed && row.removeRoundTripPassed;
    catch exception
        row.error = string(getReport(exception, "extended", ...
            "hyperlinks", "off"));
    end
    rows(index) = row;
end
families = unique(string({rows.family}));
familySummary = repmat(struct("family", "", "molecules", 0, ...
    "passed", 0), numel(families), 1);
for index = 1:numel(families)
    mask = string({rows.family}) == families(index);
    familySummary(index) = struct("family", families(index), ...
        "molecules", sum(mask), "passed", sum([rows(mask).passed]));
end
report = struct("phase", "P4-standard-molecule-oracle", ...
    "matlabRelease", string(version("-release")), ...
    "platform", string(computer), ...
    "oracle", "closed-form-homologous-series-v1", ...
    "moleculeCount", numel(rows), "familyCount", numel(families), ...
    "passedCount", sum([rows.passed]), ...
    "elapsedSeconds", toc(started), "familySummary", familySummary, ...
    "passed", all([rows.passed]), "outputDirectory", outputDirectory);
writetable(struct2table(rows), fullfile(outputDirectory, ...
    "molecule-results.csv"));
writeText(fullfile(outputDirectory, "report.json"), ...
    jsonencode(report, PrettyPrint = true));
writeText(fullfile(outputDirectory, "README.md"), join([ ...
    "# P4 standard molecule oracle", "", ...
    "Independent closed-form formulae cover 20 chemical families and 200", ...
    "unique molecular graphs. Expected hydrogen counts never call the", ...
    "production target-valence implementation.", "", ...
    "See `molecule-results.csv` for the per-molecule audit."], newline));
if ~report.passed
    failed = string({rows(~[rows.passed]).id});
    error("KSSOLV:Modeling:P4StandardMoleculeOracle", ...
        "Standard molecule oracle failures: %s", strjoin(failed, ", "));
end
end

function model = execute(model, commandId, parameters)
result = kssolv.modeling.CommandExecutor.execute( ...
    model, commandId, parameters);
model = result.model;
end

function symbols = siteSymbols(model)
symbols = strings(1, model.num_sites);
for index = 1:model.num_sites
    symbols(index) = string(model(index).specie.symbol);
end
end

function counts = elementCounts(symbols)
fields = ["C", "H", "N", "O", "S", "F", "Cl", "Br"];
counts = cell2struct(num2cell(zeros(1, numel(fields))), ...
    cellstr(fields), 2);
for symbol = symbols
    counts.(symbol) = counts.(symbol) + 1;
end
end

function value = formulaText(counts)
order = ["C", "H", "Br", "Cl", "F", "N", "O", "S"];
value = "";
for symbol = order
    count = counts.(symbol);
    if count == 0, continue, end
    value = value + symbol;
    if count ~= 1, value = value + string(count); end
end
end

function passed = hydrogenTopologyPassed(model, heavyCount)
bonds = model.properties.topology.bonds;
passed = true;
for hydrogen = heavyCount + 1:model.num_sites
    connected = bonds(any(bonds(:, 1:2) == hydrogen, 2), :);
    passed = passed && size(connected, 1) == 1 && connected(3) == 1;
end
end

function writeText(path, value)
file = fopen(path, "w", "n", "UTF-8");
if file < 0
    error("KSSOLV:Modeling:AcceptanceWrite", ...
        "Unable to create '%s'.", path);
end
cleanup = onCleanup(@()fclose(file));
fwrite(file, char(value), "char");
clear cleanup
end
