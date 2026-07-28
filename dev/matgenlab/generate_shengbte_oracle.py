#!/usr/bin/env python3
"""Freeze pymatgen-core 2026.7.24 ShengBTE Control behavior."""

from __future__ import annotations

import json
from pathlib import Path

from pymatgen.core import Structure
from pymatgen.io.shengbte import Control


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "dev" / "matgenlab" / "oracles" / "shengbte_2026.7.24.json"


def main() -> None:
    lattice = [
        [0.0, 2.734363999, 2.734363999],
        [2.734363999, 0.0, 2.734363999],
        [2.734363999, 2.734363999, 0.0],
    ]
    structure = Structure(lattice, ["Si", "Si"], [[0, 0, 0], [0.25] * 3])
    control = Control.from_structure(structure, reciprocal_density=50000, scell=[5] * 3)
    restored = control.get_structure()
    temperature = Control(ngrid=[9, 11, 13], temperature={"min": 100, "max": 500, "step": 50})
    data = {
        "pymatgen_core_version": "2026.7.24",
        "from_structure": control.as_dict(),
        "restored_lattice": restored.lattice.matrix.tolist(),
        "restored_frac_coords": restored.frac_coords.tolist(),
        "temperature_range": temperature.as_dict(),
    }
    OUTPUT.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
