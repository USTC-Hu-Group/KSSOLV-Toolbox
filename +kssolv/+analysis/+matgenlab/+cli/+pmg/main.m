function result = main(argv, handlers)
%MAIN Entry point for the native MATLAB pmg command dispatcher.
if nargin < 1 || isempty(argv)
    fprintf("%s\n", helpText());
    error("KSSOLV:Matgenlab:Pmg:CommandRequired", ...
        "Please specify a command.");
end
if nargin < 2, handlers = struct(); end
if isstruct(argv)
    if isfield(argv, "func") && isa(argv.func, "function_handle")
        result = argv.func(argv);
        return
    end
    error("KSSOLV:Matgenlab:Pmg:Arguments", ...
        "A namespace struct must contain a function handle in func.");
end
tokens = reshape(string(argv), 1, []);
command = lower(tokens(1));
arguments = tokens(2:end);
namespace = parseCommand(command, arguments);
if isfield(handlers, char(command))
    result = handlers.(char(command))(namespace);
    return
end
switch command
    case "config"
        kssolv.analysis.matgenlab.cli.pmg_config.configure_pmg(namespace);
        result = [];
    case "analyze"
        result = kssolv.analysis.matgenlab.cli.pmg_analyze. ...
            analyze(namespace);
    case "plot"
        result = kssolv.analysis.matgenlab.cli.pmg_plot.plot(namespace);
    case "structure"
        result = kssolv.analysis.matgenlab.cli.pmg_structure. ...
            analyze_structures(namespace);
    case "view"
        result = kssolv.analysis.matgenlab.cli.pmg.parse_view(namespace);
    case "diff"
        result = kssolv.analysis.matgenlab.cli.pmg.diff_incar(namespace);
    case "potcar"
        result = kssolv.analysis.matgenlab.cli.pmg_potcar. ...
            generate_potcar(namespace);
    otherwise
        error("KSSOLV:Matgenlab:Pmg:UnknownCommand", ...
            "Unknown pmg command '%s'.", command);
end
end

function args = parseCommand(command, tokens)
args = struct();
switch command
    case "diff"
        values = afterFlag(tokens, ["-i", "--incar"], 2);
        args.incars = cellstr(values);
    case "view"
        positionals = tokens(~startsWith(tokens, "-"));
        if isempty(positionals)
            error("KSSOLV:Matgenlab:Pmg:ViewArguments", ...
                "view requires a structure filename.");
        end
        args.filename = {char(positionals(1))};
        excluded = afterFlag(tokens, ["-e", "--exclude_bonding"], 1, false);
        if ~isempty(excluded), args.exclude_bonding = cellstr(excluded); end
    case "plot"
        args = parsePlot(tokens);
    case "structure"
        args = parseStructure(tokens);
    case "analyze"
        args = parseAnalyze(tokens);
    case "config"
        args = parseConfig(tokens);
    case "potcar"
        args = parsePotcar(tokens);
    otherwise
        error("KSSOLV:Matgenlab:Pmg:UnknownCommand", ...
            "Unknown pmg command '%s'.", command);
end
end

function args = parsePlot(tokens)
args = struct("site", false, "element", [], "orbital", false, ...
    "inds", [], "radius", 3, "out_file", []);
[args, tokens] = scalarPath(args, tokens, ["-d", "--dos"], "dos_file");
[args, tokens] = scalarPath(args, tokens, ["-c", "--chgint"], "chgcar_file");
[args, tokens] = scalarPath(args, tokens, ["-x", "--xrd"], ...
    "xrd_structure_file");
[args, tokens] = scalarPath(args, tokens, "--out_file", "out_file");
[args, tokens] = scalarPath(args, tokens, ["-e", "--element"], "element");
[args, tokens] = scalarPath(args, tokens, ["-i", "--indices"], "inds");
[args, tokens] = numericValue(args, tokens, ["-r", "--radius"], "radius");
args.site = any(tokens == "-s" | tokens == "--site");
args.orbital = any(tokens == "-o" | tokens == "--orbital");
end

function args = parseStructure(tokens)
args = struct("convert", false, "symmetry", [], "group", [], ...
    "localenv", [], "filenames", {{}});
