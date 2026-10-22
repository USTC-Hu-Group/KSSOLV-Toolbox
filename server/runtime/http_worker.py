"""Authenticated loopback HTTP jobs for JVM-free Runtime callbacks.

Uses only Python's standard library, already required by the supervisor.
Credentials stay in memory, never in command lines, URLs, files or logs.
"""
import hmac
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import secrets
import socket
import ssl
import threading
import time
from urllib.parse import urlsplit


class Job:
    def __init__(self):
        self.created = time.monotonic()
        self.cancelled = threading.Event()
        self.connection = None
        self.result = {'state': 'running'}

    def snapshot(self):
        return self.result

    def cancel(self):
        self.cancelled.set()
        connection = self.connection
        if connection is not None:
            try:
                if connection.sock:
                    connection.sock.shutdown(socket.SHUT_RDWR)
                connection.close()
            except OSError:
                pass

    def run(self, url, headers):
        connection = None
        try:
            target = urlsplit(url)
            if target.scheme not in ('http', 'https') or not target.hostname or target.username or target.password or target.fragment:
                raise ValueError('Invalid target')
            factory = http.client.HTTPSConnection if target.scheme == 'https' else http.client.HTTPConnection
            connection = factory(target.hostname, target.port, timeout=10)
            self.connection = connection
            if self.cancelled.is_set():
                return
            connection.connect()
            if self.cancelled.is_set():
                return
            path = (target.path or '/') + ('?' + target.query if target.query else '')
            headers.setdefault('User-Agent', 'KSSOLV-Toolbox')
            connection.request('GET', path, headers=headers)
            response = connection.getresponse()
            if response.status != 200:
                self.result = {'state': 'finished', 'error': {'kind': 'http', 'status': response.status}}
                return  # Never return an error body which could echo secrets.
            body = response.read(1024 * 1024 + 1)
            if len(body) > 1024 * 1024:
                raise ValueError('Response too large')
            data = json.loads(body)
            if not isinstance(data, dict):
                raise ValueError('Expected object')
            self.result = {'state': 'finished', 'response': data}
        except (TimeoutError, socket.timeout):
            self.result = {'state': 'finished', 'error': {'kind': 'timeout'}}
        except ssl.SSLError:
            self.result = {'state': 'finished', 'error': {'kind': 'tls'}}
        except (ValueError, UnicodeError):
            self.result = {'state': 'finished', 'error': {'kind': 'json'}}
        except (OSError, http.client.HTTPException):
            self.result = {'state': 'finished', 'error': {'kind': 'connection'}}
        finally:
            headers.clear()
            if connection:
                connection.close()
            self.connection = None


