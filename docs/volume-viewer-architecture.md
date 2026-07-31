# Volumetric data viewer architecture and delivery plan

逐工作包、测试数据和量化退出条件参见
[KSSOLV 三维体数据查看器详细开发计划](volume-viewer-development-plan.zh-CN.md)。

## Goal and scope

The Volumetric Data Viewer extends the atomic viewer into a scientific 3D data
viewer for periodic and finite scalar fields. The first supported inputs are:

- VASP `CHGCAR` and `CHG`;
- Gaussian/CPMD Cube (`.cube`, `.cub`, and compressed variants already accepted
  by matgenlab);
- XCrySDen XSF scalar datagrids (`.xsf`) and, in a later phase, BXSF bandgrids.

The atomic structure remains visible as an optional overlay. The first release
supports scalar fields; XSF forces, vector fields, and non-collinear VASP
magnetization glyphs are follow-on representations, not reasons to weaken the
scalar-grid contract.

## Existing MATLAB foundation

The repository already contains most of the scientific file parsing:

| Format | Existing implementation | Existing test evidence |
| --- | --- | --- |
| CHGCAR | `kssolv.analysis.matgenlab.io.vasp.Chgcar.from_file` and `vasp.VolumetricData.parse_file` | `VaspOutputsFrozenOracleTest`, CHGCAR fixtures, spin and non-spin parsing |
| Cube | `common.VolumetricData.from_cube`, delegated to `vasp.VolumetricData.from_cube` | `CommonIOTest` round trip and multiple cube fixtures |
| XSF | `xcrysden.XSF.from_file`, `XSFGrid`, and `structure_properties` | `XcrysdenTest` for structures, 2D/3D datagrids, bandgrids, streaming, and malformed input |

These parsers remain the source of truth. A new UI must not parse these formats
again in TypeScript. The first implementation task is a thin normalization
layer plus compatibility hardening for Cube variants such as negative
`NATOMS`, dataset identifiers, and `NVAL`.

The format invariants are:

- CHGCAR is an `(nx, ny, nz)` periodic FFT grid in lattice coordinates, with
  `x` varying fastest. Its stored charge must be normalized according to the
  VASP definition before exposing physical units.
- Cube has an arbitrary origin and three voxel vectors, normally expressed in
  Bohr. It can be non-orthogonal and can contain multiple values per voxel.
- XSF datagrids have an explicit origin and two or three spanning vectors. XSF
  can store several labeled grids in one block and its grid need not be
  orthogonal.

## Application boundary

Create a separate `frontend/apps/volume-viewer` Vue 3 application. It shares the
existing atomic renderer instead of growing format-specific branches inside
`crystal-viewer`.

Before the new app is added, extract reusable code into:

```text
frontend/packages/atomic-scene/
  scene contracts and validators
  camera, orientation axes, selection, and export contracts
frontend/packages/three-scene/
  atom, bond, cell, polyhedron, magmom, and shared renderer utilities
frontend/apps/crystal-viewer/
frontend/apps/volume-viewer/
```

MATLAB owns file parsing, physical units, component semantics, and validation.
Vue owns presentation and interaction. Three.js owns the shared camera and GPU
scene. Large scalar arrays never travel as JSON number arrays.

## VolumeSceneSpec 1.0

Do not add millions of samples to `AtomicSceneSpec`. Introduce a separate,
versioned discriminated contract:

```ts
interface VolumeSceneSpec {
  schemaVersion: '1.0';
  kind: 'volume';
  requestId: string;
  source: {
    format: 'chgcar' | 'cube' | 'xsf';
    name: string;
  };
  atomicOverlay?: AtomicSceneSpec;
  grid: {
    dimensions: [number, number, number];
    origin: [number, number, number];
    voxelVectors: [
      [number, number, number],
      [number, number, number],
      [number, number, number],
    ];
    periodic: [boolean, boolean, boolean];
    indexOrder: 'x-fastest';
    sampling: 'cell-periodic' | 'point-inclusive';
  };
  channels: Array<{
    id: string;
    label: string;
    units: string;
    signed: boolean;
    minimum: number;
    maximum: number;
    mean: number;
    standardDeviation: number;
    integral?: number;
    transport: {
      transferId: string;
      valueEncoding: 'float32-le' | 'float64-le' | 'uint16-linear-le';
      elementCount: number;
      byteLength: number;
      crc32: number;
      scale?: number;
      offset?: number;
    };
  }>;
  transport: {
    protocol: 'chunked-binary';
    chunkBytes: number;
  };
  warnings: Array<{
    code: string;
    message: string;
    severity: 'info' | 'warning' | 'error';
  }>;
}
```

