"""Registration and live management authorization share the Portal identity."""

import _k8s_paths
from concurrent.futures import ThreadPoolExecutor
import unittest
import test_portal as portal_tests
from test_portal import PASSWORD,RECOVERY
from portal import Rejected

class ManagementRolesTest(unittest.TestCase):
    setUp=portal_tests.PortalTest.setUp
    tearDown=portal_tests.PortalTest.tearDown
    account=portal_tests.PortalTest.account

    def test_full_http_role_authorization_revokes_host_sessions_and_keeps_passwords_private(self):
        import http.client
        import json
        import os
        from pathlib import Path
        import sys
        import threading
        from unittest.mock import patch
        from portal import Server as PortalServer
        from cloud import Cloud
        from admin_server import Admin,Handler,Server
        self.account('owner');uid=self.account('alice')
        portal_server=PortalServer(('127.0.0.1',0),self.portal)
        token_file=Path(self.directory.name)/'bridge-token';token_file.write_text('test-only-bridge-secret-'*3)
        config={'origin':self.portal.origin,'state_dir':self.directory.name+'/admin','script_dir':self.directory.name+'/scripts','portal_url':'http://127.0.0.1:'+str(portal_server.server_port),'bridge_token_file':str(token_file)}
        cloud=Cloud(config,lambda:self.now);admin=Admin(cloud)
        host=Server(('127.0.0.1',0),Handler);host.admin=admin
        for server in (portal_server,host):threading.Thread(target=server.serve_forever,daemon=True).start()
        def request(path,data=None,session=None):
            connection=http.client.HTTPConnection('127.0.0.1',host.server_port,timeout=5)
            headers={'Host':self.portal.authority,'Origin':self.portal.origin,'Content-Type':'application/json'}
            if session:headers.update({'Cookie':session['cookie'],'X-CSRF-Token':session['csrf']})
            connection.request('POST' if data is not None else 'GET','/online/admin/api/'+path,body=json.dumps(data) if data is not None else None,headers=headers)
            response=connection.getresponse();status=response.status;cookie=response.getheader('Set-Cookie');raw=response.read().decode();connection.close()
            body=json.loads(raw)
            if cookie:body['cookie']=cookie.split(';')[0]
            self.assertNotIn(PASSWORD,raw);self.assertNotIn('auth_token',raw)
            return status,body
        try:
            with patch.dict(os.environ,{'KSSOLV_ADMIN_BRIDGE_TOKEN':token_file.read_text()}):
                self.assertEqual(request('login',{'username':'alice','password':PASSWORD})[0],401)
                status,owner=request('login',{'username':'owner','password':PASSWORD})
                self.assertEqual(status,200);self.assertEqual(owner['role'],'superadmin')
                self.assertEqual(request('roles',{'uid':uid,'role':'admin','confirmation':'alice'},owner)[0],200)
                status,alice=request('login',{'username':'alice','password':PASSWORD})
                self.assertEqual(status,200);self.assertEqual(alice['role'],'admin')
                self.assertEqual(request('state',session=alice)[1]['viewer']['role'],'admin')
                self.assertEqual(request('roles',{'uid':uid,'role':'user','confirmation':'alice'},alice)[0],403)
                self.assertEqual(request('roles',{'uid':uid,'role':'user','confirmation':'alice'},owner)[0],200)
                self.assertEqual(request('state',session=alice)[0],401)
                self.assertEqual(request('state',session=owner)[1]['viewer']['role'],'superadmin')
                self.assertEqual(self.kube.provisions,[])
                self.portal.set_management_role(self.portal.management_login('owner',PASSWORD,'test')['token'],uid,'admin','alice')
                self.assertEqual(request('state',session=alice)[0],401,'regranting must not resurrect an old session')
        finally:
            for server in (host,portal_server):server.shutdown();server.server_close()

    def test_first_registration_is_atomic_and_bootstrap_cannot_be_repeated(self):
        with ThreadPoolExecutor(max_workers=2) as pool:
            users=list(pool.map(self.account,['alice','bob']))
        self.assertEqual(sorted(self.portal.user(uid)['role'] for uid in users),['superadmin','user'])
        with self.portal.db() as db:db.execute('DELETE FROM users')
        uid=self.account('charlie')
        self.assertEqual(self.portal.user(uid)['role'],'user')

    def test_superadministrator_grants_and_revokes_access_without_starting_compute(self):
        owner=self.account('owner');uid=self.account('alice')
        super_session=self.portal.management_login('owner',PASSWORD,'ip')
        self.assertEqual(super_session['role'],'superadmin')
        with self.assertRaises(Rejected):self.portal.management_login('alice',PASSWORD,'ip')
        self.portal.set_management_role(super_session['token'],uid,'admin','alice')
        session=self.portal.management_login('alice',PASSWORD,'ip')
        self.assertEqual(self.portal.management_identity(session['token'])['role'],'admin')
        self.assertEqual(self.kube.provisions,[])
        with self.assertRaises(Rejected):self.portal.set_management_role(session['token'],uid,'admin','alice')
        with self.assertRaises(Rejected):self.portal.set_management_role(super_session['token'],owner,'user','owner')
        with self.assertRaises(Rejected):self.portal.set_management_role(super_session['token'],uid,'superadmin','alice')
        with self.assertRaises(Rejected):self.portal.set_management_role(super_session['token'],uid,'user','wrong')
        hub=self.portal.new_session(uid,'hub',self.portal.authority)
        self.portal.set_management_role(super_session['token'],uid,'user','alice')
        with self.assertRaises(Rejected):self.portal.management_identity(session['token'])
        self.assertEqual(self.portal.authenticate(hub,self.portal.authority,'hub')['uid'],uid)

    def test_password_reset_freeze_and_role_changes_invalidate_management_access(self):
        owner=self.account('owner');uid=self.account('alice')
        token=self.portal.management_login('owner',PASSWORD,'ip')['token']
        self.portal.set_management_role(token,uid,'admin','alice')
        session=self.portal.management_login('alice',PASSWORD,'ip')
        self.portal.stop(uid,'Idle timeout')
        self.assertEqual(self.portal.management_identity(session['token'])['uid'],uid)
        with self.portal.db() as db:db.execute('UPDATE users SET frozen=1 WHERE uid=?',(uid,))
        with self.assertRaises(Rejected):self.portal.management_identity(session['token'])
        with self.portal.db() as db:db.execute('UPDATE users SET frozen=0 WHERE uid=?',(uid,))
        self.portal.reset_password('alice',RECOVERY['recovery_answer'],'new-test-password-123','new-test-password-123','ip')
        with self.assertRaises(Rejected):self.portal.management_identity(session['token'])
        self.assertEqual(self.portal.management_login('alice','new-test-password-123','ip')['role'],'admin')

    def test_existing_database_never_promotes_an_arbitrary_user_on_restart(self):
        from portal import Portal
        from test_portal import ORIGIN,INVITATION
        uid=self.account('alice')
        with self.portal.db() as db:db.execute("UPDATE users SET role='user' WHERE uid=?",(uid,))
        other=Portal(self.directory.name,ORIGIN,INVITATION,self.kube)
        try:self.assertEqual(other.user(uid)['role'],'user')
        finally:other.pool.shutdown(wait=True)
