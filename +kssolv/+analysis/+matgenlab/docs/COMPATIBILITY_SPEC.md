# matgenlab P0 compatibility specification

## Compatibility contract

The frozen commits in `UPSTREAM_SOURCES.md` define the reference behavior.
matgenlab is production-compatible only when each inventoried public item is in
exactly one auditable state:

- `implemented`: MATLAB behavior passes its applicable differential tests;
- `external`: behavior is available when the named external program/data source
  is installed and configured;
- `unsupported-upstream`: the frozen upstream itself marks the behavior
  unavailable on the target platform;
- `license-blocked`: redistribution is forbidden, while compatible
  user-supplied configuration and parsing remain implemented.

Missing, planned, and silently skipped are not release states. Platform or
dependency exclusions must name their predicate and linked upstream tests.

## API mapping

- Python `pymatgen.<area>` maps to
  `kssolv.analysis.matgenlab.<area>`.
- Public Python classes map to MATLAB `classdef` classes with the same semantic
  name. Public functions use the same semantic name unless MATLAB syntax
  forbids it; exceptions require a recorded mapping.
- Python keyword arguments map to MATLAB `name=value` arguments. Defaults,
  accepted types, validation order, warnings, and failure conditions are part
  of the compatibility surface.
- Overloads that Python resolves dynamically may use explicit MATLAB methods,
  but results and accepted domains must remain equivalent.
- MATLAB indices exposed to callers are one-based. Differential fixtures and
  serialized compatibility records must include an explicit `index_base` field
  whenever an integer represents an index. Conversion occurs only at the
  language boundary.

## Data model

- Collections of coordinates are `N-by-3` row arrays.
- Fractional coordinates and Cartesian coordinates are never inferred from
  magnitude; the API or serialized field identifies the coordinate system.
- Lattice vectors follow the same row-vector convention used by pymatgen.
- Periodic images are integer `N-by-3` row arrays.
- Species/site ordering is stable unless the corresponding upstream operation
  documents reordering.
- Units follow the frozen upstream API. Public values whose units are not
  encoded in a type must document them. Unit conversion is explicit and tested.
- Occupancies, oxidation states, spin, charge, and site properties must survive
  object copying, transformations, and serialization without lossy coercion.

## Serialization

matgenlab implements a MSON-compatible dictionary representation. Frozen
pymatgen `as_dict` JSON is accepted, including `@module`, `@class`, and supported
version metadata. MATLAB serialization must be deterministic after normalizing
dictionary key ordering and numeric formatting.

JSON `null`, Python `None`, MATLAB missing values, empty numeric arrays, and
empty collections are distinct when the upstream schema distinguishes them.
Non-finite values require an explicit schema rule and may not silently become
JSON strings.

## Numerical comparison

A single global tolerance is forbidden. Differential tests select a documented
domain profile:

| Profile | Default comparison |
|---|---|
| exact | strings, identifiers, counts, ordering, integer arrays, symmetry labels |
| scalar | `abs(a-b) <= atol + rtol*abs(b)` with API-specific `atol`/`rtol` |
| coordinates | periodic minimum-image difference plus coordinate tolerance |
| lattice | metric/volume/angle comparison plus orientation when significant |
| structure | species, occupancy, properties, periodic sites, and ordering policy |
| spectrum | axes, labels, interpolation policy, normalization, and value tolerance |

Tolerance values belong to individual oracle metadata and must be tight enough
to reveal algorithmic differences. NaN equality, signed zero, infinities,
degeneracies, and eigenvector phase/order are explicit per test.

## Errors and warnings

MATLAB exception identifiers map to frozen Python exception categories in the
compatibility ledger. Tests verify both the failure condition and stable
identifier; message text is compared only when users or file formats rely on it.
Warnings may not be dropped merely because MATLAB and Python warning mechanisms
differ.

## Differential-test protocol

1. Run the exact frozen Python commit in a recorded Python/dependency
   environment.
2. Serialize inputs and reference outputs using a versioned oracle schema.
3. Run MATLAB on the same logical input with explicit index base, units, random
   seed, and numerical profile.
4. Compare values, types, ordering, warnings/errors, and relevant invariants.
5. For file I/O, compare parsed semantics and perform a parse-write-parse
   round-trip; byte equality is required only for formats that promise it.

Reference results generated from another pymatgen version are invalid. Random,
locale, timezone, filesystem-order, BLAS-thread, and network-dependent behavior
must be controlled or recorded.

## P0 acceptance gate

P0 is accepted only when:

- both official tags resolve to the declared full commits;
- every declared source module parses or has a recorded parse failure;
- public class/function/member signatures, module paths, tests, and fixtures are
  present in machine-readable JSON and normalized CSV;
- each source, test, and fixture row carries provenance and/or a SHA-256 hash;
- regeneration from verified checkouts is byte-for-byte reproducible;
- compatibility, indexing, coordinates, units, serialization, error, tolerance,
  external-dependency, and licensing rules are documented.

Later phase gates must use the inventory as a denominator. Passing a selected
subset of differential tests cannot establish compatibility for an untracked
public item.