The canonical linear index is:

```text
index = x + nx * (y + ny * z)
```

For a MATLAB array shaped `[nx, ny, nz]`, `single(values(:))` already has this
ordering. A Cartesian sample position is:

```text
position = origin
         + x * voxelVectorA
         + y * voxelVectorB
         + z * voxelVectorC
```

The `sampling` field prevents an off-by-one convention from being hidden in
the renderer. CHGCAR uses periodic samples without a duplicated terminal
plane; an XSF or Cube adapter records its actual convention explicitly.

## MATLAB components

Add the following package under `+kssolv/+ui/+scene/+volume`:

1. `VolumeFileReader`
   - dispatches filenames and aliases;
   - calls the existing CHGCAR, Cube, or XSF parser;
   - returns a normalized grid/channel object;
   - reports unsupported multi-dataset variants with actionable errors.
2. `VolumeSceneBuilder`
   - computes channel statistics and units;
   - creates the optional `AtomicSceneSpec` overlay using the existing atomic
     scene builders;
   - applies an adaptive interactive level of detail without modifying the
     source data.
3. `VolumeChunkEncoder`
   - converts samples to little-endian `Float32`;
   - emits bounded base64 chunks through named `uihtml` events;
   - includes CRC32, sequence numbers and cancellation tokens.
4. `VolumeSceneValidator`
   - enforces finite values, positive dimensions, exact sample counts, memory
     limits, valid affine transforms, channel uniqueness, and request IDs.
5. `VolumeDisplay`
   - hosts the production Vite assets in `uihtml`;
   - coordinates `volume:ready`, `volume:begin`, `volume:manifest`,
     `volume:chunk`, `volume:complete`, `volume:cancel`, and `volume:error`;
   - sends a bounded preview first, retains the full-resolution MATLAB object,
     and refines the same logical request with the full grid.

The first interactive payload is bounded to `96^3` samples. Larger inputs are
downsampled conservatively for the first view, then refined by chunking the
full grid under the 256³/384 MiB transport limits. GPU direct-volume mode also
checks the browser-reported `MAX_3D_TEXTURE_SIZE`; systems without WebGL2 keep
a CPU lattice-slice viewer instead of showing a blank viewport.

## Vue and rendering components

Use Vue 3, Vite, Composition API, and TypeScript. Isosurface extraction and
statistics run in dedicated workers, using transferable `ArrayBuffer`
instances to avoid main-thread copies.

The first-class representations are:

1. **Isosurface** (default)
   - positive and negative surfaces with independent color and opacity;
   - absolute, standard-deviation, and percentile isovalue modes;
   - periodic wrapping, vertex normals, optional smoothing;
   - generated in a worker and cached by channel, LOD, isovalue, smoothing,
     and periodicity.
2. **Slice**
   - I/J/K-aligned planes first, because they remain correct for skewed grids;
   - arbitrary Cartesian planes after resampling support is complete;
   - colormap, range, interpolation, coordinate probe, and histogram.
3. **Direct volume**
   - `Data3DTexture` and a Three.js ray-marching shader;
   - scalar and gradient opacity transfer functions;
   - stable midpoint sampling, clipping box, and early ray termination;
   - interaction does not change sampling density or device-pixel ratio.
4. **Atomic overlay**
   - atoms, bonds, unit cell, polyhedra, axes, selection, and camera behavior
     from the shared atomic renderer;
   - all overlays and volume geometry use one Three.js camera and one
     interaction model.

The delivered isosurface implementation uses a small, original
marching-tetrahedra worker. It emits oriented non-degenerate triangles,
deduplicates vertices for smooth normals, supports cell-periodic terminal
wrapping, cancels stale workers, and keeps a six-entry/128 MiB LRU geometry
cache. VTK.js was evaluated but is not bundled because it was unnecessary for
the accepted accuracy and package-size targets. No VTK renderer or second
camera is present.

NGL is a useful interaction and representation reference for worker-backed
isosurfaces, wrapping, sigma isovalues, and slices. Mol* is a reference for
half-float direct volumes, GPU isosurfaces, and periodic-volume behavior. These
projects are references, not new application frameworks.

## User interface

The viewer uses the current Materials/Pretty atomic viewport as its base:

- top-left source card: filename, format, dimensions, channel, and units;
- right settings:
  - channel/dataset;
  - representation;
  - isovalue mode and positive/negative values;
  - colors, opacity, smoothing, and periodic wrapping;
  - slice axis/index or volume transfer function;
  - sampling quality and LOD;
  - atom, bond, cell, polyhedron, axes, and clipping visibility;
