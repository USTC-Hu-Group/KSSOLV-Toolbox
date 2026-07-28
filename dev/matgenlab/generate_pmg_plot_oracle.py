#!/usr/bin/env python3
"""Generate the frozen pymatgen 2026.5.4 pmg_plot reference data."""

from __future__ import annotations

import json
from pathlib import Path

from pymatgen.analysis.diffraction.xrd import XRDCalculator
from pymatgen.core import Structure
from pymatgen.io.vasp import Chgcar, Vasprun
from pymatgen.symmetry.analyzer import SpacegroupAnalyzer


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = (
    ROOT
    / "+kssolv"
    / "+analysis"
    / "+matgenlab"
    / "+test"
    / "+cli"
    / "+fixtures"
    / "+pmg_plot"
)
OUTPUT = ROOT / "dev" / "matgenlab" / "oracles" / "pmg_plot_2026.5.4.json"


def main() -> None:
    structure = Structure.from_file(FIXTURES / "POSCAR_Fe3O4")
    pattern = XRDCalculator().get_pattern(structure)

    run = Vasprun(FIXTURES / "vasprun_Li_no_projected.xml.gz")
    dos = run.complete_dos
    spins = sorted(dos.densities, key=int, reverse=True)

    projected = Vasprun(FIXTURES / "vasprun.Al.xml.gz").complete_dos

    chgcar = Chgcar.from_file(FIXTURES / "CHGCAR.Fe3O4.gz")
    symmetrized = SpacegroupAnalyzer(
        chgcar.structure, symprec=0.1
    ).get_symmetrized_structure()
    indices = [
        chgcar.structure.index(sites[0])
        for sites in symmetrized.equivalent_sites
    ]
    curves = [chgcar.get_integrated_diff(index, 3, 30) for index in indices]

    data = {
        "upstream": "pymatgen==2026.5.4",
        "xrd": {
            "count": len(pattern.x),
            "x": pattern.x.tolist(),
            "y": pattern.y.tolist(),
        },
        "dos": {
            "count": len(dos.energies),
            "energies": dos.energies.tolist(),
            "efermi": dos.efermi,
            "spin_names": [spin.name for spin in spins],
            "densities": {
                spin.name: dos.densities[spin].tolist() for spin in spins
            },
        },
        "projected_dos": {
            "site_count": len(projected.structure),
            "element_labels": sorted(
                element.symbol for element in projected.get_element_dos()
            ),
            "orbital_labels": sorted(
                orbital.name for orbital in projected.get_spd_dos()
            ),
        },
        "chgint": {
            "indices": indices,
            "labels": [
                f"Atom {index} - {chgcar.structure[index].species_string}"
                for index in indices
            ],
            "curves": [curve.tolist() for curve in curves],
        },
    }
    OUTPUT.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
