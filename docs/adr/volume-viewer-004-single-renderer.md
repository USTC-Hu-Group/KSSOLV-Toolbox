# ADR-004: Three.js remains the only renderer and camera owner

- Status: accepted
- Date: 2026-07-29

## Decision

Atomic geometry, isosurfaces, slices, and direct volume rendering share one
Three.js scene, camera, controls instance, picking pipeline, and export view.

## Alternatives

Embedding a VTK.js render window beside the current Three.js renderer was
rejected because it duplicates cameras, interaction, depth composition, and
GPU lifetime management.

## Consequences

VTK.js may be used as a worker-side geometry algorithm, but its renderer and
interactor are not used. vtkPolyData is converted to Three BufferGeometry.

## Revisit condition

Revisit only if Three.js cannot meet a measured volume-rendering requirement
and a single-renderer migration plan is approved.
