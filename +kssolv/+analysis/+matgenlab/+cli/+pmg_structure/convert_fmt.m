function result = convert_fmt(args)
%CONVERT_FMT Convert a structure file to another supported format.
%
% This is the MATLAB counterpart of pymatgen.cli.pmg_structure.convert_fmt.
% ARGS is a scalar struct with a filenames field containing input and output
% paths.  As in pymatgen, an output name containing "prim" requests a
% primitive structure.

args = validateArgs(args);
filenames = normalizeFilenames(args.filenames);
if numel(filenames) ~= 2
    fprintf("File format conversion takes in only two filenames.\n");
end
if numel(filenames) < 2
    error("KSSOLV:Matgenlab:PmgStructure:FilenameCount", ...
        "File format conversion requires input and output filenames.");
end

inputFilename = filenames(1);
outputFilename = filenames(2);
primitive = contains(lower(outputFilename), "prim");
structure = readStructure(inputFilename, primitive);
format = inferOutputFormat(outputFilename);
structure.to(outputFilename, format);
result = struct("input", inputFilename, "output", outputFilename, ...
    "format", format, "primitive", primitive, "structure", structure);
end

function args = validateArgs(args)
if ~isstruct(args) || ~isscalar(args) || ~isfield(args, "filenames")
    error("KSSOLV:Matgenlab:PmgStructure:Arguments", ...
        "args must be a scalar struct containing filenames.");
end
end

function filenames = normalizeFilenames(value)
filenames = reshape(string(value), 1, []);
if any(ismissing(filenames) | strlength(filenames) == 0)
    error("KSSOLV:Matgenlab:PmgStructure:Filename", ...
        "filenames must contain nonempty paths.");
end
end

function structure = readStructure(filename, primitive)
warningState = warning;
cleanup = onCleanup(@() warning(warningState));
warning("off", "all");
structure = kssolv.analysis.matgenlab.core.Structure.from_file( ...
    filename, "", "primitive", primitive);
clear cleanup
end

function format = inferOutputFormat(filename)
[~, name, extension] = fileparts(filename);
extension = lower(string(extension));
name = upper(string(name));
if any(name == ["POSCAR", "CONTCAR"]) || ...
        startsWith(name, "POSCAR_") || startsWith(name, "CONTCAR_") || ...
        strlength(extension) == 0
    format = "poscar";
else
    format = erase(extension, ".");
end
end
