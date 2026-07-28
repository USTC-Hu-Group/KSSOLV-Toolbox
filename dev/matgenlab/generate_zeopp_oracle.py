#!/usr/bin/env python3
"""Generate the frozen pymatgen-core 2026.7.24 Zeo++ I/O oracle."""

from __future__ import annotations

import json
from pathlib import Path

from pymatgen.core import Lattice, Molecule, Structure
from pymatgen.io.zeopp import ZeoCssr, ZeoVoronoiXYZ


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = (
    ROOT
    / "+kssolv"
    / "+analysis"
    / "+matgenlab"
    / "+test"
    / "+io"
    / "+fixtures"
    / "+zeopp"
)
OUTPUT = ROOT / "dev" / "matgenlab" / "oracles" / "zeopp_2026.7.24.json"


def main() -> None:
    lattice = Lattice.from_parameters(5.1, 6.2, 7.3, 81, 92, 103)
    structure = Structure(
        lattice,
        ["Si", "O"],
        [[0.1, 0.2, 0.3], [0.75, 0.5, 0.25]],
        site_properties={"charge": [1.25, -0.5]},
    )
    cssr = ZeoCssr(structure)
    methane = Molecule(
        ["C", "H", "H", "H", "H"],
        [
            [0, 0, 0],
            [0, 0, 1.089],
            [1.026719, 0, -0.363],
            [-0.513360, -0.889165, -0.363],
            [-0.513360, 0.889165, -0.363],
        ],
        site_properties={"voronoi_radius": [0.4, 0.2, 0.2, 0.2, 0.2]},
    )
    official_cssr = ZeoCssr.from_file(FIXTURES / "EDI.cssr")
    official_xyz = ZeoVoronoiXYZ.from_file(FIXTURES / "EDI_voro.xyz")
    payload = {
        "source": "pymatgen-core 2026.7.24",
        "synthetic_cssr": str(cssr),
        "synthetic_cssr_frac_coords": cssr.structure.frac_coords.tolist(),
        "methane_xyz": str(ZeoVoronoiXYZ(methane)),
        "official_cssr": {
            "num_sites": len(official_cssr.structure),
            "lengths": list(official_cssr.structure.lattice.lengths),
            "angles": list(official_cssr.structure.lattice.angles),
            "first_frac_coord": official_cssr.structure.frac_coords[0].tolist(),
            "last_frac_coord": official_cssr.structure.frac_coords[-1].tolist(),
        },
        "official_voronoi_xyz": {
            "num_sites": len(official_xyz.molecule),
            "formula": official_xyz.molecule.formula,
            "first_cart_coord": official_xyz.molecule.cart_coords[0].tolist(),
            "first_radius": official_xyz.molecule[0].properties["voronoi_radius"],
            "last_cart_coord": official_xyz.molecule.cart_coords[-1].tolist(),
            "last_radius": official_xyz.molecule[-1].properties["voronoi_radius"],
        },
        "backend_fixture": {
            "voronoi_xyz": "2\nX2\nX 3.0 1.0 2.0 0.4\nX -0.5 0.25 0.75 0.8",
            "edge_centers": [[3.0, 1.0, 2.0], [-0.5, 0.25, 0.75]],
            "face_centers": [[6.0, 4.0, 5.0]],
            "free_sphere_line": "temp 2.58251 1.29452 2.58251",
        },
    }
    OUTPUT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
