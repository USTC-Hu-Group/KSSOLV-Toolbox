"""Exercise versioned host Shell jobs in temporary directories, without a cluster or JVM."""

import _k8s_paths
import datetime as dt
import hashlib
import http.client
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
from cloud import Cloud,Problem
from custom_scripts import Scripts,next_cron
from script_runner import Runner,unit_source
import test_admin as fixtures

class ScriptsTest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.now=1770000000.
        self.cloud=Cloud({'state_dir':self.tmp.name,'script_timezone':'Asia/Shanghai'},lambda:self.now)
        self.actor={'uid':'a'*24,'username':'test-admin','role':'admin','frozen':False}
        self.cloud.bridge=lambda *args:{'users':[self.actor]}
        self.runner=Runner(self.cloud);self.scripts=self.runner.scripts
    def tearDown(self):self.runner.stop.set();self.runner.pool.shutdown(wait=True);self.tmp.cleanup()
    def save(self,source='printf "hello\\n"\n',identifier='test-script',revision=0,timeout=300):
        return self.scripts.save({'id':identifier,'name':'Test','description':'Test only','source':source,'expectedRevision':revision,'timeout':timeout},self.actor)
    def review(self,item):return {key:item[key] for key in ('id','revision','sha256')}|{'confirmation':item['id']}
    def run_job(self,item):
        identifier=self.scripts.run(self.review(item),self.actor)['run'];self.runner.tick()
        self.runner.futures[identifier].result(timeout=12)
        return self.scripts.result(identifier)
    def test_save_validates_without_executing_and_normalizes_upload(self):
        marker=Path(self.tmp.name)/'must-not-exist'
        item=self.save('\ufeff#!/bin/bash\r\nprintf test > '+str(marker)+'\r\n')
        self.assertFalse(marker.exists());self.assertNotIn('\r',item['source']);self.assertNotIn('\ufeff',item['source'])
        self.assertEqual(item['sha256'],hashlib.sha256(item['source'].encode()).hexdigest())
        with self.assertRaisesRegex(Problem,'syntax'):self.save('if then\n','bad-script')
        for identifier in ('../escape','x;id','A-script','a'):
            with self.assertRaises(Problem):self.save(identifier=identifier)
        for source in ('','\x00','x'*131073):
            with self.assertRaises(Problem):self.save(source,'bad-script')
        for timeout in (0,86401,True,1.5):
            with self.assertRaises(Problem):self.save(identifier='bad-script',timeout=timeout)
    def test_review_checks_hash_version_confirmation_and_optimistic_save(self):
        item=self.save()
        for field,value in [('revision',2),('sha256','0'*64),('confirmation','wrong')]:
            data=self.review(item);data[field]=value
            with self.assertRaises(Problem):self.scripts.run(data,self.actor)
        with self.assertRaises(Problem):self.save(revision=0)
        self.save('printf new',revision=1)
        with self.assertRaises(Problem):self.scripts.run(self.review(item),self.actor)
    def test_queued_run_keeps_immutable_revision_after_edit(self):
        original=self.save();identifier=self.scripts.run(self.review(original),self.actor)['run']
        self.save('printf changed\n',revision=1)
        self.runner.tick();self.runner.futures[identifier].result(timeout=10)
        result=self.scripts.result(identifier)
        self.assertEqual(result['revision'],1);self.assertEqual(result['output'],'hello\n');self.assertEqual(result['status'],'succeeded')
        self.assertEqual((self.scripts.directory/identifier/'script.sh').read_text(),original['source'])
    def test_nonzero_exit_code_and_stderr_are_retained(self):
        result=self.run_job(self.save('printf "error\\n" >&2\nexit 7\n'))
        self.assertEqual(result['status'],'failed');self.assertEqual(result['exit_code'],7);self.assertEqual(result['output'],'error\n')
    def test_closed_stdout_does_not_end_a_running_job(self):
        start=time.monotonic();result=self.run_job(self.save('exec 1>&- 2>&-\nsleep 0.5\n'))
        self.assertEqual(result['status'],'succeeded');self.assertGreater(time.monotonic()-start,.45)
    def test_timeout_and_background_children_are_terminated(self):
        result=self.run_job(self.save('sleep 30 &\nwait\n',timeout=1))
        self.assertEqual(result['status'],'timed_out');self.assertIsNotNone(result['exit_code'])
        result=self.run_job(self.save('sleep 30 &\nprintf parent-done\n','background-script'))
        self.assertEqual(result['status'],'succeeded');self.assertEqual(result['output'],'parent-done')
    def test_cancel_queued_and_running_jobs(self):
        item=self.save('printf started\nsleep 30\n');first=self.scripts.run(self.review(item),self.actor)['run']
        self.scripts.cancel(first,self.actor);self.assertEqual(self.scripts.result(first)['status'],'cancelled')
        identifier=self.scripts.run(self.review(item),self.actor)['run'];self.runner.tick()
        for _ in range(50):
            if self.scripts.result(identifier)['output']:break
            time.sleep(.02)
        self.scripts.cancel(identifier,self.actor);self.runner.futures[identifier].result(timeout=10)
        self.assertEqual(self.scripts.result(identifier)['status'],'cancelled')
    def test_output_is_bounded_and_result_tail_is_indicated(self):
        with patch('script_runner.MAX_LOG',150000):result=self.run_job(self.save("printf '%200000s' x\n"))
        self.assertTrue(result['truncated']);self.assertTrue(result['tailOnly']);self.assertEqual(len(result['output']),128*1024)
        self.assertEqual((self.scripts.directory/result['id']/'output.log').stat().st_size,150000)
    def test_same_script_cannot_overlap_and_global_parallelism_is_two(self):
        item=self.save('sleep .3\n');self.scripts.run(self.review(item),self.actor)
        with self.assertRaises(Problem):self.scripts.run(self.review(item),self.actor)
        for name in ('second-script','third-script'):self.scripts.run(self.review(self.save('sleep .3\n',name)),self.actor)
        self.runner.tick();self.assertEqual(len(self.runner.futures),2)
        with self.cloud.db() as db:self.assertEqual(db.execute("SELECT COUNT(*) FROM script_runs WHERE status='queued'").fetchone()[0],1)
    def test_schedule_survives_edits_and_skips_missed_intervals(self):
        original=self.save();data=self.review(original)|{'kind':'interval','expression':'1','enabled':True}
        self.scripts.schedule(data,self.actor);self.save('printf new\n',revision=1);self.now+=3600
        self.runner.schedule_due()
        with self.cloud.db() as db:
            runs=list(db.execute('SELECT * FROM script_runs'));schedule=db.execute('SELECT * FROM script_schedules').fetchone()
        self.assertEqual(len(runs),1);self.assertEqual(runs[0]['revision'],1);self.assertEqual(schedule['next_run'],self.now+60)
        self.now+=60;self.runner.schedule_due()
        self.assertEqual(self.scripts.runs()['runs'][0]['status'],'skipped')
        self.scripts.pause(original['id'],self.actor)
        self.assertFalse(self.scripts.inventory()['scripts'][0]['schedule']['enabled'])
    def test_revoked_creator_is_blocked_and_schedule_disabled(self):
        item=self.save();identifier=self.scripts.run(self.review(item),self.actor)['run']
        self.scripts.schedule(self.review(item)|{'kind':'interval','expression':'1','enabled':True},self.actor)
        self.actor['role']='user';self.now+=60;self.runner.tick()
        self.assertEqual(self.scripts.result(identifier)['status'],'blocked')
        self.assertFalse(self.scripts.inventory()['scripts'][0]['schedule']['enabled'])
    def test_bridge_outage_defers_jobs_without_executing(self):
        item=self.save();identifier=self.scripts.run(self.review(item),self.actor)['run']
        self.cloud.bridge=lambda *args:(_ for _ in ()).throw(Problem('offline'))
        with self.assertRaises(Problem):self.runner.tick()
        self.assertEqual(self.scripts.result(identifier)['status'],'queued');self.assertFalse((self.scripts.directory/identifier).exists())
    def test_executor_restart_marks_running_job_interrupted_without_reexecution(self):
        item=self.save();identifier=self.scripts.run(self.review(item),self.actor)['run']
        with self.cloud.db() as db:db.execute("UPDATE script_runs SET status='running' WHERE id=?",(identifier,))
        self.runner.recover();self.assertEqual(self.scripts.result(identifier)['status'],'interrupted');self.assertFalse((self.scripts.directory/identifier).exists())
    def test_result_and_cursor_validate_identity_and_paginate_equal_timestamps(self):
        for identifier in ('../escape','0'*23,'g'*24):
            with self.assertRaises(Problem):self.scripts.result(identifier)
        item=self.save()
        for _ in range(53):
            run=self.scripts.run(self.review(item),self.actor)['run'];self.scripts.cancel(run,self.actor)
        first=self.scripts.runs();second=self.scripts.runs(before=first['next'])
        self.assertEqual(len(first['runs']),50);self.assertEqual(len(second['runs']),3)
        self.assertFalse(set(r['id'] for r in first['runs']) & set(r['id'] for r in second['runs']))
        with self.assertRaises(Problem):self.scripts.runs(before='nan:'+'a'*24)
    def test_service_is_separate_from_protected_web_process(self):
        unit=unit_source();self.assertIn('script_runner.py',unit);self.assertIn('KillMode=control-group',unit)
        source=(Path(__file__).parents[1]/'admin/install_admin.py').read_text()
        self.assertIn('ProtectSystem=strict',source);self.assertIn('kssolv-script-runner.service',source)

