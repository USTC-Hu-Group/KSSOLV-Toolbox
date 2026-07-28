#!/usr/bin/env python3
"""Copy frozen pymatgen diffraction tables into deterministic JSON assets."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source-root",
        type=Path,
        default=Path(
            "/tmp/matgenlab-plan.tMNeV8/pymatgen-2026.5.4/"
            "src/pymatgen/analysis/diffraction"
        ),
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path("+kssolv/+analysis/+matgenlab/+analysis/+data"),
    )
    args = parser.parse_args()
    args.output_root.mkdir(parents=True, exist_ok=True)

    for name in (
        "atomic_scattering_params.json",
        "neutron_scattering_length.json",
    ):
        source = args.source_root / name
        payload = json.loads(source.read_text(encoding="utf-8"))
        destination = args.output_root / name
        destination.write_text(
            json.dumps(
                payload,
                sort_keys=True,
                separators=(",", ":"),
                ensure_ascii=False,
            )
            + "\n",
            encoding="utf-8",
        )
        print(f"Wrote {len(payload)} records to {destination}")


if __name__ == "__main__":
    main()
