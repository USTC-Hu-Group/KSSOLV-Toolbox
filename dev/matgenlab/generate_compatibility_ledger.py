#!/usr/bin/env python3
"""Generate an auditable pymatgen-to-matgenlab API compatibility ledger.

The frozen upstream API inventory is the denominator. Static MATLAB discovery
only produces ``candidate`` rows; an API becomes ``implemented`` solely through
an explicit override that names its verification evidence.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INVENTORY = ROOT / "dev/matgenlab/inventory/api.csv"
OVERRIDES = ROOT / "dev/matgenlab/api_status_overrides.csv"
OUTPUT_CSV = ROOT / "dev/matgenlab/inventory/compatibility_ledger.csv"
OUTPUT_JSON = ROOT / "dev/matgenlab/inventory/compatibility_summary.json"
MATLAB_ROOT = ROOT / "+kssolv/+analysis/+matgenlab"

RELEASE_STATES = {
    "implemented",
    "external",
    "unsupported-upstream",
    "license-blocked",
}


def api_id(row: dict[str, str]) -> str:
    return "::".join(
        (row["source"], row["module"], row["kind"], row["qualname"] or row["name"])
    )


def matlab_module_dir(module: str) -> Path:
    parts = module.split(".")[1:]
    return MATLAB_ROOT.joinpath(*(f"+{part}" for part in parts))


def find_class_file(class_name: str, module: str | None = None) -> Path | None:
    if module:
        preferred = matlab_module_dir(module) / f"{class_name}.m"
        if preferred.is_file():
            return preferred
    matches = sorted(MATLAB_ROOT.rglob(f"{class_name}.m"))
    matches = [path for path in matches if "+test" not in path.parts]
    return matches[0] if matches else None


def find_function_file(function_name: str, module: str) -> Path | None:
    preferred = matlab_module_dir(module) / f"{function_name}.m"
    if preferred.is_file():
        return preferred
    # Core modules are intentionally flattened into the MATLAB +core package.
    # Prefer that canonical implementation over same-named helpers elsewhere
    # (for example ChemEnv also owns a private solid_angle implementation).
    if module.startswith("pymatgen.core."):
        core_preferred = MATLAB_ROOT / "+core" / f"{function_name}.m"
        if core_preferred.is_file():
            return core_preferred
    matches = sorted(MATLAB_ROOT.rglob(f"{function_name}.m"))
    matches = [path for path in matches if "+test" not in path.parts]
    return matches[0] if matches else None


def class_hierarchy_files(class_name: str, module: str | None = None) -> list[Path]:
    """Return the class file followed by locally implemented base classes."""

    paths: list[Path] = []
    pending = [class_name]
    visited: set[str] = set()
    while pending:
        current = pending.pop(0)
        if current in visited:
            continue
        visited.add(current)
        path = find_class_file(current, module)
        if path is None:
            continue
        paths.append(path)
        text = path.read_text(encoding="utf-8")
        flattened = re.sub(r"\.\.\.\s*\n\s*", " ", text)
        match = re.search(
            rf"classdef(?:\s*\([^)]*\))?\s+{re.escape(current)}\s*<\s*([^\n]+)",
            flattened,
        )
        if match:
            for base in match.group(1).split("&"):
                pending.append(base.strip().rsplit(".", 1)[-1])
    return paths


def static_candidate(row: dict[str, str]) -> tuple[str, str]:
    kind = row["kind"]
    name = row["name"]
    qualname = row["qualname"]
    if kind == "class":
        path = find_class_file(name, row["module"])
        return ("candidate", relative(path)) if path else ("missing", "")
    if kind in {"method", "property"}:
        class_name = qualname.split(".", 1)[0]
        path = find_class_file(class_name, row["module"])
        if path is None:
            return "missing", ""
        for candidate_path in class_hierarchy_files(class_name, row["module"]):
            text = candidate_path.read_text(encoding="utf-8")
            if re.search(rf"\b{re.escape(name)}\b", text):
                return "candidate", relative(candidate_path)
        return "missing", relative(path)
    if kind == "function":
        path = find_function_file(name, row["module"])
        return ("candidate", relative(path)) if path else ("missing", "")
    if kind == "import":
        target = row["import_target"].rsplit(".", 1)[-1]
        path = find_class_file(target)
        if path is None:
            path = find_function_file(target, row["module"])
        return ("candidate", relative(path)) if path else ("missing", "")
    return "missing", ""


def relative(path: Path | None) -> str:
    return "" if path is None else path.relative_to(ROOT).as_posix()


def load_overrides() -> dict[str, dict[str, str]]:
    if not OVERRIDES.exists():
        return {}
    with OVERRIDES.open(newline="", encoding="utf-8") as handle:
        result = {}
        for row in csv.DictReader(handle):
            if row["api_id"] in result:
                raise ValueError(f"Duplicate override for {row['api_id']}")
            if row["status"] not in RELEASE_STATES:
                raise ValueError(
                    f"Invalid override status {row['status']!r} for {row['api_id']}"
                )
            if not row["evidence"].strip():
                raise ValueError(f"Override lacks evidence for {row['api_id']}")
            result[row["api_id"]] = row
        return result


def generate(check: bool = False) -> dict[str, object]:
    overrides = load_overrides()
    with INVENTORY.open(newline="", encoding="utf-8") as handle:
        inventory = list(csv.DictReader(handle))

    ledger: list[dict[str, str]] = []
    seen_overrides: set[str] = set()
    for source_row in inventory:
        identifier = api_id(source_row)
        discovered, matlab_path = static_candidate(source_row)
        override = overrides.get(identifier)
        if override:
            status = override["status"]
            evidence = override["evidence"]
            notes = override.get("notes", "")
            seen_overrides.add(identifier)
        else:
            status = discovered
            evidence = ""
            notes = ""
        ledger.append(
            {
                "api_id": identifier,
                "source": source_row["source"],
                "module": source_row["module"],
                "kind": source_row["kind"],
                "name": source_row["name"],
                "qualname": source_row["qualname"],
                "signature": source_row["signature"],
                "status": status,
                "matlab_path": matlab_path,
                "evidence": evidence,
                "notes": notes,
            }
        )

    unknown = sorted(set(overrides) - seen_overrides)
    if unknown:
        raise ValueError(f"Overrides not present in frozen inventory: {unknown[:5]}")

    counts = Counter(row["status"] for row in ledger)
    module_counts: dict[str, Counter[str]] = {}
    for row in ledger:
        module_counts.setdefault(row["module"], Counter())[row["status"]] += 1
    summary: dict[str, object] = {
        "inventory": relative(INVENTORY),
        "total": len(ledger),
        "release_complete": sum(counts[state] for state in RELEASE_STATES),
        "counts": dict(sorted(counts.items())),
        "modules": {
            module: dict(sorted(values.items()))
            for module, values in sorted(module_counts.items())
        },
    }

    fieldnames = list(ledger[0])
    csv_text = render_csv(ledger, fieldnames)
    json_text = json.dumps(summary, indent=2, sort_keys=True) + "\n"
    if check:
        if not OUTPUT_CSV.exists() or OUTPUT_CSV.read_text() != csv_text:
            raise SystemExit(f"{relative(OUTPUT_CSV)} is stale")
        if not OUTPUT_JSON.exists() or OUTPUT_JSON.read_text() != json_text:
            raise SystemExit(f"{relative(OUTPUT_JSON)} is stale")
    else:
        OUTPUT_CSV.write_text(csv_text, encoding="utf-8")
        OUTPUT_JSON.write_text(json_text, encoding="utf-8")
    return summary


def render_csv(rows: list[dict[str, str]], fields: list[str]) -> str:
    import io

    buffer = io.StringIO(newline="")
    writer = csv.DictWriter(buffer, fieldnames=fields, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return buffer.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    summary = generate(check=args.check)
    print(json.dumps(summary["counts"], sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
