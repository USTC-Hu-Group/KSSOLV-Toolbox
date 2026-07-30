# Volume viewer implementation baseline

Recorded on 2026-07-29 before adding the volume-viewer application.

## Frontend

- Crystal viewer tests: 57 passing tests in 11 files.
- Production JavaScript: 718.44 kB, 191.68 kB gzip.
- Production CSS: 8.42 kB, 2.51 kB gzip.
- Toolchain: Vue 3.5, Three.js 0.185.1, Vite 8.1, TypeScript 6.0.

Commands:

```bash
cd frontend
pnpm --filter @kssolv/crystal-viewer test
pnpm --filter @kssolv/crystal-viewer lint:check
pnpm --filter @kssolv/crystal-viewer build
```

## MATLAB scientific foundation

- `io.vasp.Chgcar.from_file` parses non-spin, spin, and non-collinear grids.
- `io.common.VolumetricData.from_cube` parses a single Cube dataset.
- `io.xcrysden.XSF.from_file` parses structures, 2D/3D datagrids, and
  bandgrids.

The implementation begins by adding a public FileParser normalization layer
and hardening Cube multi-dataset geometry. Existing matgenlab classes remain
the format parser source of truth.

## Reference environment

- MATLAB: `/Applications/MATLAB_R2026b.app/bin/matlab`,
  `26.2.0.3320248 (R2026b) Prerelease Update 2`.
- Host: macOS 26.5.2, Apple Silicon `arm64`.
- GPU: Apple M3 Pro, 14 cores, Metal 4.
- Node.js 26.4.0; pnpm 11.17.0.
- Display: built-in 3024 × 1964 Retina panel.

MATLAB's Parallel Computing Toolbox does not expose `gpuDevice` on macOS;
the viewer's GPU path is WebGL2 inside `uihtml`, so capability checks are
performed against `MAX_3D_TEXTURE_SIZE` and float-filter extensions in the
embedded browser instead.

## Implemented volume-viewer measurements

- Volume viewer production entry: 740.12 kB, 199.56 kB gzip (Vite report).
- Worker chunks: isosurface 2.51 kB; statistics 0.68 kB.
- Three cold `128³` transport-decode plus marching-tetrahedra runs:
  1049/861/836 ms, median 861 ms on the reference desktop.
- `128²` lattice slice extraction: 2 ms. Hot derived-data cache lookup:
  below the 1 ms reporter resolution.
- Crystal viewer regression: 57/57 tests.
- Shared packages: atomic-scene 2/2, three-scene 11/11,
  volume-scene 11/11 tests.
- Volume viewer: 36/36 tests after bridge state, progressive LOD replacement,
  histogram, bounded LRU,
  geometry, all export formats, fallback, acceptance soak, periodic wrapping,
  and grid-math coverage.
