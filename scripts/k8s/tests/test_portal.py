
import _k8s_paths
import concurrent.futures
import http.client
import base64
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch
from types import SimpleNamespace

from portal import Portal, Rejected, Server, PUBLIC
from kube import tenant_resources, tenant_namespace, Kubernetes, APIError
from deploy import manifests

ORIGIN = "http://kssolv-k8s.localhost:18130"
PASSWORD = "test-only-password-12345"
INVITATION = "test-invitation-with-enough-entropy"
RECOVERY = dict(password_confirmation=PASSWORD, recovery_question='我的测试备忘问题是什么？',
                recovery_answer='test-only-private-answer')


class FakeKube:
    def __init__(self):
        self.running, self.provisions, self.stopped, self.restarts = {}, [], [], []
        self.fail_stop = False
        self.instances = {}
        self.changed = threading.Condition()

    def ensure(self, uid, password, *, restart=False):
        self.provisions.append((uid, password))
        if restart: self.restarts.append(uid)
        with self.changed:
            self.running[uid] = True
            self.instances[uid] = 'instance-' + uid + '-' + str(len(self.restarts))
            self.changed.notify_all()

    def ready(self, uid): return self.running.get(uid, False)

    def instance(self, uid):
        return self.instances.get(uid, 'instance-' + uid) if self.ready(uid) else ''

    def stop(self, uid):
        if self.fail_stop: raise RuntimeError("temporary control-plane failure")
        self.running[uid] = False
        self.stopped.append(uid)


class PortalTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.now = 1000.0
        self.kube = FakeKube()
        self.portal = Portal(self.directory.name, ORIGIN, INVITATION, self.kube,
                             idle_seconds=30, max_running=2, clock=lambda: self.now)

    def tearDown(self):
        self.portal.pool.shutdown(wait=True)
        self.directory.cleanup()

    def account(self, name="alice"):
        return self.portal.register(name, PASSWORD, INVITATION, "test", **RECOVERY)

    def login(self, name="alice"):
        token = self.portal.login(name, PASSWORD, "test")
        session = self.portal.authenticate(token, self.portal.authority, "hub")
        with self.kube.changed:
            self.assertTrue(self.kube.changed.wait_for(lambda:self.kube.ready(session['uid']),timeout=3))
        self.portal.status(session["uid"])
        return token, session

    def tenant(self, session):
        code = self.portal.launch(session).split("code=")[1]
        host = self.portal.host(session["uid"])
        token = self.portal.claim(code, host)
        return token, host

    def rejection(self, status, function, *args):
        with self.assertRaises(Rejected) as result: function(*args)
        self.assertEqual(result.exception.status, status)

    def test_username_length_boundary(self):
        uid = self.account('a' * 32)
        self.assertEqual(self.portal.user(uid)['username'], 'a' * 32)
        with self.assertRaises(Rejected) as rejected: self.account('a' * 33)
        self.assertEqual(rejected.exception.status, 400)

    def test_password_hash_invitation_validation_and_duplicate_registration(self):
        self.rejection(403, self.portal.register, "alice", PASSWORD, "bad", "test")
        self.rejection(400, self.portal.register, "../../evil", PASSWORD, INVITATION, "test")
        self.rejection(400, self.portal.register, "alice", "short", INVITATION, "test")
        uid = self.account()
        user = self.portal.user(uid)
        self.assertNotEqual(user["password_hash"], PASSWORD)
        self.assertNotIn(PASSWORD.encode(), self.portal.dbfile.read_bytes())
        with self.assertRaises(Rejected) as duplicate:
            self.account()
        self.assertEqual(duplicate.exception.status, 409)
        self.rejection(401, self.portal.login, "alice", "wrong", "test")
        self.rejection(401, self.portal.login, "unknown", "wrong", "test")
        self.login()

    def test_host_role_and_one_time_code_cannot_cross_tenants(self):
        self.account(); self.account("bob")
        _, alice = self.login(); _, bob = self.login("bob")
        code = self.portal.launch(alice).split("code=")[1]
        self.rejection(401, self.portal.claim, code, self.portal.host(bob["uid"]))
        token = self.portal.claim(code, self.portal.host(alice["uid"]))
        self.rejection(401, self.portal.claim, code, self.portal.host(alice["uid"]))
        self.rejection(401, self.portal.authenticate, token, self.portal.host(bob["uid"]), "tenant")
        self.rejection(401, self.portal.authenticate, token, self.portal.authority, "hub")
        self.assertNotEqual(self.portal.user(alice["uid"])["runtime_secret"], self.portal.user(bob["uid"])["runtime_secret"])

    def test_polling_does_not_prevent_idle_shutdown_and_login_reuses_identity_and_storage(self):
        uid = self.account(); hub, session = self.login(); token, host = self.tenant(session)
        original = self.portal.user(uid)["runtime_secret"]
        for _ in range(4):
            self.now += 10
            self.portal.status(uid)
        self.portal.sweep()
        self.assertIn(uid, self.kube.stopped)
        self.assertEqual(self.portal.user(uid)["state"], "stopped")
        self.rejection(401, self.portal.authenticate, hub, self.portal.authority, "hub")
        self.rejection(401, self.portal.authenticate, token, host, "tenant")
        _, restored = self.login()
        self.assertEqual(restored["uid"], uid)
        self.assertEqual(self.portal.user(uid)["runtime_secret"], original)
        self.assertEqual(self.kube.provisions[-1], (uid, original))

    def test_reopening_entry_reuses_identity_and_running_instance(self):
        uid = self.account()
        token, session = self.login()
        provisions = list(self.kube.provisions)
        self.now += 20
        self.assertEqual(self.portal.status(uid)['idleRemaining'], 10)
        resumed = self.portal.authenticate(token, self.portal.authority, 'hub')
        first = self.portal.launch(resumed)
        self.assertEqual(self.portal.status(uid)['idleRemaining'], 30)
        second = self.portal.launch(resumed)
        self.assertNotEqual(first, second)
        self.assertEqual(self.kube.provisions, provisions)
        self.assertEqual(self.portal.status(uid)['portalOrigin'], ORIGIN)

    def test_sibling_tenant_domain_matches_single_level_wildcard_certificate(self):
        with tempfile.TemporaryDirectory() as directory:
            portal=Portal(directory,'https://kssolv.example.org',INVITATION,FakeKube(),tenant_domain='example.org')
            try:
                uid='a'*24
                self.assertEqual(portal.host(uid),'u-'+uid+'.example.org')
                self.assertTrue(portal.known_host(portal.host(uid)))
                self.assertTrue(portal.known_host('kssolv.example.org'))
                self.assertFalse(portal.known_host('u-'+uid+'.kssolv.example.org'))
                self.assertFalse(portal.known_host('other.example.org'))
            finally: portal.pool.shutdown(wait=True)

    def test_human_activity_keeps_only_its_own_tenant_alive(self):
        alice_uid = self.account(); bob_uid = self.account("bob")
        _, alice = self.login(); self.login("bob")
        token, host = self.tenant(alice)
        self.now += 25
        self.portal.activity(self.portal.authenticate(token, host, "tenant"))
        self.now += 10
        self.portal.sweep()
        self.assertNotIn(alice_uid, self.kube.stopped)
        self.assertIn(bob_uid, self.kube.stopped)

    def test_logout_revokes_access_even_when_kubernetes_temporarily_fails(self):
        uid = self.account(); hub, session = self.login(); token, host = self.tenant(session)
        self.kube.fail_stop = True
        with self.assertRaises(RuntimeError): self.portal.stop(uid, "logout")
        self.rejection(401, self.portal.authenticate, token, host, "tenant")
        self.rejection(401, self.portal.authenticate, hub, self.portal.authority, "hub")
        self.kube.fail_stop = False
        self.portal.sweep()
        self.assertEqual(self.portal.user(uid)["state"], "stopped")

    def test_capacity_and_login_rate_limit_are_enforced(self):
        for name in ("alice", "bob", "carol"): self.account(name)
        self.login(); self.login("bob")
        self.rejection(409, self.portal.login, "carol", PASSWORD, "test")
        for _ in range(8): self.rejection(401, self.portal.login, "unknown", "wrong", "test")
        self.rejection(429, self.portal.login, "unknown", "wrong", "test")

    def test_explicit_workspace_exit_preserves_only_hub_login_and_own_storage_identity(self):
        self.account(); self.account('bob')
        hub, alice = self.login(); token, host = self.tenant(alice)
        _, bob = self.login('bob')
        secret = self.portal.user(alice['uid'])['runtime_secret']
        self.portal.stop(alice['uid'],'Exited workspace.',keep_login=True)
        self.portal.authenticate(hub,self.portal.authority,'hub')
        self.rejection(401,self.portal.authenticate,token,host,'tenant')
        self.assertFalse(self.kube.ready(alice['uid']))
        self.assertTrue(self.kube.ready(bob['uid']))
        self.assertEqual(self.portal.user(alice['uid'])['runtime_secret'],secret)
        self.assertEqual(self.portal.status(alice['uid'])['state'],'stopped')

    def test_failed_entry_is_recoverable_even_when_proxy_health_is_ready(self):
        uid = self.account(); _, session = self.login()
        response = SimpleNamespace(status=503, read=lambda _: b'busy')
        connection = SimpleNamespace(request=lambda *a, **k: None, getresponse=lambda: response, close=lambda: None)
        with patch('portal.http.client.HTTPConnection', return_value=connection):
            self.rejection(503, self.portal.entry, uid)
            state = self.portal.status(uid)
            self.assertTrue(state['ready'])
            self.assertTrue(state['canRestart'])
            self.assertTrue(state['connectionError'])
            self.assertNotIn(self.portal.user(uid)['runtime_secret'], state['connectionError'])
            response.status = 200
            self.portal.entry(uid)
            self.assertFalse(self.portal.status(uid)['connectionError'])
        self.kube.running[uid] = False
        state = self.portal.status(uid)
        self.assertFalse(state['ready'])
        self.assertTrue(state['canRestart'])
        self.assertTrue(state['connectionError'])

    def test_old_healthy_replica_cannot_complete_a_new_runtime_generation(self):
        kube = object.__new__(Kubernetes)
        deployment = {'metadata': {'generation': 2}, 'spec': {'replicas': 1},
                      'status': {'observedGeneration': 2, 'availableReplicas': 1, 'updatedReplicas': 0}}
        kube.request = lambda *args: deployment
        self.assertFalse(kube.ready('a' * 24))
        deployment['status']['updatedReplicas'] = 1
        self.assertTrue(kube.ready('a' * 24))

    def test_runtime_identity_tracks_container_restarts_without_resetting_idle_time(self):
        uid = self.account(); _, session = self.login()
        initial = self.portal.status(uid)['runtimeInstance']
        self.now += 10
        self.kube.running[uid] = False
        self.assertEqual(self.portal.status(uid)['runtimeInstance'], '')
        self.kube.instances[uid] = 'replacement-container'
        self.kube.running[uid] = True
        state = self.portal.status(uid)
        self.assertNotEqual(state['runtimeInstance'], initial)
        self.assertEqual(state['idleRemaining'], 20)
        self.portal.launch(session, automatic=True)
        self.assertEqual(self.portal.status(uid)['idleRemaining'], 20)
        self.portal.launch(session)
        self.assertEqual(self.portal.status(uid)['idleRemaining'], 30)

    def test_instance_uses_only_a_single_ready_runtime_and_changes_on_container_restart(self):
        kube = object.__new__(Kubernetes)
        pod = {'metadata': {'uid': 'pod-uid'}, 'status': {'containerStatuses': [
            {'name': 'runtime', 'ready': True, 'state': {'running': {}}, 'containerID': 'container-a'}]}}
        items = [pod]; requests = []
        def request(method, path):
            requests.append((method, path)); return {'items': items}
        kube.request = request
        initial = kube.instance('a' * 24)
        self.assertEqual(len(initial), 64)
        self.assertNotIn('container-a', initial)
        self.assertIn('/namespaces/kssolv-u-' + 'a' * 24 + '/pods?labelSelector=', requests[-1][1])
        container = pod['status']['containerStatuses'][0]
        container['ready'] = False
        self.assertEqual(kube.instance('a' * 24), '')
        container.update(ready=True, containerID='container-b')
        self.assertNotEqual(kube.instance('a' * 24), initial)
        pod['metadata']['deletionTimestamp'] = '2026-10-20T00:00:00Z'
        self.assertEqual(kube.instance('a' * 24), '')

    def test_kubernetes_restart_changes_template_but_preserves_volume_and_machine_identity(self):
        uid = 'a' * 24; changes = []
        config = dict(runtime_image='test:1', pull_policy='IfNotPresent', storage_class='local',
                      storage='10Gi', cpu='8', memory='16Gi', system_namespace='kssolv-system')
        kube = object.__new__(Kubernetes); kube.config = config
        def request(method, path, data=None):
            if method == 'GET':
                return {'metadata': {'labels': {'kssolv-user': uid, 'app.kubernetes.io/managed-by': 'kssolv-portal'}}}
            if method == 'POST': raise APIError(409)
            changes.append((path, data))
        kube.request = request
        kube.ensure(uid, 'same-machine-secret', restart=True)
        first = next(data for path, data in changes if path.endswith('/deployments/runtime'))['spec']
        self.assertTrue(first['template']['metadata']['annotations']['kssolv-restart'])
        self.assertEqual(first['template']['spec']['volumes'][0]['persistentVolumeClaim']['claimName'], 'data')
        self.assertFalse(any('/persistentvolumeclaims' in path or '/secrets' in path for path, _ in changes))
        changes.clear(); kube.ensure(uid, 'same-machine-secret', restart=True)
        second = next(data for path, data in changes if path.endswith('/deployments/runtime'))['spec']
        self.assertNotEqual(first['template']['metadata']['annotations'], second['template']['metadata']['annotations'])

    def test_confirmed_restart_replaces_only_own_runtime_and_retains_hub_login_and_storage_identity(self):
        uid = self.account(); self.account('bob')
        hub, session = self.login(); tenant, host = self.tenant(session)
        _, bob = self.login('bob')
        secret = self.portal.user(uid)['runtime_secret']
        entered, release = threading.Event(), threading.Event()
        original = self.kube.ensure
        def ensure(uid, password, *, restart=False):
            entered.set(); release.wait(3); original(uid, password, restart=restart)
        self.kube.ensure = ensure
        try:
            self.portal.restart(session)
            self.assertTrue(entered.wait(3))
            self.assertEqual(self.portal.status(uid)['state'], 'restarting')
            self.assertFalse(self.portal.status(uid)['ready'], 'Old healthy Pod cannot finish a restart')
            self.portal.authenticate(hub, self.portal.authority, 'hub')
            self.rejection(401, self.portal.authenticate, tenant, host, 'tenant')
        finally: release.set()
        with self.portal.lock(uid):
            self.assertTrue(self.portal.status(uid)['ready'])
        self.assertEqual(self.kube.restarts, [uid])
        self.assertEqual(self.portal.user(uid)['runtime_secret'], secret)
        self.assertTrue(self.portal.status(bob['uid'])['ready'])
        self.assertEqual(self.kube.stopped, [])

    def test_administrator_restart_replaces_instance_even_with_unchanged_resources(self):
        uid = self.account()
        hub, session = self.login()
        tenant, host = self.tenant(session)
        secret = self.portal.user(uid)['runtime_secret']
        recorded = []
        ensure = self.kube.ensure
        def provision(uid, password, **options):
            recorded.append(options)
            ensure(uid, password, restart=options.get('restart', False))
        self.kube.ensure = provision
        server = Server(('127.0.0.1', 0), self.portal)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        bridge_token = 'test-only-admin-bridge-token-' * 2
        try:
            bodies = [{'uid': uid},
                      {'uid': uid, 'profile': 'small'},
                      {'uid': uid, 'profile': 'custom', 'resources': {'cpu': '3', 'memory': '12Gi'}}]
            for index, body in enumerate(bodies, 1):
                before = self.kube.instance(uid)
                connection = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=3)
                try:
                    with patch.dict(os.environ, {'KSSOLV_ADMIN_BRIDGE_TOKEN': bridge_token}):
                        connection.request('POST', '/_portal/internal-admin/restart', json.dumps(body),
                                           {'Host': self.portal.authority, 'Origin': ORIGIN,
                                            'Content-Type': 'application/json',
                                            'Authorization': 'Bearer ' + bridge_token})
                        response = connection.getresponse()
                        self.assertEqual(response.status, 200, response.read())
                    with self.kube.changed:
                        self.assertTrue(self.kube.changed.wait_for(lambda: len(recorded) == index, timeout=3))
                    with self.portal.lock(uid):
                        self.assertTrue(self.portal.status(uid)['ready'])
                    self.assertNotEqual(self.kube.instance(uid), before)
                    self.assertTrue(recorded[-1]['restart'])
                finally:
                    connection.close()
            self.assertEqual(recorded[1]['resources'], self.portal.profiles['small'])
            self.assertEqual(recorded[2]['resources'], {'cpu': '3', 'memory': '12Gi'})
            self.assertEqual(self.portal.user(uid)['runtime_secret'], secret)
            self.portal.authenticate(hub, self.portal.authority, 'hub')
            self.rejection(401, self.portal.authenticate, tenant, host, 'tenant')
            self.assertEqual(self.kube.stopped, [])
        finally:
            server.shutdown()
            server.server_close()

    def test_http_origin_gate_and_auth_proxy_remove_portal_cookie(self):
        self.account(); _, session = self.login(); token, host = self.tenant(session)
        server = Server(("127.0.0.1", 0), self.portal)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        def request(path, headers, body=None):
            connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=5)
            connection.request("GET" if body is None else "POST", path, body=body, headers=headers)
            response = connection.getresponse(); result=(response.status, dict(response.getheaders()), response.read())
            connection.close(); return result
        try:
            status, headers, body = request('/online', {'Host':self.portal.authority})
            self.assertEqual(status,200)
            self.assertIn(b'id="tenant-workspace"',body)
            self.assertIn('frame-src http://*.kssolv-k8s.localhost:18130', headers['Content-Security-Policy'])
            self.assertIn("img-src 'self' data:", headers['Content-Security-Policy'])
            critical = (PUBLIC/'critical.css').read_bytes()
            self.assertIn(b'<style>'+critical+b'</style>',body)
            digest = base64.b64encode(hashlib.sha256(critical).digest()).decode()
            self.assertIn("'sha256-"+digest+"'",headers['Content-Security-Policy'])
            self.assertNotIn("'unsafe-inline'",headers['Content-Security-Policy'])
            self.assertIn("frame-ancestors 'none'",headers['Content-Security-Policy'])
            code=self.portal.launch(session).split('code=')[1]
            self.portal.entry=lambda uid:(200,b'<!doctype html><html><body>Runtime entry</body></html>')
            status, headers, _ = request('/_portal/claim?code='+code,{'Host':host})
            self.assertEqual(status,200)
            self.assertIn('frame-ancestors '+ORIGIN,headers['Content-Security-Policy'])
            status, _, _ = request("/_portal/api/login", {"Host": self.portal.authority,"Content-Type":"application/json","Origin":"https://evil.invalid"}, '{}')
            self.assertEqual(status, 403)
            status, headers, _ = request("/internal/auth", {"Host":host,"Cookie":"kssolv_tenant="+token+"; connector=keep"})
            self.assertEqual(status, 200)
            self.assertEqual(headers["X-KSSOLV-Cookie"], "connector=keep")
            self.assertNotIn(token, str(headers))
            status, _, _ = request("/internal/auth", {"Host":host,"Cookie":"kssolv_tenant="+token,"X-Original-Origin":"https://evil.invalid"})
            self.assertEqual(status, 403)
            status, _, _ = request("/_portal/api/logout", {"Host":host,"Content-Type":"application/json","Origin":"http://"+host}, '{}')
            self.assertEqual(status, 401)
            status, _, _ = request('/_portal/api/logout', {'Host':host,'Cookie':'kssolv_tenant='+token,
                'Content-Type':'application/json','Origin':'https://evil.invalid'}, '{}')
            self.assertEqual(status,403)
            self.assertTrue(self.kube.ready(session['uid']))
            self.account('bob'); bob_hub, bob = self.login('bob')
            status, _, body = request('/_portal/api/session', {'Host':host,'Cookie':'kssolv_tenant='+token})
            self.assertEqual(status,200)
            self.assertEqual(json.loads(body)['username'],'alice')
            status, headers, _ = request('/_portal/api/logout', {'Host':host,'Cookie':'kssolv_tenant='+token,
                'Content-Type':'application/json','Origin':'http://'+host}, '{}')
            self.assertEqual(status,200)
            self.assertIn('Max-Age=0',headers['Set-Cookie'])
            self.rejection(401,self.portal.authenticate,token,host,'tenant')
            self.assertFalse(self.kube.ready(session['uid']))
            self.assertTrue(self.kube.ready(bob['uid']))
            self.portal.authenticate(bob_hub,self.portal.authority,'hub')
        finally: server.shutdown(); server.server_close()

    def test_entry_failures_render_recovery_dialog_but_api_errors_remain_json(self):
        self.account(); _, session = self.login()
        host = self.portal.host(session['uid'])
        server = Server(('127.0.0.1', 0), self.portal)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        def request(path):
            connection = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=5)
            connection.request('GET', path, headers={'Host': host})
            response = connection.getresponse()
            result = response.status, dict(response.getheaders()), response.read().decode()
            connection.close(); return result
        def unavailable(uid): raise Rejected(503, '工作空间尚未就绪。<script>alert(1)</script>')
        def timeout(uid): raise TimeoutError('private runtime details')
        try:
            for entry, expected_status in [(unavailable, 503), (timeout, 503)]:
                self.portal.entry = entry
                code = self.portal.launch(session).split('code=')[1]
                status, headers, body = request('/_portal/claim?code=' + code)
                self.assertEqual(status, expected_status)
                self.assertIn('text/html', headers['Content-Type'])
                self.assertIn('class="mwDialog"', body)
                self.assertIn('/_portal/i18n.js', body)
                self.assertIn('id="portal-language"', body)
                self.assertIn('重新连接', body)
                self.assertIn('action="' + ORIGIN + '/online"', body)
                self.assertIn('target="_top"', body)
                self.assertNotIn('<script>', body)
                self.assertNotIn('private runtime details', body)
                style = (PUBLIC / 'style.css').read_bytes()
                digest = base64.b64encode(hashlib.sha256(style).digest()).decode()
                self.assertIn("style-src 'sha256-" + digest + "'", headers['Content-Security-Policy'])
                self.assertIn('form-action ' + ORIGIN, headers['Content-Security-Policy'])
                self.assertIn('frame-ancestors ' + ORIGIN, headers['Content-Security-Policy'])
            status, headers, body = request('/_portal/claim?code=expired')
            self.assertEqual(status, 401)
            self.assertIn('连接已过期', body)
            self.assertIn('重新登录', body)
            status, _, body = request('/_portal/connection-error')
            self.assertEqual(status, 401)
            self.assertIn('会话已结束', body)
            status, headers, body = request('/_portal/i18n.js')
            self.assertEqual(status, 200)
            self.assertIn('text/javascript', headers['Content-Type'])
            self.assertIn('kssolv.portal.language', body)
            status, headers, body = request('/_portal/api/session')
            self.assertEqual(status, 401)
            self.assertIn('application/json', headers['Content-Type'])
            self.assertIn('error', json.loads(body))
        finally: server.shutdown(); server.server_close()

    def test_tenant_exit_and_hub_resume_retain_runtime_and_cookies_until_idle_expiry(self):
        self.account(); hub, session = self.login(); token, host = self.tenant(session)
        server=Server(('127.0.0.1',0),self.portal)
        threading.Thread(target=server.serve_forever,daemon=True).start()
        try:
            for origin, expected in [('https://evil.invalid',403),('http://'+host,200)]:
                connection=http.client.HTTPConnection('127.0.0.1',server.server_port,timeout=5)
                connection.request('POST','/_portal/api/exit','{}',{'Host':host,'Origin':origin,
                    'Cookie':'kssolv_tenant='+token,'Content-Type':'application/json'})
                response=connection.getresponse();self.assertEqual(response.status,expected)
                if expected==200: self.assertIsNone(response.getheader('Set-Cookie'))
                response.read();connection.close()
            self.portal.authenticate(hub,self.portal.authority,'hub')
            self.portal.authenticate(token,host,'tenant')
            self.assertEqual(self.portal.status(session['uid'])['state'],'running')
            self.now+=20
            connection=http.client.HTTPConnection('127.0.0.1',server.server_port,timeout=5)
            connection.request('POST','/_portal/api/resume','{}',{'Host':self.portal.authority,
                'Origin':ORIGIN,'Cookie':'kssolv_hub='+hub,'Content-Type':'application/json'})
            response=connection.getresponse();self.assertEqual(response.status,200)
            self.assertEqual(json.loads(response.read())['idleRemaining'],30);connection.close()
            self.assertEqual(len(self.kube.provisions),1)
            self.now+=31;self.portal.sweep()
            self.assertEqual(self.portal.status(session['uid'])['state'],'stopped')
            self.rejection(409,self.portal.resume,session)
        finally: server.shutdown();server.server_close()

    def test_resource_spec_restricts_mounts_capabilities_network_and_rbac(self):
        config = dict(runtime_image="image:1", pull_policy="IfNotPresent", storage_class="standard",
                      storage="20Gi", cpu="4", memory="8Gi", system_namespace="kssolv-system", node_port=30088)
        uid = "a"*24; namespace, resources = tenant_resources(uid, "random-machine-secret", config)
        self.assertEqual(namespace, tenant_namespace(uid))
        pod = resources[-1]["spec"]["template"]["spec"]
        self.assertFalse(pod["automountServiceAccountToken"])
        self.assertFalse(any("hostPath" in item for item in pod["volumes"]))
        self.assertEqual(pod["containers"][0]["securityContext"]["capabilities"]["drop"], ["ALL"])
        self.assertNotIn("serviceAccountToken", json.dumps(pod["volumes"]))
        self.assertEqual(resources[1]["spec"]["policyTypes"], ["Ingress","Egress"])
        role = manifests(config, "portal:1")[2]
        self.assertFalse(any("pods/exec" in item["resources"] or "*" in item["verbs"] for item in role["rules"]))
        self.assertFalse(any("secrets" in item["resources"] and set(item["verbs"]) & {"get","list","watch"} for item in role["rules"]))

    def test_https_host_cookie_prefix_prevents_legacy_domain_cookie_shadowing(self):
        self.portal.scheme='https';self.portal.origin=ORIGIN.replace('http:','https:')
        self.account();self.account('bob')
        server=Server(('127.0.0.1',0),self.portal)
        threading.Thread(target=server.serve_forever,daemon=True).start()
        try:
            connection=http.client.HTTPConnection('127.0.0.1',server.server_port,timeout=5)
            connection.request('POST','/_portal/api/login',json.dumps({'username':'alice','password':PASSWORD}),
                {'Host':self.portal.authority,'Origin':self.portal.origin,'Content-Type':'application/json'})
            response=connection.getresponse();header=response.getheader('Set-Cookie');response.read();connection.close()
            self.assertTrue(header.startswith('__Host-kssolv_hub='));self.assertIn('; Secure',header)
            self.assertIn('; Path=/',header);self.assertNotIn('Domain=',header)
            bob=self.portal.login('bob',PASSWORD,'test')
            connection=http.client.HTTPConnection('127.0.0.1',server.server_port,timeout=5)
            connection.request('GET','/_portal/api/me',headers={'Host':self.portal.authority,
                'Cookie':header.split(';')[0]+'; kssolv_hub='+bob})
            response=connection.getresponse();self.assertEqual(response.status,200)
            self.assertEqual(json.loads(response.read())['username'],'alice');connection.close()
        finally:server.shutdown();server.server_close()

    def test_redeploy_changes_timeout_and_reconciles_owned_policy_without_replacing_secrets(self):
        config = dict(runtime_image="image:1", pull_policy="IfNotPresent", storage_class="standard",
                      storage="20Gi", cpu="4", memory="8Gi", system_namespace="kssolv-system", node_port=30088,
                      idle_seconds=120)
        before = manifests(config, "portal:1")[6]["spec"]["template"]["metadata"]
        config["idle_seconds"] = 1800
        after = manifests(config, "portal:1")[6]["spec"]["template"]["metadata"]
        self.assertNotEqual(before, after)
        client = object.__new__(Kubernetes); client.config = config; calls=[]
        uid = "a"*24
        def request(method,path,data=None):
            calls.append((method,path,data))
            if method == "POST": raise APIError(409)
            if method == "GET": return {"metadata":{"labels":{"kssolv-user":uid,"app.kubernetes.io/managed-by":"kssolv-portal"}}}
            return {}
        client.request = request
        client.ensure(uid,"unchanged-random-credential")
        patched = [path for method,path,_ in calls if method=="PATCH"]
        self.assertTrue(any(path.endswith('/networkpolicies/tenant-isolation') for path in patched))
        self.assertTrue(any(path.endswith('/resourcequotas/tenant') for path in patched))
        self.assertFalse(any('/secrets/' in path or '/persistentvolumeclaims/' in path for path in patched))
        self.assertFalse(any(method=='POST' and path.endswith('/persistentvolumeclaims') for method,path,_ in calls))
        client.request = lambda method,path,data=None: (_ for _ in ()).throw(APIError(409)) if method=="POST" else {"metadata":{"labels":{"kssolv-user":"b"*24}}}
        with self.assertRaises(ValueError): client.ensure(uid,"not-used")


if __name__ == "__main__": unittest.main()
