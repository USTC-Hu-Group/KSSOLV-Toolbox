function [status, result] = get_energies(rootdir, reanalyze, verbose, ...
        quick, sortBy, format)
%GET_ENERGIES Recursively assimilate and print VASP run energies.
%
% This is the native MATLAB counterpart of pymatgen.cli.pmg_analyze.
% Assimilated data is cached in vasp_data.gz in the current directory.

if nargin < 2 || isempty(reanalyze), reanalyze = false; end
if nargin < 3 || isempty(verbose), verbose = false; end
if nargin < 4 || isempty(quick), quick = false; end
if nargin < 5 || isempty(sortBy), sortBy = "energy_per_atom"; end
if nargin < 6 || isempty(format), format = "simple"; end
rootdir = validateDirectory(rootdir);
reanalyze = scalarLogical(reanalyze, "reanalyze");
verbose = scalarLogical(verbose, "verbose");
quick = scalarLogical(quick, "quick");
sortBy = string(sortBy);
if ~isscalar(sortBy) || ...
        ~any(sortBy == ["energy_per_atom", "filename", ""])
    error("KSSOLV:Matgenlab:PmgAnalyze:Sort", ...
        "sort must be energy_per_atom or filename.");
end

if quick
    drone = kssolv.analysis.matgenlab.apps.borg. ...
        SimpleVaspToComputedEntryDrone(true);
else
    drone = kssolv.analysis.matgenlab.apps.borg. ...
        VaspToComputedEntryDrone(true, "data", ...
        {"filename", "initial_structure"});
end
queen = kssolv.analysis.matgenlab.apps.borg.BorgQueen(drone);
saveFile = fullfile(pwd, "vasp_data.gz");
if isfile(saveFile) && ~reanalyze
    message = "Using previously assimilated data from vasp_data.gz. " + ...
        "Use -r to force re-analysis.";
    queen.load_data(saveFile);
else
    if verbose
        fprintf("Detected 1 cpus\n");
    end
    queen.serial_assimilate(rootdir);
    message = "Analysis results saved to vasp_data.gz for faster " + ...
        "subsequent loading.";
    queen.save_data(saveFile);
end

entries = queen.get_data();
entries = entries(~cellfun(@isempty, entries));
if sortBy == "energy_per_atom"
    keys = cellfun(@(entry) entry.energy_per_atom, entries);
    [~, order] = sort(keys);
    entries = entries(order);
elseif sortBy == "filename"
    keys = cellfun(@entryFilename, entries);
    [~, order] = sort(keys);
    entries = entries(order);
end

[rows, tableRows] = buildRows(entries, quick, rootdir);
if isempty(rows)
    fprintf("No valid vasp run found.\n");
    if isfile(saveFile), delete(saveFile); end
    tableText = "";
else
    headers = ["Directory", "Formula", "Energy", "E/Atom", "% vol chg"];
    tableText = kssolv.analysis.matgenlab.cli.pmg_analyze. ...
        tabulate_native(tableRows, headers, format);
    fprintf("%s\n\n%s\n", tableText, message);
end
status = 0;
result = struct("rows", rows, "table", tableText, ...
    "message", message, "cache_file", string(saveFile), ...
    "quick", quick);
end

function rootdir = validateDirectory(rootdir)
rootdir = string(rootdir);
if ~isscalar(rootdir) || ismissing(rootdir) || ~isfolder(rootdir)
    error("KSSOLV:Matgenlab:PmgAnalyze:Directory", ...
        "Root directory '%s' does not exist.", rootdir);
end
end

function value = scalarLogical(value, name)
if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
    error("KSSOLV:Matgenlab:PmgAnalyze:Arguments", ...
        "%s must be a logical scalar.", name);
end
value = logical(value);
end

function value = entryFilename(entry)
if isfield(entry.data, "filename")
    value = string(entry.data.filename);
else
    value = "";
end
end

function [rows, tableRows] = buildRows(entries, quick, rootdir)
template = struct("filename", "", "formula", "", "energy", 0, ...
    "energy_per_atom", 0, "volume_change_percent", []);
rows = repmat(template, 1, numel(entries));
tableRows = cell(numel(entries), 5);
for index = 1:numel(entries)
    entry = entries{index};
    filename = displayFilename(entryFilename(entry), rootdir);
    formula = regexprep(string(entry.formula), "\s+", "");
    if quick
        volumeText = "NA";
        volumeChange = [];
    else
        if ~isfield(entry.data, "initial_structure") || ...
                isempty(entry.data.initial_structure)
            error("KSSOLV:Matgenlab:PmgAnalyze:InitialStructure", ...
                "Detailed analysis requires initial_structure data.");
        end
        volumeChange = (entry.structure.volume / ...
            entry.data.initial_structure.volume - 1) * 100;
        volumeText = string(sprintf("%.2f", volumeChange));
    end
    rows(index) = struct("filename", filename, "formula", formula, ...
        "energy", entry.energy, ...
        "energy_per_atom", entry.energy_per_atom, ...
        "volume_change_percent", volumeChange);
    tableRows(index, :) = {filename, formula, ...
        string(sprintf("%.5f", entry.energy)), ...
        string(sprintf("%.5f", entry.energy_per_atom)), volumeText};
end
end

function value = displayFilename(value, rootdir)
value = replace(string(value), "\", "/");
rootdir = replace(string(rootdir), "\", "/");
if ~isAbsolute(rootdir)
    absoluteRoot = replace(string(fullfile(pwd, rootdir)), "\", "/");
    prefix = strip(absoluteRoot, "right", "/") + "/";
    if startsWith(value, prefix)
        value = strip(rootdir, "right", "/") + "/" + ...
            extractAfter(value, strlength(prefix));
    end
end
if startsWith(value, "./"), value = extractAfter(value, 2); end
end

function value = isAbsolute(path)
value = startsWith(path, "/") || ...
    ~isempty(regexp(path, "^[A-Za-z]:/", "once"));
end
