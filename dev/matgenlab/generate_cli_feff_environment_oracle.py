#!/usr/bin/env python3
"""Freeze the three legacy pymatgen 2026.5.4 CLI workflows."""

from __future__ import annotations

import contextlib
import io
import json
import sys
from pathlib import Path
from types import SimpleNamespace

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

from pymatgen.cli import feff_plot_cross_section as cross_module
from pymatgen.cli import feff_plot_dos as dos_module
from pymatgen.cli import get_environment as environment_module


class FakeXmu:
    @classmethod
    def from_file(cls, xmu_file, feff_file):
        return cls()

    def as_dict(self):
        return {
            "calc": "XANES",
            "atom": "Fe",
            "formula": "FeO",
            "energies": [1.0, 2.0, 3.0],
            "scross": [0.5, 1.0, 0.75],
            "across": [1.0, 2.0, 1.5],
            "edge": "K",
        }


cross_module.Xmu = FakeXmu
cross_module.pretty_plot = lambda width, height: plt.subplots(figsize=(width, height))[1]
cross_module.plt.show = lambda: None
sys.argv = ["feff_plot_cross_section", "xmu.dat", "feff.inp"]
cross_module.main()
cross_axes = plt.gca()
cross_oracle = {
    "title": cross_axes.get_title(),
    "xlabel": cross_axes.get_xlabel(),
    "ylabel": cross_axes.get_ylabel(),
    "labels": [line.get_label() for line in cross_axes.lines],
}
plt.close("all")


class FakeCompleteDos:
    structure = [
        SimpleNamespace(specie=SimpleNamespace(symbol="Fe")),
        SimpleNamespace(specie=SimpleNamespace(symbol="O")),
    ]

    def get_site_dos(self, site):
        return f"site-{site.specie.symbol}"

    def get_element_dos(self):
        return {"Fe": "element-Fe", "O": "element-O"}

    def get_spd_dos(self):
        return {"s": "orbital-s"}


class FakeLDos:
    complete_dos = FakeCompleteDos()

    @classmethod
    def from_file(cls, feff_file, ldos_base):
        return cls()


class FakeDosPlotter:
    latest = None

    def __init__(self):
        FakeDosPlotter.latest = self
        self.data = {}

    def add_dos_dict(self, data):
        self.data.update(data)

    def show(self):
        return None


dos_module.LDos = FakeLDos
dos_module.DosPlotter = FakeDosPlotter
sys.argv = [
    "feff_plot_dos",
    "ldos",
    "feff.inp",
    "--site",
    "--element",
    "--orbital",
]
dos_module.main()
dos_keys = list(FakeDosPlotter.latest.data)


class FakeConfig:
    @classmethod
    def auto_load(cls):
        return cls()

    def package_options_description(self):
        return "frozen options"


environment_module.ChemEnvConfig = FakeConfig
environment_module.compute_environments = lambda config: None
sys.argv = ["get_environment"]
stream = io.StringIO()
with contextlib.redirect_stdout(stream):
    environment_status = environment_module.main()

oracle = {
    "source": "pymatgen 2026.5.4",
    "cross_section": cross_oracle,
    "dos_keys": dos_keys,
    "environment_status": environment_status,
    "environment_transcript": stream.getvalue(),
}
root = Path(__file__).resolve().parents[2]
output = root / "dev/matgenlab/oracles/cli_feff_environment_2026.5.4.json"
output.write_text(json.dumps(oracle, indent=2) + "\n", encoding="utf-8")
print(output)
