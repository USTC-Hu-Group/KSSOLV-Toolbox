"""Loopback Chat Completions fixture; records synthetic requests only."""
import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    calls = []

    def log_message(self, *_):
        pass

    def do_GET(self):
        body = json.dumps({'calls': self.calls}).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        self.calls.append({'path': self.path, 'model': data['model'],
                           'messages': data['messages'], 'stream': data.get('stream', False),
                           'tools': bool(data.get('tools'))})
        messages = data['messages']
        prompt = messages[-1]['content']
        if prompt in ('reject tools', 'reject tools 422') and data.get('tools'):
            self.error_reply(422 if prompt.endswith('422') else 400, 'tools are not supported')
            return
        if prompt == 'invalid tools':
            self.error_reply(400, 'tools contain an invalid function schema')
            return
        if prompt == 'limited':
            self.error_reply(429, 'tools are not supported')
            return
        if prompt == 'unauthorized':
            self.error_reply(401, 'fixture-provider-key')
            return
        if prompt == 'slow first token':
            time.sleep(3)
        if messages[-1]['content'] == 'use fixture tool':
            delta = {'tool_calls': [{'index': 0, 'id': 'fixture-call', 'type': 'function',
                      'function': {'name': 'getCurrentGraph', 'arguments': '{}'}}]}
            finish = 'tool_calls'
        else:
            delta = {'content': '{"answer":42}' if prompt == 'JSON reply' else 'reply from ' + data['model']}
            finish = 'stop'
        chunks = [{'model': data['model'], 'choices': [{'index': 0, 'delta': delta,
                   'finish_reason': None}]}, {'model': data['model'], 'choices': [
                  {'index': 0, 'delta': {}, 'finish_reason': finish}]}]
        if prompt == 'truncated':
            chunks = chunks[:1]
        body = ''.join('data: ' + json.dumps(c) + '\n\n' for c in chunks).encode() + (b'' if prompt == 'truncated' else b'data: [DONE]\n\n')
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def error_reply(self, status, message):
        body = json.dumps({'error': {'message': message}}).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=18996)
    args = parser.parse_args()
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
