# JDFTx I/O compatibility package

This package implements the frozen `pymatgen.io.jdftx` API inventory from
`pymatgen-core` `v2026.7.24` in pure MATLAB. All 158 frozen entries are
implemented: 27 classes, 19 functions, 96 methods, and 16 properties.

The implementation includes:

- typed scalar, numeric, container, repeatable, dump, and multiformat tag
  codecs;
- `JDFTXInfile` parsing, include expansion, validation, comparison,
  structure conversion, deterministic writing, and MSON-style
  serialization;
- ordered `JDFTXStructure`, optimization-step, trajectory, electronic-step,
  outfile-slice, and appended-outfile models;
- parsing of energies, eigStats, lattices, coordinates, forces, spin,
  smearing, cutoffs, FFT/k-point grids, minimizer state, convergence,
  solvation, magnetization, and vibrational summaries;
- complex or normalized `bandProjections`, binary `eigenvals`, k-point
  metadata, and aggregate calculation-directory loading;
- MATLAB-native SCF and band plotting;
- input-set writing and the frozen upstream `BaseJdftxSet.yaml`.

JDFTx lattice/coordinate and Hartree quantities use the same frozen pymatgen
conversion constants. Python-style search/index helper results retain
zero-based positions; MATLAB array access remains one-based.

`JDFTXRunner` is the only executable boundary and refuses to launch a process
unless `allow_external=true` is passed explicitly. Production parsing,
modeling, serialization, binary reading, and plotting have no Python
dependency.

## Verification

`JDFTXIOTest` exercises the copied official upstream fixtures entirely in
MATLAB. `JDFTXOracleParityTest` independently compares inputs, single-point
and geometry-optimization outputs, complex band projections, eigenvalues,
and k-points against the frozen Python environment. Python is used only by
the development oracle test.

Per-API status and evidence are recorded in
`dev/matgenlab/api_status_overrides.csv` and the generated compatibility
ledger.
