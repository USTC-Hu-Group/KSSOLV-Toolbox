# ADR-002: VolumeSceneSpec is separate from AtomicSceneSpec

- Status: accepted
- Date: 2026-07-29

## Decision

Use `VolumeSceneSpec 1.0` for grid metadata, channels, transport, and warnings.
An optional `AtomicSceneSpec` is embedded as an overlay reference.

## Alternatives

Adding millions of scalar values to `AtomicSceneSpec` was rejected because it
would couple atomic topology validation to bulk transport and make JSON the
large-data path.

## Consequences

Atomic and volume schemas evolve independently. The volume viewer can display
grid-only files and can reuse the atomic renderer without weakening either
validator.

## Revisit condition

Revisit only if a later general `ScientificSceneSpec` can preserve independent
schema versions and binary transport.
