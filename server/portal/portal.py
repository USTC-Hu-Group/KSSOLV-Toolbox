"""Registration, host-scoped sessions and idle Runtime lifecycle. No third-party packages."""
import base64
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
import hashlib
import html
import http.client
import ipaddress
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import logging
import os
from pathlib import Path
import secrets
import signal
import sqlite3
import subprocess
import threading
import time
import unicodedata
from urllib.parse import parse_qs, urlsplit

from kube import Kubernetes, tenant_namespace
from profiles import profiles,workspace_resources
from portal_protocol import Rejected, digest

LOG = logging.getLogger("kssolv.portal")
PUBLIC = Path(__file__).with_name("public")
KDF_SLOTS = threading.BoundedSemaphore(2)


def password_hash(password, salt):
    with KDF_SLOTS:
        return hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt),
                              n=32768, r=8, p=1, maxmem=64*1024*1024).hex()


def validate_password(password, confirmation):
    if not isinstance(password, str) or not 12 <= len(password) <= 128:
        raise Rejected(400, "密码需为 12–128 个字符。")
    if not isinstance(confirmation, str) or password != confirmation:
        raise Rejected(400, "两次输入的密码不一致。")


def normalize_answer(answer):
    if not isinstance(answer, str) or len(answer) > 128:
        raise Rejected(400, "备忘答案需为 2–128 个字符。")
    normalized = unicodedata.normalize('NFKC', answer).strip().casefold()
    if not 2 <= len(normalized) <= 128:
        raise Rejected(400, "备忘答案需为 2–128 个字符。")
    return normalized


def recovery_fields(question, answer):
    if not isinstance(question, str) or not 4 <= len(question.strip()) <= 200:
        raise Rejected(400, "备忘问题需为 4–200 个字符。")
    salt = secrets.token_hex(16)
    return question.strip(), salt, password_hash(normalize_answer(answer), salt)


