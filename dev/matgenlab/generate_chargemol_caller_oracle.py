#!/usr/bin/env python3
"""Generate frozen Chargemol parser observables from pymatgen-core."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from pymatgen.command_line.chargemol_caller import ChargemolAnalysis


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = (
    ROOT
    / "+kssolv"
    / "+analysis"
    / "+matgenlab"
    / "+test"
    / "+command_line"
    / "+fixtures"
    / "+chargemol"
)
OUTPUT = ROOT / "dev" / "matgenlab" / "oracles" / "chargemol_caller_2026.7.24.json"


def bond_dict(analysis: ChargemolAnalysis) -> dict[str, object]:
    result: dict[str, object] = {}
    for index, record in analysis.bond_order_dict.items():
        result[str(index)] = {
            "element": record["element"].symbol,
            "bond_order_sum": record["bond_order_sum"],
            "bonded_to": [
                {
                    "index": entry["index"],
                    "element": entry["element"].symbol,
                    "bond_order": entry["bond_order"],
                    "direction": list(entry["direction"]),
                    "spin_polarization": entry["spin_polarization"],
                }
                for entry in record["bonded_to"]
            ],
        }
    return result


def analyze(name: str) -> dict[str, object]:
    analysis = ChargemolAnalysis(FIXTURES / name, run_chargemol=False)
    return {
        "ddec_charges": analysis.ddec_charges,
        "dipoles": analysis.dipoles,
        "bond_order_sums": analysis.bond_order_sums,
        "bond_order_dict": bond_dict(analysis),
        "spin_moments": analysis.ddec_spin_moments,
        "rsquared_moments": analysis.ddec_rsquared_moments,
        "rcubed_moments": analysis.ddec_rcubed_moments,
        "rfourth_moments": analysis.ddec_rfourth_moments,
        "cm5_charges": analysis.cm5_charges,
        "natoms": analysis.natoms,
        "has_structure": analysis.structure is not None,
    }


def main() -> None:
    hashes = {}
    for path in sorted(FIXTURES.rglob("*")):
        if path.is_file():
            hashes[str(path.relative_to(FIXTURES))] = hashlib.sha256(
                path.read_bytes()
            ).hexdigest()
    payload = {
        "metadata": {
            "source": "pymatgen-core",
            "tag": "v2026.7.24",
            "module": "pymatgen.command_line.chargemol_caller",
            "api_count": 7,
            "fixture_sha256": hashes,
        },
        "spin_unpolarized": analyze("spin_unpolarized"),
        "spin_polarized": analyze("spin_polarized"),
    }
    OUTPUT.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
