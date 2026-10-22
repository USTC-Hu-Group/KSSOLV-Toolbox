"""Recovery must preserve tenant identity and revoke every old authentication path."""

import _k8s_paths
import http.client
import json
from pathlib import Path
import secrets
import sqlite3
import tempfile
import threading
import unittest
from unittest.mock import patch

import portal as module
from portal import Portal, Rejected, Server, password_hash
from test_portal import FakeKube, INVITATION, ORIGIN, PASSWORD, RECOVERY

NEW_PASSWORD = 'new-test-only-password-67890'


class RecoveryTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.now = 1000
        self.kube = FakeKube()
        self.portal = Portal(self.directory.name, ORIGIN, INVITATION, self.kube, clock=lambda: self.now)

    def tearDown(self):
        self.portal.pool.shutdown(wait=True)
        self.directory.cleanup()

    def account(self, name='alice', **overrides):
        return self.portal.register(name, PASSWORD, INVITATION, 'test', **(RECOVERY | overrides))

    def reject(self, status, callback, *args, **kwargs):
        with self.assertRaises(Rejected) as error:
            callback(*args, **kwargs)
        self.assertEqual(error.exception.status, status)
        return error.exception.message

    def reset_password(self, username='alice', answer=RECOVERY['recovery_answer'], password=NEW_PASSWORD, confirmation=NEW_PASSWORD, ip='test'):
        return self.portal.reset_password(username, answer, password, confirmation, ip)

    def test_registration_requires_matching_passwords_and_nonempty_recovery(self):
        for fields in ({'password_confirmation': None}, {'password_confirmation': 'different'},
                       {'recovery_question': ''}, {'recovery_question': 'x'*201},
                       {'recovery_answer': ''}, {'recovery_answer': ' '*10}, {'recovery_answer': []}):
            with self.subTest(fields=fields):
                self.reject(400, self.account, **fields)
        with self.portal.db() as db:
            self.assertEqual(db.execute('SELECT count(*) FROM users').fetchone()[0], 0)
        uid = self.account()
        row = self.portal.user(uid)
        self.assertEqual(row['recovery_question'], RECOVERY['recovery_question'])
        self.assertNotEqual(row['recovery_salt'], row['salt'])
        self.assertNotIn(RECOVERY['recovery_answer'], str(row))
        self.assertNotIn(RECOVERY['recovery_answer'].encode(), self.portal.dbfile.read_bytes())

    def test_correct_answer_resets_password_revokes_sessions_and_preserves_other_user(self):
        uid, other_uid = self.account(), self.account('bob')
        secret = self.portal.user(uid)['runtime_secret']
        hub = self.portal.login('alice', PASSWORD, 'test')
        other_hub = self.portal.login('bob', PASSWORD, 'test')
        with self.kube.changed:
            self.assertTrue(self.kube.changed.wait_for(lambda:self.kube.ready(uid) and self.kube.ready(other_uid), timeout=3))
        self.portal.status(uid)
        session = self.portal.authenticate(hub, self.portal.authority, 'hub')
        host = self.portal.host(uid)
        tenant = self.portal.claim(self.portal.launch(session).split('code=')[1], host)
        pending_code = self.portal.launch(session).split('code=')[1]
        original = self.portal.user(uid)
        self.reset_password(answer='  TEST-ONLY-PRIVATE-ANSWER  ')
        changed = self.portal.user(uid)
        self.assertEqual((changed['uid'], changed['runtime_secret']), (uid, secret))
        self.assertNotEqual(changed['salt'], original['salt'])
        self.assertNotEqual(changed['password_hash'], original['password_hash'])
        self.assertEqual(changed['state'], 'stopped')
        self.assertFalse(self.kube.ready(uid))
        self.assertTrue(self.kube.ready(other_uid))
        self.reject(401, self.portal.authenticate, hub, self.portal.authority, 'hub')
        self.reject(401, self.portal.authenticate, tenant, host, 'tenant')
        self.reject(401, self.portal.claim, pending_code, host)
        self.portal.authenticate(other_hub, self.portal.authority, 'hub')
        self.reject(401, self.portal.login, 'alice', PASSWORD, 'test')
        token = self.portal.login('alice', NEW_PASSWORD, 'test')
        self.assertEqual(self.portal.authenticate(token, self.portal.authority, 'hub')['uid'], uid)

    def test_wrong_answers_and_invalid_confirmation_leave_credentials_and_sessions_untouched(self):
        uid = self.account()
        hub = self.portal.new_session(uid, 'hub', self.portal.authority)
        before = self.portal.user(uid)
        self.reject(400, self.reset_password, confirmation='not-matching')
        self.reject(400, self.reset_password, password='short', confirmation='short')
        self.reject(401, self.reset_password, answer='wrong-answer')
        self.reject(401, self.reset_password, username='unknown')
        self.assertEqual(self.portal.user(uid), before)
        self.portal.authenticate(hub, self.portal.authority, 'hub')
        self.assertFalse(self.kube.stopped)

    def test_reset_rate_limit_follows_account_across_ips_and_expires(self):
        self.account()
        for index in range(5):
            self.reject(401, self.reset_password, answer='incorrect', ip=str(index))
        self.reject(429, self.reset_password, ip='another-ip')
        self.now += 901
        self.reset_password()

    def test_successful_recovery_clears_only_own_password_login_lockout(self):
        self.account(); self.account('bob')
        for _ in range(8):
            self.reject(401, self.portal.login, 'alice', 'wrong-password', 'test')
        self.reject(401, self.portal.login, 'bob', 'wrong-password', 'test')
        self.reject(429, self.portal.login, 'alice', PASSWORD, 'test')
        self.reset_password()
        self.portal.login('alice', NEW_PASSWORD, 'test')
        with self.portal.db() as db:
            self.assertEqual(db.execute("SELECT count(*) FROM attempts WHERE identity='login-user:bob'").fetchone()[0], 1)
            self.assertEqual(db.execute("SELECT count(*) FROM attempts WHERE identity='recovery-reset-user:alice'").fetchone()[0], 1)

    def test_question_lookup_limit_and_unknown_account_message(self):
        self.account()
        for _ in range(10):
            self.assertEqual(self.portal.recovery_question('alice', 'test'), RECOVERY['recovery_question'])
        self.reject(429, self.portal.recovery_question, 'alice', 'other-ip')
        self.now += 301
        self.assertEqual(self.portal.recovery_question('alice', 'test'), RECOVERY['recovery_question'])
        self.reject(400, self.portal.recovery_question, 'unknown', 'test')

    def test_control_plane_failure_after_reset_does_not_restore_old_access(self):
        uid = self.account()
        hub = self.portal.new_session(uid, 'hub', self.portal.authority)
        self.kube.fail_stop = True
        with self.assertLogs('kssolv.portal', level='ERROR'):
            self.reset_password()
        self.assertEqual(self.portal.user(uid)['state'], 'stopping')
        self.reject(401, self.portal.authenticate, hub, self.portal.authority, 'hub')
        self.reject(401, self.portal.login, 'alice', PASSWORD, 'test')
        self.kube.fail_stop = False
        self.portal.sweep()
        self.assertEqual(self.portal.user(uid)['state'], 'stopped')

    def test_old_password_verified_during_reset_cannot_issue_a_late_session(self):
        self.account()
        verified, release = threading.Event(), threading.Event()
        result = []
        def slow_hash(value, salt):
            value_hash = password_hash(value, salt)
            if threading.current_thread().name == 'old-password-login':
                verified.set()
                if not release.wait(5): raise TimeoutError('reset did not finish')
            return value_hash
        def login():
            try: result.append(self.portal.login('alice', PASSWORD, 'test'))
            except Rejected as error: result.append(error.status)
        with patch.object(module, 'password_hash', slow_hash):
            thread = threading.Thread(target=login, name='old-password-login')
            thread.start()
            try:
                self.assertTrue(verified.wait(5))
                self.reset_password()
            finally:
                release.set(); thread.join(5)
        self.assertEqual(result, [401])
        with self.portal.db() as db:
            self.assertEqual(db.execute('SELECT count(*) FROM sessions').fetchone()[0], 0)

    def test_http_registration_recovery_origin_and_tenant_boundaries(self):
        server = Server(('127.0.0.1', 0), self.portal)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        def request(endpoint, data, origin=ORIGIN, host=None, cookie=None):
            connection = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=5)
            headers = {'Host': host or self.portal.authority, 'Origin': origin, 'Content-Type': 'application/json'}
            if cookie: headers['Cookie'] = cookie
            try:
                connection.request('POST', '/_portal/api/'+endpoint, json.dumps(data), headers)
                response = connection.getresponse()
                return response.status, dict(response.getheaders()), json.loads(response.read())
            finally: connection.close()
        try:
            registration = {'username':'alice', 'password':PASSWORD, 'invitation':INVITATION,
                            'passwordConfirmation':PASSWORD, 'recoveryQuestion':RECOVERY['recovery_question'],
                            'recoveryAnswer':RECOVERY['recovery_answer']}
            self.assertEqual(request('register', registration | {'passwordConfirmation':None})[0], 400)
            self.assertEqual(request('register', registration)[0], 201)
            status, _, question = request('recovery-question', {'username':'alice'})
            self.assertEqual((status, question), (200, {'question':RECOVERY['recovery_question']}))
            reset = {'username':'alice', 'password':NEW_PASSWORD, 'passwordConfirmation':NEW_PASSWORD,
                     'recoveryAnswer':RECOVERY['recovery_answer']}
            for endpoint, data in [('recovery-question', {'username':'alice'}), ('reset-password', reset), ('recovery-setup', {})]:
                self.assertEqual(request(endpoint, data, origin='https://evil.invalid')[0], 403)
                host = 'u-'+'a'*24+'.'+self.portal.tenant_authority
                self.assertEqual(request(endpoint, data, origin='http://'+host, host=host)[0], 404)
            self.assertEqual(request('recovery-setup', {})[0], 401)
            self.assertEqual(request('reset-password', reset | {'recoveryAnswer':'wrong'})[0], 401)
            status, headers, body = request('reset-password', reset)
            self.assertEqual(status, 200)
            self.assertIn('Max-Age=0', headers['Set-Cookie'])
            self.assertEqual(set(body), {'message'})
            self.assertEqual(request('login', {'username':'alice', 'password':PASSWORD})[0], 401)
            self.assertEqual(request('login', {'username':'alice', 'password':NEW_PASSWORD})[0], 200)
        finally: server.shutdown(); server.server_close()


