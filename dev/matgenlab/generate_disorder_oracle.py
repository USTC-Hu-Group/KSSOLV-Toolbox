#!/usr/bin/env python3
"""Emit Warren-Cowley reference values from frozen pymatgen."""

from __future__ import annotations

import json

from pymatgen.analysis.disorder import get_warren_cowley_parameters
from pymatgen.core import Element, Structure


def main() -> None:
    structure = Structure.from_prototype("CsCl", ["Mo", "W"], a=4)
    first = get_warren_cowley_parameters(structure, r=3.4, dr=0.3)
    second = get_warren_cowley_parameters(structure, r=4, dr=0.2)
    structure *= 4
    structure[0] = "W"
    structure[len(structure) - 1] = "Mo"
    disordered = get_warren_cowley_parameters(structure, r=3.4, dr=0.3)
    print(
        json.dumps(
            {
                "ordered_cross": first[Element.Mo, Element.W],
                "ordered_same": second[Element.Mo, Element.Mo],
                "swapped_cross": disordered[Element.Mo, Element.W],
                "swapped_reverse": disordered[Element.W, Element.Mo],
            },
            indent=2,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
