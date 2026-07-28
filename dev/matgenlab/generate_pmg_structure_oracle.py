#!/usr/bin/env python3
"""Generate the frozen pymatgen 2026.5.4 pmg-structure oracle."""

from __future__ import annotations

import io
import json
from argparse import Namespace
from contextlib import redirect_stdout
from pathlib import Path

from pymatgen.cli.pmg_structure import (
    analyze_localenv,
    analyze_structures,
    analyze_symmetry,
    compare_structures,
)
from pymatgen.core import Structure


def capture(function, args: Namespace, fixture_dir: Path) -> str:
    stream = io.StringIO()
    with redirect_stdout(stream):
        function(args)
    return stream.getvalue().replace(str(fixture_dir), "<FIXTURES>")


def main() -> None:
    repository = Path(__file__).resolve().parents[2]
    fixture_dir = (
        repository
        / "+kssolv"
        / "+analysis"
        / "+matgenlab"
        / "+test"
        / "+cli"
        / "+fixtures"
    )
    li2o = str(fixture_dir / "Li2O.cif")
    lithium = str(fixture_dir / "Li.cif")
    symmetry_args = Namespace(filenames=[li2o], symmetry=0.1)
    local_args = Namespace(filenames=[li2o], localenv=["Li-O=3"])
    element_args = Namespace(
        filenames=[li2o, lithium], group="element"
    )
    species_args = Namespace(
        filenames=[li2o, lithium], group="species"
    )
    structure = Structure.from_file(li2o, primitive=False)
    neighbors = sorted(
        neighbor.nn_distance
        for neighbor in structure.get_neighbors(structure[0], 3)
        if "O" in [species.symbol for species in neighbor.species]
    )
    oracle = {
        "pymatgen_version": "2026.5.4",
        "fixture_formulas": {
            "Li2O.cif": structure.formula,
            "Li.cif": Structure.from_file(lithium).formula,
        },
        "symmetry": {
            "international": "Fm-3m",
            "number": 225,
            "hall": "-F 4 2 3",
            "stdout": capture(analyze_symmetry, symmetry_args, fixture_dir),
        },
        "localenv": {
            "first_site_distances": neighbors,
            "stdout": capture(analyze_localenv, local_args, fixture_dir),
        },
        "element_group_stdout": capture(
            compare_structures, element_args, fixture_dir
        ),
        "species_group_stdout": capture(
            compare_structures, species_args, fixture_dir
        ),
        "dispatch_symmetry_stdout": capture(
            analyze_structures,
            Namespace(
                filenames=[li2o],
                convert=False,
                symmetry=0.1,
                group=None,
                localenv=None,
            ),
            fixture_dir,
        ),
    }
    output = (
        Path(__file__).resolve().parent
        / "oracles"
        / "pmg_structure_2026.5.4.json"
    )
    output.write_text(json.dumps(oracle, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
