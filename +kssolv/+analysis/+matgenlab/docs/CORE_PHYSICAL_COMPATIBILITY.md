# Core physical-object compatibility

Baseline: `pymatgen-core v2026.7.24` (`c71faa7a95df9bbcd20cb3d14ff112d0f72d8e39`).

The implementation covers the public inventory for:

- `pymatgen.core.constants`
- `pymatgen.core.units`
- `pymatgen.core.spectrum`
- `pymatgen.core.tensors`

MATLAB classes are value wrappers around numeric values except `Spectrum`,
which is a handle class because upstream `normalize` and `smear` mutate the
subject. `ArrayWithUnit` and `Tensor` forward parenthesis indexing to their
numeric payload. Indices exposed by MATLAB APIs are 1-based; the tensor
Voigt mapping documents both standard and Voigt index arrays explicitly.

`Unit.as_base_units` maps the upstream Python tuple to a scalar structure
with `units` and `factor` fields. The no-argument conversion-factor functions
(`Ha_to_eV`, `bohr_to_angstrom`, and peers) correspond to upstream module
constants. `Memory.from_str` preserves the one callable alias to which
upstream attaches a factory method.

Tensor structure fitting, population, symmetry reduction, and IEEE rotation
use `kssolv.analysis.spglib.Spglib` directly. No production path invokes
Python. Python is used only by `PhysicalCoreParityTest` as a frozen reference
oracle.

Default spherical integration uses a normalized 20-by-40
Gauss-Legendre/azimuth product rule. It exactly integrates Cartesian tensor
projection polynomials through the ranks used by pymatgen material tensors
and avoids shipping the upstream 79 kB encoded quadrature fixture.
