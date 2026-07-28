function output = standardize_structure(structure, sym_prec, international_monoclinic)
%STANDARDIZE_STRUCTURE Convert to a primitive standard structure.
if nargin < 2, sym_prec = 0.1; end
if nargin < 3, international_monoclinic = true; end
analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
    SpacegroupAnalyzer(structure, sym_prec);
output = analyzer.get_primitive_standard_structure( ...
    international_monoclinic);
end
