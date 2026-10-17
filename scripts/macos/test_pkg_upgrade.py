"""Run the actual preinstall against isolated install trees, never /Applications."""
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest


class UpgradeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="kssolv-upgrade-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.apps = self.root / "Applications"
        self.users = self.root / "Users"
        self.library = self.root / "Library"
        self.receipts = self.root / "receipts"
        self.events = self.root / "events"
        for directory in (self.apps, self.users, self.receipts, self.library / "LaunchAgents", self.library / "Application Support"):
            directory.mkdir(parents=True, exist_ok=True)
        self.processes = self.root / "processes"
        self.processes.write_text("501\n")
        pkgutil = self.shim("pkgutil", f'''
case "$1" in
 --pkg-info) [[ -f "{self.receipts}/$2" ]] ;;
 --forget) echo "forget $2" >> "{self.events}"; /bin/rm "{self.receipts}/$2" ;;
 *) exit 99 ;;
esac
''')
        ps = self.shim("ps", f'if [[ "$*" == *uid=* ]]; then echo 501; else /bin/cat "{self.processes}"; fi\n')
        launchctl = self.shim("launchctl", f'echo "$*" >> "{self.events}"\n')
        source = (Path(__file__).parent / "pkg/preinstall").read_text()
        replacements = {"scan /Applications": "scan " + str(self.apps), "/Users": self.users, "/Library": self.library,
                        "/usr/sbin/pkgutil": pkgutil, "/bin/ps": ps, "/bin/launchctl": launchctl}
        for old, new in replacements.items():
            source = source.replace(old, str(new))
        self.script = self.shim("preinstall", source.removeprefix("#!/bin/bash\n"))
        self.shim("runtime-common.sh", f'''kssolv_find_runtime() {{ echo "{self.root}/validated-runtime"; }}
kssolv_plist() {{ /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null; }}
''')

    def shim(self, name, body):
        path = self.root / name
        path.write_text("#!/bin/bash\n" + body)
        path.chmod(0o755)
        return path

    def app(self, relative, identifier="com.pwdft.kssolv", executable="KSSOLV_Toolbox"):
        app = self.root / relative
        (app / "Contents/MacOS").mkdir(parents=True)
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": identifier, "CFBundleExecutable": executable}))
        (app / "Contents/MacOS" / executable).touch()
        return app

    def run_installer(self, volume="/"):
        return subprocess.run(["/bin/bash", str(self.script), "package.pkg", str(self.apps), volume], capture_output=True, text=True, timeout=8)

    def test_clean_install_is_noop(self):
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no previous installation", result.stdout)
        self.assertFalse(self.events.exists())

    def test_removes_all_known_versions_and_receipts_preserving_user_files(self):
        paths = [self.app("Applications/KSSOLV_Toolbox/application/KSSOLV_Toolbox.app", "com.hanhai.kssolv-toolbox"),
                 self.app("Applications/KSSOLV Toolbox.app"),
                 self.app("Users/example/Applications/Old KSSOLV.app", "KSSOLV_Toolbox")]
        folder = paths[0].parent
        (folder / "run_KSSOLV_Toolbox.sh").touch()
        user_file = folder / "calculation.ks"
        user_file.write_text("keep")
        for identifier in ("com.pwdft.kssolv", "com.hanhai.kssolv-toolbox"):
            (self.receipts / identifier).touch()
        support = self.library / "Application Support/KSSOLV Toolbox"
        support.mkdir()
        (support / "prewarm.sh").touch()
        (support / "user-document").touch()
        plist = self.library / "LaunchAgents/com.gleamoe.kssolv.prewarm.plist"
        plist.touch()
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(all(not path.exists() for path in paths))
        self.assertEqual(user_file.read_text(), "keep")
        self.assertFalse((folder / "run_KSSOLV_Toolbox.sh").exists())
        self.assertTrue((support / "prewarm.sh").exists())
        self.assertTrue((support / "user-document").exists())
        self.assertTrue(plist.exists())
        self.assertEqual(list(self.receipts.iterdir()), [])
        events = self.events.read_text()
        self.assertLess(events.index("bootout"), events.index("forget"))
        self.assertEqual(self.run_installer().returncode, 0)

    def test_unrelated_app_and_runtime_are_preserved(self):
        unrelated = self.app("Applications/KSSOLV Toolbox.app", "com.example.unrelated")
        runtime = self.app("Applications/MATLAB/MATLAB_Runtime.app", "com.mathworks.runtime", "MATLAB")
        nested = self.app(str(runtime.relative_to(self.root) / "Contents/KSSOLV_Toolbox.app"))
        wrong_executable = self.app("Applications/Unrelated.app", executable="other")
        self.assertEqual(self.run_installer().returncode, 0)
        for path in (unrelated, runtime, nested, wrong_executable):
            self.assertTrue(path.exists())

    def test_saved_application_with_duplicate_slashes_is_removed_once(self):
        app = self.app('Applications/KSSOLV Toolbox.app')
        support = self.library / 'Application Support/KSSOLV Toolbox'
        support.mkdir()
        (support / 'application.plist').write_bytes(plistlib.dumps({'ApplicationPath': str(app).replace('/Applications/', '//Applications/')}))
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(app.exists())

    def test_saved_application_in_custom_folder_is_identified(self):
        app = self.app('Custom Application Folder/KSSOLV Toolbox.app')
        support = self.library / 'Application Support/KSSOLV Toolbox'
        support.mkdir()
        (support / 'application.plist').write_bytes(plistlib.dumps({'ApplicationPath': str(app)}))
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(app.exists())

    def test_running_version_blocks_all_removal(self):
        first = self.app("Applications/Old KSSOLV.app")
        second = self.app("Applications/KSSOLV Toolbox.app")
        self.processes.write_text(f"123 {second}/Contents/MacOS/KSSOLV_Toolbox\n")
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Close KSSOLV Toolbox", result.stderr)
        self.assertTrue(first.exists() and second.exists())
        self.assertFalse(self.events.exists())

    def test_similar_process_outside_bundle_does_not_block_removal(self):
        app = self.app("Applications/Long KSSOLV Application With Spaces.app")
        self.processes.write_text(f"123 {app}-backup/Contents/MacOS/KSSOLV_Toolbox\n")
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(app.exists())

    def test_symlink_app_and_application_directory_are_not_followed(self):
        outside = self.app("outside/Real.app")
        (self.apps / "Linked.app").symlink_to(outside, target_is_directory=True)
        (self.users / "example").mkdir()
        (self.users / "example/Applications").symlink_to(outside.parent, target_is_directory=True)
        self.assertEqual(self.run_installer().returncode, 0)
        self.assertTrue(outside.exists())

    def test_support_symlink_fails_before_app_removal(self):
        app = self.app("Applications/KSSOLV Toolbox.app")
        (self.receipts / "com.pwdft.kssolv").touch()
        outside = self.root / "outside"
        outside.mkdir()
        (outside / "prewarm.sh").touch()
        (self.library / "Application Support/KSSOLV Toolbox").symlink_to(outside, target_is_directory=True)
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertTrue(app.exists())
        self.assertTrue((outside / "prewarm.sh").exists())

    def test_other_volume_fails_without_removal(self):
        app = self.app("Applications/KSSOLV Toolbox.app")
        self.assertNotEqual(self.run_installer("/Volumes/Other").returncode, 0)
        self.assertTrue(app.exists())

    def test_removal_failure_retains_receipt_and_stops(self):
        app = self.app("Applications/KSSOLV Toolbox.app")
        receipt = self.receipts / "com.pwdft.kssolv"
        receipt.touch()
        rm = self.shim("failing-rm", "exit 7\n")
        self.script.write_text(self.script.read_text().replace("/bin/rm", str(rm)))
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertTrue(app.exists())
        self.assertTrue(receipt.exists())
        self.assertNotIn("forget", self.events.read_text())

    def test_receipt_only_install_preserves_prepared_system_support(self):
        (self.receipts / "com.hanhai.kssolv-toolbox").touch()
        support = self.library / "Application Support/KSSOLV Toolbox"
        support.mkdir()
        (support / "prewarm.sh").touch()
        self.assertEqual(self.run_installer().returncode, 0)
        self.assertTrue(support.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
