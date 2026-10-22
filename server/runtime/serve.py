"""Supervise one JVM-free KSSOLV session and its loopback-only connector proxy."""
import html
import errno
import json
import os
from pathlib import Path
import re
import signal
import secrets
import socket
import threading
import subprocess
import sys
import resource
import time
from urllib.parse import urlsplit
from urllib.request import urlopen
import xml.etree.ElementTree as ET


def session_target(data):
    url = data.get("url", "")
    parsed = urlsplit(url)
    if (data.get("protocol") != 1 or parsed.scheme not in ("http", "https")
            or parsed.hostname not in ("localhost", "127.0.0.1")
            or not parsed.port or parsed.username or parsed.password or parsed.fragment):
        raise ValueError("Invalid local connector session URL.")
    target = parsed.path + ("?" + parsed.query if parsed.query else "")
    # Quoted nginx values must never accept directives or variable expansion.
    if (not target.startswith("/") or any(char in url for char in '"\\$;{}')
            or any(ord(char) < 32 or ord(char) == 127 for char in url)):
        raise ValueError("Unsafe connector session URL.")
    return parsed.scheme, parsed.port, target


def entry_page(data):
    _, _, target = session_target(data)
    # Keep Connector's session query in a same-origin child frame. Its frontend
    # reads that query during startup, so an internal rewrite alone is not enough.
    page = ('<!doctype html><html lang="en"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>KSSOLV Toolbox Online</title><style>'
            'html,body{width:100%;height:100%;margin:0;overflow:hidden}'
            'iframe{display:block;width:100%;height:100%;border:0}'
            '</style></head><body><iframe id="kssolv-app" '
            'title="KSSOLV Toolbox Online" allow="fullscreen" allowfullscreen '
            'referrerpolicy="no-referrer" src="' + html.escape(target, quote=True)
            + '"></iframe><script>try{sessionStorage.setItem("kssolv-connected","1")}catch{}</script></body></html>')
    return page


class EntryBroker:
    def __init__(self, session, timeout=8):
        self.session = Path(session)
        self.timeout = timeout
        self.lock = threading.Lock()

    def __call__(self):
        with self.lock:
            identity = secrets.token_hex(16)
            request = self.session.with_suffix(self.session.suffix + ".request")
            temporary = request.with_suffix(".pending")
            temporary.write_text(identity)
            temporary.replace(request)
            deadline = time.monotonic() + self.timeout
            try:
                while time.monotonic() < deadline:
                    data = json.loads(self.session.read_text())
                    if data.get("request_id") == identity:
                        return entry_page(data)
                    time.sleep(0.05)
                raise TimeoutError("Runtime entry request timed out")
            finally:
                if request.exists() and request.read_text() == identity:
                    request.unlink(missing_ok=True)


def keepalive_filter(root):
    # AppContainer's browser client publishes "terminated" on pagehide, even
    # on a refresh. Keep its normal client/model cleanup but reserve server
    # termination for explicit application/container shutdown. Validate the
    # shipped protocol before enabling this version-specific compatibility.
    bundle = root / 'mcr/toolbox/matlab/appcontainer/web/release/bundle.index.js'
    substitutions = [
        ('this._unloadListener=()=>this.destroy()',
         'this._unloadListener=()=>{this._kssolvReconnecting=true;this.destroy()}'),
        ('c.publish(v.getMessageChannel(this._messageServiceChannelId),{type:"terminated"})',
         'c.publish(v.getMessageChannel(this._messageServiceChannelId),{type:this._kssolvReconnecting?"kssolvClientDetached":"terminated"})'),
        ('this._rootUIContainer.shutdown(),c.stop()',
         '(this._kssolvReconnecting||this._rootUIContainer.shutdown()),c.stop()'),
    ]
    source = bundle.read_text()
    if any(source.count(original) != 1 for original, _ in substitutions):
        raise ValueError('Unrecognized AppContainer close protocol; review Online reconnect compatibility for this Runtime build.')
    return substitutions


