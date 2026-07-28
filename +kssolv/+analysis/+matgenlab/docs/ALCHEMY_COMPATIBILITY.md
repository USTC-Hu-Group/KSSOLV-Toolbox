# Alchemy compatibility

The implementation is frozen against the `pymatgen-core` source declared in
`dev/matgenlab/upstream_baseline.json` (commit
`c71faa7a95df9bbcd20cb3d14ff112d0f72d8e39`). The denominator is read directly
from `dev/matgenlab/inventory/api.csv`.

| Frozen module | Classes | Methods | Properties | Functions | Implemented |
| --- | ---: | ---: | ---: | ---: | ---: |
| `pymatgen.alchemy.filters` | 7 | 12 | 0 | 0 | 19/19 |
| `pymatgen.alchemy.materials` | 1 | 14 | 2 | 0 | 17/17 |
| `pymatgen.alchemy.transmuters` | 3 | 12 | 0 | 1 | 16/16 |
| **Total** | **11** | **38** | **2** | **1** | **52/52** |

`AlchemyInventoryTest` resolves all 52 rows to concrete MATLAB classes,
methods, properties, or functions. Behavioral tests cover every class and the
stateful paths: strict/non-strict species matching, proximity checks,
duplicate/existing matching, charge and distance filtering, transformation
history, one-to-many branching, undo/redo, filter provenance, StructureNL,
MSON/TypeRegistry round trips, multi-block CIF, POSCAR, parameters/tags, and
batch VASP input writing.

Official upstream fixtures are vendored in
`+test/+alchemy/+fixtures`: `transformations.json`, `MultiStructure.cif`,
`LiFePO4.cif`, `Li10GeP2S12.cif`, and `POSCAR`.

## External boundary

`MPRelaxSet` and the broader `pymatgen.io.vasp.sets` package are outside this
frozen module set. `get_vasp_input`, `write_vasp_input`, and
`batch_write_vasp_input` therefore accept an explicit VaspInputSet-compatible
factory or object. Calling those APIs without an injected input set raises a
stable diagnostic instead of silently fabricating VASP settings. Once the
sets package is ported, its `MPRelaxSet` constructor can be supplied directly
without changing alchemy.
