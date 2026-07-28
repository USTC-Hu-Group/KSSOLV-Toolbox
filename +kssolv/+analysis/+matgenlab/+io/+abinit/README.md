# matgenlab ABINIT interface

This package is the native MATLAB implementation of the frozen
`pymatgen.io.abinit` API surface. It includes ABINIT variable formatting,
geometry and electronic-input objects, pseudopotential parsing and selection,
single- and multi-dataset input factories, ETSF NetCDF readers, and timing
analysis/plotting.

Production code does not invoke Python. `Pseudo.open_pspsfile` is the single
explicit external-runtime boundary because the upstream operation launches the
ABINIT executable to generate a `_PSPS.nc` file.

The frozen compatibility denominator and evidence ledger live in
`dev/matgenlab/inventory`, and the native fixture regression is
`dev/matgenlab/test_abinit_matlab.m`.
