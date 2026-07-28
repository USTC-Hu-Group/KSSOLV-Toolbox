function [status, result] = analyze(args)
%ANALYZE Dispatch the pmg analyze command from an argparse-like struct.

if ~isstruct(args) || ~isscalar(args)
    error("KSSOLV:Matgenlab:PmgAnalyze:Arguments", ...
        "args must be a scalar struct.");
end
directories = fieldOr(args, "directories", ".");
directories = reshape(string(directories), 1, []);
if isempty(directories), directories = "."; end
getEnergies = logicalScalar(fieldOr(args, "get_energies", false), ...
    "get_energies");
ionListArgument = fieldOr(args, "ion_list", []);
defaultEnergies = ~getEnergies && isempty(ionListArgument);

if getEnergies || defaultEnergies
    [status, result] = kssolv.analysis.matgenlab.cli.pmg_analyze. ...
        get_energies(directories(1), ...
        fieldOr(args, "reanalyze", false), ...
        fieldOr(args, "verbose", false), ...
        fieldOr(args, "quick", false), ...
        fieldOr(args, "sort", "energy_per_atom"), ...
        fieldOr(args, "format", "simple"));
    return
end

if ~isempty(ionListArgument)
    specification = string(ionListArgument);
    specification = specification(1);
    if specification == "All"
        error("KSSOLV:Matgenlab:PmgAnalyze:AllIonList", ...
            "ion_list is None");
    end
    tokens = regexp(specification, "^(-?\d+)-(-?\d+)$", ...
        "tokens", "once");
    if isempty(tokens)
        error("KSSOLV:Matgenlab:PmgAnalyze:IonRange", ...
            "ion_list must be All or an inclusive START-END range.");
    end
    first = str2double(tokens{1});
    last = str2double(tokens{2});
    ionList = first:last;
    [status, result] = kssolv.analysis.matgenlab.cli.pmg_analyze. ...
        get_magnetizations(directories(1), ionList);
    return
end
status = -1;
result = [];
end

function value = fieldOr(args, name, default)
if isfield(args, name)
    value = args.(name);
else
    value = default;
end
end

function value = logicalScalar(value, name)
if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
    error("KSSOLV:Matgenlab:PmgAnalyze:Arguments", ...
        "%s must be a logical scalar.", name);
end
value = logical(value);
end
