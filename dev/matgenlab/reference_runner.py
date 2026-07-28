#!/usr/bin/env python3
"""Execute deterministic pymatgen reference operations for parity tests.

The runner is a development/test dependency only. Matgenlab production code
must never invoke Python. Requests and responses use JSON so MATLAB tests can
compare results without embedding Python objects.
"""

from __future__ import annotations

import argparse
import importlib
import json
from pathlib import Path
from typing import Any

import numpy as np
from monty.json import MontyDecoder, MontyEncoder


def _decode(value: Any) -> Any:
    # ``process_decoded`` reconstructs one MSON mapping but does not walk a
    # top-level list. Oracle arguments frequently contain lists of Sites or
    # Neighbors, so recurse explicitly and reconstruct children before their
    # parent mapping.
    if isinstance(value, list):
        return [_decode(item) for item in value]
    if isinstance(value, dict):
        if set(value) == {"matgenlab_ndarray"}:
            return np.asarray(_decode(value["matgenlab_ndarray"]))
        if set(value) == {"matgenlab_spin_densities"}:
            from pymatgen.electronic_structure.core import Spin

            channels = value["matgenlab_spin_densities"]
            result = {Spin.up: np.asarray(_decode(channels["up"]))}
            if "down" in channels:
                result[Spin.down] = np.asarray(_decode(channels["down"]))
            return result
        if value.get("@class") in {"Neighbor", "PeriodicNeighbor"} and isinstance(
            value.get("species"), list
        ):
            from pymatgen.core import (
                Composition,
                Element,
                Lattice,
                PeriodicNeighbor,
                Species,
            )
            from pymatgen.core.structure import Neighbor

            converted = dict(value)
            species = {}
            for entry in value["species"]:
                oxidation = entry.get("oxidation_state")
                key = (
                    Species(entry["element"], oxidation)
                    if oxidation is not None
                    else Element(entry["element"])
                )
                species[key] = entry["occu"]
            composition = Composition(species)
            if value["@class"] == "PeriodicNeighbor":
                lattice = Lattice.from_dict(value["lattice"])
                return PeriodicNeighbor(
                    composition,
                    lattice.get_fractional_coords(value["coords"]),
                    lattice,
                    properties=value.get("properties"),
                    nn_distance=value.get("nn_distance", 0),
                    index=value.get("index", 0),
                    image=tuple(value.get("image", (0, 0, 0))),
                    label=value.get("label"),
                )
            return Neighbor(
                composition,
                value["coords"],
                properties=value.get("properties"),
                nn_distance=value.get("nn_distance", 0),
                index=value.get("index", 0),
                label=value.get("label"),
            )
        return MontyDecoder().process_decoded(value)
    return value


def _resolve(module_name: str, dotted_name: str) -> Any:
    value: Any = importlib.import_module(module_name)
    for component in dotted_name.split("."):
        value = getattr(value, component)
    return value


def _normalize(value: Any) -> Any:
    """Use plain JSON arrays/scalars for numerical parity comparisons."""

    if isinstance(value, np.ndarray):
        if np.iscomplexobj(value):
            return {
                "matgenlab_complex": {
                    "real": _normalize(value.real),
                    "imag": _normalize(value.imag),
                }
            }
        return [_normalize(item) for item in value.tolist()]
    if isinstance(value, np.generic):
        return _normalize(value.item())
    if isinstance(value, complex):
        return {
            "matgenlab_complex": {
                "real": value.real,
                "imag": value.imag,
            }
        }
    if hasattr(value, "as_dict") and callable(value.as_dict):
        return _normalize(value.as_dict())
    if isinstance(value, dict):
        return {
            key if isinstance(key, (str, int, float, bool)) else str(key):
            _normalize(item)
            for key, item in value.items()
        }
    if isinstance(value, (list, tuple)):
        return [_normalize(item) for item in value]
    return value


def execute(request: dict[str, Any]) -> dict[str, Any]:
    """Execute one reference request and return a JSON-serializable response."""

    target = _resolve(request["module"], request["symbol"])
    construct = request.get("construct")
    if construct is not None:
        method = construct.get("method")
        factory = getattr(target, method) if method else target
        decode_arguments = construct.get("decode", True)
        decode_value = _decode if decode_arguments else (lambda value: value)
        subject = factory(
            *[decode_value(value) for value in construct.get("args", [])],
            **{
                key: decode_value(value)
                for key, value in construct.get("kwargs", {}).items()
            },
        )
    else:
        subject = target

    results: list[Any] = []
    for operation in request.get("operations", []):
        kind = operation["kind"]
        name = operation.get("name")
        if kind == "get":
            result = getattr(subject, name)
        elif kind == "call":
            callable_value = getattr(subject, name) if name else subject
            result = callable_value(
                *[_decode(value) for value in operation.get("args", [])],
                **{
                    key: _decode(value)
                    for key, value in operation.get("kwargs", {}).items()
                },
            )
        elif kind == "index":
            result = subject[_decode(operation["key"])]
        else:
            raise ValueError(f"Unsupported operation kind: {kind!r}")
        results.append(_normalize(result))

    return {"ok": True, "results": results}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--response", type=Path, required=True)
    args = parser.parse_args()

    request = json.loads(args.request.read_text(encoding="utf-8"))
    try:
        response = execute(request)
    except Exception as exc:  # parity tests need structured reference failures
        response = {
            "ok": False,
            "error": {
                "type": f"{type(exc).__module__}.{type(exc).__qualname__}",
                "message": str(exc),
            },
        }

    args.response.write_text(
        json.dumps(response, cls=MontyEncoder, allow_nan=False, sort_keys=True),
        encoding="utf-8",
    )
    return 0 if response["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
