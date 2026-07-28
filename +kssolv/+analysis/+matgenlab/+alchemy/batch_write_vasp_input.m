function batch_write_vasp_input(transformedStructures, vaspInputSet, ...
        outputDir, createDirectory, subfolder, includeCif, varargin)
%BATCH_WRITE_VASP_INPUT Write one VASP input directory per structure.

if nargin < 2 || isempty(vaspInputSet)
    error("KSSOLV:Matgenlab:BatchVaspInput:MissingMPRelaxSet", ...
        "MPRelaxSet is outside the frozen implemented module set. Supply " + ...
        "a VaspInputSet-compatible factory explicitly.");
end
if nargin < 3 || isempty(outputDir), outputDir = "."; end
if nargin < 4, createDirectory = true; end
if nargin < 5, subfolder = []; end
if nargin < 6, includeCif = false; end
if ~iscell(transformedStructures)
    transformedStructures = num2cell(transformedStructures);
end
for index = 1:numel(transformedStructures)
    transformed = transformedStructures{index};
    formula = regexprep(char(transformed.final_structure.formula), '\s+', '');
    if isempty(subfolder)
        directory = fullfile(outputDir, ...
            sprintf("%s_%d", formula, index - 1));
    else
        directory = fullfile(outputDir, ...
            char(string(subfolder(transformed))), ...
            sprintf("%s_%d", formula, index - 1));
    end
    transformed.write_vasp_input(vaspInputSet, directory, ...
        createDirectory, varargin{:});
    if includeCif
        writer = kssolv.analysis.matgenlab.io.cif. ...
            CifWriter(transformed.final_structure);
        writer.write_file(fullfile(directory, formula + ".cif"));
    end
end
end
