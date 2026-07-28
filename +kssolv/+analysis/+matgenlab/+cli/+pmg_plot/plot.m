function ax = plot(args)
%PLOT Dispatch a pymatgen-compatible plot request and optionally save it.

if ~isstruct(args) || ~isscalar(args)
    error("KSSOLV:Matgenlab:PmgPlot:Arguments", ...
        "args must be a scalar struct.");
end
if present(args, "chgcar_file")
    ax = kssolv.analysis.matgenlab.cli.pmg_plot.get_chgint_plot(args);
elseif present(args, "xrd_structure_file")
    ax = kssolv.analysis.matgenlab.cli.pmg_plot.get_xrd_plot(args);
elseif present(args, "dos_file")
    ax = kssolv.analysis.matgenlab.cli.pmg_plot.get_dos_plot(args);
else
    ax = [];
    return
end

if present(args, "out_file")
    output = string(args.out_file);
    if ~isscalar(output) || ismissing(output)
        error("KSSOLV:Matgenlab:PmgPlot:Output", ...
            "out_file must be a scalar path.");
    end
    exportgraphics(ax.Parent, output);
else
    ax.Parent.Visible = "on";
end
end

function value = present(args, name)
value = isfield(args, name) && ~isempty(args.(name));
if value && (ischar(args.(name)) || isstring(args.(name)))
    value = any(strlength(string(args.(name))) > 0, "all");
elseif value && (islogical(args.(name)) || isnumeric(args.(name)))
    value = any(args.(name) ~= 0, "all");
end
end
