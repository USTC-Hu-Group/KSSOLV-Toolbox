# VASP outputs compatibility

The native MATLAB implementation targets the frozen public inventory for
`pymatgen.io.vasp.outputs` from `pymatgen-core` 2026.7.24.

## Coverage

- The frozen inventory contains 126 rows: 21 classes, 65 methods, 38
  properties, and 2 functions.
- Getter/setter duplicates reduce this to 124 unique compatibility-ledger API
  identifiers.
- All 126 rows have explicit `implemented` evidence in
  `dev/matgenlab/api_status_overrides.csv`.
- `VaspOutputsFrozenOracleTest` exercises XML, text, compressed text, HDF5,
  direct-access binary, and Fortran-record output formats using official
  upstream fixtures and frozen scalar/array oracle values.

The production implementation is native MATLAB and does not invoke Python.
Python was used only to freeze the checked-in oracle values.

## Boundaries

POTCAR data is licensed separately by VASP and is not redistributed. Output
readers parse the POTCAR titles/specifications embedded in public output
fixtures. APIs that search for full POTCAR data (`get_potcars`,
`update_potcar_spec`, and `update_charge_from_potcar`) return without mutation
when explicitly disabled or when no authorized local POTCAR is found.

No VASP executable is launched by this package. XML, OUTCAR-family text,
volumetric grids, WAVECAR/WAVEDER/WSWQ, `vaspout.h5`, and `vaspwave.h5` are
parsed locally. Standard `.gz` compression and HDF5 use MATLAB built-ins.
Reading or writing `.bz2` HDF5 files requires a system `bzip2` executable and
raises a stable package error if it is unavailable.

Wavefunction partial charges intentionally follow pymatgen's boundary: PAW
augmentation is not reconstructed by `Wavecar.get_parchg` or
`Vaspwave.get_parchg`. Existing CHGCAR/vaspwave augmentation data is preserved
when it is present in the source file.

Optional upstream Python dependencies such as `h5py` and `numpy` are not
runtime dependencies. HDF5 support requires MATLAB's HDF5 functions; no
silent Python fallback is used.

## Verification

```matlab
r = runtests( ...
    "+kssolv/+analysis/+matgenlab/+test/+io/" + ...
    "VaspOutputsFrozenOracleTest.m");
assertSuccess(r)
```

All MATLAB files in `+io/+vasp` and the outputs oracle test pass
`checkcode(..., "-id")` with zero findings.
