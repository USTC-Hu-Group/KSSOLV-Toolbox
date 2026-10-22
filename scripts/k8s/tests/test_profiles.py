
import _k8s_paths
import json
import os
import threading
import unittest
from unittest.mock import patch
import test_portal as portal_tests
from test_portal import PASSWORD
from portal import Portal,Rejected
from profiles import profiles
from kube import tenant_resources

class WorkspaceProfilesTest(unittest.TestCase):
    setUp=portal_tests.PortalTest.setUp
    tearDown=portal_tests.PortalTest.tearDown
    account=portal_tests.PortalTest.account
    def test_custom_resources_are_saved_and_used_without_changing_global_profiles(self):
        uid=self.account();recorded=[];original=profiles()
        self.kube.ensure=lambda uid,password,**options:recorded.append(options['resources'])
        with self.assertRaises(Rejected):self.portal.start(uid,'custom')
        with self.assertRaises(Rejected):self.portal.start(uid,'custom',resources={'cpu':'0','memory':'12Gi'})
        self.portal.start(uid,'custom',resources={'cpu':'3','memory':'12Gi'})
        self.portal.pool.shutdown(wait=True)
        self.assertEqual(recorded,[{'cpu':'3','memory':'12Gi'}])
        user=self.portal.user(uid)
        self.assertEqual((user['profile'],user['resource_cpu'],user['resource_memory']),('custom','3','12Gi'))
        self.assertEqual(self.portal.profiles,original)
    def test_profile_editor_is_atomic_persistent_and_leaves_running_instances_unchanged(self):
        import http.client
        from portal import Server
        uid=self.account();recorded=[]
        def ensure(uid,password,**options):
            recorded.append(options['resources']);self.kube.running[uid]=True
        self.kube.ensure=ensure
        self.portal.start(uid,'small');self.portal.pool.shutdown(wait=True)
        original=profiles();changed={**original,'small':{'cpu':'3','memory':'10Gi'}}
        server=Server(('127.0.0.1',0),self.portal);threading.Thread(target=server.serve_forever,daemon=True).start()
        def request(value,expected=original,authorized=True):
            conn=http.client.HTTPConnection('127.0.0.1',server.server_port,timeout=5)
            headers={'Host':self.portal.authority,'Origin':self.portal.origin,'Content-Type':'application/json'}
            if authorized:headers['Authorization']='Bearer '+'test-only-bridge-token-'*3
            conn.request('POST','/_portal/internal-admin/profiles',body=json.dumps({'profiles':value,'expected':expected}),headers=headers)
            response=conn.getresponse();status=response.status;body=json.loads(response.read());conn.close();return status,body
        try:
            with patch.dict(os.environ,{'KSSOLV_ADMIN_BRIDGE_TOKEN':'test-only-bridge-token-'*3}):
                self.assertEqual(request(changed,authorized=False)[0],403)
                self.assertEqual(request({**changed,'small':{'cpu':'0','memory':'10Gi'}})[0],400)
                self.assertEqual(self.portal.profiles,original)
                self.assertEqual(request(changed),(200,{'profiles':changed}))
                self.assertEqual(request(original)[0],409,'stale editors must not overwrite newer values')
                self.portal.start(uid,'large')
                self.assertEqual(self.portal.user(uid)['resource_cpu'],'2')
                self.assertEqual(recorded,[original['small']])
            restored=Portal(self.directory.name,portal_tests.ORIGIN,portal_tests.INVITATION,self.kube)
            try:
                self.assertEqual(restored.profiles,changed)
                new_uid=restored.register('bob',PASSWORD,portal_tests.INVITATION,'test',**portal_tests.RECOVERY)
                restored.start(new_uid,'small');restored.pool.shutdown(wait=True)
                self.assertEqual(recorded[-1],changed['small'],'new workspaces must use the saved preset')
            finally:restored.pool.shutdown(wait=True)
        finally:server.shutdown();server.server_close()
    def test_profile_changes_only_a_new_instance_and_legacy_sizes_remain_unchanged(self):
        uid=self.account();recorded=[]
        def ensure(uid,password,**options):
            recorded.append(options);self.kube.running[uid]=True
        self.kube.ensure=ensure
        self.portal.start(uid,'small');self.portal.pool.shutdown(wait=True)
        self.assertEqual(recorded[0]['resources'],{'cpu':'2','memory':'8Gi'})
        self.assertEqual(self.portal.user(uid)['profile'],'small')
        self.portal.start(uid,'large')
        self.assertEqual(self.portal.user(uid)['profile'],'small','running sessions must not resize on sign-in')
    def test_invalid_profile_and_frozen_accounts_cannot_start_or_authenticate(self):
        uid=self.account()
        with self.assertRaises(Rejected):self.portal.start(uid,'../../../etc/passwd')
        with self.portal.db() as db:db.execute('UPDATE users SET frozen=1 WHERE uid=?',(uid,))
        with self.assertRaises(Rejected):self.portal.login('alice',PASSWORD,'ip')
        with self.assertRaises(Rejected):self.portal.start(uid,'small')
        token=self.portal.new_session(uid,'hub',self.portal.authority)
        with self.assertRaises(Rejected):self.portal.authenticate(token,self.portal.authority,'hub')
    def test_profiles_drive_both_quota_and_container_resources(self):
        config={'storage_class':'local','storage':'10Gi','runtime_image':'runtime:test','pull_policy':'Never','system_namespace':'system'}
        for key,size in profiles().items():
            _,resources=tenant_resources('a'*24,'machine-secret',{**config,**size})
            quota=next(r for r in resources if r['kind']=='ResourceQuota')['spec']['hard']
            container=next(r for r in resources if r['kind']=='Deployment')['spec']['template']['spec']['containers'][0]
            self.assertEqual(container['resources']['limits']['memory'],size['memory'])
            self.assertEqual(quota['limits.cpu'],size['cpu'])
    def test_private_bridge_requires_its_own_token_and_freeze_revokes_sessions(self):
        import http.client
        from portal import Server
        self.account('owner');uid=self.account();token=self.portal.new_session(uid,'hub',self.portal.authority)
        server=Server(('127.0.0.1',0),self.portal);threading.Thread(target=server.serve_forever,daemon=True).start()
        def request(operation,data=None,authorized=True):
            conn=http.client.HTTPConnection('127.0.0.1',server.server_port,timeout=5)
            headers={'Host':self.portal.authority,'Origin':self.portal.origin,'Content-Type':'application/json'}
            if authorized:headers['Authorization']='Bearer '+'test-only-bridge-token-'*3
            conn.request('POST' if data is not None else 'GET','/_portal/internal-admin/'+operation,body=json.dumps(data) if data is not None else None,headers=headers)
            response=conn.getresponse();status=response.status;body=json.loads(response.read());conn.close();return status,body
        try:
            with patch.dict(os.environ,{'KSSOLV_ADMIN_BRIDGE_TOKEN':'test-only-bridge-token-'*3}):
                self.assertEqual(request('users',authorized=False)[0],403)
                status,body=request('users');self.assertEqual(status,200)
                self.assertNotIn('password_hash',json.dumps(body));self.assertNotIn('runtime_secret',json.dumps(body))
                self.assertEqual(request('freeze',{'uid':uid})[0],200)
                self.assertEqual(self.portal.user(uid)['frozen'],1)
                with self.assertRaises(Rejected):self.portal.authenticate(token,self.portal.authority,'hub')
                self.assertEqual(request('restore',{'uid':uid})[0],200)
                self.assertEqual(self.portal.user(uid)['frozen'],0);self.assertEqual(self.portal.user(uid)['state'],'stopped')
                self.assertEqual(request('resources',{'uid':uid,'profile':'custom','resources':{'cpu':'3','memory':'12Gi'}})[0],200)
                self.assertEqual(self.portal.user(uid)['resource_memory'],'12Gi')
                self.assertEqual(self.portal.user(uid)['profile'],'custom')
                self.assertEqual(request('resources',{'uid':uid,'profile':'custom','resources':{'cpu':'0','memory':'12Gi'}})[0],400)
                self.assertEqual(self.portal.user(uid)['resource_cpu'],'3')
        finally:server.shutdown();server.server_close()
