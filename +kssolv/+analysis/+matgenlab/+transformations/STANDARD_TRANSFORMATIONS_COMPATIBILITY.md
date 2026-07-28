# `standard_transformations` compatibility

This directory implements all 43 public inventory rows frozen from
`pymatgen.transformations.standard_transformations` in `pymatgen-core`
2026.7.24: 16 classes, 18 methods, 8 properties, and one function.

The implementation is MATLAB-native. Frozen oracle values cover rotations,
deformations, supercell selection, substitutions, oxidation states, Ewald
ordering, partial removal, occupancy discretization, cell standardization,
charge, perturbation, and relaxed-structure scaling. Official LiFePO4,
TiO2, and surface-relaxation fixtures are vendored in the test package.
Neither production nor tests execute Python.

## Platform boundaries

- Site lists supplied to transformation helpers use MATLAB one-based indices.
- Primitive/conventional standardization uses the repository's compiled
  spglib MEX boundary. No `enum.x`, `makestr.x`, AIRSS, database, or Python
  executable is invoked.
- Enumeration and Ewald ranking are implemented in MATLAB, including unique
  multiset generation and symmetry filtering. Very large ordering problems
  retain the upstream module's inherently combinatorial memory/time cost.
- A supplied random seed is deterministic within MATLAB. MATLAB's MT19937
  stream is not bitwise identical to NumPy's PCG64 stream, so equally valid
  randomly selected site indices can differ across the two languages.
- Structure transformations return new MATLAB value objects and do not mutate
  the caller's structure.