- bottom: histogram/transfer-function editor and probe value;
- exports: viewport PNG, scene metadata JSON, slice PNG/CSV, and isosurface
  glTF/GLB/PLY/STL.

Changing a display option must not reparse the file. Changing isovalue cancels
stale worker jobs. Rebuilding or switching representation preserves the camera
position, orientation, target, and zoom.

## Delivery phases and acceptance

| Phase | Deliverable | Acceptance criteria |
| --- | --- | --- |
| 0 | Atomic-viewer parity and shared-code boundary | Pretty and Materials use identical card metrics, default visibility values, camera fitting, axes viewport, and default fast Phong path; theme art remains distinct; all current frontend tests pass. |
| 1 | MATLAB adapters and `VolumeSceneSpec 1.0` | CHGCAR, one-value Cube, and 3D XSF fixtures normalize to the same canonical index order; validators reject truncation, non-finite data, invalid transforms, and oversized requests. |
| 2 | Chunked `uihtml` transport | A `128^3` Float32 channel is reconstructed byte-for-byte; out-of-order, missing, duplicate, stale, and cancelled chunks are handled deterministically; the UI shows bounded progress and actionable errors. |
| 3 | Atomic overlay plus isosurface MVP | CHGCAR, Cube, and XSF each display an atomic overlay and a correct isosurface in the same camera; positive/negative Cube orbital surfaces work; skewed XSF and CHGCAR transforms match MATLAB probe coordinates. |
| 4 | Slice, histogram, and probe | I/J/K slices, value range, histogram, interpolation, and point probes agree with MATLAB reference values within Float32 tolerance. |
| 5 | Direct GPU volume rendering | WebGL2-capable systems use `Data3DTexture`, transfer functions, clipping, and adaptive ray steps; unsupported or oversized devices fall back to isosurface/slice without a blank viewport. |
| 6 | Format hardening | Spin-polarized/non-collinear CHGCAR channels, Cube `NVAL` and negative-`NATOMS` datasets, multiple XSF datagrids, compressed files, and periodic boundary conventions pass frozen fixtures. |
| 7 | Performance and exports | On the reference desktop, `128^3` decode plus first isosurface is under 2 s, isovalue interaction never blocks the main thread for more than 100 ms, orbit stays at least 30 FPS, and viewer memory stays below 400 MiB; PNG and mesh exports pass round trips. |
| 8 | MATLAB product integration | File manager routes supported volume files to `VolumeDisplay`; closing a document cancels work and releases GPU/worker memory; production assets are generated by `pnpm sync:runtime`, never edited in place. |

## Verification data

Maintain small, redistributable frozen fixtures:

- Si or NaCl CHGCAR with electron-count integral;
- spin-polarized CHGCAR with total and difference channels;
- H2O density Cube and signed molecular-orbital Cube;
- Cube with non-zero origin, skewed voxel vectors, `NVAL`, and negative
  `NATOMS`;
- periodic skewed-cell XSF with one and multiple datagrids;
- analytic scalar sphere sampled on orthogonal and skewed grids.

Every fixture has MATLAB assertions for dimensions, origin, transform,
min/max, integral, and selected probe values. Frontend geometry tests compare
the analytic sphere's extracted radius and bounds; visual snapshots cover
positive/negative surfaces, slices, clipping, and both atomic themes.

## Reference implementations and specifications

- [VASP CHGCAR format](https://vasp.at/wiki/CHGCAR)
- [pymatgen VolumetricData and VASP IO](https://pymatgen.org/pymatgen.io.vasp.html)
- [XCrySDen XSF specification](https://web.mit.edu/xcrysden_v1.5.60/www/XCRYSDEN/doc/XSF.html)
- [h5cube Cube format clarification](https://h5cube-spec.readthedocs.io/en/latest/cubeformat.html)
- [Three.js Data3DTexture](https://threejs.org/docs/pages/Data3DTexture.html)
- [VTK.js ImageMarchingCubes example](https://kitware.github.io/vtk-js/examples/ImageMarchingCubes.html)
- [VTK.js GPU volume rendering](https://kitware.github.io/vtk-js/api/Rendering_Core_Volume.html)
- [NGL volume representations](https://nglviewer.org/ngl/api/manual/usage/volume-representations.html)
- [Mol* volume implementation history](https://github.com/molstar/molstar/blob/master/CHANGELOG.md)

Three.js is MIT licensed and VTK.js is BSD-3-Clause licensed. Any copied or
adapted implementation must retain its applicable notice in
`THIRD-PARTY-LICENSES.md`; design inspiration alone is recorded here without
copying upstream code.
