#!/usr/bin/env python3
"""Generate the frozen matgenlab upstream API and test inventory.

The scanner uses only the Python standard library. By default it shallow-clones
the exact tags described in upstream_baseline.json, verifies the resulting
commits, and writes deterministic JSON/CSV files beside this script.

Local, already checked-out sources may be supplied with:

    --source pymatgen=/path/to/pymatgen
    --source pymatgen-core=/path/to/pymatgen-core

Those checkouts are subject to the same exact-commit verification.
"""

from __future__ import annotations

import argparse
import ast
import csv
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_BASELINE = SCRIPT_DIR / "upstream_baseline.json"
DEFAULT_OUTPUT = SCRIPT_DIR / "inventory"
CSV_FILES = ("sources.csv", "modules.csv", "api.csv", "tests.csv", "fixtures.csv")


class InventoryError(RuntimeError):
    """Raised when an inventory cannot be generated from the frozen sources."""


@dataclass(frozen=True)
class SourceCheckout:
    """A verified upstream source checkout."""

    spec: dict[str, Any]
    root: Path

    @property
    def source_id(self) -> str:
        return str(self.spec["id"])


def load_baseline(path: Path) -> dict[str, Any]:
    """Load and minimally validate the frozen source declaration."""

    with path.open(encoding="utf-8") as handle:
        baseline = json.load(handle)
    if baseline.get("schema_version") != 1:
        raise InventoryError(f"Unsupported baseline schema in {path}")
    sources = baseline.get("sources")
    if not isinstance(sources, list) or not sources:
        raise InventoryError(f"No upstream sources declared in {path}")
    required = {
        "id",
        "repository",
        "tag",
        "commit",
        "commit_date",
        "license",
        "source_roots",
        "test_roots",
        "fixture_roots",
    }
    seen: set[str] = set()
    for source in sources:
        missing = required - source.keys()
        if missing:
            raise InventoryError(
                f"Source {source.get('id', '<unknown>')} lacks {sorted(missing)}"
            )
        source_id = str(source["id"])
        if source_id in seen:
            raise InventoryError(f"Duplicate source id: {source_id}")
        seen.add(source_id)
        commit = str(source["commit"])
        if len(commit) != 40 or any(char not in "0123456789abcdef" for char in commit):
            raise InventoryError(f"Source {source_id} has an invalid full commit")
    return baseline


def parse_source_overrides(values: Sequence[str]) -> dict[str, Path]:
    """Parse repeated ID=PATH checkout overrides."""

    overrides: dict[str, Path] = {}
    for value in values:
        source_id, separator, raw_path = value.partition("=")
        if not separator or not source_id or not raw_path:
            raise InventoryError(f"Invalid --source value {value!r}; expected ID=PATH")
        if source_id in overrides:
            raise InventoryError(f"Duplicate --source override for {source_id}")
        overrides[source_id] = Path(raw_path).expanduser().resolve()
    return overrides


def run_git(arguments: Sequence[str], cwd: Path | None = None) -> str:
    """Run git and return stripped stdout with actionable errors."""

    command = ["git", *arguments]
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        raise InventoryError("git is required to fetch and verify sources") from exc
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.strip() or exc.stdout.strip()
        raise InventoryError(f"{' '.join(command)} failed: {detail}") from exc
    return result.stdout.strip()


def verify_checkout(root: Path, source: dict[str, Any]) -> None:
    """Require the checkout to resolve exactly to the frozen commit."""

    if not root.is_dir():
        raise InventoryError(f"Source path does not exist: {root}")
    actual = run_git(["rev-parse", "HEAD"], cwd=root)
    expected = str(source["commit"])
    if actual != expected:
        raise InventoryError(
            f"{source['id']} is at {actual}, expected frozen commit {expected}"
        )
    for key in ("source_roots", "test_roots", "fixture_roots"):
        for relative in source[key]:
            path = root / relative
            if not path.is_dir():
                raise InventoryError(f"{source['id']} lacks declared {key}: {relative}")


