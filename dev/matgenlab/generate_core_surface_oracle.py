"""Generate frozen pymatgen-core surface reference data for MATLAB tests."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from pymatgen.core import Lattice, Structure
from pymatgen.core.surface import (
    ReconstructionGenerator,
    SlabGenerator,
    generate_all_slabs,
    get_d,
    get_symmetrically_distinct_miller_indices,
    get_symmetrically_equivalent_miller_indices,
    hkl_transformation,
    miller_index_from_sites,
)


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "+kssolv/+analysis/+matgenlab/+test/+fixtures/+core/surfaces"
OUTPUT = ROOT / "dev/matgenlab/oracles/core_surface_2026.7.24.json"


def structure_payload(structure: Structure) -> dict:
    return {
        "num_sites": len(structure),
        "lattice": np.asarray(structure.lattice.matrix).tolist(),
        "frac_coords": np.asarray(structure.frac_coords).tolist(),
        "species": [site.species_string for site in structure],
    }


def slab_payload(slab) -> dict:
    data = structure_payload(slab)
    data.update(
        {
            "miller_index": list(slab.miller_index),
            "shift": slab.shift,
            "scale_factor": np.asarray(slab.scale_factor).tolist(),
            "surface_area": slab.surface_area,
            "normal": slab.normal.tolist(),
            "center_of_mass": slab.center_of_mass.tolist(),
            "dipole": slab.dipole.tolist(),
            "is_symmetric": slab.is_symmetric(),
            "is_polar": slab.is_polar(),
            "energy": slab.energy,
            "ouc_num_sites": len(slab.oriented_unit_cell),
            "ouc_lattice": np.asarray(slab.oriented_unit_cell.lattice.matrix).tolist(),
        }
    )
    return data


def main() -> None:
    cscl = Structure.from_spacegroup(
        "Pm-3m", Lattice.cubic(4.2), ["Cs", "Cl"], [[0, 0, 0], [0.5, 0.5, 0.5]]
    )
    fe = Structure.from_spacegroup("Im-3m", Lattice.cubic(2.82), ["Fe"], [[0, 0, 0]])
    ag = Structure(
        Lattice.cubic(4.06),
        ["Ag"] * 4,
        [[0, 0, 0], [0, 0.5, 0.5], [0.5, 0, 0.5], [0.5, 0.5, 0]],
    )
    mg = Structure(
        Lattice.from_parameters(3.2, 3.2, 5.13, 90, 90, 120),
        ["Mg", "Mg"],
        [[1 / 3, 2 / 3, 1 / 4], [2 / 3, 1 / 3, 3 / 4]],
    )
    mgo = Structure(
        Lattice.cubic(3.010),
        ["Mg"] * 4 + ["O"] * 4,
        [
            [0, 0, 0],
            [0, 0.5, 0.5],
            [0.5, 0, 0.5],
            [0.5, 0.5, 0],
            [0.5, 0, 0],
            [0.5, 0.5, 0.5],
            [0, 0, 0.5],
            [0, 0.5, 0],
        ],
    )
    mgo.add_oxidation_state_by_element({"Mg": 2, "O": -6})

    fcc = Structure.from_spacegroup("Fm-3m", Lattice.cubic(3), ["Fe"], [[0, 0, 0]])
    fcc_gen = SlabGenerator(fcc, [1, 1, 1], 10, 10, max_normal_search=1)
    fcc_slab = fcc_gen.get_slab()
    fcc_nonprimitive = SlabGenerator(
        fcc, [1, 1, 1], 10, 10, primitive=False, max_normal_search=1
    ).get_slab()

    ag_results = {}
    for centered in (False, True):
        slab = SlabGenerator(ag, (3, 1, 0), 10, 10, center_slab=centered).get_slabs()[0]
        surface_sites = slab.get_surface_sites()
        ag_results[str(centered).lower()] = {
            "slab": slab_payload(slab),
            "top_surface_sites": len(surface_sites["top"]),
            "bottom_surface_sites": len(surface_sites["bottom"]),
        }

    tasker_source = SlabGenerator(mgo, (1, 1, 1), 10, 10, max_normal_search=1).get_slabs()[0]
    tasker_source.make_supercell([2, 1, 1])
    tasker = tasker_source.get_tasker2_slabs()

    reconstructions = {}
    ni = Structure.from_spacegroup("Fm-3m", Lattice.cubic(3.51), ["Ni"], [[0, 0, 0]])
    for name in (
        "fcc_110_missing_row_1x2",
        "fcc_111_adatom_t_1x1",
        "fcc_111_adatom_ft_1x1",
    ):
        generator = ReconstructionGenerator(ni, 10, 10, name)
        plain = generator.get_unreconstructed_slabs()[0]
        rebuilt = generator.build_slabs()[0]
        reconstructions[name] = {
            "plain_sites": len(plain),
            "reconstructed_sites": len(rebuilt),
            "plain_ouc_sites": len(plain.oriented_unit_cell),
            "reconstructed_ouc_sites": len(rebuilt.oriented_unit_cell),
            "reconstruction": rebuilt.reconstruction,
            "symmetric": rebuilt.is_symmetric(),
            "surface_area": rebuilt.surface_area,
        }

    cubic = Lattice.cubic(1)
    miller_sites = [[0.5, -1.5, 3], [0.5, 3, -1.5], [2.5, 1.5, -4]]
    data = {
        "source": {
            "distribution": "pymatgen-core",
            "version": "2026.7.24",
        },
        "miller": {
            "cscl_distinct_1": get_symmetrically_distinct_miller_indices(cscl, 1),
            "cscl_distinct_2": get_symmetrically_distinct_miller_indices(cscl, 2),
            "mg_equivalent_100": get_symmetrically_equivalent_miller_indices(mg, (1, 0, 0)),
            "mg_equivalent_200": get_symmetrically_equivalent_miller_indices(mg, (2, 0, 0)),
            "cubic_sites": miller_index_from_sites(cubic, miller_sites),
            "transformation": hkl_transformation(
                np.array([[0.5, 0.5, 0], [-0.5, 0.5, 0], [0, 0, 1]]),
                (1, 1, 0),
            ),
        },
        "fcc_111": {
            "primitive": slab_payload(fcc_slab),
            "nonprimitive": slab_payload(fcc_nonprimitive),
        },
        "ag_310": ag_results,
        "tasker": {
            "source": slab_payload(tasker_source),
            "count": len(tasker),
            "slabs": [slab_payload(slab) for slab in tasker],
        },
        "counts": {
            "cscl_get_slabs": len(SlabGenerator(cscl, [0, 0, 1], 10, 10).get_slabs()),
            "cscl_all_index_1": len(generate_all_slabs(cscl, 1, 10, 10)),
            "fe_all_with_reconstruction": len(
                generate_all_slabs(fe, 1, 10, 10, include_reconstructions=True)
            ),
        },
        "reconstructions": reconstructions,
        "get_d": get_d(ReconstructionGenerator(ni, 10, 10, "fcc_110_missing_row_1x2").get_unreconstructed_slabs()[0]),
    }
    OUTPUT.write_text(
        json.dumps(
            data,
            indent=2,
            default=lambda value: value.item()
            if isinstance(value, np.generic)
            else np.asarray(value).tolist(),
        )
        + "\n"
    )


if __name__ == "__main__":
    main()
