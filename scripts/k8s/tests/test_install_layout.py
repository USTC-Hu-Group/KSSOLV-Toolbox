"""Installed services import without the checkout or test bootstrap on sys.path."""
import _k8s_paths
from _k8s_paths import ROOT
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest

from manuals import build_context


class InstallLayoutTest(unittest.TestCase):
    def test_direct_script_namespace_keeps_bridge_rejections_as_client_errors(self):
        # Launch a fresh interpreter and load the production script in a
        # distinct entry namespace. No Kubernetes API or real nginx is used.
        program = textwrap.dedent('''
            import http.client, json, os, runpy, sys, tempfile, threading
            from pathlib import Path
            entry = Path(sys.argv[1])
            sys.path.insert(0, str(entry.parent))
            namespace = runpy.run_path(str(entry), run_name='portal_service_entry')
            class Kube:
                config = {}
            token = 'test-only-bridge-credential-' * 2
            os.environ['KSSOLV_ADMIN_BRIDGE_TOKEN'] = token
            with tempfile.TemporaryDirectory() as directory:
                portal = namespace['Portal'](directory, 'https://portal.example.org',
                                              'test-only-registration-invitation', Kube())
                server = namespace['Server'](('127.0.0.1', 0), portal)
                threading.Thread(target=server.serve_forever, daemon=True).start()
                statuses = []
                try:
                    cases = [('POST', 'users', {}, ''),
                             ('POST', 'invitation', {'value': 'short'}, token),
                             ('POST', 'admin-login', {'username': None, 'password': None}, token),
                             ('GET', 'users', None, token)]
                    for method, operation, data, credential in cases:
                        connection = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=3)
                        headers = {'Host': portal.authority, 'Origin': portal.origin,
                                   'Content-Type': 'application/json', 'Authorization': 'Bearer ' + credential}
                        connection.request(method, '/_portal/internal-admin/' + operation,
                                           json.dumps(data) if data is not None else None, headers)
                        response = connection.getresponse()
                        statuses.append(response.status)
                        response.read()
                        connection.close()
                finally:
                    server.shutdown()
                    server.server_close()
                    portal.pool.shutdown(wait=True)
                print(json.dumps(statuses))
        ''')
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([sys.executable, '-c', program, str(ROOT / 'server/portal/portal.py')],
                                    cwd=directory, env=dict(os.environ, PYTHONPATH='', PYTHONDONTWRITEBYTECODE='1'),
                                    check=True, capture_output=True, text=True, timeout=15)
        self.assertEqual(json.loads(result.stdout), [403, 400, 401, 200])

    def test_portal_image_context_contains_only_service_sources_and_requested_assets(self):
        with build_context(ROOT / 'scripts/k8s') as context:
            self.assertEqual({item.name for item in context.iterdir()}, {'Dockerfile', 'portal', 'manuals'})
            production = context / 'portal'
            self.assertEqual({item.name for item in production.iterdir()},
                             {'portal.py', 'kube.py', 'profiles.py', 'portal_control.py', 'portal_protocol.py', 'nginx.conf', 'public'})
            for file in production.glob('*.py'):
                self.assertEqual(file.read_bytes(), (ROOT / 'server/portal' / file.name).read_bytes())
            self.assertFalse((production / 'tests').exists())
            self.assertFalse((production / 'admin').exists())

    def test_host_staging_preserves_service_paths_without_importing_scripts_as_runtime_code(self):
        source = ROOT / 'scripts/k8s/admin/install_admin.py'
        spec = importlib.util.spec_from_file_location('kssolv_install_layout_fixture', source)
        installer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(installer)
        with tempfile.TemporaryDirectory() as directory:
            application = Path(directory) / 'app'
            installer.stage_application(application)
            self.assertEqual({file.name for file in (application / 'admin').glob('*.py')},
                             {'admin_server.py', 'cloud.py', 'custom_scripts.py', 'host_ops.py',
                              'script_runner.py', 'install_admin.py', 'set_superadmin.py'})
            self.assertTrue((application / 'portal/public/i18n.js').is_file())
            self.assertTrue((application / 'admin/public/index.html').is_file())
            self.assertFalse((application / 'tests').exists())
            environment = dict(os.environ, PYTHONPATH='', PYTHONDONTWRITEBYTECODE='1')
            command = ('import admin_server, host_ops, script_runner; '
                       'assert (admin_server.PUBLIC / "i18n.js").is_file(); '
                       'assert (admin_server.STATIC / "index.html").is_file()')
            subprocess.run([sys.executable, '-c', command], cwd=application / 'admin',
                           env=environment, check=True, capture_output=True, text=True)
            for name in ('install_admin.py', 'set_superadmin.py', 'admin_server.py', 'script_runner.py', 'host_ops.py'):
                subprocess.run([sys.executable, str(application / 'admin' / name), '--help'],
                               cwd=directory, env=environment, check=True, capture_output=True, text=True)


if __name__ == '__main__':
    unittest.main()
