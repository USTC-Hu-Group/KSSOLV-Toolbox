#!/usr/bin/env python3
"""Generate deterministic pymatgen 2026.5.4 OPTIMADE behavior oracle."""

from __future__ import annotations

import json
from pathlib import Path

from pymatgen.ext.optimade import OptimadeRester, Provider


def resource() -> dict:
    return {
        "meta": {"data_returned": 2},
        "links": {"next": None},
        "data": [
            {
                "id": "disordered-1",
                "type": "structures",
                "attributes": {
                    "lattice_vectors": [[4, 0, 0], [0, 4, 0], [0, 0, 4]],
                    "cartesian_site_positions": [[0, 0, 0], [2, 2, 2]],
                    "species": [
                        {
                            "name": "Na-vacancy",
                            "chemical_symbols": ["Na", "vacancy"],
                            "concentration": [0.75, 0.25],
                        },
                        {
                            "name": "Cl",
                            "chemical_symbols": ["Cl"],
                            "concentration": [1],
                        },
                    ],
                    "species_at_sites": ["Na-vacancy", "Cl"],
                    "nelements": 2,
                    "demo_quality": "frozen",
                },
            },
            {
                "id": "ordered-2",
                "type": "structures",
                "attributes": {
                    "lattice_vectors": [[5, 0, 0], [0, 5, 0], [0, 0, 5]],
                    "cartesian_site_positions": [[0, 0, 0], [2.5, 2.5, 2.5], [1, 1, 1]],
                    "species": [
                        {"name": "Na", "chemical_symbols": ["Na"], "concentration": [1]},
                        {"name": "Cl", "chemical_symbols": ["Cl"], "concentration": [1]},
                    ],
                    "species_at_sites": ["Na", "Cl", "Na"],
                    "nsites": 3,
                },
            },
        ],
    }


def main() -> None:
    first_filter = OptimadeRester._build_filter(
        elements=["Ga", "N"],
        nelements=2,
        nsites=(1, 100),
        chemical_formula_anonymous="A2B",
        chemical_formula_hill="GaN",
    )
    second_filter = OptimadeRester._build_filter(
        elements=["C", "H", "O"],
        nelements=(3, 4),
        nsites=(1, 100),
        chemical_formula_anonymous="A4B3C",
        chemical_formula_hill="C4H3O",
    )
    snls = OptimadeRester._get_snls_from_resource(
        resource(), "https://fixture.test/v1/structures?filter=x", "fixture"
    )
    parsed = {}
    for identifier, snl in snls.items():
        parsed[identifier] = {
            "cart_coords": snl.structure.cart_coords.tolist(),
            "site_species": [str(site.species) for site in snl.structure],
            "optimade_data": snl.data["_optimade"],
            "history": [node.as_dict() for node in snl.history],
        }
    provider = Provider(
        name="Fixture", base_url="https://fixture.test/", description="Offline",
        homepage="https://fixture.test/home", prefix="fx"
    )
    oracle = {
        "pymatgen_version": "2026.5.4",
        "filters": [first_filter, second_filter],
        "mandatory_response_fields": sorted(OptimadeRester.mandatory_response_fields),
        "provider_repr": repr(provider),
        "resource": resource(),
        "parsed": parsed,
    }
    output = Path(__file__).resolve().parent / "oracles" / "optimade_2026.5.4.json"
    output.write_text(json.dumps(oracle, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