class ChatJob(Job):
    """Stream on a worker thread so MATLAB can service UI events while polling."""
    def __init__(self):
        super().__init__()
        self.lock = threading.Lock()
        self.tokens = []

    def snapshot(self):
        with self.lock:
            reply = dict(self.result, tokens=self.tokens)
            self.tokens = []
            return reply

    def run(self, url, headers, parameters):
        connection = None
        try:
            target = urlsplit(url)
            if target.scheme not in ('http', 'https') or not target.hostname or target.username or target.password or target.fragment:
                raise ValueError('Invalid target')
            factory = http.client.HTTPSConnection if target.scheme == 'https' else http.client.HTTPConnection
            path = (target.path or '/') + ('?' + target.query if target.query else '')
            headers = dict(headers, **{'Content-Type': 'application/json'})
            # Retry only an explicit rejection of the optional tools parameter,
            # before any successful stream. Never retry authentication or a
            # partial response, and never change endpoint/model/credential.
            for attempt in range(2):
                connection = factory(target.hostname, target.port, timeout=10)
                self.connection = connection
                if self.cancelled.is_set():
                    return
                connection.connect()
                if self.cancelled.is_set():
                    return
                connection.sock.settimeout(30)
                connection.request('POST', path, body=json.dumps(parameters).encode(), headers=headers)
                response = connection.getresponse()
                if response.status == 200:
                    break
                error_body = response.read(65536).decode('utf-8', errors='replace').lower()
                unsupported = ('tool' in error_body and any(word in error_body for word in
                               ('unsupported', 'not support', 'not allowed', 'unknown parameter', 'unrecognized')))
                if attempt == 0 and response.status in (400, 422) and parameters.get('tools') and unsupported:
                    parameters = {k: v for k, v in parameters.items() if k not in ('tools', 'tool_choice')}
                    connection.close()
                    continue
                self.result = {'state': 'finished', 'error': {'kind': 'http', 'status': response.status}}
                return
            content, tools, model, size = [], {}, '', 0
            complete = False
            deadline = time.monotonic() + 180
            while not self.cancelled.is_set() and time.monotonic() < deadline:
                line = response.readline(262145)
                size += len(line)
                if len(line) > 262144 or size > 16 * 1024 * 1024:
                    raise ValueError('Response too large')
                if not line:
                    break
                if not line.startswith(b'data:'):
                    continue
                payload = line[5:].strip()
                if payload == b'[DONE]':
                    complete = True
                    break
                event = json.loads(payload)
                if event.get('error'):
                    raise ValueError('Provider stream error')
                model = event.get('model', model)
                for choice in event.get('choices', []):
                    delta = choice.get('delta', {})
                    text = delta.get('content') or ''
                    if text:
                        content.append(text)
                        with self.lock:
                            self.tokens.append(text)
                    for call in delta.get('tool_calls') or []:
                        item = tools.setdefault(call.get('index', 0), {'id': '', 'type': 'function',
                                                'function': {'name': '', 'arguments': ''}})
                        for key in ('id', 'type'):
                            if call.get(key):
                                item[key] = call[key]
                        for key in ('name', 'arguments'):
                            item['function'][key] += call.get('function', {}).get(key) or ''
                    reason = choice.get('finish_reason')
                    if reason:
                        if reason not in ('stop', 'tool_calls', 'function_call'):
                            self.result = {'state': 'finished', 'error': {'kind': 'incomplete'}}
                            return
                        complete = True
                if complete:
                    break
            if not complete or self.cancelled.is_set():
                self.result = {'state': 'finished', 'error': {'kind': 'incomplete'}}
                return
            message = {'role': 'assistant', 'content': ''.join(content)}
            if tools:
                message['tool_calls'] = [tools[index] for index in sorted(tools)]
            self.result = {'state': 'finished', 'response': {'model': model, 'choices': [{'message': message}]}}
        except (TimeoutError, socket.timeout):
            self.result = {'state': 'finished', 'error': {'kind': 'timeout'}}
        except ssl.SSLError:
            self.result = {'state': 'finished', 'error': {'kind': 'tls'}}
        except (ValueError, UnicodeError, TypeError, AttributeError):
            self.result = {'state': 'finished', 'error': {'kind': 'json'}}
        except (OSError, http.client.HTTPException):
            self.result = {'state': 'finished', 'error': {'kind': 'connection'}}
        finally:
            headers.clear()
            parameters.clear()
            if connection:
                connection.close()
            self.connection = None


class Workspace:
    """Resolve only the current Runtime's explicitly mounted working directory."""
    def __init__(self, root):
        if Path(root).is_symlink():
            raise ValueError('The workspace root must be a real directory.')
        self.root = Path(root).resolve(strict=True)

    def resolve(self, relative, writable=False):
        if (not isinstance(relative, str) or len(relative) > 4096 or
                '\\' in relative or any(ord(char) < 32 for char in relative)):
            raise ValueError('Invalid workspace path.')
        path = Path(relative)
        if path.is_absolute() or '..' in path.parts:
            raise ValueError('The path must stay inside Files.')
        target = (self.root / path).resolve(strict=not writable)
        if not target.is_relative_to(self.root):
            raise ValueError('The path must stay inside Files.')
        if writable and not target.parent.is_dir():
            raise ValueError('The destination folder does not exist.')
        return target

    def request(self, data):
        action = data.get('action')
        target = self.resolve(data.get('path', ''), data.get('writable') is True)
        if action == 'resolve':
            if data.get('writable') is True and target.is_dir():
                raise IsADirectoryError('Choose a file name, not an existing folder.')
            return {'path': str(target), 'root': str(self.root)}
        if action == 'mkdir':
            if target == self.root:
                raise ValueError('Choose a new folder name.')
            target.mkdir()
            return {'ok': True}
        if action != 'list' or not target.is_dir():
            raise ValueError('Choose a workspace folder.')
        entries = []
        # Do not enumerate or disclose symlinks outside the user's volume.
        for item in sorted(target.iterdir(), key=lambda item: item.name.casefold()):
            try:
                resolved = self.resolve(item.relative_to(self.root).as_posix())
                info = resolved.stat()
            except (OSError, ValueError, RuntimeError):
                continue
            if not resolved.is_dir() and not resolved.is_file():
                continue
            entries.append({'name': item.name, 'path': item.relative_to(self.root).as_posix(),
                            'isDirectory': resolved.is_dir(), 'bytes': info.st_size})
            if len(entries) >= 1000:
                break
        entries.sort(key=lambda item: (not item['isDirectory'], item['name'].casefold()))
        return {'entries': entries, 'truncated': len(entries) == 1000}