class LegacyRecoveryTest(unittest.TestCase):
    def test_additive_migration_and_authenticated_first_time_setup(self):
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory)/'accounts.sqlite3'
            uid, salt = secrets.token_hex(12), secrets.token_hex(16)
            hashed = password_hash(PASSWORD, salt)
            with sqlite3.connect(database) as db:
                db.execute("CREATE TABLE users(uid TEXT PRIMARY KEY,username TEXT UNIQUE NOT NULL,salt TEXT NOT NULL,password_hash TEXT NOT NULL,runtime_secret TEXT NOT NULL,last_human REAL NOT NULL,started REAL NOT NULL DEFAULT 0,state TEXT NOT NULL DEFAULT 'stopped',reason TEXT NOT NULL DEFAULT '')")
                db.execute('INSERT INTO users(uid,username,salt,password_hash,runtime_secret,last_human) VALUES (?,?,?,?,?,?)',
                           (uid, 'alice', salt, hashed, 'unchanged-test-runtime-secret', 1000))
            portal = Portal(directory, ORIGIN, INVITATION, FakeKube())
            try:
                self.assertEqual(portal.user(uid)['password_hash'], hashed)
                self.assertFalse(portal.status(uid)['recoveryConfigured'])
                messages=[]
                for username in ('alice', 'unknown'):
                    with self.assertRaises(Rejected) as error: portal.recovery_question(username, 'test')
                    messages.append(error.exception.message)
                self.assertEqual(*messages)
                with self.assertRaises(Rejected) as error:
                    portal.reset_password('alice', RECOVERY['recovery_answer'], NEW_PASSWORD, NEW_PASSWORD, 'test')
                self.assertEqual(error.exception.status, 401)
                hub = portal.login('alice', PASSWORD, 'test')
                session = portal.authenticate(hub, portal.authority, 'hub')
                with self.assertRaises(Rejected): portal.set_recovery(session, 'wrong', RECOVERY['recovery_question'], RECOVERY['recovery_answer'])
                portal.set_recovery(session, PASSWORD, RECOVERY['recovery_question'], RECOVERY['recovery_answer'])
                self.assertTrue(portal.status(uid)['recoveryConfigured'])
                with self.assertRaises(Rejected) as duplicate:
                    portal.set_recovery(session, PASSWORD, 'Another question?', 'another-answer')
                self.assertEqual(duplicate.exception.status, 409)
                with portal.db() as db: db.execute('DELETE FROM sessions WHERE uid=?', (uid,))
                with self.assertRaises(Rejected) as expired:
                    portal.set_recovery(session, PASSWORD, RECOVERY['recovery_question'], RECOVERY['recovery_answer'])
                self.assertEqual(expired.exception.status, 401)
                answer_hash = portal.user(uid)['recovery_hash']
            finally: portal.pool.shutdown(wait=True)
            # Starting the next process is safe and does not reset recovery fields.
            reopened = Portal(directory, ORIGIN, INVITATION, FakeKube())
            try:
                self.assertEqual(reopened.user(uid)['recovery_hash'], answer_hash)
                self.assertEqual(reopened.user(uid)['runtime_secret'], 'unchanged-test-runtime-secret')
            finally: reopened.pool.shutdown(wait=True)


if __name__ == '__main__': unittest.main()
