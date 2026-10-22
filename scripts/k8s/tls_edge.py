#!/usr/bin/env python3
"""Expose an existing Kubernetes NodePort through host HTTPS, retaining per-user origins."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import ssl
import subprocess
import time
from urllib.parse import urlsplit


def admin_locations(domain,upstream):
    if not re.fullmatch(r'[a-z0-9][a-z0-9.-]+',domain) or not re.fullmatch(r'127\.0\.0\.1:[0-9]{2,5}',upstream):
        raise ValueError('Use a trusted administration domain and loopback upstream')
    result=f'''        # KSSOLV host administration
        location = /admin {{
            if ($host != {domain}) {{ return 404; }}
            return 308 /online/admin;
        }}
        location = /admin/ {{
            if ($host != {domain}) {{ return 404; }}
            return 308 /online/admin;
        }}
        location ^~ /admin/ {{ return 404; }}
'''
    for match in ('= /online/admin','^~ /online/admin/'):
        result+=f'''        location {match} {{
            if ($host != {domain}) {{ return 404; }}
            proxy_pass http://{upstream};
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_buffering off;
            proxy_connect_timeout 3s;
            proxy_read_timeout 35s;
        }}
'''
    return result


def edge_config(domain, upstream, redirect_http=True, tenant_domain=None, *,
                https_port=8443, http_port=8080, admin_upstream=None,
                cert="/run/tls/fullchain.pem", key="/run/tls/private.key"):
    if not re.fullmatch(r"[a-z0-9][a-z0-9.-]+", domain):
        raise ValueError("Use a DNS hostname without a scheme or port")
    if not re.fullmatch(r"[a-zA-Z0-9_.-]+:[0-9]{2,5}", upstream):
        raise ValueError("Use a trusted hostname:port upstream")
    tenant_domain=tenant_domain or domain
    if not re.fullmatch(r"[a-z0-9][a-z0-9.-]+",tenant_domain): raise ValueError('Invalid tenant domain')
    if admin_upstream is not None and not re.fullmatch(r'127\.0\.0\.1:[0-9]{2,5}',admin_upstream):raise ValueError('Administration upstream must be loopback-only')
    def quoted_path(value):
        value = str(value)
        if any(character in value for character in ('\n', '\r', '\x00')):
            raise ValueError("TLS paths must not contain control characters")
        return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('$', '\\$') + '"'
    names=domain+' "~^u-[a-f0-9]{24}\\.'+re.escape(tenant_domain)+'$"'
    http = f'''server {{ listen {http_port} default_server; return 444; }}
    server {{ listen {http_port}; server_name {names}; return 308 https://$host$request_uri; }}''' if redirect_http else ""
    admin=admin_locations(domain,admin_upstream) if admin_upstream else ''
    return f'''pid /tmp/nginx.pid;
error_log stderr warn;
worker_processes 1;
events {{ worker_connections 2048; }}
http {{
    access_log off;
    client_body_temp_path /tmp/body;
    proxy_temp_path /tmp/proxy;
    fastcgi_temp_path /tmp/fastcgi;
    uwsgi_temp_path /tmp/uwsgi;
    scgi_temp_path /tmp/scgi;
    map $http_upgrade $connection_upgrade {{ default upgrade; '' close; }}
    upstream cluster_portal {{ server {upstream}; }}
    {http}
    server {{ listen {https_port} ssl default_server; ssl_reject_handshake on; }}
    server {{
        listen {https_port} ssl;
        server_name {names};
        ssl_certificate {quoted_path(cert)};
        ssl_certificate_key {quoted_path(key)};
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_session_tickets off;
        client_max_body_size 256m;
{admin}        location / {{
            proxy_pass http://cluster_portal;
            proxy_http_version 1.1;
            proxy_set_header Host $http_host;
            proxy_set_header X-Forwarded-Proto https;
            # Replace client-provided forwarding headers at the public edge.
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_connect_timeout 5s;
            proxy_read_timeout 86400s;
            proxy_send_timeout 120s;
        }}
    }}
}}
'''


def validate_certificate(cert, key, domain, tenant_domain=None):
    # load_cert_chain also verifies that the private key matches the certificate.
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert, key, password=lambda: "")
    for host in (domain, "u-" + "a"*24 + "." + (tenant_domain or domain)):
        subprocess.run(["openssl", "verify", "-verify_hostname", host, "-untrusted", str(cert), str(cert)],
                       stdout=subprocess.DEVNULL, check=True)


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--domain", help="Portal hostname; defaults to the hostname in KSSOLV_PUBLIC_ORIGIN")
    parser.add_argument("--tenant-domain", default=os.environ.get("KSSOLV_TENANT_DOMAIN"),
                        help="Tenant DNS suffix without '*.'; defaults to KSSOLV_TENANT_DOMAIN or the portal hostname")
    parser.add_argument("--cert", type=Path, required=True, help="PEM full chain, including intermediate certificates")
    parser.add_argument("--key", type=Path, required=True, help="Matching PEM private key")
    parser.add_argument("--state-dir", type=Path, help="Private directory outside the repository; required for container deployment")
    parser.add_argument("--image", default="kssolv-portal:20261018-15")
    parser.add_argument("--network", default="kind")
    parser.add_argument("--upstream", default="cloud-worker:30088")
    parser.add_argument("--admin-upstream",help="Optional host console, e.g. 127.0.0.1:8095 (host rendering only)")
    parser.add_argument("--no-http-redirect", action="store_true", help="Publish only TCP443; do not bind TCP80")
    parser.add_argument("--render-only", action="store_true",
                        help="Print a standalone host nginx configuration on stdout; do not read keys, run Docker or start services")
    args = parser.parse_args(argv)
    if not args.render_only and args.state_dir is None:
        parser.error("--state-dir is required unless --render-only is used")
    if not args.domain:
        try:
            origin = urlsplit(os.environ.get("KSSOLV_PUBLIC_ORIGIN", ""))
            if (origin.scheme != "https" or not origin.hostname or origin.port not in (None, 443)
                    or origin.path or origin.query or origin.fragment or origin.username):
                raise ValueError("Invalid HTTPS origin")
        except ValueError:
            parser.error("Set --domain or KSSOLV_PUBLIC_ORIGIN to an HTTPS origin on port 443 without a path")
        args.domain = origin.hostname
    args.tenant_domain = args.tenant_domain or args.domain
    try:
        edge_config(args.domain, args.upstream, not args.no_http_redirect, args.tenant_domain,admin_upstream=args.admin_upstream)
        if args.admin_upstream and not args.render_only:parser.error("--admin-upstream requires --render-only for a host service")
    except ValueError as error:
        parser.error(str(error))
    return args


def main():
    args = parse_args()
    if args.render_only:
        print(edge_config(args.domain, args.upstream, not args.no_http_redirect, args.tenant_domain,
                          https_port=443, http_port=80, cert=args.cert.resolve(), key=args.key.resolve(),admin_upstream=args.admin_upstream))
        return
    if os.geteuid() != 0: raise SystemExit("Run as root to protect and stage TLS key files")
    config = edge_config(args.domain, args.upstream, not args.no_http_redirect,args.tenant_domain)
    validate_certificate(args.cert.resolve(), args.key.resolve(), args.domain,args.tenant_domain)
    directory = args.state_dir.resolve()
    root = Path(__file__).resolve().parent
    repository = root.parent.parent if root.name == "k8s" and root.parent.name == "scripts" else root
    if directory == repository or repository in directory.parents:
        raise SystemExit("TLS state must be outside the source repository")
    directory.mkdir(parents=True, exist_ok=True, mode=0o700); directory.chmod(0o700)
    staged = directory / ("release-" + time.strftime("%Y%m%d%H%M%S", time.gmtime()))
    staged.mkdir(mode=0o700)
    for source, name in ((args.cert,"fullchain.pem"),(args.key,"private.key")):
        shutil.copyfile(source, staged/name); (staged/name).chmod(0o400); os.chown(staged/name,10001,10001)
    (staged/"nginx.conf").write_text(config); (staged/"nginx.conf").chmod(0o444)
    base = ["docker","run","--network",args.network,"--user","10001:10001","--read-only",
            "--cap-drop","ALL","--security-opt","no-new-privileges","--memory","256m","--cpus","1","--ulimit","nofile=4096:4096",
            "--tmpfs","/tmp:rw,noexec,nosuid,nodev,size=128m,mode=1777"]
    for name,target in (("fullchain.pem","/run/tls/fullchain.pem"),("private.key","/run/tls/private.key"),("nginx.conf","/etc/kssolv-edge.conf")):
        base += ["--mount",f"type=bind,src={staged/name},dst={target},readonly"]
    subprocess.run(base+["--rm","--entrypoint","nginx",args.image,"-t","-c","/etc/kssolv-edge.conf"],check=True)
    name="kssolv-tls-edge"
    probe=subprocess.run(["docker","inspect",name],capture_output=True,text=True)
    backup=None
    if probe.returncode==0:
        current=json.loads(probe.stdout)[0]
        if current["Config"].get("Labels",{}).get("app.kubernetes.io/managed-by")!="kssolv-portal":
            raise SystemExit("Refusing to replace a TLS edge not managed by this project")
        backup=name+"-backup-"+time.strftime("%Y%m%d%H%M%S",time.gmtime())
        subprocess.run(["docker","stop",name],check=True,stdout=subprocess.DEVNULL)
        subprocess.run(["docker","rename",name,backup],check=True)
    command=base+["-d","--name",name,"--restart","unless-stopped","--label","app.kubernetes.io/managed-by=kssolv-portal","-p","443:8443"]
    if not args.no_http_redirect:command += ["-p","80:8080"]
    try:
        subprocess.run(command+["--entrypoint","/usr/bin/tini",args.image,"--","nginx","-c","/etc/kssolv-edge.conf","-g","daemon off;"],check=True,stdout=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        subprocess.run(["docker","rm","-f",name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        if backup:
            subprocess.run(["docker","rename",backup,name],check=True)
            subprocess.run(["docker","start",name],check=True,stdout=subprocess.DEVNULL)
        raise
    print("TLS edge started for https://"+args.domain+"; validate with the matching HTTPS portal origin.")


if __name__=="__main__":main()
