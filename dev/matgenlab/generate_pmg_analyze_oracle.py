#!/usr/bin/env python3
"""Generate the frozen pymatgen 2026.5.4 pmg-analyze oracle."""

from __future__ import annotations

import io
import json
import os
import shutil
import tempfile
from contextlib import redirect_stdout
from pathlib import Path

import pymatgen.cli.pmg_analyze as pmg_analyze
from pymatgen.io.vasp import Vasprun


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = (
    ROOT
    / "+kssolv"
    / "+analysis"
    / "+matgenlab"
    / "+test"
    / "+cli"
    / "+fixtures"
    / "+pmg_analyze"
)
OUTPUT = (
    ROOT
    / "dev"
    / "matgenlab"
    / "oracles"
    / "pmg_analyze_2026.5.4.json"
)
QUICK_FIXTURES = (
    ROOT
    / "+kssolv"
    / "+analysis"
    / "+matgenlab"
    / "+test"
    / "+apps"
    / "+borg"
    / "+fixtures"
    / "+simple_vasp"
)


def capture(function, *args) -> tuple[int, str]:
    stream = io.StringIO()
    with redirect_stdout(stream):
        status = function(*args)
    return status, stream.getvalue()


def main() -> None:
    # Make the frozen reference deterministic and avoid multiprocessing
    # bootstrap requirements when this script is launched by an agent.
    pmg_analyze.multiprocessing.cpu_count = lambda: 1
    with tempfile.TemporaryDirectory() as temporary:
        work = Path(temporary)
        shutil.copytree(FIXTURES, work / "run")
        shutil.copytree(QUICK_FIXTURES, work / "quick")
        previous = Path.cwd()
        os.chdir(work)
        try:
            energy_status, energy_stdout = capture(
                pmg_analyze.get_energies,
                "run",
                True,
                False,
                False,
                "energy_per_atom",
                "simple",
            )
            cached_status, cached_stdout = capture(
                pmg_analyze.get_energies,
                "run",
                False,
                False,
                False,
                "filename",
                "simple",
            )
            selected_status, selected_stdout = capture(
                pmg_analyze.get_magnetizations, "run", [0, 1]
            )
            all_status, all_stdout = capture(
                pmg_analyze.get_magnetizations, "run", []
            )
            quick_status, quick_stdout = capture(
                pmg_analyze.get_energies,
                "quick",
                True,
                False,
                True,
                "energy_per_atom",
                "simple",
            )
        finally:
            os.chdir(previous)

    run = Vasprun(FIXTURES / "vasprun.xml.gz")
    entry = run.get_computed_entry(
        inc_structure=True, data=["filename", "initial_structure"]
    )
    oracle = {
        "upstream": "pymatgen==2026.5.4",
        "energy": {
            "status": energy_status,
            "stdout": energy_stdout,
            "formula": entry.formula.replace(" ", ""),
            "energy": entry.energy,
            "energy_per_atom": entry.energy_per_atom,
            "volume_change_percent": (
                entry.structure.volume
                / entry.data["initial_structure"].volume
                - 1
            )
            * 100,
        },
        "cached": {
            "status": cached_status,
            "stdout": cached_stdout,
        },
        "quick": {
            "status": quick_status,
            "stdout": quick_stdout,
            "formula": "C1",
            "energy": -7.123456789,
            "energy_per_atom": -7.123456789,
        },
        "magnetization_selected": {
            "status": selected_status,
            "stdout": selected_stdout,
            "values": [-0.0, 0.0],
        },
        "magnetization_all": {
            "status": all_status,
            "stdout": all_stdout,
            "values": [-0.0, 0.0],
        },
    }
    OUTPUT.write_text(
        json.dumps(oracle, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
