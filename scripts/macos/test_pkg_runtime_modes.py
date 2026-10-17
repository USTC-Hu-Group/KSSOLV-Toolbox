"""Exercise actual installer scripts using inert files and shell-only fixtures."""
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock
import xml.etree.ElementTree as ET
import zipfile


ASSETS = Path(__file__).parent / 'pkg'
spec = importlib.util.spec_from_file_location('stage_runtime_payload', ASSETS.parent / 'stage_runtime_payload.py')
stager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stager)
spec = importlib.util.spec_from_file_location('write_pkg_distribution', ASSETS.parent / 'write_pkg_distribution.py')
distribution = importlib.util.module_from_spec(spec)
spec.loader.exec_module(distribution)


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='kssolv-runtime-package-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.build = self.root / 'build'; self.build.mkdir()
        self.base = self.root / 'base'
        self.out = self.root / 'output'
        self.metadata = dict(RuntimeRelease='R2026b', RuntimeVersion='26.2', RuntimeBuildVersion='26.2.0.100',
                             Architecture='maca64', JVMEnabled=False, RuntimeDelivery='web')
        (self.build / 'buildresult.json').write_text(json.dumps({'RuntimeDependencies': [{'DisplayName': 'Base', 'ID': 1}]}))
        self.save_metadata()
        self.manifest(self.base)

    def save_metadata(self):
        (self.build / 'runtime-metadata.json').write_text(json.dumps(self.metadata))

    def manifest(self, app, extra='', product='1'):
        resources = app / 'Contents/Resources'; resources.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(resources / 'bundle.zip', 'w') as archive:
            archive.writestr('ApplicationInstallerManifest.xml', '<Manifest><MCRProducts><MCRProduct>'
                             f'<ExternalProductIdentifier>{product}</ExternalProductIdentifier>'
                             f'</MCRProduct></MCRProducts>{extra}</Manifest>')

    def installer(self, mode):
        directory = self.build / 'runtime-installers' / mode; directory.mkdir(parents=True)
        app = directory / 'Runtime.app'; self.manifest(app)
        (app / 'Contents/MacOS').mkdir()
        (app / 'Contents/MacOS/setup').write_text('inert fixture; never executed')
        (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable': 'setup'}))
        if mode == 'web':
            (app / 'Contents/Resources/installAgentURL.txt').touch()
        else:
            with zipfile.ZipFile(app / 'Contents/Resources/InstallAgent.zip', 'w') as archive:
                archive.writestr('fixture.txt', 'inert offline payload')
        info = {key: self.metadata[key] for key in ('RuntimeRelease', 'RuntimeVersion', 'RuntimeBuildVersion', 'Architecture')}
        info.update(RuntimeDelivery=mode, Installer='Runtime.app', BuildResultSHA256=hashlib.sha256((self.build / 'buildresult.json').read_bytes()).hexdigest())
        (directory / 'runtime-installer.json').write_text(json.dumps(info))
        return app

    def test_none_omits_runtime_installer(self):
        value = stager.stage(self.build, self.base, 'none', self.out)
        self.assertEqual(value['RuntimeDelivery'], 'none')
        self.assertFalse((self.out / 'RuntimeSetup.app').exists())
        self.assertEqual(len(value['RequiredProductFiles']), 2)

    def test_native_runtime_choice_precedes_support_and_application_only_in_none(self):
        license_file = self.root / 'LICENSE'; license_file.write_text('application license fixture')
        for mode in ('none', 'web', 'installer'):
            resources = self.root / mode; resources.mkdir()
            output = resources / 'Distribution'
            requirements = dict(self.metadata, RuntimeDelivery=mode)
            with mock.patch.object(distribution, 'runtime_license'):
                distribution.write(resources, output, requirements, '0.4.1', license_file)
            root = ET.parse(output).getroot()
            choices = root.findall('choices-outline/line')
            self.assertEqual([x.get('choice') for x in choices],
                             (['runtime-existing'] if mode == 'none' else []) + ['runtime-support', 'application'])
            selected = root.find("choice[@id='runtime-existing']")
            if mode == 'none':
                self.assertEqual(selected.get('customLocation'), '/')
                self.assertEqual(selected.get('selected'), 'true')
                self.assertEqual(selected.get('customLocationAllowAlternateVolumes'), 'true')
                self.assertEqual(selected.find('pkg-ref').get('id'), 'com.pwdft.kssolv.runtime-selection')
                for language in ('en', 'zh_CN', 'zh-Hans'):
                    self.assertIn('EXISTING_RUNTIME_DESCRIPTION', (resources / (language + '.lproj') / 'Localizable.strings').read_text())
            else:
                self.assertIsNone(selected)
            self.assertIsNone(root.find("choice[@id='runtime-support']").get('customLocation'))
            self.assertEqual(root.find("choice[@id='application']").get('customLocation'), '/Applications')

    def test_web_and_installer_stage_exact_matching_payload(self):
        for mode in ('web', 'installer'):
            self.installer(mode)
            value = stager.stage(self.build, self.base, mode, self.root / mode)
            self.assertEqual(value['RuntimeDelivery'], mode)
            self.assertTrue((self.root / mode / 'RuntimeSetup.app/Contents/MacOS/setup').is_file())

    def test_stale_dependency_hash_is_rejected(self):
        self.installer('web')
        with (self.build / 'buildresult.json').open('a') as file: file.write(' ')
        with self.assertRaisesRegex(ValueError, 'stale'):
            stager.stage(self.build, self.base, 'web', self.out)

    def test_application_in_runtime_payload_is_rejected(self):
        app = self.installer('web'); self.manifest(app, extra='<Application/>')
        with self.assertRaisesRegex(ValueError, 'no application payload'):
            stager.stage(self.build, self.base, 'web', self.out)

    def test_missing_required_runtime_product_is_rejected(self):
        app = self.installer('web'); self.manifest(app, product='2')
        with self.assertRaisesRegex(ValueError, 'exactly'):
            stager.stage(self.build, self.base, 'web', self.out)

    def test_incomplete_offline_payload_is_rejected(self):
        app = self.installer('installer'); (app / 'Contents/Resources/InstallAgent.zip').unlink()
        with self.assertRaisesRegex(ValueError, 'Offline Runtime payload'):
            stager.stage(self.build, self.base, 'installer', self.out)

    def test_official_installer_for_mac_archive_is_supported(self):
        app = self.installer('installer')
        (app / 'Contents/Resources/InstallAgent.zip').rename(app / 'Contents/Resources/InstallerForMac')
        value = stager.stage(self.build, self.base, 'installer', self.out)
        self.assertEqual(value['RuntimeDelivery'], 'installer')

    def test_jvm_build_is_rejected(self):
        self.metadata['JVMEnabled'] = True; self.save_metadata()
        with self.assertRaisesRegex(ValueError, 'no-JVM'):
            stager.stage(self.build, self.base, 'none', self.out)


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='kssolv-runtime-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.apps = self.root / 'Applications'
        self.support = self.root / 'Library/Application Support/KSSOLV Toolbox'
        self.support.mkdir(parents=True)
        (self.root / 'logs').mkdir()
        self.apps.mkdir()
        self.events = self.root / 'events'
        self.runtime = self.apps / 'MATLAB/MATLAB_Runtime/R2026b'
        self.requirements = dict(RuntimeRelease='R2026b', RuntimeVersion='26.2', RuntimeBuildVersion='26.2.0.100',
                                 RuntimeDelivery='none', InstallerExecutable='setup', RequiredProductFiles=['MATLAB Base Runtime 26.2 maca64.xml'])
        self.write_requirements()
        self.shim('stat', 'echo loginwindow\n')
        self.shim('lipo', 'exit 0\n')
        self.script('runtime-common.sh')
        self.prepare = self.script('prepare-runtime')
        # No native executable or fake .app is launched in these tests. Only a
        # plain shell fixture implements the documented installer arguments.
        self.prepare.write_text(self.prepare.read_text().replace('$SCRIPT_DIR/RuntimeSetup.app/Contents/MacOS/$EXECUTABLE', '$SCRIPT_DIR/inert-installer.sh'))
        self.shim('inert-installer.sh', f'''
[[ "$1" == -agreeToLicense && "$2" == yes && "$3" == -runtimeFolder ]] || exit 88
echo prepare >> "{self.events}"
root="$4/R2026b"
/bin/mkdir -p "$root/runtime/maca64" "$root/bin/maca64/MATLABWindow.app/Contents/MacOS" "$root/appdata/products"
/bin/echo '<MathWorks_version_info><release>R2026b</release><version>26.2.0.100</version></MathWorks_version_info>' > "$root/VersionInfo.xml"
/usr/bin/touch "$root/runtime/maca64/libmwmclmcrrt.26.2.dylib" "$root/appdata/products/MATLAB Base Runtime 26.2 maca64.xml"
/usr/bin/touch "$root/bin/maca64/MATLABWindow.app/Contents/MacOS/MATLABWindow"
/bin/chmod 0755 "$root/bin/maca64/MATLABWindow.app/Contents/MacOS/MATLABWindow"
''')

    def shim(self, name, body):
        path = self.root / name
        path.write_text('#!/bin/bash\n' + body)
        path.chmod(0o755)
        return path

    def script(self, name):
        text = (ASSETS / name).read_text()
        text = text.replace('"/Applications', '"' + str(self.apps)).replace("'/Applications", "'" + str(self.apps))
        text = text.replace('! -L /Applications', '! -L ' + str(self.apps))
        text = text.replace('/Library/Application Support/KSSOLV Toolbox', str(self.support))
        text = text.replace("! -L /Library", '! -L ' + str(self.root / 'Library'))
        text = text.replace("'/Library/Application Support'", "'" + str(self.support.parent) + "'")
        text = text.replace('/var/tmp/kssolv-runtime-install.', str(self.root / 'logs/runtime.'))
        for tool in ('stat', 'lipo'):
            text = text.replace('/usr/bin/' + tool, str(self.root / tool))
        text = text.replace('scan /Applications', 'scan ' + str(self.apps))
        text = text.replace('/Users/*', str(self.root / 'Users/*'))
        return self.shim(name, text.removeprefix('#!/bin/bash\n'))

    def write_requirements(self):
        (self.root / 'runtime-requirements.plist').write_bytes(plistlib.dumps(self.requirements))

    def make_runtime(self, path=None, release='R2026b', version='26.2.0.100'):
        path = path or self.runtime
        for directory in ('runtime/maca64', 'bin/maca64/MATLABWindow.app/Contents/MacOS', 'appdata/products'):
            (path / directory).mkdir(parents=True, exist_ok=True)
        (path / 'VersionInfo.xml').write_text(f'<MathWorks_version_info><release>{release}</release><version>{version}</version></MathWorks_version_info>')
        (path / 'runtime/maca64/libmwmclmcrrt.26.2.dylib').touch()
        (path / 'appdata/products/MATLAB Base Runtime 26.2 maca64.xml').touch()
        window = path / 'bin/maca64/MATLABWindow.app/Contents/MacOS/MATLABWindow'
        window.touch(); window.chmod(0o755)
        return path

    def run_prepare(self, mode='none', volume='/', selection='/'):
        self.requirements['RuntimeDelivery'] = mode
        self.write_requirements()
        env = dict(os.environ)
        env.pop('KSSOLV_RUNTIME_ROOT', None)
        env['HOME'] = str(self.root / 'home')
        return subprocess.run(['/bin/bash', str(self.prepare), 'test.pkg', str(selection), volume], env=env, text=True, capture_output=True, timeout=8)

    def test_none_manual_runtime_without_any_detectable_installation(self):
        custom = self.make_runtime(self.root / '已有 Runtime With Spaces/R2026b')
        before = {str(p.relative_to(custom)): (p.stat().st_mtime_ns, p.stat().st_size) for p in custom.rglob('*')}
        result = self.run_prepare(selection=custom)
        self.assertEqual(result.returncode, 0, result.stderr)
        saved = plistlib.loads((self.support / 'runtime.plist').read_bytes())
        self.assertEqual(saved['RuntimeRoot'], str(custom.resolve()))
        self.assertFalse(self.runtime.exists())
        self.assertFalse(self.events.exists())
        self.assertEqual(before, {str(p.relative_to(custom)): (p.stat().st_mtime_ns, p.stat().st_size) for p in custom.rglob('*')})
        # Downstream application preflight and launcher discovery reuse the selection.
        result = subprocess.run(['/bin/bash', '-c', 'source "$1"; kssolv_find_runtime "$2"', 'test',
                                 str(self.root / 'runtime-common.sh'), str(self.root / 'runtime-requirements.plist')],
                                env=dict(os.environ, HOME=str(self.root / 'home'), KSSOLV_RUNTIME_ROOT=''), text=True, capture_output=True)
        self.assertEqual(result.stdout.strip(), str(custom.resolve()))

    def test_none_explicit_selection_overrides_an_existing_compatible_runtime(self):
        self.make_runtime()
        custom = self.make_runtime(self.root / 'another/R2026b')
        self.assertEqual(self.run_prepare(selection=custom).returncode, 0)
        self.assertEqual(plistlib.loads((self.support / 'runtime.plist').read_bytes())['RuntimeRoot'], str(custom.resolve()))

    def test_none_packagekit_root_alias_still_uses_automatic_detection(self):
        self.make_runtime()
        result = self.run_prepare(selection='//')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(plistlib.loads((self.support / 'runtime.plist').read_bytes())['RuntimeRoot'], str(self.runtime))

    def test_none_can_reference_existing_runtime_on_another_volume(self):
        custom = self.make_runtime(self.root / 'Volumes/Runtime Disk/R2026b')
        result = self.run_prepare(volume=str(custom.parent), selection=custom)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(plistlib.loads((self.support / 'runtime.plist').read_bytes())['RuntimeRoot'], str(custom.resolve()))

    def test_none_incompatible_selection_preserves_old_application_and_config(self):
        self.make_runtime()  # A good automatic candidate must not mask a bad choice.
        saved = self.support / 'runtime.plist'
        saved.write_bytes(plistlib.dumps({'RuntimeRoot': str(self.runtime)}))
        before = saved.read_bytes()
        old = self.apps / 'KSSOLV Toolbox.app/Contents/MacOS/KSSOLV_Toolbox'
        old.parent.mkdir(parents=True); old.write_text('old application remains')
        bad = self.make_runtime(self.root / 'incompatible/R2026b')
        for problem in ('release', 'build', 'architecture', 'component', 'parent', 'missing', 'relative'):
            with self.subTest(problem=problem):
                self.make_runtime(bad)
                self.shim('lipo', 'exit 0\n')
                selection = bad
                if problem == 'release': self.make_runtime(bad, release='R2026a')
                elif problem == 'build': self.make_runtime(bad, version='26.2.0.99')
                elif problem == 'architecture': self.shim('lipo', 'exit 1\n')
                elif problem == 'component': (bad / 'appdata/products/MATLAB Base Runtime 26.2 maca64.xml').unlink()
                elif problem == 'parent': selection = bad.parent
                elif problem == 'missing': selection = self.root / 'missing'
                elif problem == 'relative': selection = 'relative/R2026b'
                result = self.run_prepare(selection=selection)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertEqual(saved.read_bytes(), before)
                self.assertEqual(old.read_text(), 'old application remains')
                self.assertFalse(self.events.exists())

    def test_manual_selection_does_not_affect_download_modes(self):
        self.make_runtime()
        for mode in ('web', 'installer'):
            self.assertEqual(self.run_prepare(mode, selection='/not-a-runtime').returncode, 0)

    def test_reuse_existing_runtime_in_all_modes_without_installer(self):
        self.make_runtime()
        self.shim('inert-installer.sh', 'exit 42\n')
        for mode in ('web', 'installer', 'none'):
            result = self.run_prepare(mode)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('reusing compatible Runtime', result.stdout)
        self.assertFalse(self.events.exists())

    def test_web_and_offline_install_before_publishing_configuration(self):
        for mode in ('web', 'installer'):
            with self.subTest(mode=mode):
                result = self.run_prepare(mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                saved = plistlib.loads((self.support / 'runtime.plist').read_bytes())
                self.assertEqual(saved['RuntimeRoot'], str(self.runtime))
                self.assertIn('KSSOLV_RUNTIME_PREPARED', result.stdout)
                shutil.rmtree(self.runtime)
        self.assertEqual(self.events.read_text().splitlines(), ['prepare', 'prepare'])

    def test_none_missing_runtime_leaves_old_application_and_settings(self):
        old = self.apps / 'old-installation'; old.mkdir()
        marker = old / 'project.ks'; marker.write_text('keep')
        result = self.run_prepare('none')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('has not been uninstalled', result.stderr)
        self.assertEqual(marker.read_text(), 'keep')
        self.assertFalse((self.support / 'runtime.plist').exists())

    def test_missing_product_is_not_reused(self):
        self.make_runtime()
        (self.runtime / 'appdata/products/MATLAB Base Runtime 26.2 maca64.xml').unlink()
        self.assertNotEqual(self.run_prepare('none').returncode, 0)

    def test_wrong_release_is_not_reused(self):
        self.make_runtime(release='R2026a')
        self.assertNotEqual(self.run_prepare().returncode, 0)

    def test_older_update_is_not_reused(self):
        self.make_runtime(version='26.2.0.99')
        self.assertNotEqual(self.run_prepare().returncode, 0)

    def test_wrong_architecture_is_not_reused(self):
        self.make_runtime()
        self.shim('lipo', 'exit 1\n')
        self.assertNotEqual(self.run_prepare().returncode, 0)

    def test_configured_custom_runtime_with_spaces_is_reused(self):
        custom = self.make_runtime(self.root / 'Existing Runtime With Spaces/R2026b')
        (self.support / 'runtime.plist').write_bytes(plistlib.dumps({'RuntimeRoot': str(custom)}))
        result = self.run_prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(str(custom), result.stdout)

    def test_failed_download_or_install_keeps_previous_config(self):
        saved = self.support / 'runtime.plist'
        saved.write_bytes(plistlib.dumps({'RuntimeRoot': '/missing/previous'}))
        before = saved.read_bytes()
        self.shim('inert-installer.sh', 'exit 7\n')
        for mode in ('web', 'installer'):
            self.assertNotEqual(self.run_prepare(mode).returncode, 0)
            self.assertEqual(saved.read_bytes(), before)

    def test_incomplete_install_is_rejected_even_with_zero_exit(self):
        self.shim('inert-installer.sh', 'exit 0\n')
        self.assertNotEqual(self.run_prepare('installer').returncode, 0)
        self.assertFalse((self.support / 'runtime.plist').exists())

    def test_other_volume_is_rejected_before_preparation(self):
        self.assertNotEqual(self.run_prepare('web', '/Volumes/Other').returncode, 0)
        self.assertFalse(self.events.exists())

    def test_application_uninstall_refuses_to_start_without_ready_runtime(self):
        old = self.apps / 'KSSOLV Toolbox.app/Contents/MacOS'
        old.mkdir(parents=True)
        executable = old / 'KSSOLV_Toolbox'; executable.touch()
        script = self.script('preinstall')
        env = dict(os.environ, HOME=str(self.root / 'home'))
        env.pop('KSSOLV_RUNTIME_ROOT', None)
        result = subprocess.run(['/bin/bash', str(script), 'test.pkg', str(self.apps), '/'], env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Runtime preflight has not completed', result.stderr)
        self.assertTrue(executable.exists())

    def test_real_runtime_read_only_validation(self):
        actual = Path('/Applications/MATLAB/MATLAB_Runtime/R2026b')
        if not actual.exists():
            self.skipTest('matching Runtime is not installed')
        req = self.root / 'real-requirements.plist'
        req.write_bytes(plistlib.dumps(self.requirements))
        command = 'source "$1"; kssolv_runtime_usable "$2" "$3"'
        result = subprocess.run(['/bin/bash', '-c', command, 'test', str(ASSETS / 'runtime-common.sh'), str(actual), str(req)])
        self.assertEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
