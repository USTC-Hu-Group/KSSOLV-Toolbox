#!/usr/bin/env python3
"""Generate a frozen pymatgen 2026.7.24 VASP optics oracle."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from pymatgen.io.vasp.optics import (
    delta_func,
    delta_methfessel_paxton,
    get_delta,
    get_step,
    kramers_kronig,
    step_func,
    step_methfessel_paxton,
)


def encode(values):
    array = np.asarray(values)
    if np.iscomplexobj(array):
        return {"real": array.real.tolist(), "imag": array.imag.tolist()}
    return array.tolist()


root = Path(__file__).resolve().parents[2]
x = np.array([-2.0, -0.5, 0.0, 0.75, 2.0])
eps = np.array([0.0, 0.3, 1.2, 0.4, 0.1], dtype=np.complex128)
oracle = {
    "source": "pymatgen-core 2026.7.24",
    "index_base": 1,
    "x": x.tolist(),
    "delta_mp": {str(n): encode(delta_methfessel_paxton(x, n)) for n in range(4)},
    "step_mp": {str(n): encode(step_methfessel_paxton(x, n)) for n in range(4)},
    "delta": {str(n): encode(delta_func(x, n)) for n in (-1, 0, 1, 3)},
    "step": {str(n): encode(step_func(x, n)) for n in (-1, 0, 1, 3)},
    "get_delta": encode(get_delta(0.85, 0.2, 12, 0.1, 2)),
    "get_step": encode(get_step(0.85, 0.2, 12, 0.1, 2)),
    "kramers_kronig": encode(kramers_kronig(eps, 5, 0.2, -0.1)),
}
output = root / "dev/matgenlab/oracles/vasp_optics_2026.7.24.json"
output.write_text(json.dumps(oracle, indent=2) + "\n", encoding="utf-8")
print(output)
