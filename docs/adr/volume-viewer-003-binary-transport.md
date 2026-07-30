# ADR-003: uihtml uses chunked binary transport

- Status: accepted
- Date: 2026-07-29

## Decision

Encode interactive grids as little-endian Float32 or quantized Uint16, split
them into bounded chunks, and carry them through named `uihtml` events with
request IDs, sequence numbers, cancellation, and checksums.

## Alternatives

- JSON number arrays were rejected because of size, parse cost, and transient
  memory multiplication.
- Temporary files and browser-local fetch were rejected as the mandatory path
  because MATLAB installation paths and browser file access vary by platform.

## Consequences

The full-resolution grid stays in MATLAB. Frontend assembly is deterministic,
cancelable, and testable with out-of-order and corrupt chunks.

## Revisit condition

A local binary side channel may be added as an optimization only after it is
proven portable in supported MATLAB releases; chunked events remain fallback.
