#!/usr/bin/env python3
"""Generate compact MATLAB runtime data from frozen pymatgen LibxcFunc."""

from __future__ import annotations

import argparse
import ast
import json
from pathlib import Path


def generate(source_root: Path, output: Path) -> None:
    core = source_root / "src/pymatgen/core"
    tree = ast.parse((core / "libxcfunc.py").read_text(encoding="utf-8"))
    enum_class = next(
        node
        for node in tree.body
        if isinstance(node, ast.ClassDef) and node.name == "LibxcFunc"
    )
    docs = json.loads((core / "libxc_docs.json").read_text(encoding="utf-8"))
    rows = []
    for node in enum_class.body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if not isinstance(target, ast.Name) or not isinstance(node.value, ast.Constant):
            continue
        if not isinstance(node.value.value, int):
            continue
        value = node.value.value
        rows.append({"name": target.id, "value": value, **docs[str(value)]})
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(rows, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(
            "+kssolv/+analysis/+matgenlab/+core/+data/libxc_data.json"
        ),
    )
    args = parser.parse_args()
    generate(args.source_root, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
