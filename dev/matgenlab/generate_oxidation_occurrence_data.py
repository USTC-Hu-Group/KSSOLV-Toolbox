#!/usr/bin/env python3
"""Extract ICSD oxidation-state occurrence priors from frozen pymatgen."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from ruamel.yaml import YAML


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        type=Path,
        default=Path(
            "/tmp/matgenlab-plan.tMNeV8/pymatgen-core-2026.7.24/"
            "src/pymatgen/core/icsd_bv.yaml"
        ),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(
            "+kssolv/+analysis/+matgenlab/+core/+data/"
            "oxidation_state_occurrence.json"
        ),
    )
    args = parser.parse_args()
    data = YAML(typ="safe").load(args.source.read_text())
    occurrence = data["occurrence"]
    rows = [[key, value] for key, value in occurrence.items()]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(rows, separators=(",", ":"), ensure_ascii=False) + "\n"
    )
    print(f"Wrote {len(rows)} oxidation priors to {args.output}")


if __name__ == "__main__":
    main()
