"""Freeze pymatgen 2026.5.4 piezo-sensitivity fixtures as portable JSON."""
from __future__ import annotations

import json
import pickle
from pathlib import Path

import numpy as np
from monty.serialization import loadfn
from pymatgen.analysis.piezo_sensitivity import get_piezo

ROOT = Path("/tmp/matgenlab-plan.tMNeV8/pymatgen-2026.5.4")
FIXTURES = ROOT / "test-files/analysis/piezo_sensitivity"
OUTPUT = Path("dev/matgenlab/oracles/piezo_sensitivity_2026.5.4.json")


def operation(op):
    return {
        "rotation": np.asarray(op.rotation_matrix).tolist(),
        "translation": np.asarray(op.translation_vector).tolist(),
    }


def nested_operations(values):
    return [[operation(op) for op in entry] for entry in values]


def main():
    bec = np.load(FIXTURES / "pztborn.npy", allow_pickle=True)
    ist = np.load(FIXTURES / "pztist.npy", allow_pickle=True)
    fcm = np.load(FIXTURES / "pztfcm.npy", allow_pickle=True)
    pointops = np.load(FIXTURES / "pointops.npy", allow_pickle=True)
    sharedops = np.load(FIXTURES / "sharedops.npy", allow_pickle=True)
    with open(FIXTURES / "becops.pkl", "rb") as handle:
        becops = pickle.load(handle)
    with open(FIXTURES / "fcmops.pkl", "rb") as handle:
        fcmops = pickle.load(handle)
    structure = loadfn(FIXTURES / "pb2tizro6.json")
    payload = {
        "source": {"distribution": "pymatgen", "version": "2026.5.4"},
        "structure": structure.as_dict(),
        "bec": bec.tolist(),
        "ist": ist.tolist(),
        "fcm": fcm.tolist(),
        "pointops": nested_operations(pointops),
        "sharedops": [
            nested_operations(row) for row in sharedops
        ],
        "bec_relations": [[entry[0], entry[1], len(entry[2])] for entry in becops],
        "fcm_relations": [
            [entry[0], entry[1], entry[2], entry[3], len(entry[4])]
            for entry in fcmops
        ],
        "piezo": get_piezo(bec, ist, fcm).tolist(),
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, indent=2) + "\n")


if __name__ == "__main__":
    main()
