#!/usr/bin/env python3
"""Freeze IcetSQS constructor semantics from pymatgen-core 2026.7.24."""

from __future__ import annotations

import json
from pathlib import Path

from pymatgen.core import Lattice, Structure
from pymatgen.io import icet as icet_module


class FakeClusterSpace:
    """Minimal deterministic seam replacing the optional ICET dependency."""

    def __init__(self, structure, cutoffs, chemical_symbols):
        self.structure = structure
        self.cutoffs = cutoffs
        self.chemical_symbols = chemical_symbols


icet_module.ClusterSpace = FakeClusterSpace
icet_module._validate_concentrations = lambda concentrations, cluster_space: concentrations
icet_module._get_sqs_cluster_vector = (
    lambda cluster_space, target_concentrations: [0.5]
)
structure = Structure(
    Lattice.cubic(3),
    [{"Mg": 0.5, "Al": 0.5}, "O"],
    [[0, 0, 0], [0.5, 0.5, 0.5]],
)
calculator = icet_module.IcetSQS(
    structure,
    scaling=2,
    instances=2,
    cluster_cutoffs={2: 5, 3: 3},
    sqs_method="enumeration",
    sqs_kwargs={"include_smaller_cells": False},
)
oracle = {
    "source": "pymatgen-core 2026.7.24 with deterministic ICET seam",
    "composition": calculator.composition,
    "cutoffs_list": calculator.cutoffs_list,
    "sqs_method": "enumeration",
    "sqs_kwargs": calculator.sqs_kwargs,
    "sqs_vector": calculator.sqs_vector,
}
root = Path(__file__).resolve().parents[2]
output = root / "dev/matgenlab/oracles/icet_2026.7.24.json"
output.write_text(json.dumps(oracle, indent=2) + "\n", encoding="utf-8")
print(output)
