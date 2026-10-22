"""Loopback-only, credential-free model-list failures for Runtime regression."""
import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass  # Never log authorization headers or request URLs.

    def do_GET(self):
        mode = self.path.strip('/').split('/')[0]
        status = {'unauthorized': 401, 'limited': 429}.get(mode, 200)
        if mode == 'slow':
            time.sleep(25)
        if mode == 'invalid':
            body = b'{broken'
        elif mode == 'empty':
            body = b'{"data":[]}'
        else:
            body = json.dumps({'data': [{'id': 'mock-cpu'}, {'id': 'mock-stream'}]}).encode()
        try:
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=18995)
    args = parser.parse_args()
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
