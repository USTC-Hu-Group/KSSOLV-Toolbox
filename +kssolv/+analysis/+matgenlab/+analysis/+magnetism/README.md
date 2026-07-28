# Magnetism compatibility

This package implements the frozen `pymatgen.analysis.magnetism` inventory at
upstream commit `a75a4c4`: collinear structure analysis and ordering
enumeration, magnetic deformation, Heisenberg mapping/model serialization, and
Jahn–Teller analysis.

MATLAB indices are one-based. Consequently, symmetry-equivalent site lists and
Jahn–Teller `site_indices` are one larger than their Python counterparts.
Heisenberg sublattice identifiers remain zero-based because they are labels
embedded in exchange names such as `0-1-nn`; tuple-like site groups are exposed
as `containers.Map` keys such as `"1,2"`.

Ordering enumeration is performed in process by the bundled
`MagOrderingTransformation`; no `enumlib` executable is required. Results are
deterministic, and `max_orderings` remains the explicit combinatorial bound.
Writing an interaction graph requires ordinary local filesystem access only.
No network services are used.

The acceptance suite uses frozen upstream structures and verifies the official
Mn3Al exchange fit, mean-field temperature, LiFePO4 Jahn–Teller geometry, and
magnetic-deformation oracle.
