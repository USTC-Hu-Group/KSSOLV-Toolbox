#!/usr/bin/env python3
"""Generate the frozen pymatgen 2026.5.4 pmg-potcar oracle."""

from __future__ import annotations

import contextlib
import io
import json
import tempfile
from argparse import Namespace
from pathlib import Path

import pymatgen.core
import pymatgen.io.vasp.inputs
from pymatgen.cli import pmg_potcar
from pymatgen.io.vasp.inputs import Potcar as RealPotcar


class FakePotcar:
    """Record CLI construction and output without licensed POTCAR data."""

    FUNCTIONAL_CHOICES = RealPotcar.FUNCTIONAL_CHOICES
    constructions: list[dict[str, object]] = []
    writes: list[str] = []

    def __init__(self, symbols, functional=None):
        self.symbols = list(symbols)
        self.functional = (
            functional
            or pymatgen.core.SETTINGS.get("PMG_DEFAULT_FUNCTIONAL", "PBE")
        )
        self.constructions.append(
            {"symbols": self.symbols, "functional": self.functional}
        )

    def write_file(self, filename):
        self.writes.append(str(filename))


def capture(function, *args):
    stream = io.StringIO()
    with contextlib.redirect_stdout(stream):
        function(*args)
    return stream.getvalue()


def main() -> None:
    original_potcar = pymatgen.io.vasp.inputs.Potcar
    missing = object()
    original_default = pymatgen.core.SETTINGS.pop(
        "PMG_DEFAULT_FUNCTIONAL", missing
    )
    pymatgen.io.vasp.inputs.Potcar = FakePotcar
    try:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "nested").mkdir()
            (root / "plain.txt").write_text("plain\n")
            (root / "POTCAR.spec").write_text("Fe\n\n O \n")
            (root / "nested" / "POTCAR.spec").write_text("Li\nF\n")
            visits = []
            pmg_potcar.proc_dir(
                str(root),
                lambda dirname, filename: visits.append(
                    [str(Path(dirname).relative_to(root)), filename]
                ),
            )

            pmg_potcar.gen_potcar(str(root), "plain.txt")
            pmg_potcar.gen_potcar(str(root), "POTCAR.spec")
            direct = {
                "construction": FakePotcar.constructions[-1],
                "output_name": Path(FakePotcar.writes[-1]).name,
            }

            before = len(FakePotcar.constructions)
            valid_stdout = capture(
                pmg_potcar.generate_potcar,
                Namespace(
                    functional="PBE_54",
                    recursive=None,
                    symbols=["Na", "Cl"],
                ),
            )
            generated = FakePotcar.constructions[before:]

            before = len(FakePotcar.constructions)
            pmg_potcar.generate_potcar(
                Namespace(
                    functional="LDA",
                    recursive=str(root),
                    symbols=None,
                )
            )
            recursive_generated = FakePotcar.constructions[before:]

            invalid_stdout = capture(
                pmg_potcar.generate_potcar,
                Namespace(
                    functional="NOT_A_FUNCTIONAL",
                    recursive=None,
                    symbols=["Na"],
                ),
            )
            noop_stdout = capture(
                pmg_potcar.generate_potcar,
                Namespace(functional=None, recursive=None, symbols=None),
            )

            oracle = {
                "source": "pymatgen",
                "version": "2026.5.4",
                "functional_choices": sorted(RealPotcar.FUNCTIONAL_CHOICES),
                "fixture_tree": {
                    "POTCAR.spec": "Fe\n\n O \n",
                    "plain.txt": "plain\n",
                    "nested/POTCAR.spec": "Li\nF\n",
                },
                "proc_dir_visits": sorted(visits),
                "gen_potcar": direct,
                "generate_symbols": {
                    "stdout": valid_stdout,
                    "construction": generated[0],
                    "output_name": Path(FakePotcar.writes[-1]).name,
                },
                "recursive_functionals": sorted(
                    item["functional"] for item in recursive_generated
                ),
                "invalid_stdout": invalid_stdout,
                "noop_stdout": noop_stdout,
            }
    finally:
        pymatgen.io.vasp.inputs.Potcar = original_potcar
        if original_default is missing:
            pymatgen.core.SETTINGS.pop("PMG_DEFAULT_FUNCTIONAL", None)
        else:
            pymatgen.core.SETTINGS["PMG_DEFAULT_FUNCTIONAL"] = original_default

    output = (
        Path(__file__).resolve().parent
        / "oracles"
        / "pmg_potcar_2026.5.4.json"
    )
    output.write_text(json.dumps(oracle, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
