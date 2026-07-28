function result = gen_potcar(dirname, filename, varargin)
%GEN_POTCAR Generate POTCAR from one POTCAR.spec file.
%
% Optional name-value boundaries "potcar_factory" and "potcar_writer"
% make licensed resource lookup and file creation explicitly replaceable.

directory = scalarDirectory(dirname);
name = string(filename);
if ~isscalar(name) || ismissing(name)
    error("KSSOLV:Matgenlab:PmgPotcar:Filename", ...
        "filename must be a scalar string.");
end
result = struct("generated", false, "spec_path", "", ...
    "output_path", "", "symbols", strings(1, 0), "functional", "");
if name ~= "POTCAR.spec"
    return
end

options = parseOptions(varargin{:});
specPath = fullfile(directory, name);
if ~isfile(specPath)
    error("KSSOLV:Matgenlab:PmgPotcar:SpecMissing", ...
        "POTCAR specification does not exist: %s", specPath);
end
symbols = strip(splitlines(string(fileread(specPath))));
symbols = reshape(symbols(symbols ~= ""), 1, []);
functional = options.functional;
if functional == ""
    functional = string(kssolv.analysis.matgenlab.core.Settings.get( ...
        "PMG_DEFAULT_FUNCTIONAL", "PBE"));
end
outputPath = fullfile(directory, "POTCAR");
potcar = options.potcar_factory(symbols, functional);
options.potcar_writer(potcar, outputPath);

result.generated = true;
result.spec_path = specPath;
result.output_path = outputPath;
result.symbols = symbols;
result.functional = functional;
end

function options = parseOptions(varargin)
options = struct( ...
    "functional", "", ...
    "potcar_factory", @defaultFactory, ...
    "potcar_writer", @defaultWriter);
if isempty(varargin), return; end
if isscalar(varargin) && isstruct(varargin{1})
    input = varargin{1};
    names = fieldnames(input);
    for index = 1:numel(names)
        options.(names{index}) = input.(names{index});
    end
elseif mod(numel(varargin), 2) == 0
    for index = 1:2:numel(varargin)
        options.(char(string(varargin{index}))) = varargin{index + 1};
    end
else
    error("KSSOLV:Matgenlab:PmgPotcar:Options", ...
        "Options must be a scalar struct or name-value pairs.");
end
options.functional = string(options.functional);
if ~isscalar(options.functional) || ismissing(options.functional)
    error("KSSOLV:Matgenlab:PmgPotcar:Functional", ...
        "functional must be a scalar string.");
end
if ~isa(options.potcar_factory, "function_handle") || ...
        ~isa(options.potcar_writer, "function_handle")
    error("KSSOLV:Matgenlab:PmgPotcar:Boundary", ...
        "potcar_factory and potcar_writer must be function handles.");
end
end

function potcar = defaultFactory(symbols, functional)
potcar = kssolv.analysis.matgenlab.io.vasp.Potcar( ...
    symbols, functional);
end

function defaultWriter(potcar, outputPath)
potcar.write_file(outputPath);
end

function directory = scalarDirectory(value)
directory = string(value);
if ~isscalar(directory) || ismissing(directory) || strlength(directory) == 0
    error("KSSOLV:Matgenlab:PmgPotcar:Path", ...
        "dirname must be a nonempty scalar path.");
end
directory = string(char(java.io.File(char(directory)).getCanonicalPath()));
if ~isfolder(directory)
    error("KSSOLV:Matgenlab:PmgPotcar:DirectoryMissing", ...
        "Directory does not exist: %s", directory);
end
end
