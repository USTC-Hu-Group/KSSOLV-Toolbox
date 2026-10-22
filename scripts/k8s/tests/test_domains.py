"""Custom domains must agree across deployment, TLS routing and browser security."""

import _k8s_paths
import http.client
import io
import json
import os
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch
from urllib.parse import urlsplit

from test_portal import FakeKube, INVITATION, PASSWORD, RECOVERY
import deploy
from kube import tenant_resources
from portal import Portal, Server
import tls_edge


ORIGIN = "https://kssolv.glea.moe"
DEPLOY_ARGS = ["--context", "domain-test", "--secrets-dir", "/unused/domain-test-secrets",
               "--accept-runtime-license"]
EDGE_ARGS = ["--cert", "/unused/fullchain.pem", "--key", "/unused/private.key",
             "--state-dir", "/unused/tls-state"]


class DomainConfigTest(unittest.TestCase):
    def test_default_runtime_limit_and_tenant_quota_agree(self):
        with patch.dict(os.environ, {}, clear=True):
            config = deploy.portal_config(deploy.parse_args(DEPLOY_ARGS))
        _, resources = tenant_resources('a' * 24, 'test-machine-credential', config)
        quota = next(item for item in resources if item['kind'] == 'ResourceQuota')['spec']['hard']
        deployment = next(item for item in resources if item['kind'] == 'Deployment')
        allocation = deployment['spec']['template']['spec']['containers'][0]['resources']
        self.assertEqual(allocation['limits']['cpu'], '4')
        self.assertEqual(allocation['limits']['memory'], '52Gi')
        self.assertEqual(quota['limits.cpu'], allocation['limits']['cpu'])
        self.assertEqual(quota['limits.memory'], allocation['limits']['memory'])
        self.assertEqual(allocation['requests']['cpu'], '4')
        self.assertEqual(allocation['requests']['memory'], '52Gi')
        self.assertEqual(config['max_running'], 2)
        self.assertEqual(quota['pods'], '1')

    def test_environment_reaches_configmap_and_tls_without_a_tenant_override(self):
        with patch.dict(os.environ, {"KSSOLV_PUBLIC_ORIGIN": ORIGIN}, clear=True):
            config = deploy.portal_config(deploy.parse_args(DEPLOY_ARGS))
            edge = tls_edge.parse_args(EDGE_ARGS + ["--no-http-redirect"])
        resources = deploy.manifests(config, "portal:test")
        stored = json.loads(next(item for item in resources if item["kind"] == "ConfigMap")["data"]["config.json"])
        self.assertEqual(stored["origin"], ORIGIN)
        self.assertEqual(stored["tenant_domain"], "kssolv.glea.moe")
        self.assertEqual(edge.domain, "kssolv.glea.moe")
        self.assertEqual(edge.tenant_domain, stored["tenant_domain"])
        nginx = tls_edge.edge_config(edge.domain, edge.upstream, not edge.no_http_redirect, edge.tenant_domain)
        self.assertIn('server_name kssolv.glea.moe "~^u-[a-f0-9]{24}\\.kssolv\\.glea\\.moe$";', nginx)
        self.assertNotIn("listen 8080", nginx)
        self.assertNotIn("gleamoe.com", nginx)

    def test_explicit_arguments_override_environment_for_both_commands(self):
        environment = {"KSSOLV_PUBLIC_ORIGIN": ORIGIN, "KSSOLV_TENANT_DOMAIN": "kssolv.glea.moe"}
        with patch.dict(os.environ, environment, clear=True):
            config = deploy.portal_config(deploy.parse_args(DEPLOY_ARGS + [
                "--origin", "https://research.example.org", "--tenant-domain", "sessions.example.org"]))
            edge = tls_edge.parse_args(EDGE_ARGS + [
                "--domain", "research.example.org", "--tenant-domain", "sessions.example.org"])
        self.assertEqual(config["origin"], "https://research.example.org")
        self.assertEqual(config["tenant_domain"], "sessions.example.org")
        self.assertEqual(edge.domain, "research.example.org")
        self.assertEqual(edge.tenant_domain, config["tenant_domain"])

    def test_environment_supports_a_separate_tenant_domain(self):
        with patch.dict(os.environ, {"KSSOLV_PUBLIC_ORIGIN": ORIGIN,
                                    "KSSOLV_TENANT_DOMAIN": "workspaces.example.org"}, clear=True):
            config = deploy.portal_config(deploy.parse_args(DEPLOY_ARGS))
            edge = tls_edge.parse_args(EDGE_ARGS)
        self.assertEqual(config["tenant_domain"], "workspaces.example.org")
        self.assertEqual(edge.tenant_domain, config["tenant_domain"])

    def test_domain_change_triggers_portal_rollout(self):
        checksums, names = [], []
        for origin in (ORIGIN, "https://research.example.org"):
            with patch.dict(os.environ, {"KSSOLV_PUBLIC_ORIGIN": origin}, clear=True):
                config = deploy.portal_config(deploy.parse_args(DEPLOY_ARGS))
            resources = deploy.manifests(config, "portal:test")
            deployment = next(item for item in resources if item["kind"] == "Deployment")
            stored = next(item for item in resources if item["kind"] == "ConfigMap")
            self.assertTrue(stored['immutable'])
            mounted = next(v for v in deployment['spec']['template']['spec']['volumes'] if v['name'] == 'config')
            self.assertEqual(mounted['configMap']['name'], stored['metadata']['name'])
            self.assertEqual(stored, next(item for item in deploy.manifests(dict(reversed(list(config.items()))), 'portal:test')
                                          if item['kind'] == 'ConfigMap'))
            names.append(stored['metadata']['name'])
            checksums.append(deployment["spec"]["template"]["metadata"]["annotations"]["checksum/config"])
        self.assertNotEqual(*checksums)
        self.assertNotEqual(*names, 'A new Pod must not reuse a kubelet-cached configuration name')

    def test_local_development_keeps_its_default_but_tls_requires_a_domain(self):
        with patch.dict(os.environ, {}, clear=True):
            config = deploy.portal_config(deploy.parse_args(DEPLOY_ARGS))
            with patch("sys.stderr"), self.assertRaises(SystemExit): tls_edge.parse_args(EDGE_ARGS)
        self.assertEqual(config["origin"], "http://kssolv-k8s.localhost:18130")
        self.assertEqual(config["tenant_domain"], "kssolv-k8s.localhost")

    def test_invalid_environment_fails_before_deployment(self):
        for environment in ({"KSSOLV_PUBLIC_ORIGIN": ORIGIN + "/online"},
                            {"KSSOLV_PUBLIC_ORIGIN": "http://kssolv.glea.moe"},
                            {"KSSOLV_PUBLIC_ORIGIN": ORIGIN, "KSSOLV_TENANT_DOMAIN": "*.kssolv.glea.moe"}):
            with self.subTest(environment=environment), patch.dict(os.environ, environment, clear=True):
                for parse, arguments in ((deploy.parse_args, DEPLOY_ARGS), (tls_edge.parse_args, EDGE_ARGS)):
                    with patch("sys.stderr"), self.assertRaises(SystemExit): parse(arguments)

    def test_fixed_port_tls_edge_rejects_an_inconsistent_public_port(self):
        with patch.dict(os.environ, {"KSSOLV_PUBLIC_ORIGIN": ORIGIN + ":8443"}, clear=True):
            with patch("sys.stderr"), self.assertRaises(SystemExit): tls_edge.parse_args(EDGE_ARGS)

    def test_native_nginx_render_uses_custom_domain_without_docker_or_key_access(self):
        arguments = ["tls_edge.py", "--render-only", "--no-http-redirect",
                     "--upstream", "192.168.250.11:30088", "--cert", "/secure/full chain.pem",
                     "--key", "/secure/private.key"]
        output = io.StringIO()
        with patch.dict(os.environ, {"KSSOLV_PUBLIC_ORIGIN": ORIGIN}, clear=True), \
                patch("sys.argv", arguments), patch("sys.stdout", output), \
                patch.object(tls_edge.subprocess, "run", side_effect=AssertionError("Must not execute commands")), \
                patch.object(tls_edge, "validate_certificate", side_effect=AssertionError("Must not read TLS files")):
            tls_edge.main()
        nginx = output.getvalue()
        self.assertIn("listen 443 ssl;", nginx)
        self.assertNotIn("listen 80", nginx)
        self.assertIn('ssl_certificate "/secure/full chain.pem";', nginx)
        self.assertIn('ssl_certificate_key "/secure/private.key";', nginx)
        self.assertIn("server 192.168.250.11:30088;", nginx)
        self.assertIn("server_name kssolv.glea.moe ", nginx)