class Portal:
    def __init__(self, directory, origin, registration_code, kube, *, idle_seconds=1800,
                 max_running=8, max_users=100, clock=time.time, tenant_domain=None):
        parsed = urlsplit(origin)
        if (parsed.scheme not in ("http", "https") or not parsed.hostname or parsed.path
                or parsed.query or parsed.fragment or parsed.username):
            raise ValueError("PUBLIC_ORIGIN must be an origin without a path")
        if parsed.scheme != "https" and not parsed.hostname.endswith(".localhost"):
            raise ValueError("HTTP is limited to .localhost SSH-tunnel development origins; use HTTPS publicly")
        if len(registration_code) < 24:
            raise ValueError("A random registration invitation of at least 24 characters is required")
        self.origin, self.authority, self.scheme = origin, parsed.netloc.lower(), parsed.scheme
        self.hostname, self.port = parsed.hostname, parsed.port
        import re
        self.tenant_hostname = tenant_domain or self.hostname
        if not re.fullmatch(r'[a-z0-9][a-z0-9.-]*', self.tenant_hostname):
            raise ValueError('Tenant domain must be a trusted DNS hostname')
        self.tenant_authority = self.tenant_hostname + (':' + str(self.port) if self.port else '')
        self.invitation, self.kube, self.clock = registration_code, kube, clock
        self.idle_seconds, self.max_running, self.max_users = idle_seconds, max_running, max_users
        self.profiles=profiles(getattr(kube,'config',{}))
        self.profile_lock=threading.Lock()
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.dbfile = self.directory / "accounts.sqlite3"
        with self.db() as db:
            db.executescript("""
                PRAGMA journal_mode=WAL;
                CREATE TABLE IF NOT EXISTS users (
                  uid TEXT PRIMARY KEY, username TEXT UNIQUE NOT NULL, salt TEXT NOT NULL,
                  password_hash TEXT NOT NULL, runtime_secret TEXT NOT NULL,
                  last_human REAL NOT NULL, started REAL NOT NULL DEFAULT 0,
                  state TEXT NOT NULL DEFAULT 'stopped', reason TEXT NOT NULL DEFAULT '');
                CREATE TABLE IF NOT EXISTS sessions (
                  token_hash TEXT PRIMARY KEY, uid TEXT NOT NULL, kind TEXT NOT NULL,
                  host TEXT NOT NULL, expires REAL NOT NULL);
                CREATE INDEX IF NOT EXISTS session_user ON sessions(uid);
                CREATE TABLE IF NOT EXISTS codes (
                  token_hash TEXT PRIMARY KEY, uid TEXT NOT NULL, issuer TEXT NOT NULL, expires REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS attempts (
                  identity TEXT NOT NULL, timestamp REAL NOT NULL);
                CREATE INDEX IF NOT EXISTS attempt_identity ON attempts(identity,timestamp);
                CREATE TABLE IF NOT EXISTS user_events (
                  id INTEGER PRIMARY KEY AUTOINCREMENT, source_key TEXT UNIQUE,
                  timestamp REAL NOT NULL, uid TEXT NOT NULL, username TEXT NOT NULL,
                  category TEXT NOT NULL, action TEXT NOT NULL, status TEXT NOT NULL,
                  actor TEXT NOT NULL, profile TEXT NOT NULL, cpu TEXT NOT NULL, memory TEXT NOT NULL,
                  namespace TEXT NOT NULL, pod TEXT NOT NULL, detail TEXT NOT NULL);
                CREATE INDEX IF NOT EXISTS user_event_filter ON user_events(uid,category,timestamp,id);
                CREATE INDEX IF NOT EXISTS user_event_time ON user_events(timestamp,id);
            """)
            # Additive migration keeps existing identities, passwords and volumes intact.
            columns = {row['name'] for row in db.execute('PRAGMA table_info(users)')}
            for name in ('recovery_question', 'recovery_salt', 'recovery_hash', 'entry_error'):
                if name not in columns:
                    db.execute('ALTER TABLE users ADD COLUMN ' + name + " TEXT NOT NULL DEFAULT ''")
            for name,definition in [('frozen','INTEGER NOT NULL DEFAULT 0'),('profile',"TEXT NOT NULL DEFAULT 'legacy'"),('resource_cpu',"TEXT NOT NULL DEFAULT ''"),('resource_memory',"TEXT NOT NULL DEFAULT ''")]:
                if name not in columns: db.execute('ALTER TABLE users ADD COLUMN '+name+' '+definition)
            if 'role' not in columns:
                db.execute("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'user' CHECK(role IN ('user','admin','superadmin'))")
            db.execute("CREATE UNIQUE INDEX IF NOT EXISTS one_superadministrator ON users(role) WHERE role='superadmin'")
            db.execute("CREATE TABLE IF NOT EXISTS portal_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
            if db.execute('SELECT COUNT(*) FROM users').fetchone()[0]:
                db.execute("INSERT OR IGNORE INTO portal_settings VALUES ('superadmin_bootstrapped','1')")
            invite=db.execute("SELECT value FROM portal_settings WHERE key='invitation'").fetchone()
            if invite: self.invitation=invite[0]
            saved_profiles=db.execute("SELECT value FROM portal_settings WHERE key='workspace_profiles'").fetchone()
            if saved_profiles: self.profiles=profiles({'workspace_profiles':json.loads(saved_profiles[0])})
        self.dbfile.chmod(0o600)
        self.pool = ThreadPoolExecutor(max_workers=4, thread_name_prefix="tenant")
        self.locks, self.locks_guard = {}, threading.Lock()
        self.dummy_salt = secrets.token_hex(16)
        self.dummy_hash = password_hash(secrets.token_urlsafe(32), self.dummy_salt)

    @contextmanager
    def db(self):
        db = sqlite3.connect(self.dbfile, timeout=10)
        db.row_factory = sqlite3.Row
        try:
            with db: yield db
        finally:
            db.close()

    def lock(self, uid):
        with self.locks_guard:
            return self.locks.setdefault(uid, threading.RLock())

    def event(self, uid, category, action, *, db=None, status='succeeded', actor=None,
              detail='', source_key=None, timestamp=None, pod='', resources=None):
        if db is None:
            with self.db() as db:
                return self.event(uid,category,action,db=db,status=status,actor=actor,detail=detail,
                                  source_key=source_key,timestamp=timestamp,pod=pod,resources=resources)
        user=db.execute('SELECT * FROM users WHERE uid=?',(uid,)).fetchone()
        if not user:return
        defaults=getattr(self.kube,'config',{})
        size=resources or {'cpu':user['resource_cpu'] or defaults.get('cpu',''),
                           'memory':user['resource_memory'] or defaults.get('memory','')}
        db.execute('INSERT OR IGNORE INTO user_events (source_key,timestamp,uid,username,category,action,status,actor,profile,cpu,memory,namespace,pod,detail) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
                   (source_key,self.clock() if timestamp is None else timestamp,uid,user['username'],category,
                    action,status,user['username'] if actor is None else actor,user['profile'],
                    str(size['cpu']),str(size['memory']),tenant_namespace(uid),pod,detail[:2000]))

    def user_events(self, uid='', category='', before='', limit=50):
        import math
        if uid:tenant_namespace(uid)
        if category not in ('','authentication','workspace','pod','configuration'):
            raise Rejected(400,'Invalid activity category.')
        if not isinstance(limit,int) or isinstance(limit,bool) or not 1<=limit<=200:
            raise Rejected(400,'Invalid activity page size.')
        clauses=[];params=[]
        if uid:clauses.append('uid=?');params.append(uid)
        if category:clauses.append('category=?');params.append(category)
        if before:
            try:
                stamp,identifier=before.split(':');stamp=float(stamp);identifier=int(identifier)
                if not math.isfinite(stamp) or identifier<1:raise ValueError()
            except (ValueError,AttributeError):raise Rejected(400,'Invalid activity cursor.') from None
            clauses.append('(timestamp<? OR (timestamp=? AND id<?))');params.extend([stamp,stamp,identifier])
        query='SELECT * FROM user_events'+(' WHERE '+' AND '.join(clauses) if clauses else '')+' ORDER BY timestamp DESC,id DESC LIMIT ?'
        with self.db() as db:rows=[dict(r) for r in db.execute(query,(*params,limit+1))]
        more=len(rows)>limit;rows=rows[:limit]
        for row in rows:row.pop('source_key',None)
        return {'events':rows,'next':str(rows[-1]['timestamp'])+':'+str(rows[-1]['id']) if more else ''}

    def host(self, uid):
        tenant_namespace(uid)
        return "u-" + uid + "." + self.tenant_authority

    def known_host(self, host):
        host = host.lower()
        if host == self.authority: return True
        prefix, separator, suffix = host.partition(".")
        if separator and suffix == self.tenant_authority and prefix.startswith("u-"):
            try:
                tenant_namespace(prefix[2:])
                return True
            except ValueError: pass
        return False

    def user(self, uid):
        with self.db() as db:
            row = db.execute("SELECT * FROM users WHERE uid=?", (uid,)).fetchone()
        if row is None: raise Rejected(401, "请重新登录。")
        return dict(row)

    def rate_limit(self, identities, count, window):
        now = self.clock()
        with self.db() as db:
            db.execute("BEGIN IMMEDIATE")
            for identity in identities:
                total = db.execute("SELECT count(*) FROM attempts WHERE identity=? AND timestamp>?",
                                   (identity, now-window)).fetchone()[0]
                if total >= count: raise Rejected(429, "操作过于频繁，请稍后再试。")
            db.executemany("INSERT INTO attempts VALUES (?,?)", [(key, now) for key in identities])

    def register(self, username, password, invitation, ip, *, password_confirmation=None,
                 recovery_question=None, recovery_answer=None):
        import re
        self.rate_limit(["register:" + ip], 10, 3600)
        if not isinstance(invitation, str) or not secrets.compare_digest(invitation, self.invitation):
            raise Rejected(403, "邀请码无效。")
        if not isinstance(username, str) or not re.fullmatch(r"[a-z][a-z0-9-]{2,31}", username):
            raise Rejected(400, "用户名需为 3–32 位小写字母、数字或连字符，以字母开头。")
        validate_password(password, password_confirmation)
        question, answer_salt, answer_hash = recovery_fields(recovery_question, recovery_answer)
        salt, uid = secrets.token_hex(16), secrets.token_hex(12)
        hashed = password_hash(password, salt)
        with self.db() as db:
            db.execute("BEGIN IMMEDIATE")
            count=db.execute("SELECT count(*) FROM users").fetchone()[0]
            if count >= self.max_users:
                raise Rejected(409, "注册名额已满，请联系管理员。")
            role='superadmin' if count==0 and not db.execute("SELECT 1 FROM portal_settings WHERE key='superadmin_bootstrapped'").fetchone() else 'user'
            try:
                db.execute("INSERT INTO users(uid,username,salt,password_hash,runtime_secret,last_human,"
                           "recovery_question,recovery_salt,recovery_hash,role) VALUES (?,?,?,?,?,?,?,?,?,?)",
                           (uid, username, salt, hashed, secrets.token_urlsafe(40), self.clock(), question, answer_salt, answer_hash,role))
                if role=='superadmin':db.execute("INSERT INTO portal_settings VALUES ('superadmin_bootstrapped','1')")
            except sqlite3.IntegrityError:
                raise Rejected(409, "用户名不可用。") from None
        return uid

    def management_login(self,username,password,ip):
        if not isinstance(username,str) or not isinstance(password,str) or len(username)>32 or len(password)>128:
            raise Rejected(401,'Invalid administrator credentials.')
        self.rate_limit(['admin-login-ip:'+ip],20,60)
        self.rate_limit(['admin-login-user:'+username],8,300)
        with self.db() as db:row=db.execute('SELECT * FROM users WHERE username=?',(username,)).fetchone()
        actual=password_hash(password,row['salt'] if row else self.dummy_salt)
        if not secrets.compare_digest(actual,row['password_hash'] if row else self.dummy_hash) or not row:
            raise Rejected(401,'Invalid administrator credentials.')
        with self.lock(row['uid']):
            user=self.user(row['uid'])
            if user['password_hash']!=row['password_hash'] or user['frozen'] or user['role'] not in ('admin','superadmin'):
                raise Rejected(401,'Invalid administrator credentials.')
            token=self.new_session(user['uid'],'admin',self.authority)
            self.event(user['uid'],'authentication','admin_login')
            return {'token':token,'uid':user['uid'],'username':user['username'],'role':user['role']}

    def management_identity(self,token,db=None):
        if db is None:
            with self.db() as db:return self.management_identity(token,db)
        if not isinstance(token,str):raise Rejected(401,'Administrator sign-in required.')
        row=db.execute("SELECT u.uid,u.username,u.role FROM sessions s JOIN users u ON u.uid=s.uid WHERE s.token_hash=? AND s.kind='admin' AND s.host=? AND s.expires>? AND u.frozen=0 AND u.role IN ('admin','superadmin')",(digest(token),self.authority,self.clock())).fetchone()
        if not row:raise Rejected(401,'Administrator sign-in required.')
        return dict(row)

    def set_management_role(self,token,uid,role,confirmation):
        if role not in ('user','admin'):raise Rejected(400,'Only user and administrator roles can be assigned here.')
        with self.db() as db:
            db.execute('BEGIN IMMEDIATE')
            actor=self.management_identity(token,db)
            if actor['role']!='superadmin':raise Rejected(403,'Only the superadministrator can manage administrator roles.')
            target=db.execute('SELECT username,role,frozen FROM users WHERE uid=?',(uid,)).fetchone()
            if not target:raise Rejected(404,'User does not exist.')
            if confirmation!=target['username']:raise Rejected(400,'Confirmation text does not match the target.')
            if target['role']=='superadmin':raise Rejected(403,'The superadministrator account is protected.')
            if target['frozen'] and role=='admin':raise Rejected(400,'Restore the frozen account before granting administrator access.')
            db.execute('UPDATE users SET role=? WHERE uid=?',(role,uid))
            db.execute("DELETE FROM sessions WHERE uid=? AND kind='admin'",(uid,))
        return {'uid':uid,'username':target['username'],'role':role}

    def login(self, username, password, ip, profile=None):
        if not isinstance(username, str) or not isinstance(password, str) or len(password) > 128:
            raise Rejected(401, "用户名或密码不正确。")
        self.rate_limit(["login-ip:" + ip], 20, 60)
        self.rate_limit(["login-user:" + username[:32]], 8, 300)
        with self.db() as db:
            row = db.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()
        actual = password_hash(password, row["salt"] if row else self.dummy_salt)
        if not secrets.compare_digest(actual, row["password_hash"] if row else self.dummy_hash) or not row:
            raise Rejected(401, "用户名或密码不正确。")
        with self.lock(row['uid']):
            # A concurrent password reset must not mint a session from an old hash.
            if self.user(row['uid'])['password_hash'] != row['password_hash']:
                raise Rejected(401, "用户名或密码不正确。")
            if self.user(row["uid"])["frozen"]: raise Rejected(403,"账号已冻结，请联系管理员。")
            token = self.new_session(row["uid"], "hub", self.authority)
            self.start(row["uid"],profile)
            self.event(row['uid'],'authentication','login')
            return token

    def recovery_question(self, username, ip):
        self.rate_limit(['recovery-question-ip:'+ip], 20, 60)
        if not isinstance(username, str) or len(username) > 32:
            raise Rejected(400, "请输入有效的用户名。")
        self.rate_limit(['recovery-question-user:'+username], 10, 300)
        with self.db() as db:
            row = db.execute('SELECT recovery_question FROM users WHERE username=?', (username,)).fetchone()
        if not row or not row['recovery_question']:
            raise Rejected(400, "该账号未设置备忘问题或不可用，请联系管理员。")
        return row['recovery_question']

    def set_recovery(self, session, password, question, answer):
        uid = session['uid']
        self.rate_limit(['recovery-setup:'+uid], 5, 900)
        if not isinstance(password, str) or len(password) > 128:
            raise Rejected(401, "当前密码不正确。")
        with self.lock(uid):
            self.authenticate_token_hash(session)
            row = self.user(uid)
            if not secrets.compare_digest(password_hash(password, row['salt']), row['password_hash']):
                raise Rejected(401, "当前密码不正确。")
            if row['recovery_hash']:
                raise Rejected(409, "备忘问题已设置。")
            question, salt, hashed = recovery_fields(question, answer)
            with self.db() as db:
                db.execute('UPDATE users SET recovery_question=?,recovery_salt=?,recovery_hash=? WHERE uid=?',
                           (question, salt, hashed, uid))

    def authenticate_token_hash(self, session):
        # Recheck under the tenant lock after an HTTP handler has authenticated.
        with self.db() as db:
            row = db.execute('SELECT 1 FROM sessions WHERE token_hash=? AND uid=? AND kind=? AND expires>?',
                             (session['token_hash'], session['uid'], 'hub', self.clock())).fetchone()
        if not row: raise Rejected(401, "会话已结束，请重新登录。")

    def reset_password(self, username, answer, password, confirmation, ip):
        if not isinstance(username, str) or len(username) > 32:
            raise Rejected(400, "请输入有效的用户名。")
        self.rate_limit(['recovery-reset-ip:'+ip], 20, 900)
        self.rate_limit(['recovery-reset-user:'+username], 5, 900)
        validate_password(password, confirmation)
        normalized = normalize_answer(answer)
        with self.db() as db:
            row = db.execute('SELECT * FROM users WHERE username=?', (username,)).fetchone()
        hashed = password_hash(normalized, row['recovery_salt'] if row and row['recovery_hash'] else self.dummy_salt)
        if not row or not row['recovery_hash'] or not secrets.compare_digest(hashed, row['recovery_hash']):
            raise Rejected(401, "用户名或备忘答案不正确，或该账号尚未设置备忘问题。")
        uid = row['uid']
        salt = secrets.token_hex(16)
        new_hash = password_hash(password, salt)
        with self.lock(uid):
            current = self.user(uid)
            if current['password_hash'] != row['password_hash'] or current['recovery_hash'] != row['recovery_hash']:
                raise Rejected(409, "账号信息已更新，请重新验证。")
            with self.db() as db:
                db.execute("UPDATE users SET salt=?,password_hash=?,state='stopping',reason='密码已重置，请重新登录。' WHERE uid=?",
                           (salt, new_hash, uid))
                db.execute('DELETE FROM sessions WHERE uid=?', (uid,))
                db.execute('DELETE FROM codes WHERE uid=?', (uid,))
                db.execute('DELETE FROM attempts WHERE identity=?', ('login-user:'+username,))
            try:
                self.stop(uid, '密码已重置，请重新登录。')
            except Exception as error:
                # Credentials are already changed and access revoked. The sweep
                # retries stopping the old Runtime; reporting failure invites a retry.
                LOG.error('Post-reset Runtime stop pending: %s', type(error).__name__)

    def new_session(self, uid, kind, host, expires=None):
        token = secrets.token_urlsafe(32)
        with self.db() as db:
            db.execute("INSERT INTO sessions VALUES (?,?,?,?,?)",
                       (digest(token), uid, kind, host, expires or self.clock()+8*3600))
        return token

    def authenticate(self, token, host, kind):
        with self.db() as db:
            row = db.execute("SELECT * FROM sessions WHERE token_hash=? AND host=? AND kind=? AND expires>?",
                             (digest(token), host.lower(), kind, self.clock())).fetchone()
        if row is None: raise Rejected(401, "会话已结束，请重新登录。")
        if self.user(row["uid"])["frozen"]: raise Rejected(403,"账号已冻结，请联系管理员。")
        return dict(row)

    def start(self, uid, profile=None, *, resources=None, actor=None):
        with self.lock(uid), self.db() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT state,frozen FROM users WHERE uid=?", (uid,)).fetchone()
            if row is None: raise Rejected(404,"用户不存在。")
            if row['frozen']: raise Rejected(403,"账号已冻结，请联系管理员。")
            if profile=='custom' and resources is not None:
                try:size=workspace_resources(resources)
                except ValueError as error:raise Rejected(400,str(error)) from None
            elif profile is not None and profile in self.profiles and resources is None:size=self.profiles[profile]
            elif profile is not None or resources is not None:raise Rejected(400,"工作空间配置无效。")
            if row[0] in ("starting", "running", "restarting"):
                db.execute("UPDATE users SET last_human=? WHERE uid=?", (self.clock(), uid))
                return
            if profile is not None:
                db.execute('UPDATE users SET profile=?,resource_cpu=?,resource_memory=? WHERE uid=?',(profile,size['cpu'],size['memory'],uid))
            total = db.execute("SELECT count(*) FROM users WHERE state IN ('starting','running','restarting','stopping')").fetchone()[0]
            if total >= self.max_running:
                raise Rejected(409, "当前实例名额已满，请稍后点击重连。")
            db.execute("UPDATE users SET state='starting',reason='',entry_error='',started=?,last_human=? WHERE uid=?",
                       (self.clock(), self.clock(), uid))
            self.event(uid,'workspace','start_requested',db=db,status='requested',actor=actor)
        self.pool.submit(self._provision, uid)

    def restart(self, session):
        uid = session['uid']
        self.rate_limit(['restart:' + uid], 3, 300)
        return self.restart_workspace(uid, session=session)

    def restart_workspace(self, uid, profile=None, *, resources=None, actor=None, session=None):
        """Replace the Pod template for both user and administrator restarts."""
        with self.lock(uid):
            if session is not None:
                self.authenticate_token_hash(session)
            user = self.user(uid)
            if user['frozen']:
                raise Rejected(403, "账号已冻结，请联系管理员。")
            size = None
            if profile == 'custom' and resources is not None:
                try: size = workspace_resources(resources)
                except ValueError as error: raise Rejected(400, str(error)) from None
            elif profile is not None and profile in self.profiles and resources is None:
                size = self.profiles[profile]
            elif profile is not None or resources is not None:
                raise Rejected(400, "工作空间配置无效。")
            if user['state'] in ('starting', 'restarting', 'stopping'):
                raise Rejected(409, '工作空间正在启动或停止，请稍候。')
            if user['state'] != 'running':
                return self.start(uid, profile, resources=resources, actor=actor)
            with self.db() as db:
                # Keep the hub login and PVC; discard credentials for the old UI.
                if size is not None:
                    db.execute('UPDATE users SET profile=?,resource_cpu=?,resource_memory=? WHERE uid=?',
                               (profile, size['cpu'], size['memory'], uid))
                db.execute("DELETE FROM sessions WHERE uid=? AND kind NOT IN ('hub','admin')", (uid,))
                db.execute('DELETE FROM codes WHERE uid=?', (uid,))
                db.execute("UPDATE users SET state='restarting',entry_error='',reason='',started=?,last_human=? WHERE uid=?",
                           (self.clock(), self.clock(), uid))
                self.event(uid,'workspace','restart_requested',db=db,status='requested',actor=actor)
            self.pool.submit(self._provision, uid, True)

    def _provision(self, uid, restart=False):
        with self.lock(uid):
            user = self.user(uid)
            if user["state"] != ("restarting" if restart else "starting"): return
            try:
                resources={'cpu':user['resource_cpu'],'memory':user['resource_memory']} if user['resource_cpu'] else None
                options={'resources':resources} if resources else {}
                if restart:
                    self.kube.ensure(uid, user["runtime_secret"], restart=True,**options)
                    # A ready old generation must not finish the restart before
                    # the new template has been accepted by Kubernetes.
                    with self.db() as db:
                        db.execute("UPDATE users SET state='starting' WHERE uid=? AND state='restarting'", (uid,))
                else:
                    self.kube.ensure(uid, user["runtime_secret"],**options)
            except Exception as error:
                LOG.error("Tenant %s provision failed: %s status=%s", uid, type(error).__name__, getattr(error, "status", "n/a"))
                try: self.kube.stop(uid)
                except Exception: pass
                with self.db() as db:
                    db.execute("UPDATE users SET state='error',reason='实例启动失败，请重试或联系管理员。' WHERE uid=?", (uid,))
                    self.event(uid,'workspace','start_failed',db=db,status='failed',actor='system',detail=type(error).__name__)

    def status(self, uid):
        user = self.user(uid)
        if user["state"] == "starting" and self.kube.ready(uid):
            with self.db() as db:
                changed=db.execute("UPDATE users SET state='running',last_human=? WHERE uid=? AND state='starting'",
                                   (self.clock(), uid)).rowcount
                if changed:self.event(uid,'workspace','workspace_ready',db=db,actor='system')
            user = self.user(uid)
        ready = user["state"] == "running" and self.kube.ready(uid)
        instance = self.kube.instance(uid) if ready else ""
        ready = ready and bool(instance)
        connection_error = user['entry_error'] if user['state'] == 'running' else ''
        if user['state'] == 'running' and not ready:
            connection_error = connection_error or '工作空间暂时不可用，请重试连接；若持续失败，可重启工作空间。'
        return {"connectionError": connection_error, "canRestart": bool(connection_error), "runtimeInstance": instance,
                "profile":user["profile"],"resources":{"cpu":user["resource_cpu"] or getattr(self.kube,"config",{}).get("cpu",""),"memory":user["resource_memory"] or getattr(self.kube,"config",{}).get("memory","")},
                "username": user["username"], "state": user["state"], "ready": ready, "portalOrigin": self.origin,
                "recoveryConfigured": bool(user['recovery_hash']),
                "message": user["reason"], "idleSeconds": self.idle_seconds,
                "idleRemaining": max(0, int(self.idle_seconds-(self.clock()-user["last_human"]))) }

    def launch(self, session, *, automatic=False):
        uid = session["uid"]
        self.rate_limit(['launch:'+uid],30,60)
        if not self.status(uid)["ready"]: raise Rejected(409, "实例仍在启动，请稍候。")
        # A fresh visit/reconnect is an explicit connection action. Polling
        # status or keeping a WebSocket open still cannot extend idle time.
        if not automatic: self.activity(session)
        code = secrets.token_urlsafe(32)
        with self.db() as db:
            db.execute("INSERT INTO codes VALUES (?,?,?,?)", (digest(code), uid, session["token_hash"], self.clock()+30))
        return self.scheme + "://" + self.host(uid) + "/_portal/claim?code=" + code

    def claim(self, code, host):
        with self.db() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT c.*,s.expires AS session_expires FROM codes c JOIN sessions s ON c.issuer=s.token_hash "
                             "WHERE c.token_hash=? AND c.expires>? AND s.expires>? AND s.kind='hub'",
                             (digest(code), self.clock(), self.clock())).fetchone()
            if row is None or self.host(row["uid"]) != host:
                raise Rejected(401, "登录跳转已过期，请返回入口重试。")
            db.execute("DELETE FROM codes WHERE token_hash=?", (digest(code),))
            token = secrets.token_urlsafe(32)
            db.execute("INSERT INTO sessions VALUES (?,?,?,?,?)",
                       (digest(token), row["uid"], "tenant", host, row["session_expires"]))
        return token

    def activity(self, session):
        with self.db() as db:
            db.execute("UPDATE users SET last_human=? WHERE uid=? AND state='running'", (self.clock(), session["uid"]))

    def resume(self, session):
        # Reuse the live browser client; issuing another entry request would
        # reconstruct AppContainer and discard transient dialogs/view state.
        with self.lock(session['uid']):
            if self.user(session['uid'])['state'] != 'running':
                raise Rejected(409, '原工作空间已不可用，请重新启动。')
            state = self.status(session['uid'])
            if state['connectionError']:
                raise Rejected(503, state['connectionError'])
            self.activity(session)
            return self.status(session['uid'])

    def entry(self, uid):
        user=self.user(uid)
        if user['state']!='running': raise Rejected(401,'实例已释放，请重新登录。')
        connection=http.client.HTTPConnection('runtime.'+tenant_namespace(uid)+'.svc.cluster.local',8080,timeout=12)
        credential=base64.b64encode(('runtime:'+user['runtime_secret']).encode()).decode()
        try:
            connection.request('GET','/online',headers={'Authorization':'Basic '+credential})
            response=connection.getresponse();body=response.read(1024*1024+1)
            if response.status not in (200,409) or len(body)>1024*1024:
                raise OSError('Runtime entry unavailable')
            with self.db() as db:
                db.execute("UPDATE users SET entry_error='' WHERE uid=? AND state='running'", (uid,))
            return response.status,body.replace(b'<head>',b'<head><script src="/_portal/bridge.js"></script><script src="/_portal/activity.js" defer></script>',1)
        except (OSError, http.client.HTTPException):
            message = '工作空间未能响应。请重试连接；若持续失败，可返回入口重启工作空间。'
            with self.db() as db:
                db.execute("UPDATE users SET entry_error=? WHERE uid=? AND state='running'", (message, uid))
            raise Rejected(503, message) from None
        finally: connection.close()

    def stop(self, uid, reason, keep_login=False, *, logout=False, actor='system'):
        if logout:actor=None
        with self.lock(uid):
            with self.db() as db:
                current=db.execute('SELECT state FROM users WHERE uid=?',(uid,)).fetchone()
                active=current and current['state']!='stopped'
                db.execute("UPDATE users SET state='stopping',reason=? WHERE uid=?", (reason, uid))
                if keep_login:
                    db.execute("DELETE FROM sessions WHERE uid=? AND kind NOT IN ('hub','admin')", (uid,))
                else:
                    db.execute("DELETE FROM sessions WHERE uid=? AND kind<>'admin'", (uid,))
                db.execute("DELETE FROM codes WHERE uid=?", (uid,))
                if logout:self.event(uid,'authentication','logout',db=db)
                if active:self.event(uid,'workspace','stop_requested',db=db,status='requested',detail=reason,actor=actor)
            try:self.kube.stop(uid)
            except Exception:
                self.event(uid,'workspace','stop_failed',status='failed',detail=reason,actor=actor)
                raise
            with self.db() as db:
                db.execute("UPDATE users SET state='stopped' WHERE uid=?", (uid,))
                if active:self.event(uid,'workspace','workspace_stopped',db=db,detail=reason,actor=actor)

    def sweep(self):
        now = self.clock()
        with self.db() as db:
            users = [dict(row) for row in db.execute("SELECT * FROM users WHERE state IN ('starting','running','restarting','stopping')")]
            db.execute("DELETE FROM attempts WHERE timestamp<?", (now-3600,))
            db.execute("DELETE FROM codes WHERE expires<?", (now,))
            db.execute("DELETE FROM sessions WHERE expires<?", (now,))
        for user in users:
            try:
                if user["state"] == "starting": self.status(user["uid"])
                threshold = 450 if user["state"] in ("starting", "restarting") else self.idle_seconds
                if user["state"] == "stopping" or now-user["last_human"] >= threshold:
                    # Recheck under the same lock as user input and startup.
                    with self.lock(user["uid"]):
                        current = self.user(user["uid"])
                        cutoff = 450 if current["state"] in ("starting", "restarting") else self.idle_seconds
                        if current["state"] == "stopping" or now-current["last_human"] >= cutoff:
                            self.stop(user["uid"], "长时间未操作，实例已释放。已保存文件和设置仍保留。")
            except Exception as error:
                LOG.error("Tenant reconciliation failed: %s", type(error).__name__)


