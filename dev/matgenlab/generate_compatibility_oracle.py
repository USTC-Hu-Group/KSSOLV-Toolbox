#!/usr/bin/env python3
"""Freeze selected pymatgen v2026.5.4 compatibility semantics as JSON."""

from __future__ import annotations

import json
import math
import subprocess
from pathlib import Path

import pymatgen.analysis.compatibility as compatibility_module
from pymatgen.analysis.compatibility import (
    Compatibility,
    MITCompatibility,
    MaterialsProject2020Compatibility,
    MaterialsProjectAqueousCompatibility,
    MaterialsProjectCompatibility,
    SmoothPESCompatibility,
    needs_u_correction,
)
from pymatgen.core.entries import ComputedEntry, ConstantEnergyAdjustment


def entry(formula: str, energy: float, run_type: str, hubbards=None, **kwargs):
    parameters = {"run_type": run_type, "hubbards": hubbards, "software": "other"}
    return ComputedEntry(formula, energy, parameters=parameters, **kwargs)


def adjustment_data(processed):
    if processed is None:
        return None
    return {
        "correction": processed.correction,
        "names": [item.name for item in processed.energy_adjustments],
        "values": [item.value for item in processed.energy_adjustments],
        "uncertainties": [
            item.uncertainty if math.isfinite(item.uncertainty) else None
            for item in processed.energy_adjustments
        ],
    }


def main() -> None:
    upstream_root = Path(compatibility_module.__file__).resolve().parents[4]
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], text=True, cwd=upstream_root
    ).strip()
    mp = MaterialsProject2020Compatibility(check_potcar=False)
    gga = MaterialsProject2020Compatibility("GGA", check_potcar=False)
    smooth = SmoothPESCompatibility(check_potcar=False)

    fe2o3 = entry(
        "Fe2O3",
        -1,
        "GGA+U",
        {"Fe": 5.3, "O": 0},
        data={"oxide_type": "oxide", "oxidation_states": {"Fe": 3, "O": -2}},
    )
    fe2coo4 = entry(
        "Fe2CoO4",
        -10,
        "GGA+U",
        {"Fe": 5.3, "Co": 3.32, "O": 0},
        data={"oxide_type": "oxide"},
    )
    legacy = MaterialsProjectCompatibility(check_potcar_hash=False)
    legacy_entry = ComputedEntry(
        "Fe2O3",
        -1,
        parameters={
            "run_type": "GGA+U",
            "hubbards": {"Fe": 5.3, "O": 0},
            "potcar_symbols": ["PBE Fe_pv", "PBE O"],
        },
    )
    legacy_explanation = legacy.get_explanation_dict(legacy_entry)

    aqueous = MaterialsProjectAqueousCompatibility(
        solid_compat=None, o2_energy=-10, h2o_energy=-20, h2o_adjustments=-0.5
    )
    aqueous_entries = [
        ComputedEntry("O2", -10),
        ComputedEntry("FeH4O2", -10),
        ComputedEntry("Li2O2H2", -10),
    ]
    aqueous.process_entries(aqueous_entries)

    overlap = ComputedEntry(
        "Fe2O3",
        -2,
        energy_adjustments=[ConstantEnergyAdjustment(-5, name="collision")],
    )

    class CollisionCompatibility(Compatibility):
        def get_adjustments(self, _entry):
            return [ConstantEnergyAdjustment(-6, name="collision")]

    collision = CollisionCompatibility()
    single_overlap = collision.process_entry(overlap, clean=False)
    batch_overlap = collision.process_entries(overlap, clean=False)

    oracle = {
        "upstream_tag": "v2026.5.4",
        "upstream_commit": commit,
        "mp2020": {
            "fe2o3": adjustment_data(mp.process_entry(fe2o3, inplace=False)),
            "gga_fe2o3": adjustment_data(
                gga.process_entry(
                    entry(
                        "Fe2O3",
                        -1,
                        "GGA",
                        {},
                        data={"oxide_type": "oxide", "oxidation_states": {"Fe": 3, "O": -2}},
                    )
                )
            ),
            "fe2coo4": adjustment_data(mp.process_entry(fe2coo4)),
        },
        "legacy": {
            "correction": legacy_entry.correction,
            "explanation_names": [item["name"] for item in legacy_explanation["corrections"]],
            "explanation_values": [item["value"] for item in legacy_explanation["corrections"]],
        },
        "smooth": {
            metal: adjustment_data(
                smooth.process_entry(
                    entry(f"{metal}O", -1, "GGA+U", {metal: u_value, "O": 0}),
                    inplace=False,
                )
            )
            for metal, u_value in {
                "Co": 3.32,
                "Cr": 3.7,
                "Fe": 5.3,
                "Mn": 3.9,
                "Mo": 4.38,
                "Ni": 6.2,
                "V": 3.25,
                "W": 6.2,
            }.items()
        },
        "aqueous": {
            "o2_correction": aqueous_entries[0].correction,
            "hydrate_correction": aqueous_entries[1].correction,
            "nonhydrate_correction": aqueous_entries[2].correction,
        },
        "cleanup": {
            "single_overlap_returned": single_overlap is not None,
            "batch_overlap_count": len(batch_overlap),
            "clean_default": CollisionCompatibility()
            .process_entries(ComputedEntry("H2", -1, correction=-4))[0]
            .correction,
        },
        "needs_u": {
            formula: sorted(needs_u_correction(formula))
            for formula in ["Fe2O3", "FeS", "FeF3", "LiH", "LiFePO4", "LiFePS4"]
        },
        "mit_hash": adjustment_data(
            MITCompatibility(check_potcar_hash=True).process_entry(
                ComputedEntry(
                    "Fe2O3",
                    -1,
                    parameters={
                        "run_type": "GGA+U",
                        "hubbards": {"Fe": 4, "O": 0},
                        "potcar_spec": [
                            {
                                "titel": "PAW_PBE Fe 06Sep2000",
                                "hash": "9530da8244e4dac17580869b4adab115",
                            },
                            {
                                "titel": "PAW_PBE O 08Apr2002",
                                "hash": "7a25bc5b9a5393f46600a4939d357982",
                            },
                        ],
                    },
                )
            )
        ),
    }
    print(json.dumps(oracle, indent=2, allow_nan=True))


if __name__ == "__main__":
    main()
