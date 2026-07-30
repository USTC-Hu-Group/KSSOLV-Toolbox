# ADR-005: Heavy volume computation runs in workers

- Status: accepted
- Date: 2026-07-29

## Decision

Decode, histogram, percentile, resampling, and marching-cubes work runs in
dedicated Web Workers using transferable ArrayBuffers. The main thread owns
Vue state, Three.js resources, and user interaction.

## Alternatives

Main-thread computation was rejected because isovalue changes and large-grid
statistics would make camera interaction unresponsive.

## Consequences

Every worker request has an ID and cancellation path. Geometry and derived
data caches have explicit budgets and are cleared when the document closes.

## Revisit condition

GPU compute may replace selected worker algorithms after deterministic CPU
oracles and fallback behavior exist.
