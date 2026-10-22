"""Client rate limits use only the authenticated gateway's canonical identity."""

import _k8s_paths
import http.client
import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import deploy
import tls_edge
from portal import Handler, Portal, Server, gateway_config
from test_portal import FakeKube, INVITATION, ORIGIN


class ClientIdentityTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.portal = Portal(self.directory.name, ORIGIN, INVITATION, FakeKube())
        self.server = Server(('127.0.0.1', 0), self.portal)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.portal.pool.shutdown(wait=True)
        self.directory.cleanup()

    def request(self, path, ip, *, authenticated=True, extra=None, repeated=()):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=3)
        headers = {'Host': self.portal.authority, 'Origin': ORIGIN,
                   'Content-Type': 'application/json', 'X-KSSOLV-Client-IP': ip}
        if authenticated:
            headers['X-KSSOLV-Proxy-Token'] = self.server.proxy_token
        headers.update(extra or {})
        try:
            body = json.dumps({'invitation': 'wrong'})
            if repeated:
                connection.putrequest('POST', path, skip_host=True, skip_accept_encoding=True)
                for name, value in list(headers.items()) + list(repeated):
                    connection.putheader(name, value)
                connection.putheader('Content-Length', str(len(body.encode())))
                connection.endheaders(body.encode())
            else:
                connection.request('POST', path, body, headers)
            response = connection.getresponse()
            response.read()
            return response.status
        finally:
            connection.close()

    def test_registration_limits_are_separate_for_two_gateway_clients(self):
        path = '/_portal/api/register'
        for _ in range(10):
            self.assertEqual(self.request(path, '198.51.100.10'), 403)
        self.assertEqual(self.request(path, '198.51.100.10'), 429)
        self.assertEqual(self.request(path, '198.51.100.20'), 403)
        with self.portal.db() as db:
            identities = {row[0] for row in db.execute('SELECT DISTINCT identity FROM attempts')}
        self.assertEqual(identities, {'register:198.51.100.10', 'register:198.51.100.20'})

    def test_forged_forwarding_headers_cannot_rotate_the_rate_limit(self):
        path = '/_portal/api/register'
        for index in range(10):
            self.assertEqual(self.request(path, '198.51.100.' + str(index), authenticated=False,
                                          extra={'X-Forwarded-For': '203.0.113.' + str(index),
                                                 'X-Real-IP': '203.0.113.42',
                                                 'X-KSSOLV-Proxy-Token': 'forged'}), 403)
        self.assertEqual(self.request(path, '198.51.100.99', authenticated=False), 429)
        with self.portal.db() as db:
            identities = {row[0] for row in db.execute('SELECT DISTINCT identity FROM attempts')}
        self.assertEqual(identities, {'register:127.0.0.1'})

    def test_all_authentication_endpoints_use_the_same_canonical_gateway_ip(self):
        cases = [('register', '/_portal/api/register', 3, 201, 'uid'),
                 ('login', '/_portal/api/login', 2, 200, 'token'),
                 ('recovery_question', '/_portal/api/recovery-question', 1, 200, 'question'),
                 ('reset_password', '/_portal/api/reset-password', 4, 200, None)]
        for method, path, argument, expected_status, result in cases:
            with self.subTest(method=method), patch.object(self.portal, method, return_value=result) as call:
                self.assertEqual(self.request(path, '2001:db8:0:0::7'), expected_status)
                self.assertEqual(call.call_args.args[argument], '2001:db8::7')

    def test_invalid_ip_or_untrusted_peer_never_supplies_a_limiter_identity(self):
        with patch.object(self.portal, 'login', return_value='token') as call:
            for options in ({'ip': '198.51.100.1, 203.0.113.1'},
                            {'ip': '198.51.100.1', 'authenticated': False},
                            {'ip': '198.51.100.1', 'extra': {'X-KSSOLV-Proxy-Token': 'wrong'}},
                            {'ip': '198.51.100.1', 'extra': {'X-KSSOLV-Proxy-Token': '\u00e9'}},
                            {'ip': '198.51.100.1', 'repeated': [('X-KSSOLV-Client-IP', '203.0.113.1')]},
                            {'ip': '198.51.100.1', 'repeated': [('X-KSSOLV-Proxy-Token', 'forged')]}):
                with self.subTest(options=options):
                    self.assertEqual(self.request('/_portal/api/login', **options), 200)
                    self.assertEqual(call.call_args.args[2], '127.0.0.1')
        handler = object.__new__(Handler)
        handler.server = self.server
        handler.client_address = ('198.51.100.5', 1234)
        handler.headers = http.client.HTTPMessage()
        handler.headers['X-KSSOLV-Proxy-Token'] = self.server.proxy_token
        handler.headers['X-KSSOLV-Client-IP'] = '203.0.113.7'
        self.assertEqual(handler.client_ip(), '198.51.100.5')


