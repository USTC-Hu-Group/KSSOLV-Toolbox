#!/usr/bin/env python3
"""Extract the frozen covalent-radius table without importing pymatgen."""

from __future__ import annotations

import argparse
import ast
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        type=Path,
        default=Path(
            "/tmp/matgenlab-plan.tMNeV8/pymatgen-core-2026.7.24/"
            "src/pymatgen/core/molecule_structure_comparator.py"
        ),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(
            "+kssolv/+analysis/+matgenlab/+core/+data/covalent_radii_2008.json"
        ),
    )
    args = parser.parse_args()

    tree = ast.parse(args.source.read_text())
    table = None
    for node in tree.body:
        if isinstance(node, ast.ClassDef) and node.name == "CovalentRadius":
            for statement in node.body:
                if isinstance(statement, ast.AnnAssign):
                    if isinstance(statement.target, ast.Name) and statement.target.id == "radius":
                        table = ast.literal_eval(statement.value)
    if not isinstance(table, dict) or not table:
        raise ValueError("Could not locate CovalentRadius.radius")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(table, separators=(",", ":"), sort_keys=True) + "\n"
    )
    print(f"Wrote {len(table)} covalent radii to {args.output}")


if __name__ == "__main__":
    main()
