"""Unit tests for the deterministic upstream inventory generator."""

from __future__ import annotations

import ast
import json
import tempfile
import unittest
from pathlib import Path

import generate_upstream_inventory as inventory


class InventoryGeneratorTest(unittest.TestCase):
    def test_module_api_extracts_signatures_and_package_reexports(self) -> None:
        tree = ast.parse(
            '''
from .other import ReExport
import numpy as np

class Public:
    """A public class."""

    def __init__(self, value: int = 3) -> None:
        self.value = value

    @property
    def doubled(self) -> int:
        return 2 * self.value

    def calculate(self, factor: float = 1.0) -> float:
        return self.value * factor

def helper(name: str, /, *, count: int = 1) -> str:
    return name * count
'''
        )
        records = inventory.module_api(tree, is_package=True)
        by_key = {(record["kind"], record["qualname"]): record for record in records}

        self.assertEqual(
            by_key[("class", "Public")]["signature"],
            "(self, value: int=3) -> None",
        )
        self.assertEqual(
            by_key[("function", "helper")]["signature"],
            "(name: str, /, *, count: int=1) -> str",
        )
        self.assertIn(("property", "Public.doubled"), by_key)
        self.assertIn(("method", "Public.calculate"), by_key)
        self.assertEqual(
            by_key[("import", "ReExport")]["import_target"], ".other.ReExport"
        )
        self.assertEqual(by_key[("import", "np")]["import_target"], "numpy")

    def test_ordinary_module_does_not_publish_dependency_imports(self) -> None:
        tree = ast.parse("import numpy as np\nfrom pathlib import Path\n")
        self.assertEqual(inventory.module_api(tree, is_package=False), [])

    def test_literal_all_controls_public_surface(self) -> None:
        tree = ast.parse(
            '''
from .other import Exported, Hidden
__all__ = ["Exported", "_named_but_exported"]

def visible_by_convention():
    pass

def _named_but_exported(value=1):
    return value
'''
        )
        records = inventory.module_api(tree, is_package=False)
        by_key = {(record["kind"], record["name"]) for record in records}
        self.assertEqual(
            by_key,
            {("import", "Exported"), ("function", "_named_but_exported")},
        )

    def test_committed_baseline_uses_full_unique_commits(self) -> None:
        baseline = inventory.load_baseline(inventory.DEFAULT_BASELINE)
        commits = [source["commit"] for source in baseline["sources"]]
        self.assertEqual(len(commits), len(set(commits)))
        self.assertTrue(all(len(commit) == 40 for commit in commits))

    def test_write_inventory_is_byte_reproducible(self) -> None:
        minimal = {
            "schema_version": 1,
            "generator": "generator",
            "baseline_schema_version": 1,
            "sources": [],
            "summary": {},
            "modules": [],
            "api": [],
            "tests": [],
            "fixtures": [],
        }
        with tempfile.TemporaryDirectory() as raw_temp:
            root = Path(raw_temp)
            first = root / "first"
            second = root / "second"
            inventory.write_inventory(first, minimal)
            inventory.write_inventory(second, json.loads(json.dumps(minimal)))
            self.assertEqual(inventory.compare_outputs(first, second), [])


if __name__ == "__main__":
    unittest.main()
