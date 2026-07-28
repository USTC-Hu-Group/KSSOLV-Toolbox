function result = generate_potcar(args)
%GENERATE_POTCAR Dispatch recursive or symbol-based POTCAR generation.
%
% Unlike the Python CLI wrapper, symbol mode requires args.output so this
% library function never writes to an implicit current working directory.

if ~isstruct(args) || ~isscalar(args)
    error("KSSOLV:Matgenlab:PmgPotcar:Arguments", ...
        "args must be a scalar struct.");
end
functional = argument(args, "functional", "");
if isempty(functional) || strlength(string(functional)) == 0
    functional = kssolv.analysis.matgenlab.core.Settings.get( ...
        "PMG_DEFAULT_FUNCTIONAL", "PBE");
end
functional = string(functional);
if ~isscalar(functional) || ismissing(functional)
    error("KSSOLV:Matgenlab:PmgPotcar:Functional", ...
        "functional must be a scalar string.");
end

factory = argument(args, "potcar_factory", @defaultFactory);
writer = argument(args, "potcar_writer", @defaultWriter);
validateBoundary(factory, writer);
recursive = argument(args, "recursive", "");
symbols = argument(args, "symbols", strings(1, 0));

if present(recursive)
    root = string(recursive);
    if ~isscalar(root) || ismissing(root)
        error("KSSOLV:Matgenlab:PmgPotcar:Recursive", ...
            "recursive must be a scalar directory path.");
    end
    callback = @(directory, filename) ...
        kssolv.analysis.matgenlab.cli.pmg_potcar.gen_potcar( ...
            directory, filename, "potcar_factory", factory, ...
            "potcar_writer", writer);
    visited = kssolv.analysis.matgenlab.cli.pmg_potcar.proc_dir( ...
        root, callback);
    result = struct("mode", "recursive", "success", true, ...
        "functional", functional, "visited", visited, ...
        "output_path", "");
elseif present(symbols)
    if ~isfield(args, "output") || ~present(args.output)
        error("KSSOLV:Matgenlab:PmgPotcar:OutputRequired", ...
            "Symbol mode requires an explicit args.output path.");
    end
    outputPath = scalarOutput(args.output);
    result = struct("mode", "symbols", "success", false, ...
        "functional", functional, "visited", strings(1, 0), ...
        "output_path", outputPath);
    try
        validateFunctional(functional);
        normalizedSymbols = reshape(string(symbols), 1, []);
        normalizedSymbols = strip(normalizedSymbols);
        normalizedSymbols = normalizedSymbols(normalizedSymbols ~= "");
        potcar = factory(normalizedSymbols, functional);
        writer(potcar, outputPath);
        result.success = true;
        result.symbols = normalizedSymbols;
    catch exception
        fprintf("An error has occurred: %s\n", exception.message);
        result.error = string(exception.message);
    end
else
    fprintf("No valid options selected.\n");
    result = struct("mode", "none", "success", false, ...
        "functional", functional, "visited", strings(1, 0), ...
        "output_path", "");
end
end

function value = argument(args, name, defaultValue)
if isfield(args, name), value = args.(name);
else, value = defaultValue;
end
end

function value = present(input)
value = ~isempty(input);
if value && (ischar(input) || isstring(input))
    value = any(strlength(string(input)) > 0, "all");
elseif value && (islogical(input) || isnumeric(input))
    value = any(input ~= 0, "all");
end
end

function validateBoundary(factory, writer)
if ~isa(factory, "function_handle") || ~isa(writer, "function_handle")
    error("KSSOLV:Matgenlab:PmgPotcar:Boundary", ...
        "potcar_factory and potcar_writer must be function handles.");
end
end

function validateFunctional(functional)
choices = ["LDA", "LDA_52", "LDA_52_W_HASH", "LDA_54", ...
    "LDA_54_W_HASH", "LDA_64", "LDA_US", "PBE", "PBE_52", ...
    "PBE_52_W_HASH", "PBE_54", "PBE_54_W_HASH", "PBE_64", ...
    "PW91", "PW91_US", "Perdew_Zunger81"];
if ~any(functional == choices)
    rendered = "'" + strjoin(sort(choices), "', '") + "'";
    error("KSSOLV:Matgenlab:PmgPotcar:Functional", ...
        "Invalid functional '%s'. Choose from: [%s]", ...
        functional, rendered);
end
end

function outputPath = scalarOutput(input)
outputPath = string(input);
if ~isscalar(outputPath) || ismissing(outputPath) || ...
        strlength(outputPath) == 0
    error("KSSOLV:Matgenlab:PmgPotcar:Output", ...
        "output must be a nonempty scalar path.");
end
outputPath = string(char(java.io.File(char(outputPath)).getCanonicalPath()));
parent = string(fileparts(outputPath));
if parent == "", parent = string(pwd); end
if ~isfolder(parent)
    error("KSSOLV:Matgenlab:PmgPotcar:OutputDirectory", ...
        "Output directory does not exist: %s", parent);
end
if isfolder(outputPath)
    error("KSSOLV:Matgenlab:PmgPotcar:OutputDirectory", ...
        "Output path names a directory: %s", outputPath);
end
end

function potcar = defaultFactory(symbols, functional)
potcar = kssolv.analysis.matgenlab.io.vasp.Potcar( ...
    symbols, functional);
end

function defaultWriter(potcar, outputPath)
potcar.write_file(outputPath);
end
