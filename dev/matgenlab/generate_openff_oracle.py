#!/usr/bin/env python3
"""Generate the frozen pymatgen-core 2026.7.24 OpenFF oracle."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
import openff.toolkit as tk
from pymatgen.core import Molecule
from pymatgen.io.openff import (
    add_conformer,
    create_openff_mol,
    get_atom_map,
    infer_openff_mol,
    mol_graph_from_openff_mol,
    mol_graph_to_openff_mol,
)


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = (
    ROOT
    / "+kssolv"
    / "+analysis"
    / "+matgenlab"
    / "+test"
    / "+io"
    / "+fixtures"
    / "+openff"
)
OUTPUT = ROOT / "dev" / "matgenlab" / "oracles" / "openff_2026.7.24.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    cases = [
        ("CCO.xyz", "CCO"),
        ("FEC-r.xyz", "O=C1OC[C@@H](F)O1"),
        ("FEC-s.xyz", "O=C1OC[C@H](F)O1"),
        ("PF6.xyz", "F[P-](F)(F)(F)(F)F"),
    ]
    inferred: dict[str, object] = {}
    mappings: dict[str, list[int]] = {}
    for filename, smiles in cases:
        geometry = Molecule.from_file(FIXTURES / filename)
        molecule = infer_openff_mol(geometry)
        target = tk.Molecule.from_smiles(smiles)
        isomorphic, atom_map = get_atom_map(molecule, target)
        assert isomorphic
        inferred[filename] = {
            "n_atoms": molecule.n_atoms,
            "n_bonds": molecule.n_bonds,
        }
        mappings[filename] = list(atom_map.values())

    pf6 = tk.Molecule.from_smiles("F[P-](F)(F)(F)(F)F")
    graph = mol_graph_from_openff_mol(pf6)
    restored = mol_graph_to_openff_mol(graph)
    cco_geometry = Molecule.from_file(FIXTURES / "CCO.xyz")
    conformed, cco_map = add_conformer(
        tk.Molecule.from_smiles("CCO"), cco_geometry
    )
    cco_charges = np.load(FIXTURES / "CCO.npy")
    created = create_openff_mol(
        "CCO", FIXTURES / "CCO.xyz", 1.0, cco_charges, "am1bcc"
    )
    payload = {
        "source": "pymatgen-core 2026.7.24",
        "inferred": inferred,
        "atom_maps_zero_based": mappings,
        "pf6_roundtrip": {
            "n_atoms": restored.n_atoms,
            "n_bonds": restored.n_bonds,
            "total_charge": restored.total_charge.magnitude,
        },
        "cco_conformer": {
            "n_conformers": conformed.n_conformers,
            "atom_map_zero_based": list(cco_map.values()),
        },
        "cco_partial_charges": created.partial_charges.magnitude.tolist(),
        "li_partial_charges": np.load(FIXTURES / "Li.npy").tolist(),
        "fixture_sha256": {
            path.name: digest(path)
            for path in sorted(FIXTURES.iterdir())
            if path.is_file()
        },
    }
    OUTPUT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
