#!/usr/bin/env python3
"""Freeze enumlib-caller input semantics from pymatgen-core 2026.7.24."""

from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path

from pymatgen.command_line import enumlib_caller
from pymatgen.core import Lattice, Structure


def undecorated_adaptor():
    """Return the class hidden inside monty's missing-executable wrapper."""
    public = enumlib_caller.EnumlibAdaptor
    if isinstance(public, type):
        return public
    for cell in public.__closure__ or ():
        if isinstance(cell.cell_contents, type):
            return cell.cell_contents
    raise RuntimeError("Cannot locate the undecorated EnumlibAdaptor class")


def input_for(structure: Structure, **kwargs) -> dict:
    adaptor = undecorated_adaptor()(structure, **kwargs)
    old_cwd = Path.cwd()
    with tempfile.TemporaryDirectory() as directory:
        os.chdir(directory)
        try:
            adaptor._gen_input_file()
            text = Path("struct_enum.in").read_text(encoding="utf-8")
        finally:
            os.chdir(old_cwd)
    return {
        "input": text,
        "index_species": [str(species) for species in adaptor.index_species],
        "ordered_sites": len(adaptor.ordered_sites),
    }


def main() -> None:
    cases = {
        "half_occupied_si": input_for(
            Structure(Lattice.cubic(4), [{"Si": 0.5}], [[0, 0, 0]])
        ),
        "quarter_li_with_ordered_o": input_for(
            Structure(
                Lattice.cubic(4),
                [{"Li": 0.25}, "O"],
                [[0, 0, 0], [0.5, 0.5, 0.5]],
            ),
            check_ordered_symmetry=False,
        ),
    }
    payload = {
        "source": "pymatgen-core 2026.7.24",
        "module": "pymatgen.command_line.enumlib_caller",
        "cases": cases,
        "run_tot_stdout": "header\n  enum RunTot\n  1  2  3  7\n",
        "run_tot_count": 7,
        "enum_error_message": "Unable to enumerate structure.",
    }
    destination = (
        Path(__file__).resolve().parent
        / "oracles"
        / "enumlib_caller_2026.7.24.json"
    )
    destination.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