def nginx_config(data, worker=None, auth_file=None, keepalive=None):
    scheme, port, _ = session_target(data)
    auth = ''
    compatibility = ''
    if keepalive:
        compatibility = ('proxy_set_header Accept-Encoding "";\n'
                         'sub_filter_types application/javascript text/javascript;\n'
                         'sub_filter_once on;\n')
        for original, replacement in keepalive:
            compatibility += f"sub_filter '{original}' '{replacement}';\n"
    if auth_file:
        if not re.fullmatch(r'/[a-zA-Z0-9_./-]+', str(auth_file)):
            raise ValueError('Use an absolute authentication file path without special characters.')
        auth = f'auth_basic "KSSOLV Toolbox Online"; auth_basic_user_file {auth_file};'
    page = entry_page(data)
    # HTML escaping protects the attribute; nginx quoting protects its directive.
    page = page.replace('\\', '\\\\').replace('"', '\\"').replace('$', '\\$')
    entry = f'''default_type text/html;
            charset utf-8;
            add_header Cache-Control no-store always;
            add_header Referrer-Policy no-referrer always;
            return 200 "{page}";'''
    if worker is not None:
        entry = f'''proxy_pass http://127.0.0.1:{worker.server_port}/entry;
            proxy_set_header Authorization "Bearer {worker.token}";
            proxy_read_timeout 10s;
            add_header Referrer-Policy no-referrer always;'''
    metrics = ''
    if worker is not None:
        metrics = f'''location = /_kssolv/resources {{
            proxy_pass http://127.0.0.1:{worker.server_port}/resources;
            proxy_set_header Authorization "Bearer {worker.token}";
            proxy_read_timeout 3s;
            add_header Cache-Control no-store always;
        }}'''
    return f'''pid /tmp/kssolv/nginx.pid;
master_process off;
error_log /dev/stderr warn;
worker_processes 1;
events {{ worker_connections 1024; }}
http {{
    access_log off;
    client_body_temp_path /tmp/kssolv/body;
    proxy_temp_path /tmp/kssolv/proxy;
    fastcgi_temp_path /tmp/kssolv/fastcgi;
    uwsgi_temp_path /tmp/kssolv/uwsgi;
    scgi_temp_path /tmp/kssolv/scgi;
    map $http_upgrade $connection_upgrade {{ default upgrade; '' close; }}
    map "$uri:$http_upgrade" $session_connection_key {{
        default "";
        "~*:websocket$" session;
        "~^/(?:online/?)?:$" session;
    }}
    limit_conn_zone $session_connection_key zone=kssolv_session:1m;
    map $arg_kssolv_filename $download_disposition {{
        default $upstream_http_content_disposition;
        "~*^(?=.{{1,1024}}$)(?![.]{{1,2}}$)(?!.*%(?:0[0-9a-f]|1[0-9a-f]|7f|2f|5c|3a))(?:[a-z0-9._~-]|%[0-9a-f]{{2}})*$" "attachment; filename*=UTF-8''$arg_kssolv_filename";
    }}
    map "$http_origin|$http_host" $connector_origin {{
        default $http_origin;
        "~^https?://(?<origin_authority>[^/]+)[|](?P=origin_authority)$" "{scheme}://localhost:{port}";
    }}
    server {{
        listen 8080;
        server_name _;
        absolute_redirect off;
        client_max_body_size 256m;
        {auth}
        limit_conn kssolv_session 1;
        limit_conn_status 409;
        error_page 409 = @session_busy;
        add_header Referrer-Policy no-referrer always;
        {metrics}
        location = /healthz {{ auth_basic off; return 200 "ok\\n"; }}
        location @session_busy {{
            default_type text/html;
            add_header Cache-Control no-store always;
            return 409 '<!doctype html><title>KSSOLV Toolbox Online</title><h1>This session is already open</h1><p>Close its other tab or browser before reconnecting.</p><button type="button" onclick="location.replace(&quot;/online&quot;)">Retry</button><script>try{{if(sessionStorage.getItem("kssolv-connected")==="1"){{sessionStorage.removeItem("kssolv-connected");setTimeout(()=>location.replace("/online"),1000)}}}}catch{{}}</script>';
        }}
        location = / {{ {entry} }}
        location = /online {{ {entry} }}
        location = /online/ {{ {entry} }}
        location ^~ /download/static/ {{
            # Only native authentication parameters reach Connector. The
            # friendly name remains encoded and is used only as a header.
            proxy_pass {scheme}://127.0.0.1:{port}$uri?snc=$arg_snc&csrfToken=$arg_csrftoken;
            proxy_http_version 1.1;
            proxy_set_header Host "localhost:{port}";
            proxy_set_header Authorization "";
            proxy_set_header Origin $connector_origin;
            proxy_ssl_verify off;
            proxy_buffering off;
            proxy_read_timeout 86400s;
            proxy_hide_header Content-Disposition;
            add_header Content-Disposition $download_disposition always;
            add_header Referrer-Policy no-referrer always;
        }}
        location / {{
            proxy_pass {scheme}://127.0.0.1:{port};
            proxy_http_version 1.1;
            proxy_set_header Host "localhost:{port}";
            proxy_set_header Authorization "";
            proxy_set_header Origin $connector_origin;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_read_timeout 86400s;
            proxy_send_timeout 86400s;
            proxy_buffering off;
            proxy_ssl_verify off;
            {compatibility}
            proxy_redirect ~^https?://(localhost|127\\.0\\.0\\.1):{port}(/.*)$ $2;
        }}
    }}
}}
'''


