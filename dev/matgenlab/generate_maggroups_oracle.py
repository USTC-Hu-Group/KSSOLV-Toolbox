"""Generate frozen pymatgen-core 2026.7.24 magnetic-group references."""

from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

from pymatgen.core import Lattice
from pymatgen.symmetry.maggroups import MagneticSpaceGroup


ROOT = Path(__file__).resolve().parents[2]
DATABASE = Path(
    "/tmp/matgenlab-plan.tMNeV8/pymatgen-core-2026.7.24/"
    "src/pymatgen/symmetry/symm_data_magnetic.sqlite"
)
TARGET = ROOT / "dev/matgenlab/oracles/maggroups_2026.7.24.json"


def operations(group: MagneticSpaceGroup) -> list[dict]:
    return [
        {
            "rotation": op.rotation_matrix.tolist(),
            "translation": op.translation_vector.tolist(),
            "time_reversal": op.time_reversal,
        }
        for op in group.symmetry_ops
    ]


def main() -> None:
    connection = sqlite3.connect(DATABASE)
    identifiers = connection.execute(
        "SELECT magtype, BNS1, BNS2, BNS_label, OG1, OG2, OG3, OG_label "
        "FROM space_groups ORDER BY OG3"
    ).fetchall()
    connection.close()
    identifier_text = "\n".join("|".join(map(str, row)) for row in identifiers)

    msg_2 = MagneticSpaceGroup([62, 448])
    msg_3 = MagneticSpaceGroup([20, 37])
    msg_4 = MagneticSpaceGroup(
        [2, 7], "c,1/4a+1/4b,-1/2a+1/2b;0,0,0"
    )
    orbit_group = MagneticSpaceGroup("Pn'ma'")
    orbit, moments = orbit_group.get_orbit([0.11, 0.22, 0.33], [1, 2, 3])
    lattices = {
        "cubic": Lattice.cubic(1),
        "hexagonal": Lattice.hexagonal(1, 2),
        "rhombohedral": Lattice.rhombohedral(3, 80),
        "tetragonal": Lattice.tetragonal(1, 2),
        "orthorhombic": Lattice.orthorhombic(1, 2, 3),
    }
    compatibility = {}
    for label in ["Fm-3m", "Pnma", "P2/c", "P-1"]:
        group = MagneticSpaceGroup(label)
        compatibility[label] = {
            name: group.is_compatible(lattice)
            for name, lattice in lattices.items()
        }

    group_411 = MagneticSpaceGroup([4, 11])
    payload = {
        "upstream": "pymatgen-core 2026.7.24",
        "database": {
            "count": len(identifiers),
            "identifier_sha256": hashlib.sha256(
                identifier_text.encode()
            ).hexdigest(),
            "samples": [
                list(identifiers[index])
                for index in [0, 229, 230, 529, 1649, 1650]
            ],
        },
        "identity": {
            "bns_label": MagneticSpaceGroup([71, 538]).sg_symbol,
            "og_label": MagneticSpaceGroup.from_og([65, 10, 554]).sg_symbol,
            "crystal_systems": [
                {"label": label, "system": MagneticSpaceGroup(label).crystal_system}
                for label in [[1, 1], [2, 4], [16, 1], [75, 1],
                              [143, 1], [168, 109], [195, 1]]
            ],
        },
        "symbols": [
            {"label": [70, 530], "symbol": MagneticSpaceGroup([70, 530]).sg_symbol},
            {"label": [62, 448], "symbol": msg_2.sg_symbol},
            {"label": [20, 37], "symbol": msg_3.sg_symbol},
        ],
        "operations": [
            {"id": "62.448", "values": operations(msg_2)},
            {"id": "20.37", "values": operations(msg_3)},
            {"id": "2.7_transformed", "values": operations(msg_4)},
        ],
        "orbit": {
            "points": [point.tolist() for point in orbit],
            "magmoms": [moment.global_moment.tolist() for moment in moments],
        },
        "compatibility": [
            {"label": label, "values": values}
            for label, values in compatibility.items()
        ],
        "data_str": group_411.data_str(),
        "str": str(group_411),
    }
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(TARGET)


if __name__ == "__main__":
    main()
