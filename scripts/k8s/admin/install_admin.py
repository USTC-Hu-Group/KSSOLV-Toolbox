#!/usr/bin/env python3
"""Install a loopback-only host console behind the existing TLS edge."""
import argparse
import base64
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
from urllib.parse import urlsplit

# Repository source layout and the existing flattened host install layout.
SOURCE_ROOT = Path(__file__).resolve().parents[3] / 'server'
if not (SOURCE_ROOT / 'admin' / 'admin_server.py').is_file():
    SOURCE_ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(SOURCE_ROOT / 'admin'), str(SOURCE_ROOT / 'portal'),
               str(Path(__file__).resolve().parents[1])]
from admin_server import private_write
from tls_edge import admin_locations
from script_runner import unit_source


def stage_application(destination, source_root=SOURCE_ROOT):
    """Install the split source tree under the established host service paths."""
    destination = Path(destination)
    source_root = Path(source_root)
    if source_root.resolve() == destination.resolve():
        return
    for section, names in {
        'admin': ('admin_server.py', 'cloud.py', 'custom_scripts.py', 'host_ops.py', 'script_runner.py'),
        'portal': ('profiles.py',),
    }.items():
        target = destination / section
        target.mkdir(parents=True, exist_ok=True)
        for name in names:
            shutil.copy2(source_root / section / name, target / name)
    for section in ('admin', 'portal'):
        shutil.copytree(source_root / section / 'public', destination / section / 'public',
                        dirs_exist_ok=True, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    operations = Path(__file__).resolve().parents[1]
    shutil.copy2(operations / 'tls_edge.py', destination / 'tls_edge.py')
    for name in ('install_admin.py', 'set_superadmin.py'):
        shutil.copy2(Path(__file__).with_name(name), destination / 'admin' / name)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--origin',required=True);parser.add_argument('--kubeconfig',default='/root/k8s-lab/admin.conf');parser.add_argument('--portal-url',default='http://192.168.250.11:30088');parser.add_argument('--edge-config',default='/etc/kssolv/nginx-edge.conf');parser.add_argument('--portal-image',required=True);parser.add_argument('--config',default='/etc/kssolv/admin.json');parser.add_argument('--workers',nargs='+',default=['k8s-worker1','k8s-worker2']);parser.add_argument('--control-plane',default='k8s-cp1');args=parser.parse_args()
    if os.geteuid()!=0:raise SystemExit('Run installer on the virtualization host as root.')
    origin=urlsplit(args.origin)
    if origin.scheme!='https' or origin.path or origin.query or origin.username:raise SystemExit('Use an HTTPS origin without a path.')
    stage_application('/opt/kssolv-admin/app')
    os.umask(0o077);secret_dir=Path('/opt/kssolv-secrets');secret_dir.mkdir(mode=0o700,exist_ok=True)
    token_file=secret_dir/'admin-bridge-token'
    if not token_file.exists():private_write(token_file,secrets.token_urlsafe(48)+'\n')
    config_path=Path(args.config)
    config=json.loads(config_path.read_text()) if config_path.exists() else {}
    config.pop('account',None)
    config['auth_mode']='portal'
    config.setdefault('script_timezone','Asia/Shanghai')
    config.update(origin=args.origin,kubeconfig=args.kubeconfig,portal_url=args.portal_url,workers=args.workers,control_plane=args.control_plane,state_dir='/var/lib/kssolv-admin',script_dir='/opt/kssolv-admin/scripts',bridge_token_file=str(token_file),invitation_file=str(secret_dir/'registration-code'),port=8095)
    private_write(config_path,json.dumps(config,indent=2)+'\n')
    for path in (Path(config['state_dir']),Path(config['script_dir'])):path.mkdir(parents=True,exist_ok=True,mode=0o700)
    kub=['kubectl','--kubeconfig',args.kubeconfig]
    def command(*arguments,**kwargs):return subprocess.run([*kub,*arguments],check=True,text=True,capture_output=True,**kwargs).stdout
    token=token_file.read_text().strip()
    secret={'apiVersion':'v1','kind':'Secret','metadata':{'name':'admin-bridge','namespace':'kssolv-system'},'type':'Opaque','data':{'token':base64.b64encode(token.encode()).decode()}}
    existing=command('-n','kssolv-system','get','secret','admin-bridge','--ignore-not-found','-o','json')
    if existing.strip():secret['metadata']['resourceVersion']=json.loads(existing)['metadata']['resourceVersion']
    command('replace' if existing.strip() else 'create','-f','-',input=json.dumps(secret))
    deployment=json.loads(command('-n','kssolv-system','get','deployment','portal','-o','json'))
    container=deployment['spec']['template']['spec']['containers'][0];container['image']=args.portal_image
    container['env']=[e for e in container.get('env',[]) if e['name']!='KSSOLV_ADMIN_BRIDGE_TOKEN']+[{'name':'KSSOLV_ADMIN_BRIDGE_TOKEN','valueFrom':{'secretKeyRef':{'name':'admin-bridge','key':'token'}}}]
    command('-n','kssolv-system','patch','deployment','portal','--type=merge','-p',json.dumps({'spec':{'template':{'spec':{'containers':[container]}}}}))
    print(command('-n','kssolv-system','rollout','status','deployment/portal','--timeout=180s'),flush=True)
    service='''[Unit]
Description=KSSOLV Toolbox Online Management (host loopback)
After=network-online.target libvirtd.service
Wants=network-online.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/kssolv-admin/app/admin/admin_server.py --config /etc/kssolv/admin.json
Restart=on-failure
RestartSec=5
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=read-only
ProtectSystem=strict
ReadWritePaths=/var/lib/kssolv-admin /opt/kssolv-secrets /etc/kssolv
[Install]
WantedBy=multi-user.target
'''
    Path('/etc/systemd/system/kssolv-admin.service').write_text(service.replace('/etc/kssolv/admin.json',str(config_path)))
    subprocess.run(['systemctl','daemon-reload'],check=True);subprocess.run(['systemctl','enable','--now','kssolv-admin.service'],check=True)
    subprocess.run(['systemctl','restart','kssolv-admin.service'],check=True)
    Path('/etc/systemd/system/kssolv-script-runner.service').write_text(unit_source(str(config_path)))
    subprocess.run(['systemctl','daemon-reload'],check=True)
    subprocess.run(['systemctl','enable','kssolv-script-runner.service'],check=True)
    subprocess.run(['systemctl','restart','kssolv-script-runner.service'],check=True)
    edge=Path(args.edge_config);text=edge.read_text();marker='        # KSSOLV host administration\n'
    location=admin_locations(origin.hostname,'127.0.0.1:8095')
    if text.count('        location / {')!=1:raise SystemExit('Ambiguous edge configuration; no TLS changes applied.')
    if marker in text:
        start=text.index(marker);end=text.index('        location / {',start)
        candidate=text[:start]+location+text[end:]
    else:candidate=text.replace('        location / {',location+'        location / {')
    if candidate!=text:
        temporary=edge.with_name(edge.name+'.admin-candidate');temporary.write_text(candidate)
        subprocess.run(['nginx','-t','-c',str(temporary)],check=True)
        shutil.copy2(edge,edge.with_name(edge.name+'.before-admin'));temporary.replace(edge)
    # ExecReload runs in the edge unit's PrivateTmp namespace, where its PID file lives.
    subprocess.run(['systemctl','reload','kssolv-edge.service'],check=True)
    print('Management:',args.origin+'/online/admin')
    print('Management sign-in uses registered workspace accounts. The first registration becomes superadministrator.')
    print('Custom scripts:',config['script_dir'])
if __name__=='__main__':main()