def acquire_sources(
    baseline: dict[str, Any],
    overrides: dict[str, Path],
    temporary_root: Path,
) -> list[SourceCheckout]:
    """Resolve overrides or shallow-clone every declared source."""

    temporary_root.mkdir(parents=True, exist_ok=True)
    known_ids = {str(source["id"]) for source in baseline["sources"]}
    unknown_ids = set(overrides) - known_ids
    if unknown_ids:
        raise InventoryError(f"Unknown --source ids: {sorted(unknown_ids)}")

    checkouts: list[SourceCheckout] = []
    for source in baseline["sources"]:
        source_id = str(source["id"])
        if source_id in overrides:
            root = overrides[source_id]
        else:
            root = temporary_root / source_id
            run_git(
                [
                    "clone",
                    "--quiet",
                    "--depth",
                    "1",
                    "--branch",
                    str(source["tag"]),
                    str(source["repository"]),
                    str(root),
                ]
            )
        verify_checkout(root, source)
        checkouts.append(SourceCheckout(source, root))
    return checkouts


def sha256_file(path: Path) -> str:
    """Return a file's lowercase SHA-256 digest."""

    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_public_name(name: str) -> bool:
    """Apply pymatgen's conventional underscore-based public-name rule."""

    return bool(name) and not name.startswith("_")


def module_name(source_root: Path, path: Path) -> str:
    """Convert a Python source path below src/pymatgen to its module name."""

    relative = path.relative_to(source_root)
    parts = list(relative.with_suffix("").parts)
    if parts[-1] == "__init__":
        parts.pop()
    return ".".join(("pymatgen", *parts)) if parts else "pymatgen"


def safe_unparse(node: ast.AST | None) -> str:
    """Return a deterministic compact representation of an AST node."""

    if node is None:
        return ""
    try:
        return ast.unparse(node)
    except (AttributeError, ValueError):
        return ""


def function_signature(node: ast.FunctionDef | ast.AsyncFunctionDef) -> str:
    """Reconstruct a function signature from its AST."""

    signature = f"({safe_unparse(node.args)})"
    if node.returns is not None:
        signature += f" -> {safe_unparse(node.returns)}"
    return signature


def decorator_names(decorators: Iterable[ast.expr]) -> list[str]:
    """Render decorators without the leading at-sign."""

    return [safe_unparse(item) for item in decorators]


def first_doc_line(node: ast.AST) -> str:
    """Return the first non-empty line of an object's docstring."""

    docstring = ast.get_docstring(node, clean=True) or ""
    for line in docstring.splitlines():
        if line.strip():
            return line.strip()
    return ""


def explicit_all(tree: ast.Module) -> list[str] | None:
    """Extract a literal module __all__, if present."""

    for node in tree.body:
        value: ast.expr | None = None
        if isinstance(node, ast.Assign):
            if any(isinstance(target, ast.Name) and target.id == "__all__" for target in node.targets):
                value = node.value
        elif isinstance(node, ast.AnnAssign):
            if isinstance(node.target, ast.Name) and node.target.id == "__all__":
                value = node.value
        if value is not None:
            try:
                evaluated = ast.literal_eval(value)
            except (ValueError, TypeError):
                return None
            if isinstance(evaluated, (list, tuple)) and all(
                isinstance(item, str) for item in evaluated
            ):
                return list(evaluated)
    return None


def imported_symbols(
    tree: ast.Module,
    declared_all: list[str] | None,
    *,
    is_package: bool,
) -> list[dict[str, Any]]:
    """Record intentional package re-exports.

    Imports in ordinary implementation modules are dependencies, not public API.
    Package initializers are treated as re-export surfaces; a literal ``__all__``
    remains authoritative in any module.
    """

    if declared_all is None and not is_package:
        return []
    selected = set(declared_all) if declared_all is not None else None
    records: list[dict[str, Any]] = []
    for node in tree.body:
        candidates: list[tuple[str, str]] = []
        if isinstance(node, ast.Import):
            for alias in node.names:
                exposed = alias.asname or alias.name.split(".", maxsplit=1)[0]
                candidates.append((exposed, alias.name))
        elif isinstance(node, ast.ImportFrom):
            prefix = "." * node.level + (node.module or "")
            for alias in node.names:
                if alias.name == "*":
                    continue
                exposed = alias.asname or alias.name
                target = f"{prefix}.{alias.name}" if prefix else alias.name
                candidates.append((exposed, target))
        for exposed, target in candidates:
            if (selected is not None and exposed not in selected) or (
                selected is None and not is_public_name(exposed)
            ):
                continue
            records.append(
                {
                    "kind": "import",
                    "name": exposed,
                    "qualname": exposed,
                    "signature": "",
                    "lineno": node.lineno,
                    "doc_summary": "",
                    "decorators": [],
                    "bases": [],
                    "import_target": target,
                }
            )
    return records


