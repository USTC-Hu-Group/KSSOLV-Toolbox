function ax = get_dos_plot(args)
%GET_DOS_PLOT Plot a total or projected DOS from a vasprun.xml file.

args = requireScalarStruct(args);
filename = requirePath(args, "dos_file");
run = kssolv.analysis.matgenlab.io.vasp.Vasprun(filename);
dos = run.complete_dos;
doses = containers.Map("KeyType", "char", "ValueType", "any");
doses("Total") = dos;

if truthy(args, "site")
    for index = 1:run.final_structure.num_sites
        site = run.final_structure(index);
        label = sprintf("Site %d %s", index - 1, site.specie.symbol);
        doses(label) = dos.get_site_dos(index);
    end
end
if present(args, "element")
    symbols = split(string(firstValue(args.element)), ",");
    symbols = strip(symbols);
    selected = containers.Map("KeyType", "char", "ValueType", "any");
    elementDos = dos.get_element_dos();
    keys = elementDos.keys;
    for index = 1:numel(keys)
        if any(symbols == string(keys{index}))
            selected(keys{index}) = elementDos(keys{index});
        end
    end
    doses = selected;
end
if truthy(args, "orbital")
    doses = dos.get_spd_dos();
end

plotter = kssolv.analysis.matgenlab.electronic_structure.DosPlotter();
plotter.add_dos_dict(doses);
ax = plotter.get_plot();
ax.UserData = struct("kind", "dos", "labels", string(doses.keys), ...
    "dos", doses, "source", filename);
end

function args = requireScalarStruct(args)
if ~isstruct(args) || ~isscalar(args)
    error("KSSOLV:Matgenlab:PmgPlot:Arguments", ...
        "args must be a scalar struct.");
end
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

function value = truthy(args, name)
value = present(args, name);
if value && (isnumeric(args.(name)) || islogical(args.(name)))
    value = any(args.(name) ~= 0, "all");
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
