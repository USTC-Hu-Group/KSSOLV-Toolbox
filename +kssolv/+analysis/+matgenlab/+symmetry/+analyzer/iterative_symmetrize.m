function result = iterative_symmetrize(molecule, max_n, tolerance, epsilon)
%ITERATIVE_SYMMETRIZE Repeatedly analyze and symmetrize a molecule.
if nargin < 2, max_n = 10; end
if nargin < 3, tolerance = 0.3; end
if nargin < 4, epsilon = 1e-2; end
current = molecule;
result = struct();
for iteration = 1:max_n
    analyzer = ...
        kssolv.analysis.matgenlab.symmetry.analyzer.PointGroupAnalyzer( ...
        current, tolerance);
    result = analyzer.symmetrize_molecule();
    updated = result.sym_mol;
    if all(abs(updated.cart_coords - current.cart_coords) <= epsilon, "all")
        break
    end
    current = updated;
end
end