def runtime_root(app):
    metadata = json.loads((app / "runtime-metadata.json").read_text())
    if metadata["JVMEnabled"] is not False or metadata["Architecture"] != "glnxa64":
        raise ValueError("Payload must target Linux x86-64 with JVM disabled.")
    root = Path("/opt/matlabruntime") / metadata["RuntimeRelease"]
    version = ET.parse(root / "VersionInfo.xml").getroot().findtext("version")
    required = metadata["RuntimeBuildVersion"]
    if not version or not required or tuple(map(int, version.split("."))) < tuple(map(int, required.split("."))):
        raise ValueError("Runtime build is older than the Compiler build; update the base image.")
    return root


class ProxyProcess:
    """Recover the single nginx process without restarting the Runtime.

    A killed nginx worker can leave limit_conn counters in its master's shared
    memory. Running without a second process supervisor makes a restart clear
    that state; this container's supervisor already owns process lifetimes.
    """
    def __init__(self, config):
        self.config = config
        self.process = None
        self.restarts = []

    def check(self):
        if self.process is not None and self.process.poll() is None:
            return
        now = time.monotonic()
        self.restarts = [stamp for stamp in self.restarts if now - stamp < 60]
        if len(self.restarts) >= 4:
            raise RuntimeError('Online proxy repeatedly exited; stopping the instance.')
        if self.process is not None:
            print('Restarting Online proxy; Runtime session is preserved.', flush=True)
        self.restarts.append(now)
        self.process = subprocess.Popen(
            ['nginx', '-c', str(self.config), '-g', 'daemon off;'], start_new_session=True)


def prepare_runtime_directories(environment, work=Path('/data/work')):
    for directory in [Path(environment[name]) for name in
                      ('HOME', 'MATLAB_PREFDIR', 'MCR_CACHE_ROOT')] + [work]:
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        if not os.access(directory, os.W_OK | os.X_OK):
            raise PermissionError(f'Runtime directory is not writable: {directory}. '
                                  'Use a volume writable by UID/GID 10001 or its Kubernetes fsGroup.')
    return work


def validate_runtime_cache(cache):
    cache = Path(cache)
    if os.statvfs(cache).f_flag & getattr(os, 'ST_NOEXEC', 0):
        raise RuntimeError(f'MATLAB Runtime cache is mounted noexec: {cache}. '
                           'MCR_CACHE_ROOT must allow loading native extensions such as symspg.')


def cleanup_virtual_display(temporary=Path('/tmp'), display=99):
    """Remove crash leftovers only after ruling out a live display server.

    Kubernetes keeps emptyDir files across container restarts, including Xvfb's
    lock and socket after SIGKILL/OOM. A live lock owner or listening endpoint
    must never be displaced by another supervisor.
    """
    temporary = Path(temporary)
    lock = temporary / f'.X{display}-lock'
    endpoint = temporary / '.X11-unix' / f'X{display}'
    addresses = [str(endpoint)]
    if sys.platform.startswith('linux'):
        addresses.append('\0' + str(endpoint))
    for address in addresses:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as probe:
            probe.settimeout(1)
            try:
                probe.connect(address)
            except OSError as error:
                if error.errno not in (errno.ENOENT, errno.ECONNREFUSED):
                    raise
            else:
                raise RuntimeError(f'Virtual display :{display} is already listening.')
    try:
        owner = int(lock.read_text().strip())
    except FileNotFoundError:
        owner = 0
    except ValueError:
        owner = 0
    if owner > 0:
        try:
            os.kill(owner, 0)
        except ProcessLookupError:
            pass
        else:
            raise RuntimeError(f'Virtual display :{display} still has a live lock owner.')
    lock.unlink(missing_ok=True)
    endpoint.unlink(missing_ok=True)


