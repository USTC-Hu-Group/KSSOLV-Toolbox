# Volume viewer acceptance record

Recorded on 2026-07-29 on the reference environment documented in
`volume-viewer-baseline.md`.

## Automated evidence

| Area | Result |
| --- | --- |
| Crystal viewer regression | 57/57 |
| Shared atomic scene | 2/2 |
| Shared camera/resources | 11/11 |
| Volume contract/transport | 11/11 |
| Volume renderer/state/render/export | 36/36 |
| MATLAB VolumeIO/transport/LOD/oracle/limits | 22/22 |
| MATLAB VASP/Cube/XSF frozen-parser regression | 25/25 |
| MATLAB relevant regression suite | 65 passed, 0 failed, 1 assumption-filtered |
| MATLAB Code Analyzer | 46 changed production/test files, 0 issues |
| `128³` decode + analytic isosurface | 836/861/1049 ms; median 861 ms; budget < 2 s |
| `128²` scalar slice / hot cache | 2 ms / <1 ms; budgets <100 ms |
| Production orbit sampling | 1059 s final candidate: 116.0 FPS average, 77.9 FPS minimum |
| Production soak | 1800 s intermediate build: 3600 updates, 6 context recoveries, 0 errors |
| Volume entry gzip | 199.56 kB reported by Vite; budget < 250 KiB |
| All JavaScript gzip | 198,663 bytes by `gzip -c`; delayed-chunk budget < 750 KiB |

The analytic surface tests cover transport decode, radius error,
non-degenerate triangles,
greater than 99% normal orientation, a linear-field plane, x-fastest indexing,
skew world/grid transforms, interpolation, finite-voxel histogram accounting,
indexed-geometry expansion, and glTF/GLB/PLY/STL topology and world bounds.

Transport coverage includes little-endian Float32 and Uint16 linear
quantization, per-chunk CRC32, final canonical-buffer CRC32, out-of-order and
duplicate delivery, mutated duplicate detection, gaps/overlaps, stale request
isolation, and monotonic byte progress.

The single assumption-filtered MATLAB test is
`MoleculeTest/zmatrixMatchesPymatgen`; the external Python `pymatgen`
package is not installed in this reference environment. It is not recorded as
a pass and remains an external-oracle release check.

## Real runtime evidence

- Production app visually inspected in the in-app browser for signed positive
  and negative isosurfaces, skew slices, direct GPU volume, settings changes,
  status reporting, and orientation inset.
- The browser stress path completed 50 reloads and 200 consecutive threshold
  changes without an unhandled console error or a stale final value.
- The completed 30-minute intermediate-build soak performed 3600 scene
  updates and 6 real context-loss recoveries with 0 errors. JavaScript heap
  changed from 25,122,994 to 24,465,262 bytes; renderer resources remained at
  9 geometries, 0 textures, and 4 programs.
- The final-candidate soak was stopped at the user's request after 1059
  seconds because the preceding full soak had passed. It completed 2118 scene
  updates and 3 context-loss recoveries with 0 errors, averaged 116.0 FPS
  (77.9 minimum), and changed JavaScript heap from 41,977,461 to 38,627,039
  bytes. Renderer resources again remained at 9 geometries, 0 textures, and
  4 programs. This is recorded as a user-approved shortened repeat, not as a
  second completed 30-minute soak.
- A real `WEBGL_lose_context` loss/restore cycle rebuilt the GPU scene with an
  identical before/after screenshot SHA-256
  (`c734f8fe7cadba99d3e6bf1a499375d1a98347f0dd983176f6ab435ad4fe1512`).
- The production Canvas2D fallback was forced through the acceptance-only URL
  seam and kept scalar slices plus PNG/CSV export available while disabling
  isosurface and direct-volume GPU modes; the path completed with 0 console
  errors.
- Real MATLAB R2026b `AppContainer + uihtml` handshake loaded non-spin CHGCAR,
  spin CHGCAR, Cube, and XSF with exact dimensions and channel counts.
- Real complete `kssolv('', false)` launch exercised Project Browser,
  DocumentGroup, and `VolumeDisplay`; the dataset and active request were
  observed from the running app.
- Closing a CHGCAR document immediately after creation cleared its request
  token and dataset state (`VOLUME_CLOSE_CANCEL_PASS`).
- The runtime build is generated only by `pnpm sync:runtime`; source/dist
  checksums are compared in the release command log.

## Release matrix

| Scenario | macOS R2026b | Windows MATLAB |
| --- | --- | --- |
| CHGCAR parse/channel/transport | Passed | Not available in this workspace |
| Cube parse/units/transport | Passed | Not available in this workspace |
| XSF parse/skew grid/uihtml | Passed | Not available in this workspace |
| Stale-request cancellation | Passed by unit/integration path | Not available |
| GPU fallback/context recovery | Browser path implemented and inspected | Not available |

Windows is not claimed as tested by this record. A Windows release runner must
execute the same MATLAB test class and seven end-to-end scenarios before a
cross-platform release is tagged.
