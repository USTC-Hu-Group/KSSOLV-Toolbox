#!/usr/bin/env python3
"""Freeze pymatgen-core v2026.7.24 Bader ACF parser behavior."""

from __future__ import annotations

import contextlib
import json
from pathlib import Path

from pymatgen.command_line.bader_caller import BaderAnalysis


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = (
    ROOT
    / "+kssolv"
    / "+analysis"
    / "+matgenlab"
    / "+test"
    / "+command_line"
    / "+fixtures"
    / "+bader"
)
OUTPUT = (
    ROOT
    / "dev"
    / "matgenlab"
    / "oracles"
    / "bader_caller_2026.7.24.json"
)


def main() -> None:
    analysis = BaderAnalysis.__new__(BaderAnalysis)
    with contextlib.chdir(FIXTURES):
        parsed = analysis._parse_acf()
    nelects = [8] * 6 + [6] * 8
    oracle = {
        "metadata": {
            "source": "pymatgen-core",
            "tag": "v2026.7.24",
            "module": "pymatgen.command_line.bader_caller",
            "api_count": 11,
            "fixture": "ACF.dat",
        },
        "data": parsed,
        "vacuum_charge": analysis.vacuum_charge,
        "vacuum_volume": analysis.vacuum_volume,
        "nelectrons": analysis.nelectrons,
        "charge_transfer": [
            row["charge"] - nelect for row, nelect in zip(parsed, nelects, strict=True)
        ],
        "partial_charge": [
            nelect - row["charge"] for row, nelect in zip(parsed, nelects, strict=True)
        ],
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(oracle, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
