# Native MATLAB Packmol

This package is a clean MATLAB reimplementation of
[m3g/packmol](https://github.com/m3g/packmol), pinned for parity work to
commit `14e50c65fa9120b58e1ba33ad482c7c7260f72b2`.

It does not use Packmol.jl, `Packmol_jll`, a subprocess, or a system Packmol
installation. The public entry points are:

- `kssolv.analysis.packmol.packmol(input, ...)` for input text or a file;
- `kssolv.analysis.packmol.main(["-i", input, "-o", output])` for the
  command-line signature;
- `kssolv.analysis.packmol.native_executor(request)` for matgenlab and
  modeling builder integration;
- `parse_input`, `prepare_system`, `initial_point`, `evaluate`, `gencan`,
  `compare_gradient`, and `write_output` for algorithm-level testing and
  composition;
- `exit_codes()` for Packmol's public status values 0 and 170 through 174.

The implementation preserves Packmol's six rigid variables per movable
molecule, the two historical Euler conventions, atom-pair radius objective,
short-radius term, PBC minimum image, linked-cell candidate search, all
restraint codes 2 through 15, analytical gradients, bound-constrained
GENCAN design, restart/check/chkgrad flows, and PDB/XYZ/TINKER/CHARMM CRD
I/O. Historical source behaviors that affect numerical parity are retained,
including outside-box midpoint handling, outside-ellipsoid scaling, repeated
PDB connectivity, hexadecimal indices, residue/chain numbering, and the
fixed-molecule CRD coordinates. The m3g/packmol MIT license is included as
`LICENSE`.

Run the package tests with:

```matlab
runtests("+kssolv/+analysis/+packmol/+test")
```

The regression suite contains byte-for-byte output oracles produced by the
pinned upstream executable, an exact nonzero objective oracle, analytical
gradient checks, all restraint families, periodic minimum-image behavior,
restart round trips, CLI flag order, native executor behavior, and packing
success/failure cases.
