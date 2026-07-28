# VASP input-set compatibility

This package is a native MATLAB port of the public API inventory for
`pymatgen.io.vasp.sets` in pymatgen-core 2026.7.24.

## Coverage

- All 96 frozen inventory rows are implemented and have per-API evidence in
  `dev/matgenlab/api_status_overrides.csv`.
- The 29 public classes include the configurable base, MP/MIT relaxation and
  static sets, HSE/SOC/NMR/GW/absorption sets, molecular-dynamics sets, and
  NEB/CINEB sets.
- The nine upstream YAML configurations are stored as merged frozen JSON.
  Production execution reads these files directly and never invokes Python.
- `VaspInputSet` composes the native `Incar`, `Kpoints`, `Poscar`, `Potcar`,
  and `VaspInput` implementations.

## Licensed POTCAR boundary

Real POTCAR datasets are never read implicitly. `allow_potcar` defaults to
`false`; requesting `potcar` or a normal POTCAR-backed input set then raises
`KSSOLV:Matgenlab:VaspInputSet:PotcarAuthorization`. Portable generation uses
`potcar_spec=true`, which writes only public POTCAR symbols. Setting
`allow_potcar=true` is an explicit authorization and still requires a valid
local VASP pseudopotential installation.

## Evidence

`VaspSetsTest` uses official Si and NEB POSCAR fixtures and a frozen Python
oracle generated with pymatgen-core 2026.7.24. It verifies representative
INCAR/KPOINTS/POTCAR-symbol parity, every concrete set's construction,
directory write/read, previous-run inheritance, serialization, the licensed
POTCAR boundary, NEB image layout, and numerical helpers.
