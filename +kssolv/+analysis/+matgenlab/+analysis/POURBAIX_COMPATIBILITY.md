# Pourbaix diagram compatibility

This module implements all 45 public items in the frozen
`pymatgen.analysis.pourbaix_diagram` inventory at upstream commit `a75a4c4`.
The implementation covers solid and ion `PourbaixEntry` objects, weighted
`MultiEntry` mixtures, `IonEntry`, multi-element convex-hull preprocessing,
stable domains in pH–potential space, decomposition energies, MSON
serialization, composition parsing, and MATLAB plotting.

The thermodynamic convention is the frozen upstream convention:
`MU_H2O = -2.4583 eV` and `PREFAC = 0.0591 eV`. Domain clipping uses the
upstream default pH and potential bounds and deterministic MATLAB/Qhull
geometry. MATLAB arrays and fixture positions are one-based; serialized
`entry_id` values remain unchanged because they are identifiers rather than
indices. The `nproc` argument is accepted for API compatibility, while
preprocessing runs deterministically in process.

Production computation is pure MATLAB. No Python runtime, web service, database,
or executable is needed. The acceptance suite ships the official Zn, Ag–Te,
Ag–Te–N, and C–Na–Sn fixture and verifies the upstream stable-domain counts,
representative domain choices, exact decomposition-energy oracles, concentration
regressions, degenerate reaction handling, MSON round trips, plotting, and the
line-by-line 45-item API inventory.
