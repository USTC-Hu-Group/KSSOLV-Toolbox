function [status, text] = diff_incar(args)
%DIFF_INCAR Print a tabulated difference between two INCAR files.
if ~isstruct(args) || ~isfield(args, "incars") || ...
        numel(args.incars) ~= 2
    error("KSSOLV:Matgenlab:Pmg:DiffArguments", ...
        "args.incars must contain two INCAR paths.");
end
if iscell(args.incars)
    firstPath = string(args.incars{1});
    secondPath = string(args.incars{2});
else
    paths = string(args.incars);
    firstPath = paths(1);
    secondPath = paths(2);
end
first = kssolv.analysis.matgenlab.io.vasp.Incar.from_file(firstPath);
second = kssolv.analysis.matgenlab.io.vasp.Incar.from_file(secondPath);
difference = first.diff(second);
rows = {"SAME PARAMS", "", ""; "---------------", "", ""};
sameNames = sort(string(fieldnames(difference.Same)));
for name = reshape(sameNames, 1, [])
    if name == "SYSTEM", continue; end
    value = formatLists(difference.Same.(char(name)), name);
    rows(end + 1, :) = {char(name), value, value}; %#ok<AGROW>
end
rows(end + 1:end + 3, :) = { ...
    "", "", ""; "DIFFERENT PARAMS", "", ""; ...
    "----------------", "", ""};
differentNames = sort(string(fieldnames(difference.Different)));
for name = reshape(differentNames, 1, [])
    if name == "SYSTEM", continue; end
    entry = difference.Different.(char(name));
    rows(end + 1, :) = {char(name), ...
        formatLists(entry.INCAR1, name), ...
        formatLists(entry.INCAR2, name)}; %#ok<AGROW>
end
text = kssolv.analysis.matgenlab.cli.pmg_analyze. ...
    tabulate_native(rows, ["", firstPath, secondPath], "simple");
text = text + newline;
printOutput = true;
if isfield(args, "Print"), printOutput = logical(args.Print); end
if printOutput, fprintf("%s", text); end
status = 0;
end

function value = formatLists(input, name)
if isempty(input), value = ""; return; end
if islogical(input)
    if isscalar(input)
        if input, value = "True"; else, value = "False"; end
        return
    end
    input = double(input);
end
if isnumeric(input) && ~isscalar(input)
    input = reshape(input, 1, []);
    starts = [1, find(diff(input) ~= 0) + 1];
    stops = [starts(2:end) - 1, numel(input)];
    pieces = strings(1, numel(starts));
    for index = 1:numel(starts)
        pieces(index) = sprintf("%d*%.2f", ...
            stops(index) - starts(index) + 1, input(starts(index)));
    end
    value = strjoin(pieces, " ");
elseif isnumeric(input)
    floatTags = ["AEXX", "EDIFF", "EDIFFG", "ENCUT", "ENCUTFOCK", ...
        "HFSCREEN", "NUPDOWN", "POTIM", "SIGMA", "TIME"];
    if input == fix(input) && ismember(string(name), floatTags)
        value = string(sprintf("%.1f", input));
    else
        value = string(sprintf("%.15g", input));
    end
else
    value = string(input);
end
end
