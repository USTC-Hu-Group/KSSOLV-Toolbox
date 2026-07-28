function batch_write_input(structures, vasp_input_set, output_dir, varargin)
%BATCH_WRITE_INPUT Write one VASP input directory per structure.
if nargin < 3, output_dir = "."; end
if ~iscell(structures), structures = num2cell(structures); end
for index = 1:numel(structures)
    target = fullfile(string(output_dir), sprintf("%04d", index - 1));
    generator = vasp_input_set;
    generator.structure = structures{index};
    generator.write_input(target, varargin{:});
end
end
