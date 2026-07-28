#!/usr/bin/env python3
"""Emit optical-property samples from frozen pymatgen."""

from __future__ import annotations

import json
import sys

from pymatgen.analysis.optics import DielectricAnalysis
from pymatgen.io.vasp import Vasprun


def main() -> None:
    analysis = DielectricAnalysis.from_vasprun(Vasprun(sys.argv[1]))
    sample_indices = [(0, 0), (0, 1), (500, 2), (1500, 5)]
    samples = []
    for row, column in sample_indices:
        sample = {"index": [row, column]}
        for name in ("eps_real", "eps_imag", "n", "k", "R", "L", "T"):
            sample[name] = float(getattr(analysis, name)[row, column])
        samples.append(sample)
    indices = (1, 500, 1500)
    output = {
        "shape": list(analysis.n.shape),
        "energy_indices": list(indices),
        "energies": [float(analysis.energies[index]) for index in indices],
        "wavelengths": [float(analysis.wavelengths[index]) for index in indices],
        "samples": samples,
    }
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
