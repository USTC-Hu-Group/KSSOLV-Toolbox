"""Durable user activity, lifecycle observation, filtering and authentication boundaries."""

import _k8s_paths
import copy
import datetime
import http.client
import json
import os
from pathlib import Path
import sys
import threading
import unittest
from unittest.mock import patch
import test_portal as portal_tests
import test_admin as admin_tests
from portal import Rejected, Server
from cloud import Cloud, kssolv_related


class UserEventsTest(unittest.TestCase):
    setUp=portal_tests.PortalTest.setUp
    tearDown=portal_tests.PortalTest.tearDown
    account=portal_tests.PortalTest.account
    login=portal_tests.PortalTest.login

    def test_login_start_ready_logout_and_sizes_are_durable_snapshots(self):
        ensure=self.kube.ensure
        self.kube.ensure=lambda uid,password,**options:ensure(uid,password,restart=options.get('restart',False))
        uid=self.account();self.portal.login('alice',portal_tests.PASSWORD,'test','small')
        self.portal.pool.shutdown(wait=True);self.portal.status(uid)
        self.now+=10;self.portal.stop(uid,'User signed out.',logout=True)
        rows=self.portal.user_events(uid)['events'];actions=[e['action'] for e in rows]
        for action in ['login','logout','start_requested','workspace_ready','stop_requested','workspace_stopped']:
            self.assertIn(action,actions)
        start=next(e for e in rows if e['action']=='start_requested')
        self.assertEqual((start['cpu'],start['memory'],start['profile']),('2','8Gi','small'))
        with self.portal.db() as db:db.execute("UPDATE users SET resource_cpu='4',resource_memory='24Gi' WHERE uid=?",(uid,))
        self.assertEqual(next(e for e in self.portal.user_events(uid)['events'] if e['action']=='start_requested')['memory'],'8Gi')
        auth=self.portal.user_events(uid,'authentication')['events']
        self.assertEqual([e['action'] for e in auth],['logout','login'])
        self.assertEqual(auth[0]['timestamp'],self.now)
        body=json.dumps(rows)
        for secret in [portal_tests.PASSWORD,self.portal.user(uid)['password_hash'],self.portal.user(uid)['runtime_secret']]:
            self.assertNotIn(secret,body)
        # A new reader sees the same rows; nothing relies on a process-local cache.
        import sqlite3
        from contextlib import closing
        with closing(sqlite3.connect(self.portal.dbfile)) as db:self.assertEqual(db.execute('SELECT COUNT(*) FROM user_events').fetchone()[0],len(rows))

    def test_cursor_pagination_with_tied_timestamps_and_user_category_filters(self):
        uid=self.account();other=self.account('bravo')
        for _ in range(7):self.portal.event(uid,'workspace','start_requested')
        self.portal.event(other,'authentication','login')
        page=self.portal.user_events(uid,'workspace',limit=2);seen=[r['id'] for r in page['events']]
        self.portal.event(uid,'workspace','restart_requested') # must not duplicate/shift older pages
        while page['next']:
            page=self.portal.user_events(uid,'workspace',page['next'],2);seen.extend(r['id'] for r in page['events'])
        self.assertEqual(len(seen),7);self.assertEqual(len(set(seen)),7)
        for args in [(uid,'invalid'),(uid,'','nan:2'),(uid,'','1:0'),(uid,'','',0)]:
            with self.assertRaises(Rejected):self.portal.user_events(*args)

    def test_private_bridge_authentication_pod_validation_and_idempotence(self):
        uid=self.account();token='test-only-bridge-token-'*3
        server=Server(('127.0.0.1',0),self.portal);threading.Thread(target=server.serve_forever,daemon=True).start()
        def request(operation,data,authorized=True):
            conn=http.client.HTTPConnection('127.0.0.1',server.server_port)
            headers={'Host':self.portal.authority,'Origin':self.portal.origin,'Content-Type':'application/json'}
            if authorized:headers['Authorization']='Bearer '+token
            conn.request('POST','/_portal/internal-admin/'+operation,json.dumps(data),headers)
            response=conn.getresponse();body=json.loads(response.read());conn.close();return response.status,body
        event={'uid':uid,'namespace':'kssolv-u-'+uid,'pod':'runtime-test','key':'test-pod:start',
               'action':'pod_started','timestamp':self.now,'resources':{'cpu':'2','memory':'8Gi'}}
        try:
            with patch.dict(os.environ,{'KSSOLV_ADMIN_BRIDGE_TOKEN':token}):
                self.assertEqual(request('events',{},False)[0],403)
                self.assertEqual(request('record-pod-events',{'events':[event]})[0],200)
                self.assertEqual(request('record-pod-events',{'events':[event]})[0],200)
                status,result=request('events',{'uid':uid,'category':'pod'})
                self.assertEqual(status,200);self.assertEqual(len(result['events']),1)
                self.assertEqual(result['events'][0]['pod'],'runtime-test')
                self.assertEqual(request('record-pod-events',{'events':[{**event,'namespace':'kube-system'}]})[0],400)
        finally:server.shutdown();server.server_close()