def cookies(header):
    parsed = SimpleCookie()
    try: parsed.load(header or "")
    except Exception: return {}
    return {key: value.value for key, value in parsed.items()}


class Handler(BaseHTTPRequestHandler):
    server_version = "KSSOLV"
    def log_message(self, *_): pass  # Never log passwords, cookies or one-time codes.

    @property
    def portal(self): return self.server.portal

    def client_ip(self):
        # Only our loopback gateway knows this per-process credential. Merely
        # submitting a forwarded-IP header to NodePort must not change limits.
        peer = ipaddress.ip_address(self.client_address[0])
        credentials = self.headers.get_all('X-KSSOLV-Proxy-Token', [])
        identities = self.headers.get_all('X-KSSOLV-Client-IP', [])
        if (peer.is_loopback and len(credentials) == 1 and len(identities) == 1
                and credentials[0].isascii()
                and secrets.compare_digest(credentials[0], self.server.proxy_token)):
            try:
                return str(ipaddress.ip_address(identities[0]))
            except ValueError:
                pass
        return str(peer)

    def respond(self, status=200, data=None, headers=None, raw=None, content_type="application/json; charset=utf-8", content_security_policy=None):
        body = raw if raw is not None else json.dumps(data or {}, ensure_ascii=False).encode()
        self.send_response(status)
        for key, value in (headers or {}).items(): self.send_header(key, value)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Content-Type-Options", "nosniff")
        if self.path != "/internal/auth":
            frames = self.portal.scheme + "://*." + self.portal.tenant_authority
            ancestors = self.portal.origin if urlsplit(self.path).path == '/_portal/claim' else "'none'"
            style_hash = base64.b64encode(hashlib.sha256((PUBLIC / 'critical.css').read_bytes()).digest()).decode()
            policy = "frame-ancestors " + ancestors if urlsplit(self.path).path == '/_portal/claim' else "default-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self' 'sha256-" + style_hash + "'; frame-src " + frames + "; object-src 'none'; base-uri 'none'; frame-ancestors " + ancestors
            if urlsplit(self.path).path == '/_portal/favicon.svg':
                policy = "default-src 'none'; img-src data:; base-uri 'none'; frame-ancestors 'none'"
            self.send_header("Content-Security-Policy", content_security_policy or policy)
        self.end_headers()
        self.wfile.write(body)

    def respond_error(self, status, message, *, page=False):
        if not page:
            return self.respond(status, {"error": message})
        # Reuse the account dialog theme inline so the recovery page renders
        # immediately, even when other resources or Runtime are unavailable.
        style = (PUBLIC / 'style.css').read_text()
        expired = status == 401
        replacements = {
            '__ERROR_TITLE__': '连接已过期' if expired else '暂时无法打开工作空间',
            '__ERROR_MESSAGE__': html.escape(message),
            '__RECONNECT_LABEL__': '重新登录' if expired else '重新连接',
            '__ENTRY_URL__': html.escape(self.portal.origin + '/online', quote=True),
            '__PORTAL_STYLE__': style,
        }
        document = (PUBLIC / 'entry-error.html').read_text()
        for key, value in replacements.items(): document = document.replace(key, value)
        digest = base64.b64encode(hashlib.sha256(style.encode()).digest()).decode()
        ancestors = self.portal.origin if urlsplit(self.path).path != '/online' else "'none'"
        policy = ("default-src 'none'; style-src 'sha256-" + digest + "'; img-src 'self'; script-src 'self'; "
                  "form-action " + self.portal.origin + "; base-uri 'none'; frame-ancestors " + ancestors)
        return self.respond(status, raw=document.encode(), content_type='text/html; charset=utf-8',
                            content_security_policy=policy)

    def page_request(self, write):
        host = self.headers.get('X-Original-Host', self.headers.get('Host', '')).lower()
        return (not write and self.portal.known_host(host) and urlsplit(self.path).path in
                ('/online', '/_portal/', '/_portal/claim', '/_portal/connection-error'))

    def set_cookie(self, name, value):
        if self.portal.scheme == 'https': name='__Host-'+name
        return name + "=" + value + "; Path=/; HttpOnly; SameSite=Lax; Max-Age=28800" + ("; Secure" if self.portal.scheme == "https" else "")

    def session(self, kind=None):
        host = self.headers.get("X-Original-Host", self.headers.get("Host", "")).lower()
        kind = kind or ("hub" if host == self.portal.authority else "tenant")
        name = "kssolv_hub" if kind == "hub" else "kssolv_tenant"
        if self.portal.scheme == 'https': name='__Host-'+name
        return self.portal.authenticate(cookies(self.headers.get("Cookie")).get(name, ""), host, kind)

    def do_GET(self): self.handle_request(False)
    def do_POST(self): self.handle_request(True)

    def handle_request(self, write):
        try: self.dispatch(write)
        except Rejected as error:
            self.respond_error(error.status, error.message, page=self.page_request(write))
        except (BrokenPipeError, ConnectionResetError): pass
        except Exception as error:
            LOG.error("Request failed: %s", type(error).__name__)
            self.respond_error(503, "服务暂时不可用，请稍后重试。", page=self.page_request(write))

    def dispatch(self, write):
        portal = self.portal
        host = self.headers.get("X-Original-Host", self.headers.get("Host", "")).lower()
        path = urlsplit(self.path).path
        if path == "/healthz": return self.respond(data={"ready": True})
        if path.startswith('/_portal/internal-admin/'):
            from portal_control import dispatch
            return dispatch(self,write)
        if not portal.known_host(host): raise Rejected(400, "入口域名无效。")
        if write:
            if self.headers.get("Origin") != portal.scheme + "://" + host:
                raise Rejected(403, "请求来源无效，请从本站重新登录。")
            if self.headers.get("Content-Type", "").split(";")[0] != "application/json":
                raise Rejected(415, "请求格式无效。")
            try: length = int(self.headers.get("Content-Length", "0"))
            except ValueError: raise Rejected(400, "请求格式无效。") from None
            if not 0 <= length <= 8192: raise Rejected(413, "请求过大。")
            try: data = json.loads(self.rfile.read(length))
            except (ValueError, UnicodeDecodeError): raise Rejected(400, "请求格式无效。") from None
            if not isinstance(data, dict): raise Rejected(400, "请求格式无效。")
        else: data = {}
        if path == "/internal/auth" and not write:
            origin = self.headers.get("X-Original-Origin", "")
            if origin and origin != portal.scheme + "://" + host:
                raise Rejected(403, "跨站连接被拒绝。")
            session = self.session("tenant")
            user = portal.user(session["uid"])
            if user["state"] != "running": raise Rejected(401, "实例已释放，请重新登录。")
            raw_cookie = SimpleCookie()
            raw_cookie.load(self.headers.get("Cookie", ""))
            for name in ("kssolv_hub", "kssolv_tenant", "__Host-kssolv_hub", "__Host-kssolv_tenant"): raw_cookie.pop(name, None)
            forwarded = "; ".join(item.OutputString() for item in raw_cookie.values())
            credential = base64.b64encode(("runtime:" + user["runtime_secret"]).encode()).decode()
            return self.respond(headers={"X-KSSOLV-Upstream": "runtime." + tenant_namespace(user["uid"]) + ".svc.cluster.local:8080",
                                         "X-KSSOLV-Authorization": "Basic " + credential,
                                         "X-KSSOLV-Cookie": forwarded})
        if path == "/_portal/connection-error" and not write:
            return self.respond_error(401, '会话已结束，请重新登录。', page=True)
        if path == "/_portal/claim" and not write:
            token = portal.claim(parse_qs(urlsplit(self.path).query).get("code", [""])[0], host)
            session=portal.authenticate(token,host,'tenant')
            status,page=portal.entry(session['uid'])
            return self.respond(status,headers={"Set-Cookie": self.set_cookie("kssolv_tenant", token)},raw=page,content_type='text/html; charset=utf-8')
        if path == "/_portal/favicon.svg" and not write:
            state = parse_qs(urlsplit(self.path).query).get('state', ['idle'])[0]
            colors = {'connected': '#228b45', 'slow': '#e5a600', 'disconnected': '#d93025'}
            icon = (PUBLIC / 'favicon.svg').read_text()
            if state == 'inactive': icon = icon.replace('#074c86', '#8c8c8c')
            if state in colors:
                icon = icon.replace('<!--STATUS-->', '<circle cx="53" cy="53" r="9" fill="' + colors[state] + '" stroke="white" stroke-width="2.5"/>')
            return self.respond(raw=icon.encode(), content_type='image/svg+xml')
        if path == "/_portal/favicon.js" and not write:
            return self.respond(raw=(PUBLIC / 'favicon.js').read_bytes(), content_type='text/javascript; charset=utf-8')
        if path in ("/_portal/activity.js", "/_portal/bridge.js", "/_portal/entry-error.js", "/_portal/i18n.js", "/_portal/sizes.js") and not write:
            source = (PUBLIC / path.rsplit("/", 1)[1]).read_text().replace("__PORTAL_ORIGIN__", json.dumps(portal.origin))
            return self.respond(raw=source.encode(), content_type="text/javascript; charset=utf-8")
        if path == "/_portal/api/session" and not write:
            session = self.session("tenant")
            if portal.user(session["uid"])["state"] != "running": raise Rejected(401, "实例已释放。")
            return self.respond(data=portal.status(session["uid"]))
        if path == "/_portal/api/activity" and write:
            session = self.session("tenant")
            with portal.lock(session["uid"]):
                if portal.user(session["uid"])["state"] != "running": raise Rejected(401, "实例已释放。")
                portal.activity(session)
            return self.respond(data=portal.status(session["uid"]))
        if path in ("/_portal/api/logout", "/_portal/api/exit") and write and host != portal.authority:
            session = self.session("tenant")
            if path.endswith('/exit'):
                # Returning to the entry page keeps both the Runtime and its
                # authenticated browser connection until normal idle expiry.
                state=portal.resume(session)
                portal.event(session['uid'],'workspace','workspace_left')
                return self.respond(data=state)
            portal.stop(session["uid"], "已退出登录，实例已释放。",logout=True)
            return self.respond(data={"ok": True}, headers={"Set-Cookie": self.set_cookie("kssolv_tenant", "") + "; Max-Age=0"})
        if host != portal.authority: raise Rejected(404, "请从登录入口访问。")
        if path in ("/online", "/_portal/", "/_portal/app.js", "/_portal/style.css") and not write:
            filename = {"/online": "index.html", "/_portal/": "index.html", "/_portal/app.js": "app.js", "/_portal/style.css": "style.css"}[path]
            content_type = {"index.html": "text/html", "app.js": "text/javascript", "style.css": "text/css"}[filename]
            body = (PUBLIC / filename).read_bytes()
            if filename == 'index.html':
                body = body.replace(b'__PORTAL_CRITICAL_CSS__', (PUBLIC / 'critical.css').read_bytes())
            return self.respond(raw=body, content_type=content_type + "; charset=utf-8")
        if path == '/_portal/api/profiles' and not write:
            return self.respond(data={'profiles':portal.profiles,'default':'medium'})
        if path == "/_portal/api/register" and write:
            portal.register(data.get("username"), data.get("password"), data.get("invitation"), self.client_ip(),
                            password_confirmation=data.get('passwordConfirmation'),
                            recovery_question=data.get('recoveryQuestion'), recovery_answer=data.get('recoveryAnswer'))
            return self.respond(201, {"message": "注册成功，请使用新账号登录。"})
        if path == '/_portal/api/recovery-question' and write:
            return self.respond(data={'question': portal.recovery_question(data.get('username'), self.client_ip())})
        if path == '/_portal/api/reset-password' and write:
            portal.reset_password(data.get('username'), data.get('recoveryAnswer'), data.get('password'),
                                  data.get('passwordConfirmation'), self.client_ip())
            return self.respond(data={'message': '密码已重置，请使用新密码登录。'},
                                headers={'Set-Cookie': self.set_cookie('kssolv_hub', '')+'; Max-Age=0'})
        if path == "/_portal/api/login" and write:
            token = portal.login(data.get("username"), data.get("password"), self.client_ip(),data.get("profile"))
            return self.respond(headers={"Set-Cookie": self.set_cookie("kssolv_hub", token)}, data={"ok": True})
        session = self.session("hub")
        if path == '/_portal/api/recovery-setup' and write:
            portal.set_recovery(session, data.get('password'), data.get('recoveryQuestion'), data.get('recoveryAnswer'))
            return self.respond(data={'ok': True})
        if path == "/_portal/api/me" and not write:
            return self.respond(data=portal.status(session["uid"]))
        if path == "/_portal/api/restart" and write:
            portal.restart(session)
            return self.respond(202, {"ok": True})
        if path == "/_portal/api/start" and write:
            portal.start(session["uid"],data.get("profile"))
            return self.respond(202, {"ok": True})
        if path == "/_portal/api/launch" and write:
            url = portal.launch(session, automatic=data.get('automatic') is True)
            return self.respond(data={"url": url, "runtimeInstance": portal.status(session['uid'])['runtimeInstance']})
        if path == '/_portal/api/resume' and write:
            return self.respond(data=portal.resume(session))
        if path == "/_portal/api/logout" and write:
            portal.stop(session["uid"], "已退出登录，实例已释放。",logout=True)
            return self.respond(headers={"Set-Cookie": self.set_cookie("kssolv_hub", "") + "; Max-Age=0"})
        raise Rejected(404, "页面不存在。")