class HTTPWorker(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, port=0, token=None, entry=None, workspace=None, resources=None):
        self.token = token or secrets.token_urlsafe(32)
        self.entry = entry
        self.resources = resources
        self.workspace = Workspace(workspace) if workspace is not None else None
        self.jobs = {}
        self.lock = threading.Lock()
        self.active = 0
        super().__init__(('127.0.0.1', port), Handler)

    def start(self):
        threading.Thread(target=self.serve_forever, daemon=True).start()
        return self

    def close(self):
        with self.lock:
            jobs = list(self.jobs.values())
            self.jobs.clear()
        for job in jobs:
            job.cancel()
        self.shutdown()
        self.server_close()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, status, data):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def authorized(self):
        if not hmac.compare_digest(self.headers.get('Authorization', ''), 'Bearer ' + self.server.token):
            self.reply(403, {'error': 'Forbidden'})
            return False
        return True

    def do_POST(self):
        if not self.authorized():
            return
        if self.path not in ('/requests', '/chat', '/workspace'):
            self.reply(404, {})
            return
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= (2 * 1024 * 1024 if self.path == '/chat' else 16384):
                raise ValueError()
            data = json.loads(self.rfile.read(size))
            if self.path == '/workspace':
                if self.server.workspace is None:
                    self.reply(503, {'error': 'Persistent workspace is unavailable.'})
                    return
                try:
                    self.reply(200, self.server.workspace.request(data))
                except FileExistsError:
                    self.reply(409, {'error': 'A file or folder with this name already exists.'})
                except IsADirectoryError:
                    self.reply(400, {'error': 'A folder with this name already exists. Choose a file name.'})
                except (OSError, ValueError, RuntimeError, TypeError, AttributeError):
                    self.reply(400, {'error': 'The workspace path is unavailable or outside Files.'})
                return
            url, headers = data['url'], data['headers']
            if not isinstance(url, str) or not isinstance(headers, dict):
                raise ValueError()
            chat = self.path == '/chat'
            parameters = data.get('parameters')
            if chat and (not isinstance(parameters, dict) or parameters.get('stream') is not True):
                raise ValueError()
            job = ChatJob() if chat else Job()
            identity = secrets.token_urlsafe(24)
            with self.server.lock:
                for key, old in list(self.server.jobs.items()):
                    if time.monotonic() - old.created > (300 if isinstance(old, ChatJob) else 60):
                        old.cancel()
                        del self.server.jobs[key]
                if self.server.active >= 4 or len(self.server.jobs) >= 16:
                    self.reply(429, {})
                    return
                self.server.active += 1
                self.server.jobs[identity] = job

            def run():
                try:
                    job.run(url, headers, parameters) if chat else job.run(url, headers)
                finally:
                    with self.server.lock:
                        self.server.active -= 1
            threading.Thread(target=run, daemon=True).start()
            self.reply(200, {'id': identity})
        except (ValueError, KeyError, TypeError):
            self.reply(400, {})

    def do_GET(self):
        if not self.authorized():
            return
        if self.path == '/resources' and self.server.resources is not None:
            self.reply(200, self.server.resources.value)
            return
        if self.path == '/entry' and self.server.entry is not None:
            try:
                body = self.server.entry().encode()
                self.send_response(200)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.send_header('Cache-Control', 'no-store')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            except TimeoutError:
                self.reply(503, {'error': 'The session is busy. Please retry shortly.'})
            return
        identity = self.path.removeprefix('/requests/')
        with self.server.lock:
            job = self.server.jobs.get(identity)
            self.reply(200, job.snapshot()) if job else self.reply(404, {})

    def do_DELETE(self):
        if not self.authorized():
            return
        identity = self.path.removeprefix('/requests/')
        with self.server.lock:
            job = self.server.jobs.pop(identity, None)
        if job:
            job.cancel()
        self.reply(200, {})


if __name__ == '__main__':
    import argparse
    import os
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=0)
    args = parser.parse_args()
    server = HTTPWorker(args.port, os.environ['KSSOLV_HTTP_WORKER_TOKEN'])
    server.serve_forever()
