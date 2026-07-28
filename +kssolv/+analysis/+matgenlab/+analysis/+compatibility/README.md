# Compatibility package

This package is a native MATLAB implementation of the frozen pymatgen
`analysis.compatibility` surface at upstream tag `v2026.5.4`, commit
`8495e941504cd5123701635b6572942c78d9589c`. It includes the
legacy MP/MIT correction chains, MP2020 and SmoothPES corrections, aqueous
referencing, Gibbs SISSO entries, experimental entries, correction fitting, and
the MP two-functional mixing scheme.

The implementation is intentionally offline and pure MATLAB. It does not call
the Materials Project API or require Python. Callers must supply entries,
structures, and calculation metadata. Restricted raw VASP POTCAR data and
POTCAR content is not bundled. Symbol checks and the public fingerprints
distributed with MITRelaxSet are supported. Hash checking correctly rejects
input sets such as MPRelaxSet whose public configuration contains no hashes.
Network retrieval of MP entries remains an external data-acquisition
responsibility.

Bundled YAML/JSON coefficient tables are copied from the frozen upstream source.
The acceptance oracle is stored under
`+test/+analysis/+fixtures/compatibility_oracle.json`.

## Frozen-ledger accounting

The main-module ledger contains 71 rows: 15 classes, 18 methods, one function,
and 37 imported implementation dependencies. All 34 callable/type rows have
native MATLAB implementations. The imported rows are fulfilled by native
MATLAB language/runtime behavior or the corresponding matgenlab classes rather
than Python shims. The historical name `pymatgen.entries.compatibility` is not
the frozen module owner; in v2026.5.4 the inventory owner is
`pymatgen.analysis.compatibility`.
