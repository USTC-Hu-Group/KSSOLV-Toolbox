#!/usr/bin/env python3
"""Freeze pymatgen 2026.5.4 apps.borg.hive behavior for MATLAB tests."""

from __future__ import annotations

import json
import os
from pathlib import Path

from pymatgen.apps.borg.hive import (
    GaussianToComputedEntryDrone,
    SimpleVaspToComputedEntryDrone,
    VaspToComputedEntryDrone,
)


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
)
OUTPUT = ROOT / "dev" / "matgenlab" / "oracles" / "apps_borg_hive_2026.5.4.json"


def normalized_drone_dict(drone):
    value = drone.as_dict()
    init_args = value["init_args"]
    for key in ("parameters", "data"):
        if key in init_args:
            init_args[key] = sorted(init_args[key])
    if "file_extensions" in init_args:
        init_args["file_extensions"] = list(init_args["file_extensions"])
    return value


def entry_summary(entry):
    summary = {
        "class": type(entry).__name__,
        "formula": entry.reduced_formula,
        "energy": entry.energy,
        "parameters": {
            key: entry.parameters[key]
            for key in sorted(entry.parameters)
            if key not in {"route_parameters"}
        },
        "data": {
            key: entry.data[key]
            for key in sorted(entry.data)
            if key not in {"filename"}
        },
    }
    if "route_parameters" in entry.parameters:
        summary["parameters"]["route_parameters"] = entry.parameters[
            "route_parameters"
        ]
    if hasattr(entry, "structure"):
        if hasattr(entry.structure, "lattice"):
            summary["lattice"] = entry.structure.lattice.matrix.tolist()
            summary["frac_coords"] = entry.structure.frac_coords.tolist()
        else:
            summary["cart_coords"] = entry.structure.cart_coords.tolist()
    return summary


def main():
    vasp = VaspToComputedEntryDrone(data=["efermi"])
    vasp_structure = VaspToComputedEntryDrone(inc_structure=True)
    simple = SimpleVaspToComputedEntryDrone(inc_structure=True)
    gaussian = GaussianToComputedEntryDrone(data=["corrections"])
    gaussian_structure = GaussianToComputedEntryDrone(inc_structure=True)
    oracle = {
        "source": "pymatgen 2026.5.4",
        "drone_dicts": {
            "vasp": normalized_drone_dict(vasp),
            "vasp_structure": normalized_drone_dict(vasp_structure),
            "simple": normalized_drone_dict(simple),
            "gaussian": normalized_drone_dict(gaussian),
            "gaussian_structure": normalized_drone_dict(gaussian_structure),
        },
        "strings": {
            "vasp": str(vasp),
            "simple": str(simple),
            "gaussian": str(gaussian),
        },
        "valid_paths": {
            "vasp": [
                Path(path).name
                for path in vasp.get_valid_paths(next(os.walk(FIXTURES)))
            ],
            "gaussian": [
                Path(path).name
                for path in GaussianToComputedEntryDrone(
                    file_extensions=(".log", ".out")
                ).get_valid_paths(
                    (str(FIXTURES), [], ["methane.log", "job.out", "notes.txt"])
                )
            ],
        },
        "entries": {
            "vasp": entry_summary(vasp.assimilate(FIXTURES)),
            "vasp_structure": entry_summary(
                vasp_structure.assimilate(FIXTURES)
            ),
            "simple_structure": entry_summary(
                simple.assimilate(FIXTURES / "+simple_vasp")
            ),
            "gaussian": entry_summary(
                gaussian.assimilate(FIXTURES / "methane.log")
            ),
            "gaussian_structure": entry_summary(
                gaussian_structure.assimilate(FIXTURES / "methane.log")
            ),
        },
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(oracle, indent=2, sort_keys=True) + "\n")
    print(OUTPUT)


if __name__ == "__main__":
    main()
