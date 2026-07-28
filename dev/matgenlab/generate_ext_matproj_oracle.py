#!/usr/bin/env python3
"""Freeze pymatgen 2026.5.4 ext.matproj request-contract behavior."""

from __future__ import annotations

import gzip
import json
from pathlib import Path
from unittest.mock import patch

from pymatgen.ext.matproj import MPRester, MPRestError

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "dev/matgenlab/oracles/ext_matproj_2026.5.4.json"


class Recorder:
    def __init__(self):
        self.calls = []

    def __call__(self, sub_url, payload=None, method="GET", mp_decode=True, timeout=60):
        self.calls.append(
            {
                "sub_url": sub_url,
                "payload": payload,
                "method": method,
                "mp_decode": mp_decode,
                "timeout": timeout,
            }
        )
        if "material_ids=mp-1" in sub_url:
            return [{"structure": "final"}]
        if "initial_structures" in sub_url:
            return [{"initial_structures": ["first", "second"]}]
        if "_fields=initial_structure" in sub_url:
            return [{"initial_structure": "initial"}]
        if "_fields=structure" in sub_url:
            return [{"structure": "final"}]
        if payload and payload.get("material_ids"):
            return [{"material_id": payload["material_ids"]}]
        if payload and payload.get("formula") == "Al2O3":
            return [{"material_id": "mp-1143"}]
        return []


class Response:
    def __init__(self, status_code, data, reason=""):
        self.status_code = status_code
        self.text = json.dumps(data)
        self.content = self.text.encode()
        self.reason = reason


class Session:
    def __init__(self, responses):
        self.responses = iter(responses)
        self.calls = []

    def get(self, url, params=None, verify=True, timeout=60):
        self.calls.append(
            {
                "url": url,
                "params": params,
                "verify": verify,
                "timeout": timeout,
            }
        )
        return next(self.responses)


def method_contracts():
    rester = MPRester("a" * 32, include_user_agent=False)
    recorder = Recorder()
    rester.request = recorder
    rester.search(
        "summary",
        material_ids=["mp-1", "mp-2"],
        nsites="1,4",
        _fields=["material_id", "formula_pretty"],
    )
    rester.summary_search(formula="Fe2O3")
    rester.get_summary({"formula": "Fe2O3"})
    rester.get_summary({"formula": "Al2O3"}, fields=["material_id"])
    rester.get_summary_by_material_id("mp-19770", ["formula_pretty"])
    rester.get_material_ids("Al2O3")
    rester.get_structures("Mn3O4")
    rester.get_structures("Li-Fe-O", final=False)
    rester.get_structure_by_material_id("mp-1")
    rester.get_initial_structures_by_material_id("mp-1")
    rester.get_entries("Li-Fe-O", compatible_only=False)
    rester.get_entries(["Fe2O3", "Li-Fe-O"], compatible_only=False)
    rester.get_entries_in_chemsys(["Li", "Fe", "O"], compatible_only=False)
    return recorder.calls


def pagination_contracts():
    first = [{"index": index} for index in range(1000)]
    session = Session(
        [
            Response(200, {"data": first}),
            Response(200, {"data": [{"index": 1000}, {"index": 1001}]}),
        ]
    )
    rester = MPRester("a" * 32, include_user_agent=False)
    rester.session = session
    data = rester.request("materials/summary/?_all_fields=True", {"formula": "Fe"})

    retry_session = Session(
        [
            Response(
                400,
                {
                    "detail": "Extra inputs are not permitted: _per_page and _page"
                },
            ),
            Response(200, {"data": [{"material_id": "mp-13"}]}),
        ]
    )
    rester.session = retry_session
    retry_data = rester.request("materials/core/?_all_fields=True")

    error_session = Session([Response(503, {"detail": "down"})])
    rester.session = error_session
    try:
        rester.request("materials/core/?_all_fields=True")
    except MPRestError as exc:
        error = str(exc)
    return {
        "paged_calls": session.calls,
        "paged_count": len(data),
        "retry_calls": retry_session.calls,
        "retry_data": retry_data,
        "error": error,
    }


def s3_contract():
    calls = []

    def get(url, timeout=60):
        calls.append({"url": url, "timeout": timeout})
        payload = gzip.compress(json.dumps({"marker": 17}).encode())
        response = Response(200, {})
        response.content = payload
        return response

    rester = MPRester("a" * 32, include_user_agent=False)
    with patch("pymatgen.ext.matproj.requests.get", get):
        value = rester._retrieve_object_from_s3(
            "mp-661", "materialsproject-parsed", "ph-dos/dfpt", timeout=7
        )
    return {"calls": calls, "value": value}


def main():
    payload = {
        "source": "pymatgen 2026.5.4",
        "method_calls": method_contracts(),
        "pagination": pagination_contracts(),
        "s3": s3_contract(),
        "materials_docs": list(MPRester.MATERIALS_DOCS),
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(OUTPUT)


if __name__ == "__main__":
    main()
