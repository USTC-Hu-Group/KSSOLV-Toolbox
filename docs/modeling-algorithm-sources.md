# Modeling algorithm sources

This note records the mature open-source implementations reviewed before
implementing KSSOLV's advanced modeling builders. It is an engineering design
record, not a runtime dependency list. KSSOLV implementations must use native
MATLAB/matgenlab data structures, preserve site properties, use one-based
MATLAB indices internally, and add parity tests derived from published
invariants rather than copying test fixtures blindly.

Research snapshot: 2026-07-31.

## Special quasirandom structures

- Reference API and cluster semantics:
  [pymatgen `SQSTransformation`](https://pymatgen.org/pymatgen.transformations.html)
- Adopted design: preserve the requested alloy composition exactly; enumerate
  small configuration spaces exhaustively; switch to a deterministic,
  time-bounded Monte Carlo swap search for large spaces; minimize deviations
  from independent-alloy pair correlations over the first three shells.
- Scientific scope: this native implementation is a pair-correlation SQS
  search, not a replacement for a fully configured ATAT `mcsqs` run with
  user-defined triplet and quadruplet clusters. The output records the search
  mode, configuration-space size, objective value, shell count, and time
  budget in structure metadata.

## Nanotubes and nanoribbons

- Reference: [ASE `nanotube` and `graphene_nanoribbon` documentation](https://ase.gitlab.io/ase/ase/build/build.html)
- Source project: [Atomic Simulation Environment](https://gitlab.com/ase/ase)
- License: LGPL-2.1-or-later.
- Adopted design: chiral indices `(n,m)`, an integer axial repeat, explicit
  bond length, and optional transverse vacuum. For ribbons, distinguish
  zigzag and armchair edge construction and make edge saturation explicit.
- Required KSSOLV tests: atom count, tube radius, axial period, seam bond
  distances, handedness for `(n,m)`, ribbon periodicity, and absence of
  duplicates at the wrap seam.

## Nanowires, quantum dots, and nano voids

- Reference: [ASE nanoparticle and Wulff construction documentation](https://ase.gitlab.io/ase/ase/cluster/cluster.html)
- Reference cutting primitives: [ASE build tools](https://ase.gitlab.io/ase/ase/build/build.html)
- License: LGPL-2.1-or-later.
- Adopted design: construct a sufficiently large periodic parent supercell,
  evaluate Cartesian distance or half-space predicates, retain sites for a
  dot/wire and invert the predicate for a void, then remove duplicate periodic
  images deterministically. A Wulff mode should use Miller facets and relative
  surface energies rather than a spherical approximation.
- Required KSSOLV tests: shape predicate containment, requested periodic axes,
  minimum transverse vacuum, deterministic boundary inclusion, preserved
  composition/site properties, and no coincident sites.

## Commensurate moiré superlattices

- Reference implementation: [Twister](https://github.com/qtm-iisc/Twister)
- Method paper: [Twister: Construction and structural relaxation of
  commensurate moiré superlattices](https://arxiv.org/abs/2102.07884)
- License: BSD-3-Clause.
- Adopted design: coincidence-site-lattice search over integer transforms,
  bounded strain accommodation for unequal 2D lattices, explicit twist-center
  and interlayer separation, and a hard maximum-atom guard before materializing
  a candidate.
- Required KSSOLV tests: commensurability residual, achieved twist angle,
  in-plane strain bound, common superlattice equality for both layers,
  deterministic candidate ranking, interlayer distance, and atom-count guard.

## IDPP interpolation

- Reference implementation: [ASE NEB IDPP implementation](https://gitlab.com/ase/ase/-/blob/master/ase/mep/neb.py)
- Usage reference: [ASE IDPP tutorial](https://gitlab.com/ase/ase/-/blob/plugin-display/examples/03-tutorials/neb_idpp.py)
- Supporting structure interpolation behavior:
  [pymatgen `Structure.interpolate`](https://pymatgen.org/pymatgen.core.html)
- License: LGPL-2.1-or-later for ASE; MIT for pymatgen.
- Adopted design: first build a minimum-image linear path, form image-dependent
  target pair distances from endpoint distances, minimize the pair-potential
  objective for interior images only, and keep endpoint structures immutable.
  The KSSOLV API must require equal site count and explicit site mapping when
  ordering differs.
- Required KSSOLV tests: unchanged endpoints, periodic minimum-image motion,
  monotonically interpolated target distances, reduced close-contact penalty
  versus the linear path, deterministic convergence, and explicit failure on
  incompatible structures.

## Surface passivation

- Adsorption/site reference: [pymatgen `AdsorbateSiteFinder` and
  `AddAdsorbateTransformation`](https://pymatgen.org/pymatgen.transformations.html)
- Surface construction reference: [ASE surface and adsorbate tools](https://gitlab.com/ase/ase/blob/master/doc/ase/build/surface.rst)
- Licenses: MIT for pymatgen; LGPL-2.1-or-later for ASE.
- Adopted design: identify surface atoms from the slab normal, compare their
  coordination to a bulk reference, place passivants along missing-neighbor
  directions at species-dependent bond length, symmetry-reduce equivalent
  sites, and reject placements violating a configurable minimum distance.
- Scientific scope: automatic target coordination is inferred from the
  highest coordination observed for each species in the supplied slab. Thin
  slabs and monolayers without bulk-like interior atoms therefore require an
  explicit target coordination.
- Required KSSOLV tests: only under-coordinated surface atoms are changed,
  passivant distance/orientation, top/bottom selection, symmetry reduction,
  collision rejection, and preservation of the original slab.

## Solvent-layer packing

- Reference algorithm:
  [Packmol](https://m3g.github.io/packmol/)
- Input-model reference:
  [pymatgen PackmolBoxGen](https://pymatgen.org/pymatgen.io.html)
- Adopted design: transform the slab into a local orthonormal surface frame,
  keep the surface fixed, constrain complete solvent molecules to an
  inscribed layer box, invoke the native
  `kssolv.analysis.packmol` MATLAB implementation, validate the returned atom
  count, and map the packed coordinates back to the slab lattice.
- Execution policy: no Packmol executable, Packmol.jl runtime, or `PATH`
  lookup is required. A MATLAB callback remains available only as an explicit
  test/integration override.
- Required KSSOLV tests: native execution, generated fixed/box
  constraints, output atom count, solvent molecule provenance, local-frame
  round trip, nonperiodic surface normal, and temporary-file cleanup.

## Implementation policy

No advanced builder is enabled in the Modeling tab until its native
implementation and the acceptance tests above are present. Packmol packing is
provided by the native MATLAB implementation under
`+kssolv/+analysis/+packmol`.