class Server(ThreadingHTTPServer):
    daemon_threads = True
    def __init__(self, address, portal):
        self.portal = portal
        self.proxy_token = secrets.token_urlsafe(32)
        self.slots = threading.BoundedSemaphore(32)
        super().__init__(address, Handler)

    def process_request(self, request, address):
        if not self.slots.acquire(blocking=False):
            request.close()
            return
        try: super().process_request(request, address)
        except Exception:
            self.slots.release()
            raise

    def process_request_thread(self, request, address):
        try: super().process_request_thread(request, address)
        finally: self.slots.release()


def gateway_config(portal, proxy_token, resolver, trusted_proxies=()):
    # Real-IP rewriting is opt-in for explicitly trusted edge addresses. Do
    # not trust all private networks: NodePort may also receive direct traffic.
    trusted = [str(ipaddress.ip_network(value, strict=False)) for value in trusted_proxies]
    directives = '\n'.join('    set_real_ip_from ' + value + ';' for value in trusted)
    if trusted:
        directives += '\n    real_ip_header X-Forwarded-For;\n    real_ip_recursive on;'
    source = Path(__file__).with_name('nginx.conf').read_text()
    return (source.replace('__RESOLVER__', resolver).replace('__HUB_HOST__', portal.hostname)
            .replace('__ORIGIN__', portal.origin).replace('__TRUSTED_PROXIES__', directives)
            .replace('__PROXY_TOKEN__', proxy_token))