def supervise():
    if os.environ.get("AGREE_TO_MATLAB_RUNTIME_LICENSE") != "yes":
        raise ValueError("Set AGREE_TO_MATLAB_RUNTIME_LICENSE=yes after reviewing the MathWorks license.")
    app = Path("/opt/kssolv/app")
    root = runtime_root(app)
    keepalive = keepalive_filter(root)
    session = Path(os.environ["KSSOLV_BROWSER_SESSION_FILE"])
    auth_file = os.environ.get('KSSOLV_AUTH_FILE')
    if auth_file and (not Path(auth_file).is_file() or not Path(auth_file).stat().st_size):
        raise ValueError('KSSOLV_AUTH_FILE must be a readable, nonempty nginx password file.')
    session.parent.mkdir(parents=True, exist_ok=True)
    session.unlink(missing_ok=True)
    os.umask(0o077)
    work = prepare_runtime_directories(os.environ)
    validate_runtime_cache(os.environ['MCR_CACHE_ROOT'])
    os.chdir(work)
    cleanup_virtual_display()
    processes = []
    proxy = None
    from http_worker import HTTPWorker
    from resource_usage import ResourceUsage
    resources = ResourceUsage().start()
    http_worker = HTTPWorker(entry=EntryBroker(session), workspace=work, resources=resources).start()
    runtime_env = dict(os.environ, KSSOLV_HTTP_WORKER_URL=f"http://127.0.0.1:{http_worker.server_port}",
                       KSSOLV_HTTP_WORKER_TOKEN=http_worker.token, KSSOLV_WORKSPACE_ENABLED='true')
    stopping = False

    def stop(signum, frame):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        processes.append(subprocess.Popen(["Xvfb", ":99", "-screen", "0", "1280x900x24", "-nolisten", "tcp"], start_new_session=True))
        deadline = time.monotonic() + 10
        while not Path("/tmp/.X11-unix/X99").exists():
            if stopping or processes[0].poll() is not None or time.monotonic() > deadline:
                raise RuntimeError("Virtual display failed to start.")
            time.sleep(0.1)
        # Use the Compiler launcher to configure Runtime libraries; do not
        # bypass it or add a JVM. No command-line argument conversion is needed.
        processes.append(subprocess.Popen([str(app / "run_KSSOLV_Toolbox.sh"), str(root)],
                                          start_new_session=True, env=runtime_env))
        deadline = time.monotonic() + 300
        while not session.is_file():
            if stopping:
                return 0
            if any(process.poll() is not None for process in processes):
                raise RuntimeError("KSSOLV or virtual display exited before session publication.")
            if time.monotonic() > deadline:
                raise RuntimeError("Timed out waiting for the browser session.")
            time.sleep(0.2)
        data = json.loads(session.read_text())
        config = session.parent / "nginx.conf"
        config.write_text(nginx_config(data, http_worker, auth_file, keepalive))
        subprocess.run(["nginx", "-t", "-c", str(config)], check=True)
        proxy = ProxyProcess(config)
        proxy.check()
        print("KSSOLV Toolbox Online ready: open http://localhost:<published-port>/online "
              "(Compose default: http://localhost:8080/online; one user per container).", flush=True)
        while not stopping:
            for process in processes:
                status = process.poll()
                if status is not None:
                    return status if status != 0 else (0 if process is processes[1] else 1)
            proxy.check()
            time.sleep(0.2)
        return 0
    finally:
        resources.close()
        http_worker.close()
        if proxy is not None and proxy.process is not None:
            processes.append(proxy.process)
        # Terminate entire process groups, including Runtime helper processes.
        for process in reversed(processes):
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        deadline = time.monotonic() + 10
        while any(process.poll() is None for process in processes) and time.monotonic() < deadline:
            time.sleep(0.1)
        for process in processes:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
        session.unlink(missing_ok=True)
        if processes:
            cleanup_virtual_display()


def prepare_process_limits():
    """Bound Runtime's child-process descriptor cleanup to a practical size.

    Some container hosts inherit RLIMIT_NOFILE near 2**30. Runtime's native
    graphics launcher closes descriptors individually before exec, consuming
    minutes of CPU on its first launch. Set both limits before starting any
    Runtime child, while preserving stricter administrator limits.
    """
    soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
    ceiling = 65536
    hard = ceiling if hard == resource.RLIM_INFINITY else min(hard, ceiling)
    soft = hard if soft == resource.RLIM_INFINITY else min(soft, hard)
    resource.setrlimit(resource.RLIMIT_NOFILE, (soft, hard))
    return soft, hard


def main():
    if sys.argv[1:] == ["--healthcheck"]:
        with urlopen("http://127.0.0.1:8080/healthz", timeout=3) as response:
            return 0 if response.status == 200 else 1
    prepare_process_limits()
    return supervise()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"KSSOLV container failed: {error}", file=sys.stderr)
        sys.exit(1)
