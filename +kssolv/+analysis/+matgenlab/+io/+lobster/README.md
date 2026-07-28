# LOBSTER I/O compatibility package

This package is the MATLAB implementation of the frozen
`pymatgen.io.lobster` inventory from pymatgen `v2026.7.24`. The compatibility
ledger contains 282 upstream inventory entries: 281 runtime APIs are
implemented and the remaining entry is Python's `from __future__ import
annotations` compiler directive, which has no MATLAB runtime counterpart.

The implementation includes:

- legacy and `future` LOBSTER input models, basis-set discovery, diffing,
  MSON-style serialization, and deterministic file output;
- parsers and data models for COHP/COOP/COBI, integrated bond lists, DOS,
  charge and gross populations, fat bands, band overlaps, wavefunctions,
  Madelung/site-potential data, matrices, polarization, BWDF, and
  `lobsterout`;
- legacy adapters that preserve the frozen public class and property names;
- MATLAB plotting for COXX, DOS, and BWDF data;
- transparent reading of plain-text and gzip-compressed LOBSTER files.

MATLAB arrays use one-based indexing. Labels stored in LOBSTER files are
preserved verbatim, while query methods that correspond to Python list
positions retain the upstream zero-based result convention.

`LobsterRunner` is the only external-execution boundary. It refuses to start
an executable unless the caller explicitly passes `allow_external=true`;
parsing, modeling, serialization, and plotting are otherwise pure MATLAB.

## Verification

`LobsterIOTest` exercises frozen official upstream fixtures. The independent
`LobsterOracleParityTest` invokes the frozen Python pymatgen environment only
as a test oracle and compares numerical parser results. The production
package has no Python dependency.

The package and both test classes pass MATLAB `checkcode` without warnings.
Inventory status and evidence are recorded in
`dev/matgenlab/api_status_overrides.csv` and the generated compatibility
ledger.
