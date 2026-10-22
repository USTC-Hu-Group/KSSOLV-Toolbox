#!/usr/bin/env python3
"""Loopback-only administration service. Python standard library; no JVM."""
import argparse
import hashlib
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import secrets
import signal
import sys
import threading
import time
from urllib.parse import parse_qs,urlsplit
from cloud import Cloud,Problem
from host_ops import Operations,script_path
from custom_scripts import Scripts
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'portal'))
from profiles import profiles

PUBLIC=Path(__file__).resolve().parents[1]/'portal'/'public'
STATIC=Path(__file__).with_name('public')
def digest(value):return hashlib.sha256(value.encode()).hexdigest()
def private_write(path,value):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    temporary=path.with_name(path.name+'.new');temporary.write_text(value);temporary.chmod(0o600);temporary.replace(path)

class Forbidden(Exception):pass

class Admin:
    def __init__(self,cloud):
        self.cloud=cloud;self.ops=Operations(cloud);self.config=cloud.config;self.scripts=Scripts(cloud)
        self.stop=threading.Event();self.executor=threading.Thread(target=self.sample,daemon=True)
        with cloud.db() as db:db.execute("UPDATE jobs SET state='interrupted',message='Service restarted; review before retrying.' WHERE state IN ('queued','running')")
    def sample(self):
        while not self.stop.is_set():
            started=time.monotonic()
            try:self.cloud.collect()
            except Exception:
                with self.cloud.cache_lock:self.cloud.cache['metricErrors']=(self.cloud.cache.get('metricErrors',[])+['Collection failed; showing last sample.'])[-5:]
            self.stop.wait(max(1,15-(time.monotonic()-started)))
    def rate_limit(self,ip):
        now=self.cloud.clock()
        with self.cloud.db() as db:
            if db.execute('SELECT COUNT(*) FROM attempts WHERE identity=? AND timestamp>?',(ip,now-300)).fetchone()[0]>=8:raise Problem('Too many sign-in attempts. Try again in five minutes.')
            db.execute('INSERT INTO attempts VALUES (?,?)',(ip,now))
    def login(self,username,password,ip):
        self.rate_limit(ip)
        if not isinstance(username,str) or not isinstance(password,str) or len(password)>128:raise PermissionError('Invalid administrator credentials.')
        identity=self.cloud.bridge('admin-login',{'username':username,'password':password,'ip':ip})
        if identity.get('role') not in ('admin','superadmin') or not re.fullmatch(r'[a-f0-9]{24}',str(identity.get('uid',''))):raise PermissionError('Administrator sign-in required.')
        token,csrf=secrets.token_urlsafe(40),secrets.token_urlsafe(32)
        with self.cloud.db() as db:db.execute('INSERT INTO admin_sessions (token,csrf,expires,uid,auth_token) VALUES (?,?,?,?,?)',(digest(token),csrf,self.cloud.clock()+4*3600,identity['uid'],identity['token']))
        self.cloud.audit(identity['username'],'sign-in',ip,'ok');return token,csrf
    def authenticate(self,token):
        with self.cloud.db() as db:row=db.execute('SELECT * FROM admin_sessions WHERE token=? AND expires>?',(digest(token),self.cloud.clock())).fetchone()
        if not row:raise PermissionError('Administrator sign-in required.')
        identity=self.cloud.bridge('admin-session',{'token':row['auth_token']})
        if identity.get('uid')!=row['uid'] or identity.get('role') not in ('admin','superadmin'):raise PermissionError('Administrator sign-in required.')
        return {**dict(row),**identity}
    def set_role(self,session,data):
        if session['role']!='superadmin':raise Forbidden('Only the superadministrator can manage administrator roles.')
        with self.cloud.mutation:
            result=self.cloud.bridge('admin-role',{'token':session['auth_token'],'uid':data.get('uid'),'role':data.get('role'),'confirmation':data.get('confirmation')})
            self.cloud.audit(session['username'],'role-'+result['role'],result['username'],'succeeded')
        return result
    def update_profiles(self,data,actor='host'):
        value=profiles({'workspace_profiles':data.get('profiles')})
        with self.cloud.mutation:
            with self.cloud.db() as db:
                if db.execute("SELECT COUNT(*) FROM jobs WHERE state IN ('queued','running')").fetchone()[0]:
                    raise Problem('Another management operation is in progress.')
            result=self.cloud.bridge('profiles',{'profiles':value,'expected':data.get('expected')})
            self.cloud.audit(actor,'profiles-update','workspace-profiles','succeeded')
        return result
    def propose(self,session,body):
        clean,impact=self.ops.validate(body)
        if clean.get('profile') and clean['profile']!='custom':clean['profileResources']=self.cloud.bridge('users')['profiles'][clean['profile']]
        token=secrets.token_urlsafe(32)
        with self.cloud.db() as db:db.execute('INSERT INTO confirmations VALUES (?,?,?,?)',(digest(token),session['token'],json.dumps(clean),self.cloud.clock()+120))
        return {'token':token,'operation':clean,'impact':impact,'confirmationText':clean['target']}
    def confirm(self,session,body):
        with self.cloud.mutation,self.cloud.db() as db:
            db.execute('BEGIN IMMEDIATE')
            row=db.execute('SELECT * FROM confirmations WHERE token=? AND session=? AND expires>?',(digest(str(body.get('token',''))),session['token'],self.cloud.clock())).fetchone()
            if not row:raise Problem('Confirmation expired or was already used.')
            clean=json.loads(row['body'])
            if body.get('confirmation')!=clean['target']:raise Problem('Confirmation text does not match the target.')
            if clean.get('profile') and clean['profile']!='custom' and self.cloud.bridge('users')['profiles'].get(clean['profile'])!=clean.get('profileResources'):
                raise Problem('Workspace sizes changed. Refresh and try again.')
            if db.execute("SELECT COUNT(*) FROM jobs WHERE state IN ('queued','running')").fetchone()[0]:raise Problem('Another management operation is in progress.')
            db.execute('DELETE FROM confirmations WHERE token=?',(row['token'],))
            job=secrets.token_hex(12);db.execute('INSERT INTO jobs VALUES (?,?,?,?,?,?)',(job,self.cloud.clock(),session.get('username','host'),json.dumps(clean),'queued','Waiting for execution.'))
        threading.Thread(target=self.run_job,args=(job,clean,session),daemon=True).start();return {'job':job}
    def run_job(self,job,body,session):
        cloud=self.cloud;actor=session['username']
        def update(message,state='running'):
            with cloud.db() as db:db.execute('UPDATE jobs SET state=?,message=? WHERE id=?',(state,str(message)[-2000:],job))
        with cloud.mutation:
            update('Validating operation.');cloud.audit(actor,body['action'],body['target'],'started')
            try:
                identity=cloud.bridge('admin-session',{'token':session['auth_token']})
                if identity['uid']!=session['uid']:raise PermissionError('Administrator sign-in required.')
                message=self.ops.run(body,update);update(message,'succeeded');cloud.audit(actor,body['action'],body['target'],'succeeded')
            except Exception as error:update(str(error),'failed');cloud.audit(actor,body['action'],body['target'],'failed')
            try:cloud.collect()
            except Exception:pass

