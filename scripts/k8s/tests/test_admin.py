"""Host console security, accounting and operation boundaries, without real mutations."""

import _k8s_paths
import http.client
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch
from cloud import Cloud,Problem,quantity
from admin_server import Admin,Handler,Server
from host_ops import Operations,script_path

class AdminTest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.now=1000.
        self.config={'state_dir':self.tmp.name,'origin':'https://cloud.example.org','kubeconfig':'/private/admin.conf','workers':['worker1'],'control_plane':'cp1','script_dir':self.tmp.name+'/scripts','account':{'username':'retired-admin','salt':'retired-salt','hash':'retired-test-only-admin-hash'}}
        Path(self.config['script_dir']).mkdir()
        self.cloud=Cloud(self.config,lambda:self.now);self.admin=Admin(self.cloud)
        self.identity={'uid':'a'*24,'username':'admin','role':'superadmin'}
        self.cloud.bridge=self.auth_bridge
    def auth_bridge(self,path,data=None):
        if path=='admin-login':
            if data.get('username')!='admin' or data.get('password')!='test-only-admin-password-123':raise PermissionError('Invalid administrator credentials.')
            return {**self.identity,'token':'test-only-portal-admin-token'}
        if path=='admin-session':return dict(self.identity)
        if path=='admin-logout':return {'ok':True}
        return {'users':[],'profiles':{}}
    def tearDown(self):self.tmp.cleanup()
    def test_login_session_expiration_csrf_separation_and_rate_limit(self):
        token,csrf=self.admin.login('admin','test-only-admin-password-123','ip')
        session=self.admin.authenticate(token)
        self.assertEqual(session['csrf'],csrf);self.assertNotEqual(session['token'],token)
        self.now+=14401
        with self.assertRaises(PermissionError):self.admin.authenticate(token)
        for _ in range(8):
            with self.assertRaises((Problem,PermissionError)):self.admin.login('admin','wrong','attacker')
        with self.assertRaisesRegex(Problem,'Too many'):self.admin.login('admin','test-only-admin-password-123','attacker')
    def test_http_rejects_missing_auth_csrf_cross_origin_and_keeps_credentials_out_of_state(self):
        server=Server(('127.0.0.1',0),Handler);server.admin=self.admin
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        def request(path,data=None,headers=None):
            connection=http.client.HTTPConnection('127.0.0.1',server.server_port)
            h={'Host':'cloud.example.org',**(headers or {})}
            if data is not None:h.update({'Content-Type':'application/json','Origin':h.get('Origin','https://cloud.example.org')})
            connection.request('POST' if data is not None else 'GET',path,body=json.dumps(data) if data is not None else None,headers=h)
            response=connection.getresponse();result=response.status,dict(response.getheaders()),response.read().decode();connection.close();return result
        try:
            self.assertEqual(request('/online/admin/api/state')[0],401)
            self.assertEqual(request('/online/admin/api/user-events')[0],401)
            status,_,page=request('/online/admin')
            self.assertEqual(status,200);self.assertIn('/online/admin/app.js',page)
            self.assertEqual(request('/online/admin/api/profiles',{})[0],401)
            status,headers,body=request('/online/admin/api/login',{'username':'admin','password':'test-only-admin-password-123'})
            self.assertEqual(status,200);self.assertIn('Secure',headers['Set-Cookie']);self.assertIn('HttpOnly',headers['Set-Cookie']);self.assertIn('SameSite=Strict',headers['Set-Cookie'])
            self.assertIn('Path=/online/admin;',headers['Set-Cookie'])
            cookie=headers['Set-Cookie'].split(';')[0];csrf=json.loads(body)['csrf']
            from profiles import profiles
            values=profiles();writes=[]
            self.cloud.bridge=lambda path,data=None:self.auth_bridge(path,data) if path.startswith('admin-') else writes.append((path,data)) or {'profiles':values,'users':[]}
            self.assertEqual(request('/online/admin/api/profiles',{'profiles':values,'expected':values},{'Cookie':cookie})[0],401)
            status,_,body=request('/online/admin/api/profiles',{'profiles':values,'expected':values},{'Cookie':cookie,'X-CSRF-Token':csrf})
            self.assertEqual(status,200);self.assertEqual(json.loads(body)['profiles'],values)
            self.assertEqual(writes,[('profiles',{'profiles':values,'expected':values})])
            event_queries=[]
            self.cloud.user_events=lambda query:event_queries.append(query) or {'events':[],'next':''}
            self.assertEqual(request('/online/admin/api/user-events?uid='+('a'*24)+'&category=pod',headers={'Cookie':cookie})[0],200)
            self.assertEqual(event_queries,[{'uid':'a'*24,'category':'pod','before':''}])
            self.assertEqual(request('/online/admin/api/logout',{}, {'Cookie':cookie})[0],401)
            self.assertEqual(request('/online/admin/api/logout',{}, {'Cookie':cookie,'X-CSRF-Token':csrf,'Origin':'https://evil.invalid'})[0],401)
            status,headers,body=request('/online/admin/api/state',headers={'Cookie':cookie})
            self.assertEqual(status,200);self.assertNotIn(self.config['account']['hash'],body);self.assertNotIn('test-only-admin-password',body)
            self.assertEqual(request('/online/admin/api/logout',{}, {'Cookie':cookie,'X-CSRF-Token':csrf})[0],200)
            self.assertEqual(request('/online/admin/api/state',headers={'Cookie':cookie})[0],401)
        finally:server.shutdown();server.server_close()
    def test_profile_editor_rejects_invalid_values_and_waits_for_running_jobs(self):
        from profiles import profiles
        values=profiles();calls=[]
        self.cloud.bridge=lambda *args:calls.append(args)
        with self.assertRaises(ValueError):self.admin.update_profiles({'profiles':{**values,'small':{'cpu':'1.5','memory':'8Gi'}}})
        with self.cloud.db() as db:db.execute('INSERT INTO jobs VALUES (?,?,?,?,?,?)',('busy',self.now,'admin','{}','queued','waiting'))
        with self.assertRaisesRegex(Problem,'in progress'):self.admin.update_profiles({'profiles':values,'expected':values})
        self.assertEqual(calls,[])
    def test_pending_resize_confirmation_rejects_changed_profile_quantities(self):
        from profiles import profiles
        values=profiles();self.cloud.bridge=lambda *args:{'profiles':values}
        self.admin.ops.validate=lambda body:({'action':'resize','target':'test','profile':'small'},'Impact')
        session={'token':'session-a'};preview=self.admin.propose(session,{})
        values['small']={'cpu':'3','memory':'10Gi'}
        with self.assertRaisesRegex(Problem,'Workspace sizes changed'):
            self.admin.confirm(session,{'token':preview['token'],'confirmation':'test'})
        with self.cloud.db() as db:self.assertEqual(db.execute('SELECT COUNT(*) FROM jobs').fetchone()[0],0)
    def test_accounting_uses_monotonic_counters_ignores_stale_samples_and_sampling_gaps(self):
        def record(stamp,counter):self.cloud.record([(stamp,'pod','pod1','a'*24,1.,100.,4.,800.,counter)],stamp)
        record(100,10);record(115,25);record(115,25);record(200,100)
        with self.cloud.db() as db:
            row=db.execute('SELECT * FROM usage_hourly').fetchone();self.assertEqual(row['cpu_seconds'],15);self.assertEqual(row['allocated_core_seconds'],60);self.assertEqual(row['coverage_seconds'],15)
            self.assertEqual(db.execute('SELECT COUNT(*) FROM samples').fetchone()[0],3)
        record(215,2) # container counter reset: do not generate negative CPU time
        with self.cloud.db() as db:self.assertEqual(db.execute('SELECT cpu_seconds FROM usage_hourly').fetchone()[0],15)
    def test_accounting_splits_hour_boundaries(self):
        rows=lambda ts,c:[(ts,'pod','p','a'*24,1,2,4,8,c)]
        self.cloud.record(rows(3595,100),3595);self.cloud.record(rows(3610,115),3610)
        with self.cloud.db() as db:values=[dict(r) for r in db.execute('SELECT * FROM usage_hourly ORDER BY hour')]
        self.assertEqual([v['cpu_seconds'] for v in values],[5,10]);self.assertEqual([v['allocated_core_seconds'] for v in values],[20,40])
    def test_confirmations_are_session_bound_single_use_and_require_typed_target(self):
        self.admin.ops.validate=lambda body:({'action':'stop','target':'test-target'},'Impact')
        session={'token':'session-a'};preview=self.admin.propose(session,{})
        with self.assertRaises(Problem):self.admin.confirm({'token':'session-b'},{'token':preview['token'],'confirmation':'test-target'})
        with self.assertRaises(Problem):self.admin.confirm(session,{'token':preview['token'],'confirmation':'wrong'})
        with patch('admin_server.threading.Thread'):
            result=self.admin.confirm(session,{'token':preview['token'],'confirmation':'test-target'})
        self.assertIn('job',result)
        with self.assertRaises(Problem):self.admin.confirm(session,{'token':preview['token'],'confirmation':'test-target'})
    def test_scripts_are_register_only_and_cannot_escape_directory_or_follow_symlinks(self):
        good=Path(self.config['script_dir'])/'maintenance.py';good.write_text('print(1)')
        self.assertEqual(script_path(self.cloud,str(good)),good.resolve())
        for path in ['/tmp/evil.py',str(good.parent/'..'/'evil.py'),'/opt/run.jar','relative.sh']:
            with self.assertRaises(Problem):script_path(self.cloud,path)
        link=good.with_name('link.py');link.symlink_to(good)
        with self.assertRaises(Problem):script_path(self.cloud,str(link))
    def test_system_scope_rejects_static_pods_and_custom_controllers(self):
        ops=Operations(self.cloud)
        self.cloud.get=lambda *args:{'metadata':{'annotations':{'kubernetes.io/config.mirror':'x'}}}
        with self.assertRaisesRegex(Problem,'Static'):ops.validate({'action':'workload-stop','target':'kube-system/kube-apiserver'})
        with self.assertRaises(Problem):ops.validate({'action':'worker-restart','target':'other-vm'})
        with self.assertRaises(Problem):ops.validate({'action':'workload-destroy','target':'kube-system/../../etc/passwd'})
    def test_system_deployment_requires_same_confirmed_identity(self):
        ops=Operations(self.cloud)
        item={'metadata':{'name':'coredns','uid':'new-uid'},'spec':{'template':{'spec':{'containers':[{'name':'coredns'}]}}}}
        self.cloud.get=lambda *args:item
        clean,_=ops.validate({'action':'workload-stop','target':'kube-system/deployment/coredns'})
        self.assertEqual(clean['workloadUid'],'new-uid')
        with self.assertRaisesRegex(Problem,'identity changed'):ops.validate({**clean,'workloadUid':'old-uid'})
    def test_quantity_units(self):
        self.assertEqual(quantity('100m'),.1);self.assertEqual(quantity('52Gi'),52*1024**3);self.assertAlmostEqual(quantity('150000000n'),.15)

    def test_mirror_pods_use_namespace_and_name_when_kubelet_uid_differs(self):
        import datetime
        stamp=datetime.datetime.fromtimestamp(self.now,datetime.timezone.utc).isoformat()
        node={'metadata':{'name':'worker1'},'spec':{},'status':{'capacity':{'cpu':'4','memory':'8Gi'},'allocatable':{'cpu':'4','memory':'8Gi'},'conditions':[{'type':'Ready','status':'True'}],'nodeInfo':{'kubeletVersion':'v1.36.5'}}}
        pod={'metadata':{'uid':'mirror-api-uid','name':'kube-apiserver-worker1','namespace':'kube-system','annotations':{'kubernetes.io/config.mirror':'hash'}},'spec':{'nodeName':'worker1','containers':[{'name':'api','image':'api:test','resources':{}}]},'status':{'phase':'Running','containerStatuses':[{'name':'api','restartCount':0,'ready':True}]}}
        self.cloud.get=lambda kind,*args:{'items':[node] if kind=='nodes' else [pod] if kind=='pods' else []}
        metric={'cpu':{'time':stamp,'usageNanoCores':200000000,'usageCoreNanoSeconds':1000000000},'memory':{'workingSetBytes':1024}}
        summary={'node':{'nodeName':'worker1',**metric},'pods':[{'podRef':{'uid':'kubelet-static-hash','name':pod['metadata']['name'],'namespace':'kube-system'},**metric}]}
        self.cloud.kub=lambda *args,**kwargs:json.dumps(summary)
        snapshot=self.cloud.collect();self.assertEqual(snapshot['pods'],[])
        with self.cloud.db() as db:
            sample=db.execute("SELECT * FROM samples WHERE kind='pod' AND identity='mirror-api-uid'").fetchone()
            self.assertAlmostEqual(sample['cpu'],.2);self.assertEqual(sample['memory'],1024)
        self.assertEqual(snapshot['nodes'][0]['cpu'],4);self.assertAlmostEqual(snapshot['nodes'][0]['usedCpu'],.2)
    def test_system_destroy_allows_the_full_kubernetes_grace_period(self):
        ops=Operations(self.cloud)
        item={'metadata':{'name':'demo','uid':'verified'},'spec':{}}
        ops.workload=lambda target:('system','deployment',item)
        self.cloud.get=lambda *args:{'items':[]}
        calls=[];self.cloud.kub=lambda *args,**kwargs:calls.append((args,kwargs))
        ops.change_workload({'target':'system/deployment/demo','workloadUid':'verified','action':'workload-destroy'},lambda message:None)
        self.assertEqual(calls[0][1]['timeout'],100)

    def test_system_resource_editor_preserves_unlimited_limits_and_fractional_requests(self):
        ops=Operations(self.cloud)
        item={'metadata':{'name':'dns','uid':'stable'},'spec':{'template':{'spec':{'containers':[{'name':'dns'}]}}}}
        self.cloud.get=lambda *args:item
        body={'action':'workload-resize','target':'kube-system/deployment/dns','container':'dns','resources':{'requests':{'cpu':'0.1','memory':'70Mi'},'limits':{'memory':'170Mi'}}}
        clean,_=ops.validate(body);self.assertEqual(clean['resources']['requests']['cpu'],'0.1');self.assertNotIn('cpu',clean['resources']['limits'])
        ops.validate(clean)
        for invalid in ['NaN','Infinity','-1','0.0001','129']:
            with self.assertRaises(Problem):ops.validate({**body,'resources':{'requests':{'cpu':invalid}}})
    def test_memory_shrink_rejects_a_previously_fresh_sample_that_has_aged_out(self):
        ops=Operations(self.cloud);uid='a'*24
        self.cloud.managed=lambda namespace:uid
        pod={'metadata':{'uid':'p','name':'runtime'},'status':{'phase':'Running'},'spec':{'containers':[{'name':'runtime','resources':{'limits':{'cpu':'4','memory':'52Gi'}}}]}}
        deployment={'metadata':{'labels':{'kssolv-user':uid}},'spec':{}}
        self.cloud.get=lambda kind,*args:{'items':[pod]} if kind=='pods' else deployment
        self.cloud.bridge=lambda *args:{'profiles':{'small':{'cpu':'2','memory':'8Gi'}}}
        self.cloud.cache={'pods':[{'uid':'p','stale':False,'timestamp':self.now-100,'memory':100}]}
        with self.assertRaisesRegex(Problem,'Fresh memory usage'):
            ops.resize('kssolv-u-'+uid,'small',lambda message:None)

    def test_custom_workspace_resize_persists_user_size_and_updates_stopped_compute(self):
        ops=Operations(self.cloud);uid='a'*24;calls=[];patches=[]
        self.cloud.managed=lambda target:uid
        def bridge(operation,data=None):
            calls.append((operation,data))
            return {'users':[{'uid':uid}],'profiles':{}}
        self.cloud.bridge=bridge
        body={'action':'resize','target':'kssolv-u-'+uid,'profile':'custom','resources':{'cpu':'3','memory':'12Gi'}}
        clean,_=ops.validate(body);self.assertEqual(clean['resources'],body['resources'])
        for bad in ['0','1.5','-1','NaN','1000']:
            with self.assertRaises(Problem):ops.validate({**body,'resources':{'cpu':bad,'memory':'12Gi'}})
        deployment={'spec':{'template':{'spec':{'containers':[{'name':'runtime','resources':{'requests':{},'limits':{}}}]}}}}
        self.cloud.runtime=lambda namespace:(uid,deployment)
        self.cloud.get=lambda *args:{'items':[]}
        self.cloud.patch=lambda kind,name,body,namespace:patches.append((kind,body))
        result=ops.run(clean)
        self.assertIn('No instance was started',result)
        self.assertIn(('resources',{'uid':uid,'profile':'custom','resources':body['resources']}),calls)
        self.assertEqual(patches[-1],('resourcequota',{'spec':{'hard':{'limits.cpu':'3','limits.memory':'12Gi'}}}))
        self.assertEqual(deployment['spec']['template']['spec']['containers'][0]['resources']['limits'],body['resources'])
        self.admin.ops.validate=lambda value:(clean,'Impact')
        preview=self.admin.propose({'token':'session'},body)
        with patch('admin_server.threading.Thread'):
            self.assertIn('job',self.admin.confirm({'token':'session'},{'token':preview['token'],'confirmation':body['target']}))

    def test_repeated_stop_retains_the_original_replica_count_for_start(self):
        ops=Operations(self.cloud)
        item={'metadata':{'name':'dns','uid':'stable','annotations':{'kssolv-admin/previous-replicas':'2'}},'spec':{'replicas':0}}
        ops.workload=lambda target:('system','deployment',item)
        self.cloud.get=lambda *args:{'items':[]}
        changes=[];self.cloud.patch=lambda kind,name,body,namespace:changes.append(body)
        base={'target':'system/deployment/dns','workloadUid':'stable'}
        ops.change_workload({**base,'action':'workload-stop'},lambda message:None)
        self.assertNotIn('metadata',changes[-1])
        ops.change_workload({**base,'action':'workload-start'},lambda message:None)
        self.assertEqual(changes[-1]['spec']['replicas'],2)
