#!/usr/bin/env python3
"""Freeze versioned pymatgen molecule facts used by Babel parity tests.

OpenBabel itself is intentionally not a production or oracle-generation
dependency here.  Coordinates are read from the official pymatgen fixtures,
then formulas and geometry facts are evaluated with frozen pymatgen core.
"""

from __future__ import annotations

import json
from pathlib import Path

from pymatgen.core import Molecule
from pymatgen.io.xyz import XYZ


ROOT = Path(__file__).resolve().parents[2]
UPSTREAM = Path("/tmp/matgenlab-plan.tMNeV8/pymatgen-core-2026.7.24")
FILES = UPSTREAM / "test-files" / "io"


def pdb_molecule(path: Path) -> Molecule:
    species, coordinates = [], []
    for line in path.read_text().splitlines():
        if line.startswith(("ATOM  ", "HETATM")):
            species.append((line[76:78].strip() or line[12:16].strip())[0:2].strip())
            coordinates.append(
                [float(line[30:38]), float(line[38:46]), float(line[46:54])]
            )
    return Molecule(species, coordinates)


def main() -> None:
    ethane = pdb_molecule(FILES / "babel" / "Ethane_e.pdb")
    frames = XYZ.from_file(FILES / "xyz" / "multiple_frame.xyz").all_molecules
    methane = Molecule(
        ["C", "H", "H", "H", "H"],
        [
            [0, 0, 0],
            [0, 0, 1.089],
            [1.026719, 0, -0.363],
            [-0.513360, -0.889165, -0.363],
            [-0.513360, 0.889165, -0.363],
        ],
    )
    result = {
        "pymatgen_core_version": "2026.7.24",
        "source": "pymatgen-core test-files/io",
        "methane": {
            "formula": methane.formula,
            "atomic_numbers": list(methane.atomic_numbers),
            "carbon_hydrogen_distances": [
                methane.get_distance(0, index) for index in range(1, 5)
            ],
        },
        "ethane_pdb": {
            "formula": ethane.formula,
            "atom_count": len(ethane),
            "first_coordinate": ethane.cart_coords[0].tolist(),
            "last_coordinate": ethane.cart_coords[-1].tolist(),
        },
        "multiple_xyz": {
            "frame_count": len(frames),
            "first_formula": frames[0].formula,
            "last_formula": frames[-1].formula,
            "first_atom_count": len(frames[0]),
            "last_atom_count": len(frames[-1]),
        },
    }
    output = ROOT / "dev" / "matgenlab" / "oracles" / "babel_2026.7.24.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