class ProxyConfigurationTest(unittest.TestCase):
    def test_gateway_accepts_forwarding_only_from_explicit_edge_addresses(self):
        portal = SimpleNamespace(origin=ORIGIN, hostname='kssolv-k8s.localhost')
        token = 'gateway-test-token'
        direct = gateway_config(portal, token, '127.0.0.1')
        self.assertNotIn('set_real_ip_from', direct)
        self.assertNotIn('real_ip_header', direct)
        trusted = gateway_config(portal, token, '127.0.0.1', ['192.0.2.4', '2001:db8::/64'])
        self.assertIn('set_real_ip_from 192.0.2.4/32;', trusted)
        self.assertIn('set_real_ip_from 2001:db8::/64;', trusted)
        self.assertIn('real_ip_header X-Forwarded-For;', trusted)
        self.assertIn('proxy_set_header X-KSSOLV-Client-IP $remote_addr;', trusted)
        self.assertIn('proxy_set_header X-KSSOLV-Proxy-Token "' + token + '";', trusted)
        self.assertNotIn('__TRUSTED_PROXIES__', trusted)
        with self.assertRaises(ValueError):
            gateway_config(portal, token, '127.0.0.1', ['127.0.0.1; include /tmp/forged;'])

    def test_public_edge_replaces_rather_than_appends_client_supplied_forwarding(self):
        source = tls_edge.edge_config('online.example.org', 'worker:30088')
        self.assertIn('proxy_set_header X-Forwarded-For $remote_addr;', source)
        self.assertNotIn('$proxy_add_x_forwarded_for', source)

    def test_deployment_preserves_only_valid_explicit_trusted_proxies(self):
        arguments = ['--context', 'test-only', '--secrets-dir', '/unused/test-secrets',
                     '--accept-runtime-license']
        config = deploy.portal_config(deploy.parse_args(arguments + [
            '--trusted-proxy', '192.0.2.4', '--trusted-proxy', '2001:db8::/64']))
        self.assertEqual(config['trusted_proxies'], ['192.0.2.4/32', '2001:db8::/64'])
        for value in ('edge.example.org', '192.0.2.1; include /tmp/evil;'):
            with self.subTest(value=value), patch('sys.stderr'), self.assertRaises(SystemExit):
                deploy.parse_args(arguments + ['--trusted-proxy', value])

    def test_upgrading_proxy_trust_changes_the_mounted_config_and_rollout_checksum(self):
        arguments = ['--context', 'test-only', '--secrets-dir', '/unused/test-secrets',
                     '--accept-runtime-license']
        versions = []
        for extra in ([], ['--trusted-proxy', '192.0.2.4/32']):
            config = deploy.portal_config(deploy.parse_args(arguments + extra))
            objects = deploy.manifests(config, 'portal:upgrade-test')
            stored = next(item for item in objects if item['kind'] == 'ConfigMap')
            deployment = next(item for item in objects if item['kind'] == 'Deployment')
            template = deployment['spec']['template']
            mounted = next(item for item in template['spec']['volumes'] if item['name'] == 'config')
            self.assertEqual(mounted['configMap']['name'], stored['metadata']['name'])
            self.assertEqual(json.loads(stored['data']['config.json'])['trusted_proxies'],
                             config['trusted_proxies'])
            versions.append((stored['metadata']['name'], template['metadata']['annotations']['checksum/config']))
        self.assertNotEqual(versions[0][0], versions[1][0])
        self.assertNotEqual(versions[0][1], versions[1][1])


if __name__ == '__main__':
    unittest.main()