class CustomDomainBrowserTest(unittest.TestCase):
    def test_login_launch_cookie_csp_and_bridge_follow_the_configured_domain(self):
        # A second unrelated domain proves the application has no deployment-specific dependency.
        for origin in (ORIGIN, "https://research.example.org"):
            with self.subTest(origin=origin), tempfile.TemporaryDirectory() as directory:
                with patch.dict(os.environ, {"KSSOLV_PUBLIC_ORIGIN": origin}, clear=True):
                    config = deploy.portal_config(deploy.parse_args(DEPLOY_ARGS))
                portal = Portal(Path(directory), config["origin"], INVITATION, FakeKube(),
                                tenant_domain=config["tenant_domain"])
                backend = Server(("127.0.0.1", 0), portal)
                threading.Thread(target=backend.serve_forever, daemon=True).start()

                def request(path, *, host=portal.authority, data=None, cookie=None, request_origin=origin):
                    connection = http.client.HTTPConnection("127.0.0.1", backend.server_port, timeout=3)
                    headers = {"Host": host}
                    if cookie: headers["Cookie"] = cookie
                    if data is not None:
                        headers.update({"Origin": request_origin, "Content-Type": "application/json"})
                    try:
                        connection.request("POST" if data is not None else "GET", path,
                                           json.dumps(data) if data is not None else None, headers)
                        response = connection.getresponse()
                        return response.status, dict(response.getheaders()), response.read()
                    finally: connection.close()

                try:
                    uid = portal.register("alice", PASSWORD, INVITATION, "test", **RECOVERY)
                    # The Runtime itself is outside this domain/authentication test.
                    portal.entry = lambda uid: (200, b"<html><body>Runtime entry</body></html>")
                    status, headers, _ = request("/_portal/api/login", data={"username": "alice", "password": PASSWORD})
                    self.assertEqual(status, 200)
                    cookie = headers["Set-Cookie"]
                    self.assertTrue(cookie.startswith("__Host-kssolv_hub="))
                    self.assertIn("; Secure", cookie)
                    self.assertNotIn("Domain=", cookie)
                    with portal.kube.changed:
                        self.assertTrue(portal.kube.changed.wait_for(lambda: portal.kube.ready(uid), timeout=3))
                    portal.status(uid)
                    status, _, body = request("/_portal/api/launch", data={}, cookie=cookie.split(";", 1)[0])
                    self.assertEqual(status, 200)
                    target = urlsplit(json.loads(body)["url"])
                    self.assertEqual(target.hostname, "u-" + uid + "." + portal.hostname)
                    self.assertTrue(portal.known_host(target.hostname))
                    self.assertFalse(portal.known_host("other-" + uid + "." + portal.hostname))
                    status, headers, _ = request(target.path + "?" + target.query, host=target.netloc)
                    self.assertEqual(status, 200)
                    self.assertTrue(headers["Set-Cookie"].startswith("__Host-kssolv_tenant="))
                    tenant_cookie = headers["Set-Cookie"].split(";", 1)[0]
                    self.assertEqual(headers["Content-Security-Policy"], "frame-ancestors " + origin)
                    other_host = "u-" + ("b" * 24 if uid != "b" * 24 else "c" * 24) + "." + portal.hostname
                    self.assertEqual(request("/_portal/api/session", host=other_host, cookie=tenant_cookie)[0], 401)
                    _, headers, _ = request("/online")
                    self.assertIn("frame-src https://*." + portal.hostname, headers["Content-Security-Policy"])
                    status, _, body = request("/_portal/bridge.js", host=target.netloc)
                    self.assertEqual(status, 200)
                    self.assertIn(json.dumps(origin).encode(), body)
                    self.assertNotIn(b"gleamoe.com", body)
                    self.assertEqual(request("/online", host="kssolv.gleamoe.com")[0], 400)
                    self.assertEqual(request("/_portal/api/login", data={},
                                             request_origin="https://kssolv.gleamoe.com")[0], 403)
                finally:
                    backend.shutdown(); backend.server_close(); portal.pool.shutdown(wait=True)


if __name__ == "__main__": unittest.main()


class AdminEdgeTest(unittest.TestCase):
    def test_management_route_is_optional_loopback_only_and_limited_to_portal_host(self):
        text=tls_edge.edge_config('cloud.example.org','worker:30088',False,admin_upstream='127.0.0.1:8095')
        self.assertIn('location ^~ /online/admin/',text)
        self.assertIn('location = /online/admin {',text)
        self.assertIn('return 308 /online/admin;',text)
        self.assertIn('if ($host != cloud.example.org)',text)
        self.assertIn('proxy_pass http://127.0.0.1:8095',text)
        self.assertNotIn('/online/admin/',tls_edge.edge_config('cloud.example.org','worker:30088',False))
        with self.assertRaises(ValueError):tls_edge.edge_config('cloud.example.org','worker:30088',False,admin_upstream='0.0.0.0:8095')
