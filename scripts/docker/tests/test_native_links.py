"""Validate relocation of the existing Linux MEX without compiling native code."""

import _docker_paths
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from build_application import ROOT, normalize_native_links

TOOL = os.environ.get('KSSOLV_PATCHELF', 'patchelf')
SOURCE = ROOT / '+kssolv/+analysis/+spglib/symspg.mexa64'


@unittest.skipUnless(shutil.which(TOOL), 'A Linux patchelf executable is required')
class NativeLinkTests(unittest.TestCase):
    def fixture(self, root):
        binary = root / 'symspg.mexa64'
        shutil.copy2(SOURCE, binary)
        return binary

    def test_relocation_is_portable_idempotent_and_preserves_source(self):
        source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary = self.fixture(root)
            before = subprocess.check_output([TOOL, '--print-needed', str(binary)], text=True).splitlines()
            manifest = normalize_native_links(root, TOOL)
            self.assertEqual(set(manifest[0]['Dependencies']), {Path(item).name for item in before})
            self.assertIn('libmex.so', manifest[0]['Dependencies'])
            self.assertIn('libmx.so', manifest[0]['Dependencies'])
            self.assertFalse(any('/' in item for item in manifest[0]['Dependencies']))
            self.assertEqual(normalize_native_links(root, TOOL), manifest)
        self.assertEqual(hashlib.sha256(SOURCE.read_bytes()).hexdigest(), source_hash)

    def test_unknown_absolute_dependency_fails_before_modification(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary = self.fixture(root)
            subprocess.run([TOOL, '--add-needed', '/qa/unavailable/libunknown.so', str(binary)], check=True)
            before = binary.read_bytes()
            with self.assertRaisesRegex(RuntimeError, 'Unresolved native dependency'):
                normalize_native_links(root, TOOL)
            self.assertEqual(binary.read_bytes(), before)

    def test_java_library_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary = self.fixture(root)
            subprocess.run([TOOL, '--add-needed', 'libjvm.so', str(binary)], check=True)
            with self.assertRaisesRegex(RuntimeError, 'JVM dependency is forbidden'):
                normalize_native_links(root, TOOL)


if __name__ == '__main__':
    unittest.main()
