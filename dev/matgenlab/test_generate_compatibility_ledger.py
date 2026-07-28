from __future__ import annotations

import csv
import importlib.util
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("generate_compatibility_ledger.py")
SPEC = importlib.util.spec_from_file_location("compatibility_ledger", MODULE_PATH)
assert SPEC and SPEC.loader
LEDGER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(LEDGER)


class CompatibilityLedgerTest(unittest.TestCase):
    def test_inventory_is_the_denominator(self) -> None:
        summary = LEDGER.generate()
        with LEDGER.INVENTORY.open(newline="", encoding="utf-8") as handle:
            inventory_count = sum(1 for _ in csv.DictReader(handle))
        self.assertEqual(summary["total"], inventory_count)

    def test_static_discovery_never_claims_implemented(self) -> None:
        LEDGER.generate()
        with LEDGER.OUTPUT_CSV.open(newline="", encoding="utf-8") as handle:
            statuses = {row["status"] for row in csv.DictReader(handle)}
        self.assertNotIn("implemented-unverified", statuses)
        self.assertTrue(statuses <= LEDGER.RELEASE_STATES | {"candidate", "missing"})

    def test_generated_files_are_current(self) -> None:
        LEDGER.generate()
        LEDGER.generate(check=True)

    def test_flattened_functions_and_inherited_members_are_discovered(self) -> None:
        function_row = {
            "kind": "function",
            "name": "get_bond_length",
            "qualname": "get_bond_length",
            "module": "pymatgen.core.bonds",
        }
        status, path = LEDGER.static_candidate(function_row)
        self.assertEqual(status, "candidate")
        self.assertTrue(path.endswith("/get_bond_length.m"))

        inherited_row = {
            "kind": "property",
            "name": "x",
            "qualname": "PeriodicSite.x",
            "module": "pymatgen.core.sites",
        }
        status, path = LEDGER.static_candidate(inherited_row)
        self.assertEqual(status, "candidate")
        self.assertTrue(path.endswith("/Site.m"))

    def test_core_python_support_imports_are_explicitly_unsupported(self) -> None:
        """Do not mistake Python implementation dependencies for domain API."""

        expected_targets = {
            "os": "os",
            "warnings": "warnings",
            "PackageNotFoundError": "importlib.metadata.PackageNotFoundError",
            "version": "importlib.metadata.version",
            "TYPE_CHECKING": "typing.TYPE_CHECKING",
        }
        with LEDGER.INVENTORY.open(newline="", encoding="utf-8") as handle:
            core_imports = {
                row["qualname"]: row["import_target"]
                for row in csv.DictReader(handle)
                if row["source"] == "pymatgen-core"
                and row["module"] == "pymatgen.core"
                and row["kind"] == "import"
                and row["qualname"] in expected_targets
            }
        self.assertEqual(core_imports, expected_targets)

        overrides = LEDGER.load_overrides()
        for name in expected_targets:
            identifier = f"pymatgen-core::pymatgen.core::import::{name}"
            self.assertEqual(overrides[identifier]["status"], "unsupported-upstream")
            self.assertTrue(overrides[identifier]["evidence"].strip())

    def test_future_annotations_import_is_not_a_matgenlab_api(self) -> None:
        """The inventory records Python's future directive, not a domain symbol."""

        identifiers = {
            "pymatgen::pymatgen.analysis.elasticity::import::annotations",
            "pymatgen::pymatgen.analysis.interfaces::import::annotations",
            "pymatgen::pymatgen.analysis.structure_prediction::import::annotations",
            "pymatgen-core::pymatgen.core::import::annotations",
            "pymatgen-core::pymatgen.core.elasticity::import::annotations",
            "pymatgen-core::pymatgen.io.pwmat::import::annotations",
            "pymatgen-core::pymatgen.io.vasp::import::annotations",
            "pymatgen-core::pymatgen.util::import::annotations",
        }
        with LEDGER.INVENTORY.open(newline="", encoding="utf-8") as handle:
            rows = {
                LEDGER.api_id(row): row
                for row in csv.DictReader(handle)
                if LEDGER.api_id(row) in identifiers
            }
        self.assertEqual(set(rows), identifiers)
        for identifier in identifiers:
            self.assertEqual(
                rows[identifier]["import_target"], "__future__.annotations"
            )

        overrides = LEDGER.load_overrides()
        for identifier in identifiers:
            self.assertEqual(overrides[identifier]["status"], "unsupported-upstream")
            self.assertTrue(overrides[identifier]["evidence"].strip())


if __name__ == "__main__":
    unittest.main()
