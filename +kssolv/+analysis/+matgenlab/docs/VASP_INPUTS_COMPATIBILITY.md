# VASP inputs compatibility

## Frozen source and denominator

The implementation targets
`pymatgen-core` v2026.7.24
(`c71faa7a95df9bbcd20cb3d14ff112d0f72d8e39`),
`pymatgen.io.vasp.inputs`.

The generated upstream inventory contains 101 public rows for this module:
13 classes, 56 methods, and 32 property accessors. All 101 rows have a native
MATLAB implementation in `kssolv.analysis.matgenlab.io.vasp`.

The upstream development utility `PotcarScrambler` is also implemented.
`BadPotcarWarning` and `PotcarHashMismatch` are compatibility categories
requested by downstream callers. The frozen core release itself exposes
`UnknownPotcarWarning` and no longer performs cryptographic POTCAR validation.

## Compatibility state

| Surface | State | Notes |
|---|---|---|
| `Poscar` / `BadPoscarWarning` | implemented | Structure, MD sections, selective dynamics, VASP 4/5/6, compression, MSON mapping |
| `Incar` / `BadIncarWarning` | implemented | Case-insensitive mapping, frozen parameter database, type processing, formatting, diff, warnings, compression |
| `KpointsSupportedModes` / `Kpoints` | implemented | All six modes, tetrahedra, line mode, automatic-density algorithms, MSON mapping |
| `Orbital` / `OrbitalDescription` | implemented | Typed POTCAR PSCTR records |
| `PotcarSingle` / `Potcar` | implemented | Parsing, summary statistics, identification, specs, concatenation, compression |
| `PmgVaspPspDirError` | implemented | Stable MATLAB error identifier |
| `UnknownPotcarWarning` | implemented | Stable MATLAB warning identifier |
| `VaspInput` | implemented | Standard/optional files, directory and archive I/O, copying, explicit VASP execution |
| POTCAR library lookup | external | Requires user-owned `PMG_VASP_PSP_DIR`; restricted POTCAR data is never bundled |
| `Potcar.from_spec` data materialization | external | Requires compatible user-owned POTCAR files under `PMG_VASP_PSP_DIR` |
| `VaspInput.run_vasp` execution | external | Requires caller-supplied `vasp_cmd` or `PMG_VASP_EXE` |

MATLAB MSON dictionaries use `x_module` and `x_class` because MATLAB struct
field names cannot contain `@`. This is the repository-wide mapping for Python
`@module` and `@class`.

Likewise, the `POTCAR.spec` dictionary key is represented as `POTCAR_spec`
inside a MATLAB struct because a dot is not a valid MATLAB field name. File
I/O continues to use the exact `POTCAR.spec` filename.

`KpointsSupportedModes` exposes the same six stable names as string constants
rather than Python `Enum` instances. `Kpoints.style` therefore returns a string
scalar while preserving parsing, comparison, serialization, and emitted-file
semantics.

## POTCAR validation baseline

`incar_parameters.json` and `potcar-summary-stats.json.bz2` are byte-identical
copies of the frozen MIT-licensed, non-invertible upstream metadata assets.
No raw POTCAR is committed.

The frozen v2026.7.24 summary database no longer recognizes some older
copyright-safe fake POTCAR fixtures shipped in the same tag. Frozen Python
returns `is_valid == false` and emits `UnknownPotcarWarning` for those files;
MATLAB deliberately reproduces that behavior rather than silently accepting
them.

## Verification

- The official INCAR fixture serializes byte-for-byte like frozen Python.
- Seven official KPOINTS fixtures cover Automatic, Gamma, Monkhorst, basis,
  line-mode, explicit, and tetrahedron formats; all serialize byte-for-byte
  like frozen Python.
- All 39 official copyright-safe fake POTCAR archives parse, yielding 42
  datasets.
- The official three-dataset `POTCAR.gz` parse/write result is byte-identical
  to the decompressed source.
- A static 2026.7.24 oracle is bundled beside official INCAR, POSCAR, and seven
  KPOINTS fixtures. It does not need Python at test runtime.
- The static oracle additionally covers positional and named KPOINTS
  construction, every automatic constructor including line mode, synthetic
  POTCAR metadata, POTCAR spec/error behavior, optional VaspInput files, and
  native command execution.
- `PoscarTest`, `VaspInputsTest`, `VaspInputsFrozenOracleTest`, and
  `VaspSetsTest` contain 52 passing tests with the pinned reference
  environment enabled.
- All 101 inventory rows have explicit evidence overrides; duplicate
  getter/setter inventory rows share the same unique API identifier.
