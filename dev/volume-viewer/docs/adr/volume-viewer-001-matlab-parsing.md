# ADR-001: MATLAB owns scientific file parsing

- Status: accepted
- Date: 2026-07-29

## Decision

CHGCAR, Cube, and XSF files are parsed and normalized by matgenlab/MATLAB.
TypeScript receives a versioned manifest and a binary scalar buffer, never the
source scientific file.

## Alternatives

- Parsing again in TypeScript was rejected because it would create two sources
  of truth for units, periodicity, spin channels, and non-orthogonal grids.
- Converting everything to Cube before display was rejected because it loses
  format-specific channel and periodic metadata.

## Consequences

FileParser gains a dedicated `VolumeIO` path. Frontend validators still reject
invalid manifests, but do not reinterpret scientific formats.

## Revisit condition

Revisit only if a future browser-only product is explicitly required. It must
still share frozen cross-language oracle fixtures.
