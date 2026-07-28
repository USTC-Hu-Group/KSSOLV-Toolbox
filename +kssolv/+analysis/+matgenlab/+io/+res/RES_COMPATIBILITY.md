# `pymatgen.io.res` compatibility

This package is a MATLAB-native port of the 47 public inventory rows in
`pymatgen.io.res`, frozen from `pymatgen-core` 2026.7.24 (within the
repository-wide `pymatgen` 2026.5.4 baseline).

The port covers ShelX/AIRSS record formatting, parsing, structures, magnetic
moments, `ComputedStructureEntry`, AIRSS title and REM metadata, MSON
round-trips, strict/gentle error behavior, plain files, and gzip files. The
official `coc-115925-9326-14.res` and `spins-in-last-col.res` fixtures are
vendored under the test package. Expected values in `res_oracle.json` were
generated once with the frozen Python environment; production and tests do not
execute Python.

## Deliberate platform boundaries

- RES parsing and writing does not invoke AIRSS, CASTEP, a database, or any
  other external executable.
- MATLAB `datetime` with a date-only display represents Python `date` values.
- Plain UTF-8 and `.gz` files are handled natively. Monty's additional optional
  `.bz2`, `.xz`, and `.lzma` compression transports are outside this MATLAB
  module boundary; decompress those transports before reading.
- When an entry has no `data.seed`, upstream uses Python's process-dependent
  object hash. This port uses a deterministic `matgenlab-<reduced-formula>`
  seed so serialized output remains reproducible.
- Python exception classes map to stable MATLAB identifiers
  `KSSOLV:Matgenlab:ResParseError` and `KSSOLV:Matgenlab:ResError`.
