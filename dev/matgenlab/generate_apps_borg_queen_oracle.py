#!/usr/bin/env python3
"""Freeze pymatgen 2026.5.4 BorgQueen behavior."""

from __future__ import annotations

import json
from pathlib import Path

from pymatgen.apps.borg.hive import VaspToComputedEntryDrone
from pymatgen.apps.borg.queen import BorgQueen


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = (
    ROOT
    / "+kssolv"
    / "+analysis"
    / "+matgenlab"
    / "+test"
    / "+apps"
    / "+borg"
    / "+fixtures"
    / "+queen"
)
OUTPUT = (
    ROOT / "dev" / "matgenlab" / "oracles" / "apps_borg_queen_2026.5.4.json"
)


def main() -> None:
    drone = VaspToComputedEntryDrone()
    queen = BorgQueen(drone, FIXTURES, 1)
    entry = queen.get_data()[0]
    loaded = BorgQueen(drone)
    loaded.load_data(FIXTURES / "assimilated.json")
    data = {
        "pymatgen_version": "2026.5.4",
        "serial": {
            "count": len(queen.get_data()),
            "energy": entry.energy,
            "formula": entry.reduced_formula,
        },
        "loaded_count": len(loaded.get_data()),
        "loaded_energy": loaded.get_data()[0]["energy"],
    }
    OUTPUT.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