class CronTest(unittest.TestCase):
    def test_timezone_steps_lists_and_weekday(self):
        stamp=dt.datetime(2026,10,22,0,tzinfo=dt.timezone.utc).timestamp()
        next_time=next_cron('*/15 9 * * 1-5',stamp,'Asia/Shanghai')
        self.assertEqual(dt.datetime.fromtimestamp(next_time,dt.timezone.utc).isoformat(),'2026-10-22T01:00:00+00:00')
        self.assertEqual(next_cron('*/15 9 * * 1-5',next_time,'Asia/Shanghai'),next_time+900)
    def test_day_of_month_and_weekday_or_and_leap_day(self):
        stamp=dt.datetime(2026,10,22,tzinfo=dt.timezone.utc).timestamp()
        value=next_cron('0 0 1 * 0',stamp,'UTC')
        self.assertEqual(dt.datetime.fromtimestamp(value,dt.timezone.utc).day,25)
        value=next_cron('0 0 29 2 *',stamp,'UTC')
        self.assertEqual(dt.datetime.fromtimestamp(value,dt.timezone.utc).year,2028)
    def test_dst_nonexistent_local_time_is_skipped(self):
        stamp=dt.datetime(2026,3,8,tzinfo=dt.timezone.utc).timestamp()
        value=next_cron('30 2 * * *',stamp,'America/New_York')
        self.assertEqual(dt.datetime.fromtimestamp(value,dt.timezone.utc).day,9)
    def test_invalid_or_impossible_cron_is_rejected(self):
        for expression in ('* * * *','60 * * * *','* 24 * * *','0 0 31 2 *','@reboot','* * * * $(id)'):
            with self.assertRaises(Problem):next_cron(expression,time.time(),'UTC')

