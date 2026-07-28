#!/usr/bin/env python3
"""Freeze pymatgen 2026.5.4 bond-dissociation reference results."""

from __future__ import annotations

import json
from pathlib import Path

from monty.serialization import loadfn
from pymatgen.analysis.bond_dissociation import BondDissociationEnergies


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = (
    ROOT
    / "+kssolv"
    / "+analysis"
    / "+matgenlab"
    / "+test"
    / "+analysis"
    / "+fixtures"
    / "+bond_dissociation"
)
OUTPUT = (
    ROOT
    / "dev"
    / "matgenlab"
    / "oracles"
    / "bond_dissociation_2026.5.4.json"
)


def entries(stem: str):
    principle = loadfn(FIXTURES / f"{stem}_principle.json")
    principle["initial_molecule"] = principle["initial_molecule"].as_dict()
    principle["final_molecule"] = principle["final_molecule"].as_dict()
    fragments = loadfn(FIXTURES / f"{stem}_fragments.json")
    for entry in fragments:
        entry["initial_molecule"] = entry["initial_molecule"].as_dict()
        entry["final_molecule"] = entry["final_molecule"].as_dict()
    return principle, fragments


def run(stem: str, **kwargs):
    principle, fragments = entries(stem)
    value = BondDissociationEnergies(principle, fragments, **kwargs)
    return {
        "filtered_count": len(value.filtered_entries),
        "expected_charges": value.expected_charges,
        "ring_bonds": [list(pair) for pair in value.ring_bonds],
        "bond_pairs": [
            [[*first], [*second]] for first, second in getattr(value, "bond_pairs", [])
        ],
        "records": value.bond_dissociation_energies,
    }


def main() -> None:
    data = {
        "pymatgen_version": "2026.5.4",
        "neg_EC_40": run("neg_EC_40"),
        "neg_TFSI": run("neg_TFSI"),
        "PC_65": run("PC_65"),
        "PC_65_additional_charge": run(
            "PC_65", allow_additional_charge_separation=True
        ),
        "PC_65_multibreak": run("PC_65", multibreak=True),
    }
    OUTPUT.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
