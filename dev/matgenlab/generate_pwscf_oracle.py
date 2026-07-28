#!/usr/bin/env python3
"""Generate the frozen pymatgen-core PWSCF parity oracle."""

from __future__ import annotations

import json
from pathlib import Path

from pymatgen.core import Structure
from pymatgen.io.pwscf import PWInput, PWOutput


ROOT = Path(__file__).resolve().parents[2]
FIXTURE = (
    ROOT
    / "+kssolv"
    / "+analysis"
    / "+matgenlab"
    / "+test"
    / "+io"
    / "+fixtures"
    / "+pwscf"
    / "Si.pwscf.out"
)
OUTPUT = ROOT / "dev" / "matgenlab" / "oracles" / "pwscf_2026.7.24.json"


def main() -> None:
    structure = Structure(
        [[2.9, 0.1, 1.5], [0.9, 2.7, 1.5], [0.1, 0.1, 3.3]],
        ["O", "Li", "Li"],
        [[0, 0, 0], [0.75, 0.75, 0.75], [0.25, 0.25, 0.25]],
    )
    pw_input = PWInput(
        structure,
        pseudo={"Li": "Li.UPF", "O": "O.UPF"},
        control={"calculation": "scf", "pseudo_dir": "./"},
        system={"ecutwfc": 50},
    )
    pw_output = PWOutput(FIXTURE)
    crystal = PWInput(
        structure,
        pseudo={"Li": "Li.UPF", "O": "O.UPF"},
        kpoints_mode="crystal_b",
        kpoints_grid=[[0, 0, 0], [0, 0.5, 0.5], [0.5, 0.5, 0.5]],
        format_options={
            "coord_decimals": 8,
            "kpoints_crystal_b_indent": 2,
            "kpoints_grid_decimals": 5,
        },
    )
    result = {
        "upstream": "pymatgen-core 2026.7.24",
        "automatic_input": str(pw_input),
        "crystal_b_input": str(crystal),
        "output": {
            "final_energy": pw_output.final_energy,
            "lattice_type": pw_output.lattice_type,
            "celldm": [pw_output.get_celldm(index) for index in range(1, 7)],
            "energies": pw_output.data["energies"],
            "nkpts": pw_output.data["nkpts"],
        },
        "proc_val": {
            "degauss": PWInput.proc_val("degauss", "7.3498618000d-03"),
            "nat": PWInput.proc_val("nat", "2"),
            "nosym": PWInput.proc_val("nosym", ".TRUE."),
            "smearing": PWInput.proc_val("smearing", "'cold'"),
        },
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
