#!/usr/bin/env python3
"""Independent host Shell executor. The web service retains its read-only system mount."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import fcntl
import hashlib
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import threading
import time
from cloud import Cloud,Problem
from custom_scripts import Scripts,MAX_LOG,next_cron


class Runner:
    def __init__(self,cloud):
        self.cloud=cloud;self.scripts=Scripts(cloud);self.stop=threading.Event()
        self.pool=ThreadPoolExecutor(max_workers=2);self.futures={}

    def recover(self):
        with self.cloud.db() as db:
            db.execute("UPDATE script_runs SET status='interrupted',finished=?,message='Executor restarted; execution was not resumed.' WHERE status='running'",(self.cloud.clock(),))

    def schedule_due(self):
        now=self.cloud.clock()
        with self.cloud.db() as db:due=[dict(r) for r in db.execute('SELECT * FROM script_schedules WHERE enabled=1 AND next_run<=? ORDER BY next_run LIMIT 50',(now,))]
        if not due:return
        # An unavailable Portal defers work; it never grants execution implicitly.
        accounts={u['uid']:u for u in self.cloud.bridge('users')['users']}
        for schedule in due:
            with self.cloud.db() as db:
                db.execute('BEGIN IMMEDIATE')
                current=db.execute('SELECT * FROM script_schedules WHERE script_id=?',(schedule['script_id'],)).fetchone()
                if not current or not current['enabled'] or current['updated']!=schedule['updated'] or current['next_run']>now:continue
                actor=accounts.get(schedule['actor_uid'])
                if not actor or actor.get('frozen') or actor.get('role') not in ('admin','superadmin'):
                    db.execute("UPDATE script_schedules SET enabled=0,next_run=NULL,message='Creator no longer has administrator access.' WHERE script_id=?",(schedule['script_id'],));continue
                next_run=now+int(schedule['expression'])*60 if schedule['kind']=='interval' else next_cron(schedule['expression'],now,schedule['timezone'])
                revision=db.execute('SELECT * FROM script_revisions WHERE script_id=? AND revision=?',(schedule['script_id'],schedule['revision'])).fetchone()
                if not revision:
                    db.execute("UPDATE script_schedules SET enabled=0,next_run=NULL,message='Script revision is unavailable.' WHERE script_id=?",(schedule['script_id'],));continue
                item={**dict(revision),'id':schedule['script_id']}
                try:self.scripts.enqueue(item,{'uid':schedule['actor_uid'],'username':schedule['actor']},'schedule',db)
                except Problem as error:
                    db.execute('INSERT INTO script_runs (id,script_id,revision,sha256,actor_uid,actor,trigger,created,finished,status,message) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
                               (__import__('secrets').token_hex(12),item['id'],item['revision'],item['sha256'],schedule['actor_uid'],schedule['actor'],'schedule',now,now,'skipped',str(error)))
                db.execute('UPDATE script_schedules SET next_run=? WHERE script_id=?',(next_run,schedule['script_id']))

    def tick(self):
        now=self.cloud.clock()
        with self.cloud.db() as db:db.execute('INSERT OR REPLACE INTO script_runner_heartbeat VALUES (1,?)',(now,))
        self.schedule_due()
        self.futures={key:future for key,future in self.futures.items() if not future.done()}
        available=2-len(self.futures)
        if available<=0:return
        with self.cloud.db() as db:queued=[dict(r) for r in db.execute("SELECT * FROM script_runs WHERE status='queued' ORDER BY created LIMIT ?",(available,))]
        if not queued:return
        accounts={u['uid']:u for u in self.cloud.bridge('users')['users']}
        for run in queued:
            actor=accounts.get(run['actor_uid'])
            with self.cloud.db() as db:
                if not actor or actor.get('frozen') or actor.get('role') not in ('admin','superadmin'):
                    db.execute("UPDATE script_runs SET status='blocked',finished=?,message='Creator no longer has administrator access.' WHERE id=? AND status='queued'",(now,run['id']));continue
                changed=db.execute("UPDATE script_runs SET status='running',started=? WHERE id=? AND status='queued'",(now,run['id'])).rowcount
            if changed:self.futures[run['id']]=self.pool.submit(self.execute,run['id'])

    @staticmethod
    def terminate(process):
        try:os.killpg(process.pid,signal.SIGTERM)
        except ProcessLookupError:pass
        try:process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            try:os.killpg(process.pid,signal.SIGKILL)
            except ProcessLookupError:pass
            process.wait(timeout=3)
        # Also end descendants that outlive a normally completed Shell.
        try:os.killpg(process.pid,signal.SIGKILL)
        except ProcessLookupError:pass

    def execute(self,identifier):
        process=None;status='failed';message='';code=None;truncated=False
        try:
            with self.cloud.db() as db:
                run=db.execute('SELECT * FROM script_runs WHERE id=?',(identifier,)).fetchone()
                revision=db.execute('SELECT * FROM script_revisions WHERE script_id=? AND revision=?',(run['script_id'],run['revision'])).fetchone()
            if not revision or hashlib.sha256(revision['source'].encode()).hexdigest()!=run['sha256']:raise Problem('Script snapshot integrity check failed.')
            directory=self.scripts.directory/identifier;directory.mkdir(mode=0o700,exist_ok=False)
            source=directory/'script.sh';source.write_text(revision['source']);source.chmod(0o600)
            environment={'PATH':'/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin','HOME':'/root',
                         'LANG':'C.UTF-8','TZ':self.scripts.timezone,'KUBECONFIG':self.cloud.config.get('kubeconfig','/root/k8s-lab/admin.conf')}
            process=subprocess.Popen(['/bin/bash','--noprofile','--norc',str(source)],cwd=directory,env=environment,
                                     stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,start_new_session=True)
            started=time.monotonic();deadline=started+revision['timeout'];written=0;end_deadline=None
            with (directory/'output.log').open('wb') as output,selectors.DefaultSelector() as selector:
                selector.register(process.stdout,selectors.EVENT_READ)
                while selector.get_map() or process.poll() is None:
                    with self.cloud.db() as db:cancel=db.execute('SELECT cancel_requested FROM script_runs WHERE id=?',(identifier,)).fetchone()[0]
                    if end_deadline is None and (self.stop.is_set() or cancel or time.monotonic()>=deadline):
                        status='interrupted' if self.stop.is_set() else 'cancelled' if cancel else 'timed_out'
                        message={'interrupted':'Executor stopped; execution was not resumed.','cancelled':'Stopped by an administrator.','timed_out':'Execution time limit exceeded.'}[status]
                        self.terminate(process);end_deadline=time.monotonic()+2
                    for key,_ in selector.select(.2):
                        data=os.read(key.fileobj.fileno(),65536)
                        if not data:selector.unregister(key.fileobj);continue
                        keep=data[:max(0,MAX_LOG-written)]
                        if keep:output.write(keep);output.flush();written+=len(keep)
                        if len(keep)<len(data):truncated=True
                    if process.poll() is not None and end_deadline is None:
                        # Close inherited output pipes held by background children.
                        self.terminate(process);end_deadline=time.monotonic()+2
                    if end_deadline is not None and time.monotonic()>end_deadline:break
            code=process.wait(timeout=3)
            if not message:status='succeeded' if code==0 else 'failed';message='Completed.' if code==0 else 'Shell returned a nonzero exit code.'
        except Exception as error:message=str(error)[:1500]
        finally:
            if process is not None:
                try:self.terminate(process);code=process.returncode
                except Exception:pass
                if process.stdout:process.stdout.close()
            with self.cloud.db() as db:db.execute('UPDATE script_runs SET status=?,finished=?,exit_code=?,truncated=?,message=? WHERE id=?',
                (status,self.cloud.clock(),code,int(truncated),message,identifier))
            self.cloud.audit('script-executor','script-result',identifier,status)

    def serve(self):
        self.recover()
        try:
            while not self.stop.is_set():
                try:self.tick()
                except Exception:pass  # Queued work remains durable while dependencies recover.
                self.stop.wait(1)
        finally:self.stop.set();self.pool.shutdown(wait=True)


def unit_source(config='/etc/kssolv/admin.json'):
    return '''[Unit]
Description=KSSOLV Toolbox Online custom Shell executor
After=network-online.target kssolv-admin.service
Wants=network-online.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/kssolv-admin/app/admin/script_runner.py --config '''+config+'''
Restart=on-failure
RestartSec=5
UMask=0077
NoNewPrivileges=true
KillMode=control-group
TimeoutStopSec=10
[Install]
WantedBy=multi-user.target
'''


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--config',default='/etc/kssolv/admin.json');args=parser.parse_args()
    os.umask(0o077)
    cloud=Cloud(json.loads(Path(args.config).read_text()))
    with (cloud.directory/'script-runner.lock').open('a') as lock:
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:raise SystemExit('Another script executor is active.') from None
        runner=Runner(cloud)
        for sig in (signal.SIGINT,signal.SIGTERM):signal.signal(sig,lambda *_:runner.stop.set())
        runner.serve()
if __name__=='__main__':main()