def main():
    os.umask(0o077)
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    config = json.loads(Path(os.environ["KSSOLV_PORTAL_CONFIG"]).read_text())
    if not config.get("runtime_license_accepted"):
        raise ValueError("Accept the MATLAB Runtime license in the deployment configuration")
    portal = Portal("/data/portal", config["origin"], os.environ["REGISTRATION_CODE"], Kubernetes(config),
                    idle_seconds=config["idle_seconds"], max_running=config["max_running"], max_users=config["max_users"],
                    tenant_domain=config.get('tenant_domain'))
    server = Server(("127.0.0.1", 8091), portal)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    resolver = next(line.split()[1] for line in Path("/etc/resolv.conf").read_text().splitlines() if line.startswith("nameserver "))
    conf = gateway_config(portal, server.proxy_token, resolver, config.get('trusted_proxies', []))
    Path("/tmp/nginx.conf").write_text(conf)
    subprocess.run(["nginx", "-t", "-c", "/tmp/nginx.conf"], check=True)
    nginx = subprocess.Popen(["nginx", "-c", "/tmp/nginx.conf", "-g", "daemon off;"])
    stopping = threading.Event()
    for sig in (signal.SIGTERM, signal.SIGINT): signal.signal(sig, lambda *_: stopping.set())
    try:
        while not stopping.is_set():
            if nginx.poll() is not None: raise RuntimeError("Portal nginx exited")
            portal.sweep()
            stopping.wait(config.get("sweep_seconds", 15))
    finally:
        nginx.terminate()
        nginx.wait(timeout=10)
        server.shutdown()
        portal.pool.shutdown(wait=True)


if __name__ == "__main__": main()
