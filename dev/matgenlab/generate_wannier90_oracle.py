#!/usr/bin/env python3
"""Emit deterministic UNK oracle data from frozen pymatgen-core."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from pymatgen.io.wannier90 import Unk


def main() -> None:
    root = Path(sys.argv[1])
    output = {}
    for name in ("UNK.std", "UNK.ncl", "UNK.N2.std", "UNK.H2.ncl"):
        path = root / name
        unk = Unk.from_file(path)
        ng = [int(item) for item in unk.ng]
        indices = (
            [[0, 0, 0, 0], [int(unk.nbnd) - 1, ng[0] - 1, ng[1] - 1, ng[2] - 1]]
            if not unk.is_noncollinear
            else [
                [0, 0, 0, 0, 0],
                [0, 1, 0, 0, 0],
                [int(unk.nbnd) - 1, 1, ng[0] - 1, ng[1] - 1, ng[2] - 1],
            ]
        )
        samples = []
        for index in indices:
            value = unk.data[tuple(index)]
            samples.append(
                {"index": index, "real": float(value.real), "imag": float(value.imag)}
            )
        output[name] = {
            "ik": int(unk.ik),
            "nbnd": int(unk.nbnd),
            "ng": ng,
            "is_noncollinear": bool(unk.is_noncollinear),
            "shape": [int(item) for item in unk.data.shape],
            "samples": samples,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
