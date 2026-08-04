# KSSOLV Atomic Viewer

Vue 3 and Three.js renderer for `AtomicSceneSpec 2.0`. The discriminated
`crystal` and `molecule` scene branches share atoms, bonds, selection, camera,
export, and visual themes while retaining their own scientific metadata.
MATLAB/matgenlab owns parsing, connectivity, distances, and coordination; this
application only renders the validated scene and exposes Materials
Project-style controls.

For crystals, matgenlab supplies periodic images, boundary atoms, and
coordination environments. For molecules, explicit source-file topology and
bond orders are preserved whenever the input format supplies them. XYZ and
other coordinate-only inputs use the selected matgenlab neighbour algorithm as
a clearly reported fallback. The browser never infers chemical bonds.

The default visual theme follows pretty-lattice. The alternate Materials theme
uses the same scene geometry with VESTA colors and Crystal Toolkit-style
presentation.

Production builds are self-contained single-file HTML documents. The offline
HTML toolbar export embeds the current validated scene, display options, camera
orientation, styles, and application runtime, so the downloaded viewer can be
opened without MATLAB, a web server, or network access while retaining normal
camera and display interactions.

## Commands

```bash
pnpm dev
pnpm test
pnpm test:coverage
pnpm lint:check
pnpm typecheck
pnpm build
```

In development, the app automatically loads a deterministic NaCl scene. Add
`?molecule` for a deterministic molecule with a source double bond, or
`?stress=10000` for the built-in 10,000-atom GPU benchmark scene. In MATLAB,
`setup(htmlComponent)` attaches the `uihtml` event bridge before the Vue
application mounts.

The generated `dist` directory is copied to the MATLAB runtime by
`frontend/scripts/sync-runtime.mjs`. Do not edit the runtime copy directly.