class Server(ThreadingHTTPServer):
    daemon_threads=True
    def __init__(self,address,handler):
        self.slots=threading.BoundedSemaphore(32);super().__init__(address,handler)
    def process_request(self,request,address):
        if not self.slots.acquire(blocking=False):request.close();return
        try:super().process_request(request,address)
        except Exception:self.slots.release();raise
    def process_request_thread(self,request,address):
        try:super().process_request_thread(request,address)
        finally:self.slots.release()

class Handler(BaseHTTPRequestHandler):
    server_version='KSSOLV Admin'
    def log_message(self,*args):pass
    @property
    def admin(self):return self.server.admin
    def send(self,status=200,data=None,raw=None,kind='application/json',cookie=None,filename=None):
        body=raw if raw is not None else json.dumps(data or {},ensure_ascii=False).encode()
        self.send_response(status)
        for key,value in {'Content-Type':kind+'; charset=utf-8','Content-Length':str(len(body)),'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; object-src 'none'; base-uri 'none'; form-action 'self'"}.items():self.send_header(key,value)
        if filename:self.send_header('Content-Disposition','attachment; filename="'+filename+'"')
        if cookie:self.send_header('Set-Cookie',cookie)
        self.end_headers();self.wfile.write(body)
    def cookie(self,value,max_age=14400):
        return '__Secure-kssolv_admin='+value+'; Path=/online/admin; HttpOnly; Secure; SameSite=Strict; Max-Age='+str(max_age)
    def do_GET(self):self.dispatch(False)
    def do_POST(self):self.dispatch(True)
    def dispatch(self,write):
        try:self.route(write)
        except Forbidden as error:self.send(403,{'error':str(error)})
        except PermissionError as error:self.send(401,{'error':str(error)})
        except (Problem,ValueError,KeyError,TypeError,json.JSONDecodeError) as error:self.send(400,{'error':str(error)[:1600]})
        except (BrokenPipeError,ConnectionResetError):pass
        except Exception:self.send(503,{'error':'Management service unavailable. Review host service logs.'})
    def route(self,write):
        admin=self.admin;cloud=admin.cloud;path=urlsplit(self.path).path
        if self.headers.get('Host','').lower()!=urlsplit(admin.config['origin']).netloc.lower():raise PermissionError('Invalid management host.')
        data={}
        if write:
            if self.headers.get('Origin')!=admin.config['origin']:raise PermissionError('Invalid request origin.')
            if self.headers.get('Content-Type','').split(';')[0]!='application/json':raise Problem('JSON request required.')
            length=int(self.headers.get('Content-Length','0'))
            if not 0<length<=(512*1024 if path=='/online/admin/api/scripts/save' else 8192):raise Problem('Request is too large.')
            data=json.loads(self.rfile.read(length))
            if not isinstance(data,dict):raise Problem('Invalid request.')
        if not write and path in ('/online/admin','/online/admin/'):
            return self.send(raw=(STATIC/'index.html').read_bytes(),kind='text/html')
        files={'/online/admin/app.js':(STATIC/'app.js','text/javascript'),'/online/admin/scripts.js':(STATIC/'scripts.js','text/javascript'),'/online/admin/admin-i18n.js':(STATIC/'admin-i18n.js','text/javascript'),'/online/admin/i18n.js':(PUBLIC/'i18n.js','text/javascript'),'/online/admin/favicon.svg':(PUBLIC/'favicon.svg','image/svg+xml')}
        if not write and path=='/online/admin/style.css':return self.send(raw=(PUBLIC/'style.css').read_bytes()+b'\n'+(STATIC/'style.css').read_bytes(),kind='text/css')
        if not write and path in files:
            file,kind=files[path];return self.send(raw=file.read_bytes(),kind=kind)
        if write and path=='/online/admin/api/login':
            token,csrf=admin.login(data.get('username'),data.get('password'),self.headers.get('X-Real-IP',self.client_address[0]))
            identity=admin.authenticate(token)
            return self.send(data={'csrf':csrf,'username':identity['username'],'role':identity['role']},cookie=self.cookie(token))
        parsed=SimpleCookie();parsed.load(self.headers.get('Cookie',''))
        token=parsed.get('__Secure-kssolv_admin');session=admin.authenticate(token.value if token else '')
        if write and not secrets.compare_digest(self.headers.get('X-CSRF-Token',''),session['csrf']):raise PermissionError('Invalid CSRF token.')
        if not write and path=='/online/admin/api/me':return self.send(data={'csrf':session['csrf'],'username':session['username'],'role':session['role']})
        if write and path=='/online/admin/api/logout':
            try:cloud.bridge('admin-logout',{'token':session['auth_token']})
            finally:
                with cloud.db() as db:db.execute('DELETE FROM admin_sessions WHERE token=?',(session['token'],))
            return self.send(data={'ok':True},cookie=self.cookie('',0))
        if not write and path=='/online/admin/api/state':return self.send(data={**cloud.snapshot(),'customScripts':admin.scripts.inventory(),'viewer':{'uid':session['uid'],'username':session['username'],'role':session['role']}})
        if path.startswith('/online/admin/api/scripts/'):
            operation=path.rsplit('/',1)[-1];query=parse_qs(urlsplit(self.path).query)
            if not write:
                if operation=='source':return self.send(data=admin.scripts.get(query.get('id',[''])[0],int(query['revision'][0]) if query.get('revision') else None))
                if operation=='runs':return self.send(data=admin.scripts.runs(query.get('id',[''])[0],query.get('before',[''])[0]))
                if operation=='log':
                    identifier=query.get('id',[''])[0];admin.scripts.result(identifier)
                    file=admin.scripts.directory/identifier/'output.log'
                    return self.send(raw=file.read_bytes() if file.exists() else b'',kind='text/plain',filename='kssolv-'+identifier+'.log')
                if operation=='result':return self.send(data=admin.scripts.result(query.get('id',[''])[0]))
            else:
                if operation=='save':return self.send(data=admin.scripts.save(data,session))
                if operation=='run':return self.send(202,data=admin.scripts.run(data,session))
                if operation=='schedule':return self.send(data=admin.scripts.schedule(data,session))
                if operation=='pause':return self.send(data=admin.scripts.pause(data.get('id'),session))
                if operation=='cancel':return self.send(data=admin.scripts.cancel(data.get('id'),session))
            return self.send(404,{'error':'Script operation not found.'})
        if not write and path=='/online/admin/api/user-events':
            query=parse_qs(urlsplit(self.path).query)
            return self.send(data=cloud.user_events({key:query.get(key,[''])[0] for key in ('uid','category','before')}))
        if not write and path=='/online/admin/api/history':
            query=parse_qs(urlsplit(self.path).query);hours=int(query.get('hours',['24'])[0])
            if hours not in (1,24,168,720):raise Problem('Invalid chart range.')
            return self.send(data={'points':cloud.history(query.get('kind',[''])[0],query.get('id',[''])[0],hours)})
        if write and path=='/online/admin/api/propose':return self.send(data=admin.propose(session,data))
        if write and path=='/online/admin/api/confirm':return self.send(202,data=admin.confirm(session,data))
        if write and path=='/online/admin/api/profiles':return self.send(data=admin.update_profiles(data,session['username']))
        if write and path=='/online/admin/api/roles':return self.send(data=admin.set_role(session,data))
        if write and path=='/online/admin/api/invitation':
            if data.get('confirmation')!='ROTATE':raise Problem('Type ROTATE to confirm invitation replacement.')
            value=data.get('value')
            if not isinstance(value,str) or not 24<=len(value)<=128 or not re.fullmatch(r'[!-~]+',value):raise Problem('Use 24–128 printable ASCII characters.')
            with cloud.mutation:
                secret=cloud.get('secret','registration','-n','kssolv-system')
                import base64
                old_value=base64.b64decode(secret['data']['code']).decode()
                try:
                    cloud.bridge('invitation',{'value':value})
                    secret['data']['code']=base64.b64encode(value.encode()).decode()
                    cloud.kub('replace','-f','-',input=json.dumps(secret))
                    private_write(admin.config['invitation_file'],value+'\n')
                except Exception:
                    try:
                        cloud.bridge('invitation',{'value':old_value})
                        secret=cloud.get('secret','registration','-n','kssolv-system')
                        secret['data']['code']=base64.b64encode(old_value.encode()).decode()
                        cloud.kub('replace','-f','-',input=json.dumps(secret))
                        private_write(admin.config['invitation_file'],old_value+'\n')
                    except Exception:
                        cloud.audit(session['username'],'invitation-rotate','registration','rollback-incomplete')
                        raise Problem('Invitation rotation incomplete. Inspect portal settings, registration Secret and private invitation file on the host.')
                    cloud.audit(session['username'],'invitation-rotate','registration','rolled-back')
                    raise Problem('Invitation update failed and was rolled back. The previous invitation remains active.')
                cloud.audit(session['username'],'invitation-rotate','registration','succeeded')
            return self.send(data={'ok':True})
        if write and path=='/online/admin/api/scripts':
            identifier=data.get('id','');name=data.get('name','');description=data.get('description','')
            if not re.fullmatch(r'[a-z][a-z0-9-]{1,39}',identifier) or not isinstance(name,str) or not 1<=len(name)<=80 or not isinstance(description,str) or len(description)>500:raise Problem('Invalid script description.')
            location=script_path(cloud,data.get('path',''))
            with cloud.db() as db:db.execute('INSERT OR REPLACE INTO scripts VALUES (?,?,?,?)',(identifier,name,str(location),description))
            cloud.audit(session['username'],'script-register',identifier,'succeeded')
            return self.send(data={'ok':True,'command':'sudo /usr/bin/python3 /opt/kssolv-admin/app/admin/host_ops.py --config /etc/kssolv/admin.json run-script '+identifier})
        return self.send(404,{'error':'Management page not found.'})

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--config',default='/etc/kssolv/admin.json');args=parser.parse_args()
    os.umask(0o077);config=json.loads(Path(args.config).read_text());cloud=Cloud(config);admin=Admin(cloud)
    server=Server(('127.0.0.1',config.get('port',8095)),Handler);server.admin=admin;admin.executor.start()
    for sig in (signal.SIGTERM,signal.SIGINT):signal.signal(sig,lambda *_: (admin.stop.set(),threading.Thread(target=server.shutdown).start()))
    try:server.serve_forever()
    finally:admin.stop.set();server.server_close()
if __name__=='__main__':main()
