"""Private host-to-portal bridge; no administrator credential reaches a browser."""
import json
import os
import secrets
from urllib.parse import urlsplit
from kube import tenant_namespace
from portal_protocol import Rejected, digest

def dispatch(handler, write):
    portal=handler.portal
    expected=os.environ.get('KSSOLV_ADMIN_BRIDGE_TOKEN','')
    supplied=handler.headers.get('Authorization','').removeprefix('Bearer ')
    host=handler.headers.get('X-Original-Host',handler.headers.get('Host','')).lower()
    if len(expected)<32 or not secrets.compare_digest(expected,supplied) or host!=portal.authority:
        raise Rejected(403,'Management bridge authentication failed.')
    path=urlsplit(handler.path).path.rsplit('/',1)[-1]
    if not write:
        if path!='users': raise Rejected(404,'Management operation does not exist.')
        with portal.db() as db:
            users=[dict(r) for r in db.execute('SELECT uid,username,state,frozen,role,profile,resource_cpu,resource_memory,started,last_human FROM users ORDER BY username')]
        defaults=getattr(portal.kube,'config',{})
        return handler.respond(data={'users':users,'profiles':portal.profiles,'defaultResources':{key:defaults.get(key) for key in ('cpu','memory')},'maxRunning':portal.max_running})
    if handler.headers.get('Origin')!=portal.origin: raise Rejected(403,'Invalid management origin.')
    length=int(handler.headers.get('Content-Length','0'))
    if not 0<length<=(65536 if path=='record-pod-events' else 8192): raise Rejected(400,'Invalid management payload.')
    data=json.loads(handler.rfile.read(length))
    if not isinstance(data,dict): raise Rejected(400,'Invalid management payload.')
    if path=='events':
        return handler.respond(data=portal.user_events(data.get('uid',''),data.get('category',''),data.get('before',''),data.get('limit',50)))
    if path=='record-pod-events':
        import math
        events=data.get('events')
        if not isinstance(events,list) or not 1<=len(events)<=50:raise Rejected(400,'Invalid Pod event batch.')
        with portal.db() as db:
            for event in events:
                uid=event['uid'];namespace=tenant_namespace(uid)
                if event.get('namespace')!=namespace or event.get('action') not in ('pod_created','pod_started','pod_stopped','pod_restarted','pod_resized','pod_terminating'):
                    raise Rejected(400,'Invalid Pod event.')
                stamp=event.get('timestamp');key=event.get('key');pod=event.get('pod')
                if (not isinstance(stamp,(int,float)) or not math.isfinite(stamp) or stamp<0 or stamp>portal.clock()+60
                        or not isinstance(key,str) or not 1<=len(key)<=200 or not isinstance(pod,str) or len(pod)>253):
                    raise Rejected(400,'Invalid Pod event metadata.')
                size=event.get('resources',{})
                if set(size)!= {'cpu','memory'} or any(not isinstance(v,str) or len(v)>40 for v in size.values()):raise Rejected(400,'Invalid Pod event resources.')
                portal.event(uid,'pod',event['action'],db=db,source_key='pod:'+key,timestamp=stamp,pod=pod,
                             status=event.get('status','observed')[:40],actor='Kubernetes',
                             detail=str(event.get('detail',''))[:2000],resources=size)
        return handler.respond(data={'ok':True})
    if path=='admin-login':
        return handler.respond(data=portal.management_login(data.get('username'),data.get('password'),str(data.get('ip','host'))[:80]))
    if path=='admin-session':return handler.respond(data=portal.management_identity(data.get('token')))
    if path=='admin-role':return handler.respond(data=portal.set_management_role(data.get('token'),data.get('uid'),data.get('role'),data.get('confirmation')))
    if path=='admin-logout':
        with portal.db() as db:
            identity=portal.management_identity(data.get('token'),db)
            db.execute("DELETE FROM sessions WHERE token_hash=? AND kind='admin'",(digest(str(data.get('token',''))),))
            portal.event(identity['uid'],'authentication','admin_logout',db=db)
        return handler.respond(data={'ok':True})
    if path=='profiles':
        from profiles import profiles
        try: value=profiles({'workspace_profiles':data.get('profiles')})
        except ValueError as error: raise Rejected(400,str(error)) from None
        with portal.profile_lock:
            if data.get('expected')!=portal.profiles:
                raise Rejected(409,'Workspace sizes changed. Refresh and try again.')
            with portal.db() as db:
                db.execute("INSERT OR REPLACE INTO portal_settings VALUES ('workspace_profiles',?)",(json.dumps(value),))
            portal.profiles=value
        return handler.respond(data={'profiles':value})
    if path=='invitation':
        value=data.get('value')
        if not isinstance(value,str) or not 24<=len(value)<=128 or any(ord(c)<33 or ord(c)>126 for c in value):
            raise Rejected(400,'Use 24–128 printable ASCII characters for the invitation.')
        with portal.db() as db: db.execute("INSERT OR REPLACE INTO portal_settings VALUES ('invitation',?)",(value,))
        portal.invitation=value
        return handler.respond(data={'ok':True})
    uid=data.get('uid');tenant_namespace(uid);portal.user(uid)
    with portal.lock(uid):
        if path=='freeze':
            with portal.db() as db:
                db.execute('BEGIN IMMEDIATE')
                if db.execute('SELECT role FROM users WHERE uid=?',(uid,)).fetchone()[0]=='superadmin':raise Rejected(403,'The superadministrator account is protected.')
                db.execute('UPDATE users SET frozen=1 WHERE uid=?',(uid,))
                db.execute('DELETE FROM sessions WHERE uid=?',(uid,));db.execute('DELETE FROM codes WHERE uid=?',(uid,))
            portal.stop(uid,'账号已冻结，请联系管理员。')
            portal.event(uid,'authentication','account_frozen',actor='administrator')
        elif path=='restore':
            with portal.db() as db: db.execute('UPDATE users SET frozen=0 WHERE uid=?',(uid,))
            portal.event(uid,'authentication','account_restored',actor='administrator')
        elif path=='stop': portal.stop(uid,'管理员已关闭实例。',keep_login=True,actor='administrator')
        elif path=='start': portal.start(uid,data.get('profile'),resources=data.get('resources'),actor='administrator')
        elif path=='restart':
            portal.restart_workspace(uid,data.get('profile'),resources=data.get('resources'),actor='administrator')
        elif path=='resources':
            from profiles import workspace_resources
            profile=data.get('profile')
            if profile=='custom':
                try:size=workspace_resources(data.get('resources'))
                except ValueError as error:raise Rejected(400,str(error)) from None
            elif profile in portal.profiles and data.get('resources') is None:size=portal.profiles[profile]
            else: raise Rejected(400,'Invalid workspace profile.')
            with portal.db() as db:
                db.execute('UPDATE users SET profile=?,resource_cpu=?,resource_memory=? WHERE uid=?',(profile,size['cpu'],size['memory'],uid))
                portal.event(uid,'configuration','resources_changed',db=db,actor='administrator')
        else: raise Rejected(404,'Management operation does not exist.')
    return handler.respond(data={'ok':True})