class ObservedPodEventsTest(unittest.TestCase):
    setUp=admin_tests.AdminTest.setUp
    tearDown=admin_tests.AdminTest.tearDown
    auth_bridge=admin_tests.AdminTest.auth_bridge

    def pod(self):
        def iso(t):return datetime.datetime.fromtimestamp(t,datetime.timezone.utc).isoformat()
        return {'metadata':{'uid':'pod-1','name':'runtime-1','namespace':'kssolv-u-'+'a'*24,
                'labels':{'app.kubernetes.io/managed-by':'kssolv-portal','kssolv-user':'a'*24},'creationTimestamp':iso(900)},
                'spec':{'containers':[{'name':'runtime','resources':{'limits':{'cpu':'2','memory':'8Gi'}}}]},
                'status':{'phase':'Running','containerStatuses':[{'name':'runtime','containerID':'container-1',
                'restartCount':0,'state':{'running':{'startedAt':iso(910)}}}]}}

    def pending(self,cloud=None):
        with (cloud or self.cloud).db() as db:return [json.loads(r['body']) for r in db.execute('SELECT * FROM pod_event_outbox')]

    def test_observation_deduplicates_and_outbox_survives_restarts_and_failed_delivery(self):
        pod=self.pod();self.cloud.observe_pods([pod],self.now)
        self.cloud.observe_pods([pod],self.now+15)
        self.assertEqual([r['action'] for r in self.pending()],['pod_created','pod_started'])
        self.assertEqual([r['timestamp'] for r in self.pending()],[900,910])
        self.cloud.bridge=lambda *args:(_ for _ in ()).throw(OSError('unavailable'))
        with self.assertRaises(OSError):self.cloud.flush_pod_events()
        restarted=Cloud(self.config,lambda:self.now)
        self.assertEqual(len(self.pending(restarted)),2)
        delivered=[];restarted.bridge=lambda op,data:delivered.extend(data['events']) or {'ok':True}
        restarted.flush_pod_events();self.assertEqual(len(delivered),2);self.assertEqual(self.pending(restarted),[])
        restarted.observe_pods([pod],self.now+30);self.assertEqual(self.pending(restarted),[])
        pod['spec']['containers'][0]['resources']['limits']={'cpu':'4','memory':'24Gi'}
        restarted.observe_pods([pod],self.now+45)
        self.assertEqual(self.pending(restarted)[0]['action'],'pod_resized')
        restarted.observe_pods([],self.now+60)
        stop=self.pending(restarted)[-1];self.assertEqual(stop['action'],'pod_stopped')
        self.assertIn('observation time',stop['detail']);self.assertEqual(stop['timestamp'],self.now+60)
        self.assertEqual(stop['resources'],{'cpu':'4','memory':'24Gi'})
        restarted.observe_pods([],self.now+75);self.assertEqual(len(self.pending(restarted)),2)

    def test_finished_at_is_used_and_disappearance_does_not_duplicate_stop(self):
        pod=self.pod();self.cloud.observe_pods([pod],self.now)
        pod['status']['containerStatuses'][0]['state']={'terminated':{'finishedAt':'1970-01-01T00:16:00Z'}}
        self.cloud.observe_pods([pod],self.now+15);self.cloud.observe_pods([],self.now+30)
        stops=[e for e in self.pending() if e['action']=='pod_stopped']
        self.assertEqual(len(stops),1);self.assertEqual(stops[0]['timestamp'],960)

    def test_system_pods_are_not_account_events_or_visible_kssolv_inventory(self):
        pod=self.pod();system=copy.deepcopy(pod);system['metadata'].update(uid='system',namespace='kube-system',labels={})
        portal={'metadata':{'namespace':'kssolv-system','labels':{'app':'kssolv-portal'}}}
        self.assertFalse(kssolv_related(system));self.assertTrue(kssolv_related(portal));self.assertTrue(kssolv_related(pod))
        self.cloud.observe_pods([system],self.now);self.assertEqual(self.pending(),[])
