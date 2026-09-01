# KSSOLV Toolbox

[![Github Release Version](https://img.shields.io/github/v/release/USTC-Hu-Group/KSSOLV-Toolbox?color=blue&include_prereleases)](https://github.com/USTC-Hu-Group/KSSOLV-Toolbox/releases/latest)
[![License: BUSL-1.1](https://img.shields.io/badge/license-BUSL--1.1-blue)](https://github.com/USTC-Hu-Group/KSSOLV-Toolbox/blob/main/LICENSE)
[![GitHub top language](https://img.shields.io/github/languages/top/USTC-Hu-Group/KSSOLV-Toolbox)](https://matlab.mathworks.com/)
![MATLAB Versions Tested](https://img.shields.io/badge/tested%20with-R2026b%20%7C%20R2026a%20%7C%20R2025b-blue)

**KSSOLV Toolbox** is a MATLAB-based graphical tool designed to make running density functional theory (DFT) calculations provided by the **Kohn-Sham Solver (KSSOLV)** package easier and more intuitive. It helps researchers avoid writing complex scripts and instead complete the full workflow—from structure import and calculation setup to post-analysis—through a user-friendly interface.

![KSSOLV Toolbox crystal modeling workspace](https://github.com/USTC-Hu-Group/KSSOLV-Toolbox/blob/main/assets/kssolv-crystal-modeling.png)

![KSSOLV Toolbox GUI](https://github.com/USTC-Hu-Group/KSSOLV-Toolbox/blob/main/assets/KSSOLV%20Toolbox%20GUI.png)

## Key Features

KSSOLV Toolbox brings structure preparation, workflow execution, and result
analysis into a single project-based workspace:

- **Interactive materials modeling**: Build and edit molecules, crystals,
  surfaces, interfaces, defects, polymers, and amorphous structures in a 3D
  workspace with previews, measurements, and undoable operations.
- **Workflow-driven DFT calculations**: Configure and connect calculation tasks,
  including SCF and Non-SCF workflows, without assembling a collection of
  standalone MATLAB scripts.
- **Scientific visualization and analysis**: Inspect atomic structures, band
  structures, and CHGCAR, Cube, or XSF scalar fields using isosurfaces,
  lattice-aligned slices, direct volume rendering, and export tools.
- **Flexible local and remote execution**: Run calculations locally or use
  supported MATLAB Parallel Server, Slurm, remote MATLAB, and cluster-profile
  configurations while tracking jobs and importing completed results.
- **Reproducible modeling and automation**: Record and replay modeling
  operations, run batch preparation tasks, and use versioned MATLAB APIs for
  scripted workflows.

## Installation

**KSSOLV Toolbox** supports installation and usage within the **MATLAB® desktop environment**, and also provides a **standalone application version** that can be deployed on Windows, macOS, and Linux platforms.

For installation, usage, and feature guides, see the
[User Documentation](docs/README.md).

## Contributing

**🎯 Contributions via Issues and PRs are welcome!**

- **New feature?** Please open an Issue describing the request. After discussion and confirmation, you may submit a PR.  
- **Bug fix?** You may directly submit a PR—just include a clear description of the issue and your fix.

> By submitting code, documentation, or any other contribution to this project,
> the contributor represents that they have the right to submit it and, to the
> fullest extent permitted by law, automatically and unconditionally assigns to
> the **KSSOLV Development Team** (the Rights Holder), on a perpetual,
> irrevocable, worldwide, and royalty-free basis, all transferable economic
> copyrights and related rights in the contribution. To the extent that any such
> right cannot legally be assigned, or the assignment is ineffective, the
> contributor grants the Rights Holder a perpetual, irrevocable, worldwide,
> royalty-free, transferable, and fully sublicensable license to use, reproduce,
> modify, adapt, publish, distribute, and relicense the contribution under any
> terms, including BUSL-1.1, the Change License, and commercial licenses.
> Submission of a contribution constitutes acceptance of these terms.

## License

The original portions of **KSSOLV Toolbox** are available under the
**Business Source License 1.1 (BUSL-1.1)**:

- Non-production use is permitted under BUSL-1.1.
- Production use is permitted for teaching and education, qualifying academic
  or personal research, and qualifying charitable or nonprofit activities, as
  specified in the `Additional Use Grant`.
- Other production use, including commercial research and development,
  requires a separate [commercial license](COMMERCIAL-LICENSE.md).
- On **July 22, 2030**, or the fourth anniversary of a version's first public
  distribution under BUSL-1.1, whichever comes first, that version will become
  available under **GNU GPL v3.0 or later**.

BUSL-1.1 is a source-available license and is not an Open Source license before
the applicable Change Date. Third-party components remain under their
respective licenses; see [Third-Party Licenses](THIRD-PARTY-LICENSES.md).
Releases distributed before this license change remain subject to the licenses
that accompanied those releases.

## Citation

If you use **KSSOLV Toolbox** in your research or publications, please cite the following work.

```latex
@article{YangLiu_KSSOLV_Toolbox_2026,
  author = {Yang, Liu and Yang, Jinlong and Hu, Wei},
  title = {KSSOLV Toolbox: A MATLAB Graphical User Interface for Plane-Wave Density Functional Theory Calculations},
  journal = {Journal of Chemical Theory and Computation},
  volume = {22},
  number = {11},
  pages = {5579--5593},
  year = {2026},
  doi = {10.1021/acs.jctc.6c00523},
  note = {PMID: 42175909},
  url = {https://doi.org/10.1021/acs.jctc.6c00523},
  eprint = {https://doi.org/10.1021/acs.jctc.6c00523}
}
```
