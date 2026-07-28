#!/usr/bin/env python3
"""Generate the frozen pymatgen 2026.5.4 pmg_config oracle."""

from __future__ import annotations

import contextlib
import io
import json
import tempfile
from pathlib import Path

import yaml
from pymatgen.cli import pmg_config


POTENTIAL = """H GTH-PBE-q1
1
0.20000000 2 -4.17890044 0.72446331
0
"""

BASIS = """H DZVP-MOLOPT-GTH
1
2 0 1 2 1 1
8.3744350009 -0.0283380461 0.0000000000
1.8058681460 -0.1333810052 0.0000000000
"""


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        source = root / "cp2k"
        target = root / "resources"
        source.mkdir()
        (source / "GTH_POTENTIALS").write_text(POTENTIAL)
        (source / "BASIS_TEST").write_text(BASIS)
        with contextlib.redirect_stdout(io.StringIO()):
            pmg_config.setup_cp2k_data([str(source), str(target)])
        hydrogen = yaml.safe_load((target / "H").read_text())
        potential_hash = next(iter(hydrogen["potentials"]))
        basis_hash = next(iter(hydrogen["basis_sets"]))

        config = root / ".pmgrc.yaml"
        config.write_text("EXISTING: old\nFLAG: true\n")
        pmg_config.SETTINGS_FILE = str(config)
        pmg_config.OLD_SETTINGS_FILE = str(root / ".old.pmgrc.yaml")
        with contextlib.redirect_stdout(io.StringIO()):
            pmg_config.add_config_var(
                [
                    "EXISTING",
                    "new",
                    "FALSE_VAL",
                    "false",
                    "NONE_VAL",
                    "none",
                    "NUMBER",
                    "3.5",
                ],
                ".bak",
            )

        oracle = {
            "source": "pymatgen",
            "version": "2026.5.4",
            "cp2k": {
                "element_file_count": len(list(target.iterdir())),
                "potential_hash": potential_hash,
                "basis_hash": basis_hash,
                "potential_filename": hydrogen["potentials"][potential_hash][
                    "filename"
                ],
                "basis_filename": hydrogen["basis_sets"][basis_hash]["filename"],
                "potential_name": hydrogen["potentials"][potential_hash]["name"],
                "basis_name": hydrogen["basis_sets"][basis_hash]["name"],
            },
            "config_text": config.read_text(),
            "config_backup_text": Path(str(config) + ".bak").read_text(),
            "potcar_mapping": {
                "potpaw_PBE_54": "POT_GGA_PAW_PBE_54",
                "potpaw_PBE.64": "POT_PAW_PBE_64",
                "potUSPP_GGA": "POT_GGA_US_PW91",
                "Osmium": "Os",
            },
            "enum_commands": [
                "make@enumlib/symlib/src",
                "make@enumlib/src",
                "make enum.x@enumlib/src",
            ],
            "bader_url": (
                "https://theory.cm.utexas.edu/henkelman/code/bader/"
                "download/bader.tar.gz"
            ),
            "dispatch_priority": [
                "potcar_dirs",
                "install",
                "var_spec",
                "cp2k_data_dirs",
            ],
        }
    output = Path(__file__).parent / "oracles" / "pmg_config_2026.5.4.json"
    output.write_text(json.dumps(oracle, indent=2) + "\n")


if __name__ == "__main__":
    main()
