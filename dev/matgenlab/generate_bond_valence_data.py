#!/usr/bin/env python3
"""Convert frozen pymatgen bond-valence YAML data to MATLAB-friendly JSON."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from ruamel.yaml import YAML


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source-root",
        type=Path,
        default=Path(
            "/tmp/matgenlab-plan.tMNeV8/pymatgen-core-2026.7.24/"
            "src/pymatgen/core"
        ),
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path("+kssolv/+analysis/+matgenlab/+core/+data"),
    )
    args = parser.parse_args()
    yaml = YAML(typ="safe")

    parameters = yaml.load((args.source_root / "bvparam_1991.yaml").read_text())
    parameter_rows = [
        [symbol, float(values["r"]), float(values["c"])]
        for symbol, values in parameters.items()
    ]
    all_icsd = yaml.load((args.source_root / "icsd_bv.yaml").read_text())
    bvsum_rows = [
        [
            species,
            float(values["mean"]),
            float(values["std"]),
            int(values["n_data_pts"]),
        ]
        for species, values in all_icsd["bvsum"].items()
    ]
    occurrence_rows = [
        [species, int(value)]
        for species, value in all_icsd["occurrence"].items()
    ]

    args.output_root.mkdir(parents=True, exist_ok=True)
    outputs = {
        "bond_valence_parameters.json": parameter_rows,
        "bond_valence_icsd.json": bvsum_rows,
        "oxidation_state_occurrence.json": occurrence_rows,
    }
    for name, rows in outputs.items():
        path = args.output_root / name
        path.write_text(
            json.dumps(rows, separators=(",", ":"), ensure_ascii=False) + "\n"
        )
        print(f"Wrote {len(rows)} rows to {path}")


if __name__ == "__main__":
    main()
