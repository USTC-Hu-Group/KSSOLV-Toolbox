"""Container deployment contract tests; run in Linux with nginx for proxy tests."""

import _docker_paths
from _docker_paths import RUNTIME
import http.client
import base64
import hashlib
from html.parser import HTMLParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import unittest
import sys

from build_image import validate_payload, stage_runtime
from serve import EntryBroker, ProxyProcess, entry_page, keepalive_filter, nginx_config, session_target, prepare_runtime_directories, prepare_process_limits
from http_worker import HTTPWorker


class DeploymentTests(unittest.TestCase):
    def test_image_context_uses_only_the_canonical_production_runtime_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            stage_runtime(directory)
            destination = Path(directory) / 'runtime'
            self.assertEqual({item.name for item in destination.iterdir()},
                             {'serve.py', 'http_worker.py', 'resource_usage.py'})
            for file in destination.iterdir():
                self.assertEqual(file.read_bytes(), (RUNTIME / file.name).read_bytes())

    def test_runtime_descriptor_limit_is_bounded_in_child(self):
        result = subprocess.check_output([sys.executable, '-c',
            'import json; from serve import prepare_process_limits; '
            'print(json.dumps(prepare_process_limits()))'],
            cwd=RUNTIME, text=True)
        soft, hard = json.loads(result)
        self.assertGreater(soft, 0)
        self.assertLessEqual(soft, hard)
        self.assertLessEqual(hard, 65536)

    def test_runtime_preserves_stricter_descriptor_limits(self):
        result = subprocess.check_output([sys.executable, '-c',
            'import json, resource; from serve import prepare_process_limits; '
            'resource.setrlimit(resource.RLIMIT_NOFILE, (128, 256)); '
            'print(json.dumps(prepare_process_limits()))'],
            cwd=RUNTIME, text=True)
        self.assertEqual(json.loads(result), [128, 256])

    def test_fresh_volume_creates_private_runtime_directories_before_chdir(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            environment = {name: str(root / name.lower()) for name in
                           ('HOME', 'MATLAB_PREFDIR', 'MCR_CACHE_ROOT')}
            work = root / 'work'
            self.assertEqual(prepare_runtime_directories(environment, work), work)
            for path in [Path(value) for value in environment.values()] + [work]:
                self.assertTrue(path.is_dir())
                self.assertEqual(path.stat().st_mode & 0o777, 0o700)
                (path / 'canary').write_text('writable')
            # Existing saved data survives subsequent starts.
            prepare_runtime_directories(environment, work)
            self.assertEqual((work / 'canary').read_text(), 'writable')

    def test_invalid_work_volume_fails_before_runtime_starts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            environment = {name: str(root / name.lower()) for name in
                           ('HOME', 'MATLAB_PREFDIR', 'MCR_CACHE_ROOT')}
            work = root / 'work'
            work.write_text('not a directory')
            with self.assertRaises(FileExistsError):
                prepare_runtime_directories(environment, work)

    def test_unrecognized_runtime_close_protocol_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bundle = root / 'mcr/toolbox/matlab/appcontainer/web/release/bundle.index.js'
            bundle.parent.mkdir(parents=True)
            bundle.write_text('unknown future protocol')
            with self.assertRaises(ValueError):
                keepalive_filter(root)

    def test_entry_requests_fresh_nonce_and_times_out_without_runtime(self):
        with tempfile.TemporaryDirectory() as directory:
            session = Path(directory) / 'session.json'
            session.write_text(json.dumps({'protocol': 1, 'url': 'http://localhost:1234/old'}))
            broker = EntryBroker(session, timeout=0.15)
            with self.assertRaises(TimeoutError):
                broker()
            self.assertFalse(session.with_suffix('.json.request').exists())

            def runtime():
                request = session.with_suffix('.json.request')
                deadline = time.monotonic() + 2
                while not request.exists() and time.monotonic() < deadline:
                    time.sleep(0.01)
                data = {'protocol': 1, 'url': 'http://localhost:1234/fresh?snc=new',
                        'request_id': request.read_text()}
                temporary = session.with_suffix('.new')
                temporary.write_text(json.dumps(data))
                temporary.replace(session)
                request.unlink()
            thread = threading.Thread(target=runtime)
            thread.start()
            self.assertIn('/fresh?snc=new', EntryBroker(session)())
            thread.join()

    def test_rejects_nonlocal_or_injected_session(self):
        for url in ("http://example.com:8000/app", "file:///tmp/app", "http://localhost/app",
                    "http://localhost:8000/\n}", "http://localhost:8000/$uri",
                    'http://localhost:8000/";', "http://user@localhost:8000/app"):
            with self.subTest(url=url), self.assertRaises(ValueError):
                session_target({"protocol": 1, "url": url})

    def test_rejects_macos_and_jvm_payloads(self):
        with tempfile.TemporaryDirectory() as directory:
            payload = Path(directory)
            metadata = {"RuntimeRelease": "R2026b", "Architecture": "maca64", "JVMEnabled": False}
            manifest = payload / "runtime-metadata.json"
            manifest.write_text(json.dumps(metadata))
            with self.assertRaises(ValueError):
                validate_payload(payload)
            metadata.update(Architecture="glnxa64", JVMEnabled=True)
            manifest.write_text(json.dumps(metadata))
            with self.assertRaises(ValueError):
                validate_payload(payload)
            metadata["JVMEnabled"] = False
            manifest.write_text(json.dumps(metadata))
            (payload / "KSSOLV_Toolbox").write_bytes(b"not an ELF")
            with self.assertRaises(ValueError):
                validate_payload(payload)

    def test_accepts_linux_payload_and_rejects_pre_jre_free_release(self):
        with tempfile.TemporaryDirectory() as directory:
            payload = Path(directory)
            metadata = {"RuntimeRelease": "R2026b", "Architecture": "glnxa64", "JVMEnabled": False}
            manifest = payload / "runtime-metadata.json"
            manifest.write_text(json.dumps(metadata))
            header = b"\x7fELF\x02\x01" + bytes(12) + b"\x3e\x00"
            (payload / "KSSOLV_Toolbox").write_bytes(header)
            (payload / "run_KSSOLV_Toolbox.sh").write_text("#!/bin/sh\n")
            self.assertEqual(validate_payload(payload), "R2026b")
            metadata["RuntimeRelease"] = "R2025a"
            manifest.write_text(json.dumps(metadata))
            with self.assertRaises(ValueError):
                validate_payload(payload)

    @unittest.skipUnless(shutil.which("nginx"), "requires nginx (run in Docker)")
    def test_clean_entry_cookie_download_and_websocket_proxy(self):
        release = threading.Event()
        close_event = 'c.publish(v.getMessageChannel(this._messageServiceChannelId),{type:"terminated"})'
        class Frames(HTMLParser):
            def __init__(self):
                super().__init__()
                self.frames = []

            def handle_starttag(self, tag, attrs):
                if tag == "iframe":
                    self.frames.append(dict(attrs))

        class Backend(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == '/AppContainerWebPath/release/bundle.index.js':
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/javascript')
                    self.end_headers()
                    self.wfile.write(('before();' + close_event + ';cleanup();').encode())
                    return
                if self.headers.get("Upgrade", "").lower() == "websocket":
                    self.send_response(101)
                    self.send_header("Upgrade", "websocket")
                    self.send_header("Connection", "Upgrade")
                    self.end_headers()
                    self.wfile.write(b"\x81\x02ok")
                    self.wfile.flush()
                    if self.path == '/held-websocket':
                        release.wait(10)
                    return
                self.send_response(200)
                self.send_header("Set-Cookie", "session=test; Path=/; HttpOnly; Secure")
                if self.path.startswith("/download/static/"):
                    self.send_header("Content-Disposition", 'attachment; filename="download.bin"')
                self.end_headers()
                self.wfile.write(json.dumps({"path": self.path, "host": self.headers["Host"],
                                             "cookie": self.headers.get("Cookie"),
                                             "origin": self.headers.get("Origin")}).encode())

            def log_message(self, *args):
                pass

        backend = ThreadingHTTPServer(("127.0.0.1", 0), Backend)
        threading.Thread(target=backend.serve_forever, daemon=True).start()
        port = backend.server_port
        target = "/app?snc=test&channel=one&label=<test>'"
        data = {"protocol": 1, "url": f"http://127.0.0.1:{port}{target}"}
        folder = Path("/tmp/kssolv")
        folder.mkdir(parents=True, exist_ok=True)
        config = folder / "test-nginx.conf"
        worker = HTTPWorker(entry=lambda: entry_page(data)).start()
        password = 'disposable-validation-password'
        authorization = 'Basic ' + base64.b64encode(('tenant-a:' + password).encode()).decode()
        class AuthenticatedConnection(http.client.HTTPConnection):
            def request(self, method, url, body=None, headers={}, **kwargs):
                super().request(method, url, body, dict(headers, Authorization=authorization), **kwargs)
        salt = b'disposable-test-salt'
        password_file = folder / 'test-passwords'
        password_file.write_text('tenant-a:{SSHA}' + base64.b64encode(
            hashlib.sha1(password.encode() + salt).digest() + salt).decode() + '\n')
        config.write_text(nginx_config(data, worker, password_file,
                         [(close_event, close_event.replace('"terminated"', '"kssolvClientDetached"'))]))
        proxy = ProxyProcess(config)
        proxy.check()
        try:
            deadline = time.monotonic() + 5
            while True:
                try:
                    with socket.create_connection(("127.0.0.1", 8080), timeout=0.2):
                        break
                except OSError:
                    if time.monotonic() > deadline:
                        self.fail("nginx did not start")
                    time.sleep(0.05)
            anonymous = http.client.HTTPConnection('127.0.0.1', 8080, timeout=3)
            for route in ('/online', '/app?snc=test', '/download/static/a/b/file', '/websocket'):
                anonymous.request('GET', route, headers={'Upgrade': 'websocket', 'Connection': 'Upgrade'} if route == '/websocket' else {})
                response = anonymous.getresponse()
                self.assertEqual(response.status, 401)
                response.read()
            anonymous.request('GET', '/online', headers={'Authorization': 'Basic ' + base64.b64encode(b'tenant-b:other-instance-password').decode()})
            response = anonymous.getresponse()
            self.assertEqual(response.status, 401)
            response.read()
            anonymous.close()
            connection = AuthenticatedConnection("127.0.0.1", 8080, timeout=3)
            connection.request('GET', '/AppContainerWebPath/release/bundle.index.js')
            response = connection.getresponse()
            patched = response.read().decode()
            self.assertIn('"kssolvClientDetached"', patched)
            self.assertNotIn('"terminated"', patched)
            self.assertTrue(patched.endswith(';cleanup();'))
            for entry in ("/", "/online", "/online/"):
                with self.subTest(entry=entry):
                    connection.request("GET", entry)
                    response = connection.getresponse()
                    self.assertEqual(response.status, 200)
                    self.assertIsNone(response.getheader("Location"))
                    self.assertEqual(response.getheader("Content-Type"), "text/html; charset=utf-8")
                    self.assertEqual(response.getheader("Cache-Control"), "no-store")
                    self.assertEqual(response.getheader("Referrer-Policy"), "no-referrer")
                    page = response.read().decode()
                    self.assertIn("<title>KSSOLV Toolbox Online</title>", page)
                    self.assertIn("&amp;channel=one", page)
                    self.assertIn("&lt;test&gt;&#x27;", page)
                    frames = Frames()
                    frames.feed(page)
                    self.assertEqual(len(frames.frames), 1)
                    self.assertEqual(frames.frames[0]["src"], target)
                    self.assertEqual(frames.frames[0]["allow"], "fullscreen")
                    self.assertNotIn("sandbox", frames.frames[0])
            connection.request("GET", "/app?snc=test", headers={"Cookie": "session=test", "Origin": "http://127.0.0.1:8080"})
            response = connection.getresponse()
            self.assertIn("HttpOnly; Secure", response.getheader("Set-Cookie"))
            body = json.loads(response.read())
            self.assertEqual(body, {"path": "/app?snc=test", "host": f"localhost:{port}",
                                    "cookie": "session=test", "origin": f"http://localhost:{port}"})
            connection.request("GET", "/app", headers={"Origin": "https://untrusted.example"})
            response = connection.getresponse()
            self.assertEqual(json.loads(response.read())["origin"], "https://untrusted.example")
            encoded_name = "%E7%A1%85%20%231%25%3F.cif"
            connection.request("GET", "/download/static/token/route/download.bin?snc=test&csrfToken=csrf&kssolv_filename=" + encoded_name)
            response = connection.getresponse()
            self.assertEqual(response.getheader("Content-Disposition"), "attachment; filename*=UTF-8''" + encoded_name)
            self.assertEqual(len([key for key, _ in response.getheaders() if key.lower() == "content-disposition"]), 1)
            self.assertEqual(json.loads(response.read())["path"], "/download/static/token/route/download.bin?snc=test&csrfToken=csrf")
            for invalid_name in ("../secret", "bad%0d%0aHeader", "bad%2fname", "bad%5cname", "..", "%zz"):
                connection.request("GET", "/download/static/token/route/download.bin?snc=test&csrfToken=csrf&kssolv_filename=" + invalid_name)
                response = connection.getresponse()
                self.assertEqual(response.getheader("Content-Disposition"), 'attachment; filename="download.bin"')
                response.read()
            connection.close()
            # Exercise upgrade and bytes through nginx, not just configuration text.
            with socket.create_connection(("127.0.0.1", 8080), timeout=3) as client:
                client.sendall(("GET /websocket HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nAuthorization: " + authorization + "\r\n\r\n").encode())
                received = b""
                while b"\x81\x02ok" not in received:
                    chunk = client.recv(4096)
                    if not chunk:
                        break
                    received += chunk
                self.assertIn(b"101 Switching Protocols", received)
                self.assertIn(b"\x81\x02ok", received)
            # A live client blocks a second entry before it can rotate nonces
            # or reach the Runtime's single-client assertion.
            with socket.create_connection(("127.0.0.1", 8080), timeout=3) as client:
                client.sendall(("GET /held-websocket HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nAuthorization: " + authorization + "\r\n\r\n").encode())
                received = b''
                while b'\x81\x02ok' not in received:
                    received += client.recv(4096)
                second = AuthenticatedConnection('127.0.0.1', 8080, timeout=3)
                second.request('GET', '/online')
                response = second.getresponse()
                self.assertEqual(response.status, 409)
                response.read()
                second.request('GET', '/healthz')
                response = second.getresponse()
                self.assertEqual(response.status, 200)
                response.read()
                second.close()
                # A crash with an active WebSocket must not permanently leave
                # the shared connection count occupied after proxy recovery.
                previous = proxy.process.pid
                proxy.process.kill()
                proxy.process.wait(timeout=3)
                proxy.check()
                self.assertNotEqual(proxy.process.pid, previous)
                deadline = time.monotonic() + 3
                while True:
                    recovered = AuthenticatedConnection('127.0.0.1', 8080, timeout=1)
                    try:
                        recovered.request('GET', '/online')
                        response = recovered.getresponse()
                        self.assertEqual(response.status, 200)
                        response.read()
                        break
                    except (ConnectionError, OSError):
                        if time.monotonic() >= deadline:
                            raise
                        time.sleep(0.05)
                    finally:
                        recovered.close()
        finally:
            release.set()
            proxy.process.terminate()
            proxy.process.wait(timeout=5)
            backend.shutdown()
            backend.server_close()
            worker.close()
            password_file.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
