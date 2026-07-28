#!/usr/bin/env python3
"""Freeze representative pymatgen 2026.5.4 lobster_env results."""

from __future__ import annotations

import json
from pathlib import Path

from pymatgen.analysis.lobster_env import LobsterNeighbors


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = (
    ROOT
    / "+kssolv"
    / "+analysis"
    / "+matgenlab"
    / "+test"
    / "+analysis"
    / "+fixtures"
    / "+lobster_env"
)
OUTPUT = ROOT / "dev" / "matgenlab" / "oracles" / "lobster_env_2026.5.4.json"


def make(structure: str, interactions: str, **kwargs):
    return LobsterNeighbors.from_files(
        structure_path=FIXTURES / structure,
        icoxxlist_path=FIXTURES / interactions,
        **kwargs,
    )


def counts(value: LobsterNeighbors) -> list[int]:
    return [len(entry) for entry in value.sg_list]


def info_record(value):
    return {
        "total": value.total_icohp,
        "list": list(value.list_icohps),
        "n_bonds": value.n_bonds,
        "labels": list(value.labels),
        "atoms": [list(pair) for pair in value.atoms],
        "central_isites": value.central_isites,
    }


def main() -> None:
    data: dict[str, object] = {
        "pymatgen_version": "2026.5.4",
        "mp190_counts": {},
        "mp353_counts": {},
    }
    for condition in range(7):
        value = make(
            "CONTCAR.mp-190.gz",
            "ICOHPLIST.lobster.mp-190.gz",
            additional_condition=condition,
        )
        data["mp190_counts"][str(condition)] = counts(value)

    cases = {
        "all_005": dict(additional_condition=0, perc_strength_icohp=0.05),
        "anion_cation": dict(additional_condition=1),
        "different_elements": dict(additional_condition=2),
        "same_sign_005": dict(additional_condition=5, perc_strength_icohp=0.05),
        "same_sign_100": dict(additional_condition=5, perc_strength_icohp=1.0),
        "cation_cation_005": dict(additional_condition=6, perc_strength_icohp=0.05),
    }
    for name, options in cases.items():
        value = make(
            "CONTCAR.mp-353.gz",
            "ICOHPLIST.lobster.mp-353.gz",
            **options,
        )
        data["mp353_counts"][name] = counts(value)

    mp190 = make(
        "CONTCAR.mp-190.gz",
        "ICOHPLIST.lobster.mp-190.gz",
        additional_condition=1,
        perc_strength_icohp=0.3,
        noise_cutoff=0.0,
    )
    data["mp190_limits"] = [mp190.lowerlimit, mp190.upperlimit]
    data["mp190_site0_info"] = info_record(
        mp190.get_info_icohps_to_neighbors(isites=[0])
    )
    data["mp190_default_info"] = info_record(
        mp190.get_info_icohps_to_neighbors(isites=None)
    )
    data["mp190_between_site1"] = info_record(
        mp190.get_info_icohps_between_neighbors(isites=[1])
    )

    mp353 = make(
        "CONTCAR.mp-353.gz",
        "ICOHPLIST.lobster.mp-353.gz",
        additional_condition=1,
    )
    lse = mp353.get_light_structure_environment()
    data["mp353_valences"] = mp353.valences
    data["mp353_lse"] = [
        {
            "symbol": environments[0]["ce_symbol"],
            "csm": environments[0]["csm"],
            "permutation": environments[0]["permutation"],
        }
        for environments in lse.coordination_environments
    ]

    charged = make(
        "CONTCAR.mp-353.gz",
        "ICOHPLIST.lobster.mp-353.gz",
        additional_condition=1,
        valences_from_charges=True,
        charge_path=FIXTURES / "CHARGE.lobster.mp-353.gz",
        which_charge="Loewdin",
    )
    data["mp353_loewdin"] = charged.valences

    large = make(
        "CONTCAR.mp-1018096.gz",
        "ICOHPLIST.lobster.mp-1018096.gz",
        additional_condition=0,
        adapt_extremum_to_add_cond=True,
        valences_from_charges=True,
        charge_path=FIXTURES / "CHARGE.lobster.mp-1018096.gz",
    )
    data["large_environment_counts"] = counts(large)

    label, curve = mp190.get_info_cohps_to_neighbors(
        path_to_cohpcar=FIXTURES / "COHPCAR.lobster.mp-190.gz",
        isites=[0],
        only_bonds_to=["O"],
        per_bond=False,
    )
    data["mp190_cohp"] = {
        "label": label,
        "energy_count": len(curve.energies),
        "icohp_up_700": curve.icohp[next(iter(curve.icohp))][700],
    }

    OUTPUT.write_text(json.dumps(data, indent=2, allow_nan=True) + "\n")


if __name__ == "__main__":
    main()
