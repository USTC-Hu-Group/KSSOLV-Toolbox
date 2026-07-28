#!/usr/bin/env python3
"""Generate frozen pymatgen 2026.5.4 master pmg CLI output."""

from __future__ import annotations

import contextlib
import io
import json
from pathlib import Path

from pymatgen.cli import pmg

root = Path(__file__).resolve().parents[2]
fixture = root / "+kssolv/+analysis/+matgenlab/+test/+cli/+fixtures/+pmg"
stream = io.StringIO()
with contextlib.redirect_stdout(stream):
    status = pmg.main(
        ["diff", "--incar", str(fixture / "INCAR"), str(fixture / "INCAR_2")]
    )
diff_output = stream.getvalue()
diff_body = "SAME PARAMS" + diff_output.split("SAME PARAMS", 1)[1]
stream = io.StringIO()
empty_error = ""
with contextlib.redirect_stdout(stream):
    try:
        pmg.main([])
    except SystemExit as exc:
        empty_error = str(exc)
oracle = {
    "source": "pymatgen 2026.5.4",
    "diff_status": status,
    "diff_body": diff_body,
    "empty_error": empty_error,
    "empty_help": stream.getvalue(),
}
output = root / "dev/matgenlab/oracles/pmg_2026.5.4.json"
output.write_text(json.dumps(oracle, indent=2) + "\n", encoding="utf-8")
print(output)
