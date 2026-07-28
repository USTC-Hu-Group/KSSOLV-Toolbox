function [status, result] = get_magnetizations(directory, ionList)
%GET_MAGNETIZATIONS Print selected site magnetizations from OUTCAR files.
%
% IONLIST follows pymatgen's zero-based CLI indices.  An empty list selects
% every ion.  Invalid OUTCARs and selections are skipped, as upstream does.

directory = string(directory);
if ~isscalar(directory) || ismissing(directory) || ~isfolder(directory)
    error("KSSOLV:Matgenlab:PmgAnalyze:Directory", ...
        "Directory '%s' does not exist.", directory);
end
if nargin < 2 || isempty(ionList)
    ionList = [];
else
    ionList = double(reshape(ionList, 1, []));
    if any(~isfinite(ionList) | ionList < 0 | ionList ~= fix(ionList))
        error("KSSOLV:Matgenlab:PmgAnalyze:IonList", ...
            "ion_list must contain nonnegative integer indices.");
    end
end

files = recursiveOutcars(directory);
data = cell(0, 1);
records = struct("filename", {}, "ion_indices", {}, ...
    "magnetizations", {});
maxRow = 0;
for filename = files
    try
        outcar = kssolv.analysis.matgenlab.io.vasp.Outcar(filename);
        magnetizations = cellfun(@(row) row.tot, ...
            outcar.magnetization);
        allIons = 0:numel(magnetizations) - 1;
        if ~isempty(ionList), allIons = ionList; end
        selected = magnetizations(allIons + 1);
        displayed = displayFilename(filename, directory);
        row = [{displayed}, ...
            arrayfun(@signedNumericText, selected, ...
            "UniformOutput", false)];
        data(end + 1, 1:numel(row)) = row; %#ok<AGROW>
        maxRow = max(maxRow, numel(allIons));
        records(end + 1) = struct( ...
            "filename", displayed, ...
            "ion_indices", allIons, ...
            "magnetizations", reshape(selected, 1, [])); %#ok<AGROW>
    catch
        % pymatgen deliberately ignores malformed OUTCAR files and
        % out-of-range ion selections while walking a calculation tree.
    end
end
if size(data, 2) < maxRow + 1
    data(:, end + 1:maxRow + 1) = {""};
end
headers = ["Filename", string(0:maxRow - 1)];
tableText = kssolv.analysis.matgenlab.cli.pmg_analyze. ...
    tabulate_native(data, headers, "simple");
fprintf("%s\n", tableText);
status = 0;
result = struct("rows", records, "table", tableText);
end

function files = recursiveOutcars(directory)
listing = dir(fullfile(directory, "**", "OUTCAR*"));
listing = listing(~[listing.isdir]);
if isempty(listing)
    direct = dir(fullfile(directory, "OUTCAR*"));
    direct = direct(~[direct.isdir]);
    listing = direct;
end
if isempty(listing)
    files = strings(1, 0);
    return
end
names = string({listing.name});
keep = ~cellfun(@isempty, regexp(cellstr(names), "^OUTCAR*", "once"));
files = sort(string(fullfile({listing(keep).folder}, ...
    {listing(keep).name})));
end

function value = signedNumericText(number)
value = char(sprintf("%.15g", number));
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
