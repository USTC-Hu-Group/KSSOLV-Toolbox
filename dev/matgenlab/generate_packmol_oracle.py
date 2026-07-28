#!/usr/bin/env python3
"""Freeze pymatgen-core 2026.7.24 PACKMOL input-generation behavior."""

from __future__ import annotations

import json
from pathlib import Path

from pymatgen.core import Molecule
from pymatgen.io.packmol import PackmolBoxGen


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "dev" / "matgenlab" / "oracles" / "packmol_2026.7.24.json"

ETHANOL = Molecule(
    ["C", "C", "O", "H", "H", "H", "H", "H", "H"],
    [
        [0.00720, -0.56870, 0.00000],
        [-1.28540, 0.24990, 0.00000],
        [1.13040, 0.31470, 0.00000],
        [0.03920, -1.19720, 0.89000],
        [0.03920, -1.19720, -0.89000],
        [-1.31750, 0.87840, 0.89000],
        [-1.31750, 0.87840, -0.89000],
        [-2.14220, -0.42390, -0.00000],
        [1.98570, -0.13650, -0.00000],
    ],
)
WATER = Molecule(
    ["H", "H", "O"],
    [[9.626, 6.787, 12.673], [9.626, 8.420, 12.673], [10.203, 7.604, 12.673]],
)


def serialise(input_set) -> dict:
    return {
        "keys": list(input_set.inputs),
        "inputs": dict(input_set.inputs),
        "seed": input_set.seed,
        "inputfile": str(input_set.inputfile),
        "outputfile": str(input_set.outputfile),
        "stdoutfile": str(input_set.stdoutfile),
        "tolerance": input_set.tolerance,
    }


def main() -> None:
    fixtures = (
        ROOT
        / "+kssolv"
        / "+analysis"
        / "+matgenlab"
        / "+test"
        / "+io"
        / "+fixtures"
        / "+packmol"
    )
    molecules = [
        {"name": "water", "number": 10, "coords": WATER},
        {"name": "ethanol", "number": 20, "coords": ETHANOL},
    ]
    default = PackmolBoxGen().get_input_set(molecules)
    explicit_box = PackmolBoxGen(
        seed=-1,
        control_params={"maxit": 0, "movebadrandom": [1, 2, 3]},
        inputfile="input.in",
        outputfile="output with spaces.xyz",
        stdoutfile="stdout.txt",
    ).get_input_set(molecules, box=[0, 0, 0, 20, 21, 22])
    constrained = PackmolBoxGen(
        inputfile="input.in",
        outputfile="output.xyz",
        stdoutfile="stdout.txt",
        control_params={"precision": 0.001},
    ).get_input_set(
        [
            {
                "name": "water",
                "number": 5,
                "coords": WATER,
                "constraints": ["inside sphere 0 0 0 10"],
                "atoms_constraints": [
                    {"indices": [2], "constraints": ["inside sphere 0 0 0 5"]},
                    {"indices": [0, 1], "constraints": ["outside sphere 0 0 0 5.5"]},
                ],
            }
        ]
    )
    from_paths = PackmolBoxGen().get_input_set(
        [
            {
                "name": "EMC",
                "number": 10,
                "coords": fixtures / "subdir with spaces" / "EMC.xyz",
            },
            {
                "name": "LiTFSi",
                "number": 20,
                "coords": fixtures / "LiTFSi.xyz",
            },
        ]
    )
    data = {
        "pymatgen_core_version": "2026.7.24",
        "default": serialise(default),
        "explicit_box": serialise(explicit_box),
        "constrained": serialise(constrained),
        "from_paths": serialise(from_paths),
    }
    OUTPUT.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
