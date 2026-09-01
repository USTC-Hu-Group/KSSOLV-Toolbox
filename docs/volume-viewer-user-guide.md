# Volume Viewer User Guide

The Volume Viewer displays scalar fields together with an optional atomic
structure. It supports VASP `CHGCAR`/`CHG`, Gaussian Cube, and XCrySDen XSF
files, including gzip-compressed files.

[简体中文](volume-viewer-user-guide.zh-CN.md)

## Open a volume

1. Double-click **Volume** in the Project Browser.
2. Select a supported file.
3. Wait for the initial view and data summary to appear.

Large grids may first open at a reduced display resolution. The full data is
loaded in the background, and the status area reports progress or any GPU
fallback. Closing the document or opening another file cancels work that is no
longer needed.

## Navigate and inspect

- Drag with the left mouse button to rotate.
- Use the mouse wheel to zoom and right-drag to pan.
- Press Space to center and fit the data without changing the view direction.
- Press `I` to hide or show the summary, distribution chart, and toolbar.
- Double-click the volume to inspect its Cartesian position, grid position,
  and interpolated value.

The **Value Distribution** chart summarizes the active channel. In isosurface
mode, click the chart to set a nearby positive or negative threshold. In slice
and direct-volume modes, clicking adjusts the nearest end of the color range.

Use **Settings** to choose isosurfaces, I/J/K lattice slices, or direct volume
rendering. Structural overlays include atoms, bonds, the unit cell,
coordination polyhedra, and lattice axes.

## Choose a channel

- A non-spin-polarized CHGCAR normally contains `total`.
- A spin-polarized CHGCAR provides `total`, `diff`, and derived `up`/`down`
  channels.
- A noncollinear CHGCAR provides magnetization components and their magnitude.
- Cube files may contain one or more datasets.
- Each labeled XSF Datagrid appears as a separate channel; a 2D Datagrid opens
  in slice mode.

CHGCAR density is displayed in `1/Angstrom^3`. Cube origins, axis units, and
non-orthogonal grids are interpreted from the file. Slices follow the actual
voxel vectors rather than assuming Cartesian-aligned planes.

## Export

- Use the camera button to export the current view as PNG.
- Export the scene description as JSON when you need settings without the
  voxel array.
- In isosurface mode, export geometry as glTF, GLB, PLY, or STL.
- In slice mode, export the current plane as PNG or CSV.

Exported geometry and coordinates use Cartesian angstrom units unless the
export dialog states otherwise.

## Troubleshooting

- If WebGL2 is unavailable, use the CPU slice view and PNG/CSV export.
- If the GPU cannot hold the 3D texture, the viewer falls back to a lattice
  slice and displays the reason.
- If smooth floating-point filtering is unavailable, nearest sampling is used.
- If an isosurface contains no triangles, wait for the build to finish or move
  the threshold inside the data range.
- After a WebGL context loss, wait for the viewer to rebuild. If it continues
  to fail, switch to isosurface or slice mode.
- Files with invalid dimensions, non-finite values, or unsafe size estimates
  are rejected before a large allocation is attempted.

Sparse source grids remain sparse even when the display is interpolated. Use a
higher-resolution calculation when quantitative spatial detail is required.
