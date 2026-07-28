#!/usr/bin/env python3
"""Copy and validate frozen pymatgen structure-prediction datasets."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    import yaml

    def load_yaml(text: str):
        return yaml.safe_load(text)
except ImportError:
    from ruamel.yaml import YAML

    def load_yaml(text: str):
        return YAML(typ="safe").load(text)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source-root",
        type=Path,
        default=Path("/tmp/matgenlab-plan.tMNeV8/pymatgen-core-2026.7.24"),
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path("+kssolv/+analysis/+matgenlab/+core/+data"),
    )
    args = parser.parse_args()

    source = (
        args.source_root
        / "src/pymatgen/core/structure_prediction/data/lambda.json"
    )
    rows = json.loads(source.read_text())
    if not isinstance(rows, list) or not rows:
        raise ValueError("lambda.json must contain a non-empty row list")
    if any(not isinstance(row, list) or len(row) != 3 for row in rows):
        raise ValueError("Every lambda-table row must have three fields")

    args.output_root.mkdir(parents=True, exist_ok=True)
    output = args.output_root / "substitution_lambda.json"
    output.write_text(
        json.dumps(rows, separators=(",", ":"), ensure_ascii=False) + "\n"
    )
    print(f"Wrote {len(rows)} substitution rows to {output}")

    bond_source = (
        args.source_root
        / "src/pymatgen/core/structure_prediction/DLS_bond_params.yaml"
    )
    bond_parameters = load_yaml(bond_source.read_text())
    bond_output = args.output_root / "dls_bond_params.json"
    bond_output.write_text(
        json.dumps(
            bond_parameters, separators=(",", ":"), sort_keys=True
        )
        + "\n"
    )
    print(f"Wrote {len(bond_parameters)} DLS parameter rows to {bond_output}")


if __name__ == "__main__":
    main()