class ScriptHTTPTest(unittest.TestCase):
    setUp=fixtures.AdminTest.setUp
    tearDown=fixtures.AdminTest.tearDown
    auth_bridge=fixtures.AdminTest.auth_bridge
    def test_script_endpoints_require_auth_csrf_and_return_download_as_text(self):
        server=fixtures.Server(('127.0.0.1',0),fixtures.Handler);server.admin=self.admin
        threading.Thread(target=server.serve_forever,daemon=True).start()
        def req(path,data=None,cookie='',csrf=''):
            connection=http.client.HTTPConnection(*server.server_address,timeout=5)
            headers={'Host':'cloud.example.org','Origin':'https://cloud.example.org','Content-Type':'application/json','Cookie':cookie,'X-CSRF-Token':csrf}
            connection.request('GET' if data is None else 'POST','/online/admin/api/'+path,body=None if data is None else json.dumps(data),headers=headers)
            response=connection.getresponse();body=response.read();headers=dict(response.getheaders());connection.close();return response.status,body,headers
        try:
            self.assertEqual(req('scripts/source?id=test-script')[0],401)
            token,csrf=self.admin.login('admin','test-only-admin-password-123','test-ip');cookie='__Secure-kssolv_admin='+token
            data={'id':'test-script','name':'Example','description':'','source':'printf hello','timeout':300,'expectedRevision':0}
            self.assertEqual(req('scripts/save',data,cookie)[0],401)
            code,raw,_=req('scripts/save',data,cookie,csrf);self.assertEqual(code,200);item=json.loads(raw)
            identifier=self.admin.scripts.run({**item,'confirmation':item['id']},self.identity)['run']
            folder=self.admin.scripts.directory/identifier;folder.mkdir();(folder/'output.log').write_text('<script>not html</script>')
            code,raw,headers=req('scripts/log?id='+identifier,cookie=cookie)
            self.assertEqual(code,200);self.assertTrue(headers['Content-Type'].startswith('text/plain'));self.assertIn('attachment',headers['Content-Disposition']);self.assertEqual(raw,b'<script>not html</script>')
            connection=http.client.HTTPConnection(*server.server_address,timeout=5)
            try:
                connection.putrequest('POST','/online/admin/api/scripts/save',skip_host=True)
                for key,value in {'Host':'cloud.example.org','Origin':'https://cloud.example.org','Content-Type':'application/json','Content-Length':'600000','Cookie':cookie,'X-CSRF-Token':csrf}.items():connection.putheader(key,value)
                connection.endheaders();response=connection.getresponse();self.assertEqual(response.status,400);response.read()
            finally:connection.close()
        finally:server.shutdown();server.server_close()
