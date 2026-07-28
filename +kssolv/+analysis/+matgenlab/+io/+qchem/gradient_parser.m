function gradient = gradient_parser(filename)
%GRADIENT_PARSER Read the Q-Chem 131.0 gradient scratch file.
if nargin < 1, filename = "131.0"; end
values = kssolv.analysis.matgenlab.io.qchem.read_binary_doubles(filename);
if mod(numel(values), 3) ~= 0
    error("KSSOLV:Matgenlab:QChem:Gradient", ...
        "Gradient scratch data must contain a multiple of three doubles.");
end
gradient = reshape(values, 3, []).';
end
