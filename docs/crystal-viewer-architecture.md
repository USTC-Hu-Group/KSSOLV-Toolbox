# Atomic Viewer architecture

The KSSOLV Atomic Viewer replaces the former browser-side 3Dmol.js structure
parser and bonding inference with a versioned, MATLAB-owned scientific scene
for both periodic crystals and finite molecules.

## Scientific boundary

`AtomicSceneSpec 2.0` is a discriminated union. Its `crystal` branch is compiled
by `kssolv.ui.crystal.CrystalSceneBuilder`:

1. `matgenlab.core.Structure` parses and normalizes the periodic structure.
2. The Crystal Toolkit strategy set (`CrystalNN`, `CutOffDictNN`, `JmolNN`,
   `MinimumDistanceNN`, `MinimumOKeeffeNN`, `EconNN`, or
   `BrunnerNNReciprocal`) creates a `StructureGraph`.
3. Periodic `to_jimage` values are retained in unique bond relations.
4. Boundary and one-hop atom instances are generated explicitly.
5. `CrystalSceneValidator` checks identifiers, periodic geometry, distances,
   limits, and JSON transport.

Its `molecule` branch is compiled by
`kssolv.ui.crystal.MoleculeSceneBuilder`:

1. `StructureIO` dispatches PDB, XYZ, MOL, SDF, MOL2, CML, MRV, and aliases to
   `matgenlab.core.Molecule` without a `Structure.from_str` round-trip.
2. PDB `CONECT` and native bond tables retain source connectivity and bond
   order.
3. Coordinate-only inputs use `OpenBabelNN` (or the selected algorithm) once
   per molecule. Covalent candidates come from a spatial hash and only nearby
   pairs receive exact vectorized distance checks.
4. Molecular charge, spin multiplicity, input format, frame index, and frame
   count are transported without lattice or periodic metadata.
5. Multi-frame inputs currently select frame 1 and report the total frame
   count in scene metadata and warnings.

The TypeScript application validates both branches of `AtomicSceneSpec 2.0`
again, but never infers chemical bonds. Pretty and Materials themes only change
presentation; scientific coordinates and topology remain identical.

## Frontend boundary

`frontend/apps/crystal-viewer` uses Vue for panels and low-frequency state.
Three.js owns camera interaction and GPU resources. Atoms, bond halves, and
coordination polyhedra use `BatchedMesh`; the renderer draws on demand and
disposes every GPU resource when the MATLAB document closes.

MATLAB and the application communicate with named `uihtml` events. Every scene
request has an identifier, and structures with at least 256 sites use an
atoms-first scene before exact connectivity is delivered. Molecules are fitted
from atom bounds only and do not expose lattice, repeat, boundary, polyhedron,
or magnetic-moment controls.

## Reference implementations

Behavior and visual baselines were studied at pinned revisions:

- pretty-lattice `e2c06c084300546ab25742d6d5c7352198ded817`
- crystaltoolkit `bb0493a44c98c79a2b03baea0c94de125818ce4`
- mp-react-components `d483d7ca20aa24328aaf2f6fb96f9b70a25cdfc3`

No upstream runtime, logo, or brand asset is bundled. The implementation uses
the repositories as behavioral references. matgenlab remains the scientific
implementation, and the frontend code is native Vue/Three code.

## Build and test

From `frontend`:

```bash
pnpm --filter @kssolv/crystal-viewer test
pnpm --filter @kssolv/crystal-viewer lint:check
pnpm --filter @kssolv/crystal-viewer build
pnpm sync:runtime
```

MATLAB contract tests are in `kssolv.ui.test.CrystalSceneBuilderTest` and
`kssolv.ui.test.MoleculeSceneBuilderTest`. Reproducible performance gates are
in `kssolv.ui.test.benchmark.CrystalViewer`. The runtime copy under
`@MoleculeDisplay/CrystalViewer` is generated and must not be edited directly.

## Delivery phases and acceptance

| Phase | Deliverable | Acceptance evidence |
| --- | --- | --- |
| 0 | Upstream/reference baseline | Revisions are pinned above; no upstream runtime is copied. |
| 1 | Scientific scene compiler | Frozen CrystalNN relations and periodic images match matgenlab `StructureGraph`; molecular source topology and bond order survive parsing. |
| 2 | Versioned transport | MATLAB and TypeScript validators reject malformed, stale, mixed-branch, or oversized scenes. |
| 3 | GPU rendering core | Atoms, colored bond halves, multiple molecular bonds, cells, polyhedra, and magmoms render through batched layers. |
| 4 | Periodic visibility | Repeats, boundary atoms, bonded outside atoms, and incomplete bonds have independent controls. |
| 5 | Materials interaction layout | Orthographic trackball, fitted crystal/molecule cameras, axis views, selection, settings, export, screenshot, and fullscreen are present. |
| 6 | Pretty/Materials themes | Materials is the default; theme changes preserve the exact scientific scene. Pretty retains its own art while sharing layout, visibility defaults, fitting, axes-inset, and render-path rules. |
| 7 | MATLAB integration | Production assets load in `uihtml`; named events carry request IDs and JSON-stable arrays. |
| 8 | Correctness and performance | MATLAB tests, all registered molecule format fixtures, Vitest coverage, a 10,000-atom WebGL scene, and enforced crystal/molecule compiler/cache SLOs pass. |
| 9 | Replacement and compliance | The active 3Dmol runtime is removed; Vue/Three notices ship beside the runtime. |

The benchmark gates are 1.5 s for a 1,000-site atoms-first scene, 8 s for an
exact LiFePO4 CrystalNN scene, 3 s for a sparse 4,800-atom molecule, and 500 ms
for an identical cached crystal or molecular request.
