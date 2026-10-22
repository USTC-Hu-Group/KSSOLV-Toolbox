"""Run inside the portal image with a read-only root to validate real nginx."""

import _k8s_paths
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import re
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

from test_portal import FakeKube, INVITATION, ORIGIN, PASSWORD
from portal import Portal, Server, gateway_config
from tls_edge import edge_config


@unittest.skipUnless(shutil.which("nginx"), "Run in the portal image for real nginx verification")
class GatewayTest(unittest.TestCase):
    def test_real_edge_overwrites_forged_headers_and_preserves_distinct_client_ips(self):
        with tempfile.TemporaryDirectory() as directory:
            portal = Portal(Path(directory)/'data', ORIGIN, INVITATION, FakeKube())
            backend = Server(('127.0.0.1', 0), portal)
            threading.Thread(target=backend.serve_forever, daemon=True).start()
            reservations = [socket.socket(), socket.socket()]
            for reservation in reservations:
                reservation.bind(('127.0.0.1', 0))
            gateway_port, edge_port = [reservation.getsockname()[1] for reservation in reservations]
            source = gateway_config(portal, backend.proxy_token, '127.0.0.1', ['127.0.0.1/32'])
            source = source.replace('listen 8080;', f'listen {gateway_port};')
            source = source.replace('127.0.0.1:8091', f'127.0.0.1:{backend.server_port}')
            source = source.replace('/tmp/', directory + '/')
            # Run the public edge's actual generated HTTP proxy directives,
            # without TLS, so this test needs no certificate or external DNS.
            edge = edge_config('online.example.org', 'worker:30088', False)
            directives = re.search(r'location / \{\n(.*?)\n        \}', edge, re.S).group(1)
            directives = directives.replace('http://cluster_portal', f'http://127.0.0.1:{gateway_port}')
            source = source.rsplit('\n}', 1)[0] + f'\nserver {{ listen {edge_port}; location / {{\n{directives}\n}} }}\n}}\n'
            config = Path(directory)/'nginx.conf'
            config.write_text(source)
            subprocess.run(['nginx', '-t', '-c', str(config)], check=True, capture_output=True)
            for reservation in reservations:
                reservation.close()
            process = subprocess.Popen(['nginx', '-c', str(config), '-g', 'daemon off;'], stderr=subprocess.PIPE)
            try:
                deadline = time.monotonic() + 5
                while True:
                    try:
                        with socket.create_connection(('127.0.0.1', edge_port), timeout=1):
                            break
                    except ConnectionRefusedError:
                        if time.monotonic() > deadline:
                            raise
                        time.sleep(.05)
                for client_ip in ('127.0.0.2', '127.0.0.3'):
                    with socket.socket() as probe:
                        try: probe.bind((client_ip, 0))
                        except OSError: self.skipTest('Distinct loopback addresses require Linux')
                    connection = http.client.HTTPConnection('127.0.0.1', edge_port, timeout=3,
                                                            source_address=(client_ip, 0))
                    try:
                        with patch.object(portal, 'login', return_value='test-token') as login:
                            connection.request('POST', '/_portal/api/login', '{}', {
                                'Host': portal.authority, 'Origin': ORIGIN, 'Content-Type': 'application/json',
                                'X-Forwarded-For': '198.51.100.1', 'X-Real-IP': '198.51.100.2',
                                'X-KSSOLV-Client-IP': '198.51.100.3', 'X-KSSOLV-Proxy-Token': 'forged'})
                            response = connection.getresponse()
                            self.assertEqual(response.status, 200, response.read())
                            self.assertEqual(login.call_args.args[2], client_ip)
                    finally:
                        connection.close()
            finally:
                process.terminate()
                _, errors = process.communicate(timeout=5)
                backend.shutdown()
                backend.server_close()
                portal.pool.shutdown(wait=True)
                self.assertNotIn(b'[emerg]', errors)

    def test_read_only_nginx_startup_portal_origin_and_internal_route(self):
        with tempfile.TemporaryDirectory() as directory:
            portal = Portal(Path(directory)/"data", ORIGIN, INVITATION, FakeKube())
            backend = Server(("127.0.0.1",0),portal)
            threading.Thread(target=backend.serve_forever,daemon=True).start()
            class RuntimeHandler(BaseHTTPRequestHandler):
                def log_message(self,*args): pass
                def do_GET(self):
                    body=b'<html><head></head><body>Runtime</body></html>'
                    self.send_response(200)
                    self.send_header('Content-Type','text/html')
                    self.send_header('Content-Length',str(len(body)))
                    self.send_header('X-Frame-Options','sameorigin')
                    self.send_header('Content-Security-Policy',"default-src 'self'; frame-ancestors 'self' *.mathworks.com; script-src 'self'")
                    self.end_headers(); self.wfile.write(body)
            runtime=ThreadingHTTPServer(('127.0.0.1',0),RuntimeHandler)
            threading.Thread(target=runtime.serve_forever,daemon=True).start()
            with socket.socket() as reservation:
                reservation.bind(("127.0.0.1",0)); port=reservation.getsockname()[1]
            source = gateway_config(portal, backend.proxy_token, '127.0.0.1')
            source = source.replace("listen 8080;",f"listen {port};")
            source = source.replace("127.0.0.1:8091",f"127.0.0.1:{backend.server_port}")
            source = source.replace("/tmp/",directory+"/")
            manual_dir=Path(directory)/'manuals';manual_dir.mkdir()
            pdf=b'%PDF-1.3\nmanual static byte range fixture\n%%EOF\n'
            for locale in ['zh-CN','en-US']:
                (manual_dir/(locale+'.pdf')).write_bytes(pdf)
            source=source.replace('/opt/kssolv/portal/manuals/',str(manual_dir)+'/')
            source=source.replace('proxy_pass http://$runtime;',f'proxy_pass http://127.0.0.1:{runtime.server_port};')
            config=Path(directory)/"nginx.conf"; config.write_text(source)
            subprocess.run(["nginx","-t","-c",str(config)],check=True,capture_output=True)
            process=subprocess.Popen(["nginx","-c",str(config),"-g","daemon off;"],stderr=subprocess.PIPE)
            last_headers=[]
            def request(path,host="kssolv-k8s.localhost:18130",origin=None,cookie=None,method=None,extra=None):
                connection=http.client.HTTPConnection("127.0.0.1",port,timeout=3)
                headers={"Host":host}
                if origin: headers.update(Origin=origin,**{"Content-Type":"application/json"})
                if cookie: headers['Cookie']=cookie
                headers.update(extra or {})
                connection.request(method or ("POST" if origin else "GET"),path,body='{}' if origin else None,headers=headers)
                response=connection.getresponse(); last_headers[:]=response.getheaders(); body=response.read(); connection.close()
                return response.status,body
            try:
                deadline=time.monotonic()+5
                while True:
                    try: result=request("/healthz"); break
                    except ConnectionRefusedError:
                        if time.monotonic()>deadline: raise
                        time.sleep(.05)
                self.assertEqual(result[0],200)
                for locale in ['zh-CN','en-US']:
                    path='/online/docs/'+locale+'.pdf'
                    status,body=request(path)
                    self.assertEqual((status,body),(200,pdf))
                    headers=dict((k.lower(),v) for k,v in last_headers)
                    self.assertEqual(headers['content-type'],'application/pdf')
                    self.assertTrue(headers['content-disposition'].startswith('inline;'))
                    self.assertEqual(headers['cache-control'],'no-cache')
                    self.assertEqual(headers['x-content-type-options'],'nosniff')
                    etag=headers['etag']
                    self.assertEqual(request(path,method='HEAD'),(200,b''))
                    self.assertEqual(request(path,extra={'Range':'bytes=0-7'}),(206,pdf[:8]))
                    self.assertEqual(request(path,extra={'If-None-Match':etag}), (304,b''))
                    self.assertEqual(request(path,host='u-'+'a'*24+'.kssolv-k8s.localhost')[0],200)
                # Each language falls back independently; the other PDF remains local.
                (manual_dir/'zh-CN.pdf').unlink()
                self.assertEqual(request('/online/docs/zh-CN.pdf')[0],302)
                headers=dict((k.lower(),v) for k,v in last_headers)
                latest='https://github.com/USTC-Hu-Group/KSSOLV-Toolbox-Manual/releases/latest/download/'
                self.assertEqual(headers['location'],latest+'KSSOLV_Toolbox_User_Manual_zh-CN.pdf')
                self.assertEqual(headers['cache-control'],'no-store')
                self.assertEqual(request('/online/docs/en-US.pdf'),(200,pdf))
                (manual_dir/'en-US.pdf').unlink()
                self.assertEqual(request('/online/docs/en-US.pdf',method='HEAD')[0],302)
                headers=dict((k.lower(),v) for k,v in last_headers)
                self.assertEqual(headers['location'],latest+'KSSOLV_Toolbox_User_Manual_en.pdf')
                self.assertEqual(headers['cache-control'],'no-store')
                status,body=request("/_portal/"); self.assertEqual(status,200)
                self.assertIn(b'KSSOLV Toolbox',body)
                status,body=request('/online'); self.assertEqual(status,200)
                self.assertIn(b'id="tenant-workspace"',body)
                self.assertEqual(request("/_auth")[0],404)
                self.assertEqual(request("/_portal/api/login",origin="https://evil.invalid")[0],403)
                with patch.object(portal, 'login', return_value='test-token') as login:
                    self.assertEqual(request('/_portal/api/login', origin=ORIGIN, extra={
                        'X-Forwarded-For': '198.51.100.10', 'X-Real-IP': '198.51.100.20',
                        'X-KSSOLV-Client-IP': '198.51.100.30',
                        'X-KSSOLV-Proxy-Token': 'forged'})[0], 200)
                    self.assertEqual(login.call_args.args[2], '127.0.0.1')
                self.assertEqual(request("/online",host="u-"+"a"*24+".kssolv-k8s.localhost:18130")[0],401)
                uid=portal.register('alice',PASSWORD,INVITATION,'test', password_confirmation=PASSWORD,
                                    recovery_question='My private test question?', recovery_answer='test-only-answer');portal.start(uid)
                with portal.kube.changed: self.assertTrue(portal.kube.changed.wait_for(lambda:portal.kube.ready(uid),timeout=3))
                portal.status(uid);host=portal.host(uid);token=portal.new_session(uid,'tenant',host)
                status,body=request('/toolbox/app.html',host=host,cookie='kssolv_tenant='+token)
                self.assertEqual(status,200)
                policies=[v for k,v in last_headers if k.lower()=='content-security-policy']
                self.assertEqual(len(policies),1)
                self.assertIn("default-src 'self'",policies[0]);self.assertIn("script-src 'self'",policies[0])
                self.assertIn('frame-ancestors '+ORIGIN+" 'self'",policies[0])
                self.assertNotIn('*.mathworks.com',policies[0])
                self.assertFalse(any(k.lower()=='x-frame-options' for k,v in last_headers))
                self.assertIn(b'/_portal/bridge.js',body)
            finally:
                process.terminate(); _,error=process.communicate(timeout=5)
                backend.shutdown(); backend.server_close(); runtime.shutdown();runtime.server_close();portal.pool.shutdown(wait=True)
                self.assertNotIn(b'[emerg]',error)


if __name__=="__main__": unittest.main()
