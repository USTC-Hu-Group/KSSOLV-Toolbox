function ax = get_xrd_plot(args)
%GET_XRD_PLOT Plot the Cu K-alpha powder pattern of a structure file.

if ~isstruct(args) || ~isscalar(args) || ...
        ~isfield(args, "xrd_structure_file")
    error("KSSOLV:Matgenlab:PmgPlot:Arguments", ...
        "args must be a scalar struct containing xrd_structure_file.");
end
filename = string(args.xrd_structure_file);
if ~isscalar(filename) || ismissing(filename) || strlength(filename) == 0
    error("KSSOLV:Matgenlab:PmgPlot:Filename", ...
        "xrd_structure_file must be a nonempty path.");
end
format = inferFormat(filename);
structure = kssolv.analysis.matgenlab.core.Structure.from_file( ...
    filename, format);
calculator = kssolv.analysis.matgenlab.analysis.XRDCalculator();
figureHandle = figure("Visible", "off");
ax = axes(figureHandle);
calculator.get_plot(structure, "ax", ax);
pattern = calculator.get_pattern(structure, true, [0, 90]);
ax.UserData = struct("kind", "xrd", "pattern", pattern, ...
    "source", filename);
end

function format = inferFormat(filename)
[~, name, extension] = fileparts(filename);
if startsWith(upper(string(name)), "POSCAR") || ...
        startsWith(upper(string(name)), "CONTCAR")
    format = "poscar";
else
    format = erase(lower(string(extension)), ".");
end
end
