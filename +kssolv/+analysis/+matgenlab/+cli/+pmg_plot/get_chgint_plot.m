function ax = get_chgint_plot(args, ax)
%GET_CHGINT_PLOT Plot integrated spin charge from a CHGCAR file.

if nargin < 2, ax = []; end
if ~isstruct(args) || ~isscalar(args)
    error("KSSOLV:Matgenlab:PmgPlot:Arguments", ...
        "args must be a scalar struct.");
end
filename = requirePath(args, "chgcar_file");
if ~isfield(args, "radius")
    error("KSSOLV:Matgenlab:PmgPlot:Arguments", ...
        "args must contain radius.");
end
radius = double(args.radius);
validateattributes(radius, {'numeric'}, ...
    {'scalar','real','finite','nonnegative'});
chgcar = kssolv.analysis.matgenlab.io.vasp.Chgcar.from_file(filename);
structure = chgcar.structure;

if present(args, "inds")
    tokens = split(string(firstValue(args.inds)), ",");
    pythonIndices = str2double(strip(tokens));
    if any(isnan(pythonIndices)) || any(pythonIndices ~= fix(pythonIndices)) || ...
            any(pythonIndices < 0) || any(pythonIndices >= structure.num_sites)
        error("KSSOLV:Matgenlab:PmgPlot:Indices", ...
            "inds must contain valid comma-separated zero-based atom indices.");
    end
    atomIndices = reshape(pythonIndices + 1, 1, []);
else
    analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
        SpacegroupAnalyzer(structure, 0.1);
    symmetrized = analyzer.get_symmetrized_structure();
    atomIndices = cellfun(@(indices) indices(1), ...
        symmetrized.equivalent_indices);
end

if isempty(ax)
    figureHandle = figure("Visible", "off", ...
        "Position", [100, 100, 1200, 800]);
    ax = axes(figureHandle);
elseif ~isgraphics(ax, "axes")
    error("KSSOLV:Matgenlab:PmgPlot:Axes", ...
        "ax must be a MATLAB axes object.");
end
holdState = ishold(ax);
hold(ax, "on");
curves = cell(1, numel(atomIndices));
labels = strings(1, numel(atomIndices));
for index = 1:numel(atomIndices)
    siteIndex = atomIndices(index);
    curve = chgcar.get_integrated_diff(siteIndex, radius, 30);
    curves{index} = curve;
    labels(index) = sprintf("Atom %d - %s", ...
        siteIndex - 1, structure(siteIndex).species_string);
    plot(ax, curve(:, 1), curve(:, 2), ...
        "DisplayName", labels(index));
end
if ~holdState, hold(ax, "off"); end
legend(ax, "show", "Location", "northwest");
xlabel(ax, "Radius (A)");
ylabel(ax, "Integrated charge (e)");
ax.UserData = struct("kind", "chgint", ...
    "atom_indices", atomIndices - 1, "curves", {curves}, ...
    "labels", labels, "source", filename);
end

function filename = requirePath(args, name)
if ~isfield(args, name)
    error("KSSOLV:Matgenlab:PmgPlot:Arguments", ...
        "args must contain %s.", name);
end
filename = string(args.(name));
if ~isscalar(filename) || ismissing(filename) || strlength(filename) == 0
    error("KSSOLV:Matgenlab:PmgPlot:Filename", ...
        "%s must be a nonempty path.", name);
end
end

function value = present(args, name)
value = isfield(args, name) && ~isempty(args.(name));
if value && (ischar(args.(name)) || isstring(args.(name)))
    value = any(strlength(string(args.(name))) > 0, "all");
end
end

function value = firstValue(input)
if ischar(input), value = input;
elseif iscell(input), value = input{1};
else, value = input(1);
end
end