args.convert = any(tokens == "-c" | tokens == "--convert");
group = afterFlag(tokens, ["-g", "--group"], 1, false);
if ~isempty(group), args.group = char(group(1)); end
symmetry = afterFlag(tokens, ["-s", "--symmetry"], 1, false);
if ~isempty(symmetry), args.symmetry = str2double(symmetry(1)); end
localIndex = find(tokens == "-l" | tokens == "--localenv", 1);
if ~isempty(localIndex)
    args.localenv = cellstr(untilFlag(tokens, localIndex + 1));
end
fileIndex = find(tokens == "-f" | tokens == "--filenames", 1);
if ~isempty(fileIndex)
    args.filenames = cellstr(untilFlag(tokens, fileIndex + 1));
end
end

function args = parseAnalyze(tokens)
flags = startsWith(tokens, "-");
args = struct("directories", {cellstr(tokens(~flags))}, ...
    "get_energies", any(tokens == "-e" | tokens == "--energies"), ...
    "reanalyze", any(tokens == "-r" | tokens == "--reanalyze"), ...
    "verbose", any(tokens == "-v" | tokens == "--verbose"), ...
    "quick", any(tokens == "-q" | tokens == "--quick"), ...
    "ion_list", [], "format", "simple", ...
    "sort", "energy_per_atom");
value = afterFlag(tokens, ["-m", "--mag"], 1, false);
if ~isempty(value), args.ion_list = cellstr(value); end
value = afterFlag(tokens, ["-f", "--format"], 1, false);
if ~isempty(value), args.format = char(value); end
value = afterFlag(tokens, ["-s", "--sort"], 1, false);
if ~isempty(value), args.sort = char(value); end
end

function args = parseConfig(tokens)
args = struct("backup", ".bak");
index = find(tokens == "-p" | tokens == "--potcar", 1);
if ~isempty(index), args.potcar_dirs = cellstr(tokens(index + (1:2))); end
index = find(tokens == "--cp2k", 1);
if ~isempty(index), args.cp2k_data_dirs = cellstr(tokens(index + (1:2))); end
value = afterFlag(tokens, ["-i", "--install"], 1, false);
if ~isempty(value), args.install = char(value); end
index = find(tokens == "-a" | tokens == "--add", 1);
if ~isempty(index), args.var_spec = cellstr(tokens(index + 1:end)); end
value = afterFlag(tokens, ["-b", "--backup"], 1, false);
if ~isempty(value), args.backup = char(value); end
end

function args = parsePotcar(tokens)
args = struct("functional", []);
value = afterFlag(tokens, ["-f", "--functional"], 1, false);
if ~isempty(value), args.functional = char(value); end
index = find(tokens == "-s" | tokens == "--symbols", 1);
if ~isempty(index), args.symbols = cellstr(untilFlag(tokens, index + 1)); end
value = afterFlag(tokens, ["-r", "--recursive"], 1, false);
if ~isempty(value), args.recursive = char(value); end
end

function [args, tokens] = scalarPath(args, tokens, flags, field)
index = find(ismember(tokens, flags), 1);
if isempty(index), return; end
if index == numel(tokens)
    error("KSSOLV:Matgenlab:Pmg:MissingValue", ...
        "Option '%s' requires a value.", tokens(index));
end
args.(field) = char(tokens(index + 1));
tokens(index:index + 1) = [];
end

function [args, tokens] = numericValue(args, tokens, flags, field)
[args, tokens] = scalarPath(args, tokens, flags, field);
if ischar(args.(field)), args.(field) = str2double(args.(field)); end
end

function values = afterFlag(tokens, flags, count, required)
if nargin < 4, required = true; end
index = find(ismember(tokens, flags), 1);
if isempty(index) || index + count > numel(tokens)
    if required
        error("KSSOLV:Matgenlab:Pmg:MissingOption", ...
            "Required option '%s' is missing.", flags(end));
    end
    values = strings(1, 0);
    return
end
values = tokens(index + (1:count));
end

function values = untilFlag(tokens, start)
stop = start - 1 + find(startsWith(tokens(start:end), "-"), 1);
if isempty(stop), stop = numel(tokens) + 1; end
values = tokens(start:(stop - 1));
end

function value = helpText()
value = "`pmg` is a convenient script that uses `pymatgen` to perform " + ...
    "many analyses, plotting and format conversions.";
end
