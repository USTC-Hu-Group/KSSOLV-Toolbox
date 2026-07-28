function coefficients = orbital_coeffs_parser(filename)
%ORBITAL_COEFFS_PARSER Read the Q-Chem 53.0 orbital coefficient scratch file.
if nargin < 1, filename = "53.0"; end
coefficients = kssolv.analysis.matgenlab.io.qchem.read_binary_doubles(filename);
end
