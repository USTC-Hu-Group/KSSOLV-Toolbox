#!/usr/bin/env python3
"""Freeze official pymatgen-core v2026.7.24 Critic2 parser behavior."""

from __future__ import annotations

import json
from pathlib import Path

from pymatgen.command_line.critic2_caller import Critic2Analysis
from pymatgen.core import Structure


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = (
    ROOT
    / "+kssolv"
    / "+analysis"
    / "+matgenlab"
    / "+test"
    / "+command_line"
    / "+fixtures"
    / "+critic2"
)
OUTPUT = ROOT / "dev" / "matgenlab" / "oracles" / "critic2_caller_2026.7.24.json"


def snapshot(filename: str) -> dict:
    structure = Structure.from_file(FIXTURES / "MoS2.cif")
    analysis = Critic2Analysis(
        structure, stdout=(FIXTURES / filename).read_text(encoding="utf-8")
    )
    graph = analysis.structure_graph()
    critical_points = []
    for point in analysis.critical_points:
        critical_points.append(
            {
                "index": point.index,
                "type": point.type.value,
                "frac_coords": point.frac_coords,
                "point_group": point.point_group,
                "multiplicity": point.multiplicity,
                "field": point.field,
                "field_gradient": point.field_gradient,
                "field_hessian": point.field_hessian,
                "laplacian": point.laplacian,
                "ellipticity": point.ellipticity,
            }
        )
    nodes = [
        {
            "index": index,
            "unique_idx": node["unique_idx"],
            "frac_coords": node["frac_coords"],
        }
        for index, node in sorted(analysis.nodes.items())
    ]
    edges = [{"index": index, **edge} for index, edge in sorted(analysis.edges.items())]
    graph_edges = []
    for first, second, data in graph.graph.edges(data=True):
        graph_edges.append(
            {
                "from_idx": first,
                "to_idx": second,
                "to_jimage": data["to_jimage"],
                "weight": data["weight"],
                "field": data["field"],
                "laplacian": data["laplacian"],
                "ellipticity": data["ellipticity"],
                "frac_coords": data["frac_coords"],
            }
        )
    return {
        "critical_points": critical_points,
        "nodes": nodes,
        "edges": edges,
        "graph": {
            "site_count": len(graph.structure),
            "edge_count": graph.graph.number_of_edges(),
            "fourth_species": str(graph.structure[3].specie),
            "edges": graph_edges,
        },
    }


def main() -> None:
    oracle = {
        "metadata": {
            "source": "pymatgen-core",
            "tag": "v2026.7.24",
            "module": "pymatgen.command_line.critic2_caller",
            "api_count": 13,
        },
        "legacy": snapshot("MoS2_critic2_stdout.txt"),
        "new_format": snapshot("MoS2_critic2_stdout_new_format.txt"),
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(
            oracle,
            indent=2,
            default=lambda value: value.tolist()
            if hasattr(value, "tolist")
            else int(value),
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
