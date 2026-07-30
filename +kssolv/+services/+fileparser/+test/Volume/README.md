# Volume parser fixtures

These files are frozen, redistributable test inputs from
[`materialsproject/pymatgen-core`](https://github.com/materialsproject/pymatgen-core)
at commit `c71faa7a95df9bbcd20cb3d14ff112d0f72d8e39` (tag
`v2026.7.24`, MIT license).

| Local file | Upstream path | SHA-256 |
| --- | --- | --- |
| `CHGCAR.nospin.gz` | `test-files/io/vasp/outputs/CHGCAR.nospin.gz` | `1d0f7cab991845fb6b5576839727948d189d339e908c5908ea8ffd935337a715` |
| `CHGCAR.spin.gz` | `test-files/io/vasp/outputs/CHGCAR.spin.gz` | `43c3b6db491b08868f8e49b3114396c88090dd47aa7837eac27729865756253e` |
| `elec.cube.gz` | `test-files/command_line/bader/elec.cube.gz` | `4d3e32d374920e2a1210ebc718ad2f358751ea1861190281fce2ad4d2a0fb8df` |
| `datagrid_3d.xsf` | `test-files/io/xcrysden/datagrid_3d.xsf` | `c0a8ec512661c1ffa4c20fb922f52972ee825c01078976e2ee076729b60972c5` |

The fixtures are intentionally stored beside `VolumeIOTest.m`, rather than
being reached through matgenlab's own fixture tree. This keeps the public
FileParser contract reproducible and prevents an unrelated matgenlab fixture
reorganization from weakening FileParser coverage.

Generated fixtures for malformed input, analytic scalar fields, negative
`NATOMS`, and `NVAL` Cube variants are created in tests so their exact intent
is visible in the test source.
