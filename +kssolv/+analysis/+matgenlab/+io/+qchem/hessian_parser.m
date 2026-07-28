function hessian = hessian_parser(filename, nAtoms)
%HESSIAN_PARSER Read the Q-Chem 132.0 Hessian scratch file.
if nargin < 1, filename = "132.0"; end
values = kssolv.analysis.matgenlab.io.qchem.read_binary_doubles(filename);
if nargin < 2 || isempty(nAtoms)
    hessian = values;
    return
end
dimension = 3 * nAtoms;
if numel(values) ~= dimension ^ 2
    error("KSSOLV:Matgenlab:QChem:Hessian", ...
        "Hessian size does not agree with nAtoms.");
end
hessian = reshape(values, dimension, dimension).';
end
