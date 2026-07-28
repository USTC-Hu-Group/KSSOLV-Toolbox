#!/usr/bin/env python3
"""Emit frozen XPS samples from a VASP DOS fixture."""

from __future__ import annotations

import json
import sys

from pymatgen.analysis.xps import XPS
from pymatgen.io.vasp import Vasprun


def main() -> None:
    spectrum = XPS.from_dos(Vasprun(sys.argv[1]).complete_dos)
    indices = (96, 97, 98, 170, 171, 172)
    print(
        json.dumps(
            {
                "length": len(spectrum),
                "indices": list(indices),
                "x": [float(spectrum.x[index]) for index in indices],
                "y": [float(spectrum.y[index]) for index in indices],
                "maximum": float(spectrum.y.max()),
                "sum": float(spectrum.y.sum()),
            },
            indent=2,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
