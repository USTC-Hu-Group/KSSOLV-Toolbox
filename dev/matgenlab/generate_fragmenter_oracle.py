#!/usr/bin/env python3
"""Generate frozen pymatgen 2026.5.4 Fragmenter counts."""

from __future__ import annotations

import json
from pathlib import Path

from pymatgen.analysis.fragmenter import Fragmenter
from pymatgen.core import Molecule

root = Path(__file__).resolve().parents[2]
fixture = (
    root
    / "+kssolv/+analysis/+matgenlab/+test/+analysis/+fixtures/+fragmenter"
)
pc_frag1_edges = [[0, 2], [4, 2], [2, 1], [1, 3]]
pc_edges = [
    [5, 10],
    [5, 12],
    [5, 11],
    [5, 3],
    [3, 7],
    [3, 4],
    [3, 0],
    [4, 8],
    [4, 9],
    [4, 1],
    [6, 1],
    [6, 0],
    [6, 2],
]
small = Fragmenter(
    Molecule.from_file(fixture / "PC_frag1.xyz"),
    edges=pc_frag1_edges,
    depth=0,
)
pc = Molecule.from_file(fixture / "PC.xyz")
depth_two = Fragmenter(pc, edges=pc_edges, depth=2, open_rings=False, opt_steps=0)
exhaustive = Fragmenter(pc, edges=pc_edges, depth=0, open_rings=False)
with_previous = Fragmenter(
    pc,
    edges=pc_edges,
    depth=0,
    open_rings=False,
    prev_unique_frag_dict=small.unique_frag_dict,
)
oracle = {
    "source": "pymatgen 2026.5.4",
    "pc_frag1_depth0_total": small.total_unique_fragments,
    "pc_depth2_total": depth_two.total_unique_fragments,
    "pc_depth2_levels": {
        key: sum(len(value) for value in level.values())
        for key, level in depth_two.fragments_by_level.items()
    },
    "pc_depth0_total": exhaustive.total_unique_fragments,
    "pc_with_previous_new": with_previous.new_unique_fragments,
    "pc_with_previous_total": with_previous.total_unique_fragments,
}
output = root / "dev/matgenlab/oracles/fragmenter_2026.5.4.json"
output.write_text(json.dumps(oracle, indent=2) + "\n", encoding="utf-8")
print(output)
