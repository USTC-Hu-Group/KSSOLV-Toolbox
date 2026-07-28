function summary = bader_analysis_from_objects( ...
        chgcar, potcar, aeccar0, aeccar2, varargin)
%BADER_ANALYSIS_FROM_OBJECTS Analyze in-memory VASP volumetric objects.
if nargin < 2, potcar = []; end
if nargin < 3, aeccar0 = []; end
if nargin < 4, aeccar2 = []; end
options = parseOptions(struct( ...
    "executor", [], "bader_path", "", ...
    "parse_atomic_densities", false), varargin);
folder = string(tempname);
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, "s"));
chgcarPath = fullfile(folder, "CHGCAR");
chgcar.write_file(chgcarPath);
potcarPath = "";
if ~isempty(potcar)
    potcarPath = fullfile(folder, "POTCAR");
    potcar.write_file(potcarPath);
end
referencePath = "";
if ~isempty(aeccar0) && ~isempty(aeccar2)
    referencePath = fullfile(folder, "CHGCAR_ref");
    reference = aeccar0.linear_add(aeccar2);
    reference.write_file(referencePath);
end
analysis = kssolv.analysis.matgenlab.command_line.bader_caller. ...
    BaderAnalysis(chgcarPath, potcarPath, referencePath, "", ...
    options.bader_path, logical(options.parse_atomic_densities), ...
    executor = options.executor);
summary = analysis.summary;
if chgcar.is_spin_polarized
    magnetic = kssolv.analysis.matgenlab.io.vasp.Chgcar( ...
        chgcar.poscar, struct("total", chgcar.data.diff));
    magneticPath = fullfile(folder, "CHGCAR_mag");
    magnetic.write_file(magneticPath);
    magneticAnalysis = ...
        kssolv.analysis.matgenlab.command_line.bader_caller. ...
        BaderAnalysis(magneticPath, potcarPath, referencePath, "", ...
        options.bader_path, false, executor = options.executor);
    summary.magmom = [magneticAnalysis.data.charge];
end
clear cleanup
end

function options = parseOptions(options, values)
if isempty(values), return; end
if isscalar(values) && isstruct(values{1})
    supplied = values{1};
    names = fieldnames(supplied);
    for index = 1:numel(names)
        options.(names{index}) = supplied.(names{index});
    end
    return
end
if mod(numel(values), 2) ~= 0
    error("KSSOLV:Matgenlab:Bader:Options", ...
        "Optional arguments must be name/value pairs.");
end
for index = 1:2:numel(values)
    name = char(string(values{index}));
    if ~isfield(options, name)
        error("KSSOLV:Matgenlab:Bader:Options", ...
            "Unknown option '%s'.", name);
    end
    options.(name) = values{index + 1};
end
end