def module_api(tree: ast.Module, *, is_package: bool) -> list[dict[str, Any]]:
    """Extract public classes, functions, methods, properties, and re-exports."""

    declared_all = explicit_all(tree)
    selected = set(declared_all) if declared_all is not None else None
    records: list[dict[str, Any]] = []
    for node in tree.body:
        if not isinstance(node, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        if (selected is not None and node.name not in selected) or (
            selected is None and not is_public_name(node.name)
        ):
            continue
        if isinstance(node, ast.ClassDef):
            constructor = next(
                (
                    member
                    for member in node.body
                    if isinstance(member, (ast.FunctionDef, ast.AsyncFunctionDef))
                    and member.name in {"__init__", "__new__"}
                ),
                None,
            )
            signature = function_signature(constructor) if constructor else ""
            records.append(
                {
                    "kind": "class",
                    "name": node.name,
                    "qualname": node.name,
                    "signature": signature,
                    "lineno": node.lineno,
                    "doc_summary": first_doc_line(node),
                    "decorators": decorator_names(node.decorator_list),
                    "bases": [safe_unparse(base) for base in node.bases],
                    "import_target": "",
                }
            )
            for member in node.body:
                if not isinstance(member, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    continue
                is_property = any(
                    safe_unparse(decorator) in {"property", "cached_property"}
                    or safe_unparse(decorator).endswith(".setter")
                    for decorator in member.decorator_list
                )
                if not is_public_name(member.name) and not is_property:
                    continue
                records.append(
                    {
                        "kind": "property" if is_property else "method",
                        "name": member.name,
                        "qualname": f"{node.name}.{member.name}",
                        "signature": function_signature(member),
                        "lineno": member.lineno,
                        "doc_summary": first_doc_line(member),
                        "decorators": decorator_names(member.decorator_list),
                        "bases": [],
                        "import_target": "",
                    }
                )
        else:
            records.append(
                {
                    "kind": "async_function"
                    if isinstance(node, ast.AsyncFunctionDef)
                    else "function",
                    "name": node.name,
                    "qualname": node.name,
                    "signature": function_signature(node),
                    "lineno": node.lineno,
                    "doc_summary": first_doc_line(node),
                    "decorators": decorator_names(node.decorator_list),
                    "bases": [],
                    "import_target": "",
                }
            )
    existing = {(record["kind"], record["name"]) for record in records}
    for imported in imported_symbols(tree, declared_all, is_package=is_package):
        if ("class", imported["name"]) not in existing and (
            "function",
            imported["name"],
        ) not in existing:
            records.append(imported)
    return sorted(records, key=lambda item: (item["lineno"], item["kind"], item["qualname"]))


def inventory_modules(checkout: SourceCheckout) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Inventory importable Python modules and their public API."""

    modules: list[dict[str, Any]] = []
    api_records: list[dict[str, Any]] = []
    for relative_root in checkout.spec["source_roots"]:
        source_root = checkout.root / relative_root
        for path in sorted(source_root.rglob("*.py")):
            relative_path = path.relative_to(checkout.root).as_posix()
            module = module_name(source_root, path)
            raw = path.read_text(encoding="utf-8")
            try:
                tree = ast.parse(raw, filename=relative_path, type_comments=True)
                parse_status = "ok"
                module_records = module_api(tree, is_package=path.name == "__init__.py")
                parse_error = ""
            except (SyntaxError, UnicodeError) as exc:
                parse_status = "error"
                module_records = []
                parse_error = f"{type(exc).__name__}: {exc}"
            counts = {
                kind: sum(record["kind"] == kind for record in module_records)
                for kind in (
                    "class",
                    "function",
                    "async_function",
                    "method",
                    "property",
                    "import",
                )
            }
            modules.append(
                {
                    "source": checkout.source_id,
                    "module": module,
                    "path": relative_path,
                    "sha256": sha256_file(path),
                    "parse_status": parse_status,
                    "parse_error": parse_error,
                    "public_counts": counts,
                }
            )
            for record in module_records:
                record.update(
                    {
                        "source": checkout.source_id,
                        "module": module,
                        "path": relative_path,
                    }
                )
                api_records.append(record)
    return modules, api_records


def test_symbols(path: Path) -> dict[str, int]:
    """Count pytest/unittest test functions, classes, and methods."""

    raw = path.read_text(encoding="utf-8")
    try:
        tree = ast.parse(raw, filename=path.name, type_comments=True)
    except (SyntaxError, UnicodeError):
        return {"test_functions": 0, "test_classes": 0, "test_methods": 0}
    functions = 0
    classes = 0
    methods = 0
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith(
            "test"
        ):
            functions += 1
        elif isinstance(node, ast.ClassDef) and node.name.startswith("Test"):
            classes += 1
            methods += sum(
                isinstance(member, (ast.FunctionDef, ast.AsyncFunctionDef))
                and member.name.startswith("test")
                for member in node.body
            )
    return {
        "test_functions": functions,
        "test_classes": classes,
        "test_methods": methods,
    }


def inventory_tests(checkout: SourceCheckout) -> list[dict[str, Any]]:
    """Inventory all Python test modules declared by the baseline."""

    records: list[dict[str, Any]] = []
    for relative_root in checkout.spec["test_roots"]:
        root = checkout.root / relative_root
        paths = {
            *root.rglob("test_*.py"),
            *root.rglob("*_test.py"),
        }
        for path in sorted(paths):
            record: dict[str, Any] = {
                "source": checkout.source_id,
                "path": path.relative_to(checkout.root).as_posix(),
                "size": path.stat().st_size,
                "sha256": sha256_file(path),
            }
            record.update(test_symbols(path))
            records.append(record)
    return records


def inventory_fixtures(checkout: SourceCheckout) -> list[dict[str, Any]]:
    """Inventory every regular fixture file with size and content hash."""

    records: list[dict[str, Any]] = []
    for relative_root in checkout.spec["fixture_roots"]:
        root = checkout.root / relative_root
        for path in sorted(item for item in root.rglob("*") if item.is_file()):
            records.append(
                {
                    "source": checkout.source_id,
                    "path": path.relative_to(checkout.root).as_posix(),
                    "size": path.stat().st_size,
                    "sha256": sha256_file(path),
                }
            )
    return records


def source_records(checkouts: Sequence[SourceCheckout]) -> list[dict[str, Any]]:
    """Flatten immutable baseline provenance for CSV/JSON outputs."""

    return [
        {
            "id": checkout.source_id,
            "repository": checkout.spec["repository"],
            "tag": checkout.spec["tag"],
            "commit": checkout.spec["commit"],
            "commit_date": checkout.spec["commit_date"],
            "license": checkout.spec["license"],
        }
        for checkout in checkouts
    ]


def build_inventory(
    baseline: dict[str, Any], checkouts: Sequence[SourceCheckout]
) -> dict[str, Any]:
    """Build the complete deterministic inventory document."""

    modules: list[dict[str, Any]] = []
    api_records: list[dict[str, Any]] = []
    tests: list[dict[str, Any]] = []
    fixtures: list[dict[str, Any]] = []
    for checkout in checkouts:
        source_modules, source_api = inventory_modules(checkout)
        modules.extend(source_modules)
        api_records.extend(source_api)
        tests.extend(inventory_tests(checkout))
        fixtures.extend(inventory_fixtures(checkout))

    modules.sort(key=lambda item: (item["source"], item["module"], item["path"]))
    api_records.sort(
        key=lambda item: (
            item["source"],
            item["module"],
            item["lineno"],
            item["kind"],
            item["qualname"],
        )
    )
    tests.sort(key=lambda item: (item["source"], item["path"]))
    fixtures.sort(key=lambda item: (item["source"], item["path"]))
    sources = source_records(checkouts)
    summary = {
        "source_count": len(sources),
        "module_count": len(modules),
        "module_parse_errors": sum(module["parse_status"] != "ok" for module in modules),
        "public_class_count": sum(item["kind"] == "class" for item in api_records),
        "public_function_count": sum(
            item["kind"] in {"function", "async_function"} for item in api_records
        ),
        "public_method_count": sum(item["kind"] == "method" for item in api_records),
        "public_property_count": sum(item["kind"] == "property" for item in api_records),
        "public_import_count": sum(item["kind"] == "import" for item in api_records),
        "test_file_count": len(tests),
        "test_case_count": sum(
            item["test_functions"] + item["test_methods"] for item in tests
        ),
        "fixture_file_count": len(fixtures),
        "fixture_total_bytes": sum(item["size"] for item in fixtures),
    }
    return {
        "schema_version": 1,
        "generator": "dev/matgenlab/generate_upstream_inventory.py",
        "baseline_schema_version": baseline["schema_version"],
        "sources": sources,
        "summary": summary,
        "modules": modules,
        "api": api_records,
        "tests": tests,
        "fixtures": fixtures,
    }


def write_csv(path: Path, fieldnames: Sequence[str], rows: Iterable[dict[str, Any]]) -> None:
    """Write stable RFC-4180-compatible UTF-8 CSV."""

    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for raw in rows:
            row = {
                key: json.dumps(value, ensure_ascii=False, separators=(",", ":"))
                if isinstance(value, (list, dict))
                else value
                for key, value in raw.items()
            }
            writer.writerow(row)


def write_inventory(output: Path, inventory: dict[str, Any]) -> None:
    """Write canonical JSON and normalized CSV views."""

    output.mkdir(parents=True, exist_ok=True)
    json_path = output / "upstream_inventory.json"
    with json_path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(inventory, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    write_csv(
        output / "sources.csv",
        ("id", "repository", "tag", "commit", "commit_date", "license"),
        inventory["sources"],
    )
    write_csv(
        output / "modules.csv",
        (
            "source",
            "module",
            "path",
            "sha256",
            "parse_status",
            "parse_error",
            "public_counts",
        ),
        inventory["modules"],
    )
    write_csv(
        output / "api.csv",
        (
            "source",
            "module",
            "path",
            "kind",
            "name",
            "qualname",
            "signature",
            "lineno",
            "doc_summary",
            "decorators",
            "bases",
            "import_target",
        ),
        inventory["api"],
    )
    write_csv(
        output / "tests.csv",
        (
            "source",
            "path",
            "size",
            "sha256",
            "test_functions",
            "test_classes",
            "test_methods",
        ),
        inventory["tests"],
    )
    write_csv(
        output / "fixtures.csv",
        ("source", "path", "size", "sha256"),
        inventory["fixtures"],
    )


def compare_outputs(expected: Path, actual: Path) -> list[str]:
    """Return output names that are missing or differ byte-for-byte."""

    names = ("upstream_inventory.json", *CSV_FILES)
    differences: list[str] = []
    for name in names:
        expected_path = expected / name
        actual_path = actual / name
        if not expected_path.is_file() or not actual_path.is_file():
            differences.append(name)
        elif expected_path.read_bytes() != actual_path.read_bytes():
            differences.append(name)
    return differences


def build_parser() -> argparse.ArgumentParser:
    """Create the command-line interface."""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--baseline",
        type=Path,
        default=DEFAULT_BASELINE,
        help="frozen source declaration (default: %(default)s)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="inventory output directory (default: %(default)s)",
    )
    parser.add_argument(
        "--source",
        action="append",
        default=[],
        metavar="ID=PATH",
        help="use a local checkout; repeat for multiple sources",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="compare generated bytes with --output without modifying it",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entry point."""

    arguments = build_parser().parse_args(argv)
    try:
        baseline_path = arguments.baseline.expanduser().resolve()
        output = arguments.output.expanduser().resolve()
        baseline = load_baseline(baseline_path)
        overrides = parse_source_overrides(arguments.source)
        with tempfile.TemporaryDirectory(prefix="matgenlab-inventory-") as raw_temp:
            temporary_root = Path(raw_temp)
            checkouts = acquire_sources(baseline, overrides, temporary_root / "sources")
            inventory = build_inventory(baseline, checkouts)
            if arguments.check:
                generated = temporary_root / "generated"
                write_inventory(generated, inventory)
                differences = compare_outputs(output, generated)
                if differences:
                    raise InventoryError(
                        "inventory is stale or missing: " + ", ".join(differences)
                    )
                print(f"Inventory is current: {output}")
            else:
                staging = temporary_root / "staging"
                write_inventory(staging, inventory)
                output.mkdir(parents=True, exist_ok=True)
                for path in staging.iterdir():
                    shutil.copyfile(path, output / path.name)
                print(f"Wrote inventory: {output}")
            print(json.dumps(inventory["summary"], sort_keys=True))
    except InventoryError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
