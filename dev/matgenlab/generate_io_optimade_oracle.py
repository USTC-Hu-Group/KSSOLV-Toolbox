#!/usr/bin/env python3
"""Emit frozen pymatgen-core OPTIMADE adapter results."""

from __future__ import annotations

import json

from pymatgen.core import Lattice, Structure
from pymatgen.io.optimade import OptimadeStructureAdapter


def main() -> None:
    lattice = Lattice([[2, 0, 0], [0, 3, 0], [0, 0, 4]], pbc=(True, False, True))
    species = ["Fe", "P", "O", "O", "O", "O"]
    coords = [
        [0, 0, 0],
        [0.5, 0.5, 0.5],
        [0.25, 0.25, 0.25],
        [0.75, 0.25, 0.25],
        [0.25, 0.75, 0.25],
        [0.25, 0.25, 0.75],
    ]
    structure = Structure(lattice, species, coords)
    resource = OptimadeStructureAdapter.get_optimade_structure(structure)
    resource["id"] = "offline-test-id"
    resource["attributes"]["_custom_band_gap"] = 2.2
    restored = OptimadeStructureAdapter.get_structure(resource)
    print(
        json.dumps(
            {
                "resource": resource,
                "restored_fractional_coordinates": restored.frac_coords.tolist(),
                "restored_properties": restored.properties,
            },
            indent=2,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
