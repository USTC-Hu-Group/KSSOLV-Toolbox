"""Versioned Shell scripts, durable execution requests and schedules. Standard library only."""
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import tempfile
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from cloud import Problem

MAX_SOURCE=128*1024
MAX_LOG=4*1024*1024
SCRIPT_ID=re.compile(r'^[a-z][a-z0-9-]{1,39}$')
RUN_ID=re.compile(r'^[a-f0-9]{24}$')


def cron_fields(expression):
    if not isinstance(expression,str) or len(expression)>120:raise Problem('Invalid cron expression.')
    fields=expression.split()
    if len(fields)!=5:raise Problem('Cron requires minute, hour, day, month and weekday.')
    parsed=[]
    for raw,low,high in zip(fields,[0,0,1,1,0],[59,23,31,12,7]):
        values=set()
        for term in raw.split(','):
            match=re.fullmatch(r'(\*|\d+(?:-\d+)?)(?:/(\d+))?',term)
            if not match:raise Problem('Use cron numbers, *, ranges, lists and steps.')
            base,step=match.groups();step=int(step or 1)
            if not 1<=step<=high-low+1:raise Problem('Invalid cron step.')
            if base=='*':start,end=low,high
            elif '-' in base:start,end=map(int,base.split('-'))
            else:start=int(base);end=high if match[2] else start
            if not low<=start<=end<=high:raise Problem('Cron value is outside its allowed range.')
            values.update(range(start,end+1,step))
        parsed.append(values)
    parsed[-1]={0 if v==7 else v for v in parsed[-1]}
    return fields,parsed


def next_cron(expression,after,timezone):
    fields,(minutes,hours,days,months,weekdays)=cron_fields(expression)
    try:zone=ZoneInfo(timezone)
    except (ZoneInfoNotFoundError,ValueError):raise Problem('Invalid schedule timezone.') from None
    first=dt.datetime.fromtimestamp(after,zone).date()
    for offset in range(366*8):
        day=first+dt.timedelta(days=offset)
        if day.month not in months:continue
        dom=day.day in days;dow=(day.weekday()+1)%7 in weekdays
        matches=(dom and dow) if fields[2].startswith('*') or fields[4].startswith('*') else (dom or dow)
        if not matches:continue
        candidates=[]
        for hour in sorted(hours):
            for minute in sorted(minutes):
                for fold in (0,1):
                    local=dt.datetime.combine(day,dt.time(hour,minute),zone).replace(fold=fold)
                    stamp=local.timestamp();back=dt.datetime.fromtimestamp(stamp,zone)
                    if stamp>after and (back.date(),back.hour,back.minute)==(day,hour,minute):candidates.append(stamp)
        if candidates:return min(candidates)
    raise Problem('Cron expression has no occurrence within eight years.')


class Scripts:
    def __init__(self,cloud):
        self.cloud=cloud;self.directory=cloud.directory/'script-runs';self.directory.mkdir(mode=0o700,exist_ok=True)
        self.timezone=cloud.config.get('script_timezone','Asia/Shanghai')
        with cloud.db() as db:db.executescript('''
CREATE TABLE IF NOT EXISTS custom_scripts (id TEXT PRIMARY KEY,name TEXT NOT NULL,description TEXT NOT NULL,revision INTEGER NOT NULL,updated REAL NOT NULL,actor TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS script_revisions (script_id TEXT NOT NULL,revision INTEGER NOT NULL,source TEXT NOT NULL,sha256 TEXT NOT NULL,timeout INTEGER NOT NULL,created REAL NOT NULL,actor TEXT NOT NULL,PRIMARY KEY(script_id,revision));
CREATE TABLE IF NOT EXISTS script_schedules (script_id TEXT PRIMARY KEY,revision INTEGER NOT NULL,kind TEXT NOT NULL,expression TEXT NOT NULL,timezone TEXT NOT NULL,enabled INTEGER NOT NULL,next_run REAL,actor_uid TEXT NOT NULL,actor TEXT NOT NULL,updated REAL NOT NULL,message TEXT NOT NULL DEFAULT '');
CREATE TABLE IF NOT EXISTS script_runs (id TEXT PRIMARY KEY,script_id TEXT NOT NULL,revision INTEGER NOT NULL,sha256 TEXT NOT NULL,actor_uid TEXT NOT NULL,actor TEXT NOT NULL,trigger TEXT NOT NULL,created REAL NOT NULL,started REAL,finished REAL,status TEXT NOT NULL,exit_code INTEGER,cancel_requested INTEGER NOT NULL DEFAULT 0,truncated INTEGER NOT NULL DEFAULT 0,message TEXT NOT NULL DEFAULT '');
CREATE UNIQUE INDEX IF NOT EXISTS script_single_active ON script_runs(script_id) WHERE status IN ('queued','running');
CREATE INDEX IF NOT EXISTS script_run_history ON script_runs(script_id,created,id);
CREATE TABLE IF NOT EXISTS script_runner_heartbeat (id INTEGER PRIMARY KEY CHECK(id=1),timestamp REAL NOT NULL);
''')

    def inventory(self):
        with self.cloud.db() as db:
            scripts=[dict(r) for r in db.execute('SELECT s.*,r.sha256,r.timeout FROM custom_scripts s JOIN script_revisions r ON r.script_id=s.id AND r.revision=s.revision ORDER BY s.id')]
            schedules={r['script_id']:dict(r) for r in db.execute('SELECT * FROM script_schedules')}
            heartbeat=db.execute('SELECT timestamp FROM script_runner_heartbeat WHERE id=1').fetchone()
        for item in scripts:item['schedule']=schedules.get(item['id'])
        return {'scripts':scripts,'timezone':self.timezone,'executionUser':'root','executionHost':__import__('socket').gethostname(),
                'runnerReady':bool(heartbeat and self.cloud.clock()-heartbeat[0]<15),'maxSourceBytes':MAX_SOURCE}

    def get(self,identifier,revision=None):
        if not isinstance(identifier,str) or not SCRIPT_ID.fullmatch(identifier):raise Problem('Invalid script ID.')
        with self.cloud.db() as db:
            script=db.execute('SELECT * FROM custom_scripts WHERE id=?',(identifier,)).fetchone()
            if not script:raise Problem('Script not found.')
            row=db.execute('SELECT * FROM script_revisions WHERE script_id=? AND revision=?',(identifier,revision or script['revision'])).fetchone()
            if not row:raise Problem('Script revision not found.')
        return {**dict(script),**dict(row)}

    def save(self,data,actor):
        identifier,name,description,source=(data.get(k) for k in ('id','name','description','source'))
        if not isinstance(identifier,str) or not SCRIPT_ID.fullmatch(identifier):raise Problem('Use 2–40 lowercase letters, numbers or hyphens for the script ID.')
        if not isinstance(name,str) or not 1<=len(name.strip())<=80 or not isinstance(description,str) or len(description)>500:raise Problem('Invalid script description.')
        if not isinstance(source,str):raise Problem('Shell source is required.')
        source=source.removeprefix('\ufeff').replace('\r\n','\n').replace('\r','\n')
        if not source.strip() or '\x00' in source or len(source.encode())>MAX_SOURCE:raise Problem('Use a UTF-8 Shell script of at most 128 KiB.')
        timeout=data.get('timeout',300)
        if not isinstance(timeout,int) or isinstance(timeout,bool) or not 1<=timeout<=86400:raise Problem('Timeout must be 1–86400 seconds.')
        fd,path=tempfile.mkstemp(dir=self.cloud.directory,suffix='.sh')
        try:
            with os.fdopen(fd,'w') as file:file.write(source)
            syntax=subprocess.run(['/bin/bash','--noprofile','--norc','-n',path],capture_output=True,text=True,timeout=5)
            if syntax.returncode:raise Problem('Shell syntax error: '+syntax.stderr.replace(path,identifier+'.sh')[:1500])
        finally:Path(path).unlink(missing_ok=True)
        sha=hashlib.sha256(source.encode()).hexdigest();now=self.cloud.clock()
        with self.cloud.db() as db:
            db.execute('BEGIN IMMEDIATE')
            current=db.execute('SELECT revision FROM custom_scripts WHERE id=?',(identifier,)).fetchone()
            previous=current['revision'] if current else 0
            if data.get('expectedRevision',0)!=previous:raise Problem('Script changed. Reload it before saving or running.')
            revision=previous+1
            db.execute('INSERT INTO script_revisions VALUES (?,?,?,?,?,?,?)',(identifier,revision,source,sha,timeout,now,actor['username']))
            db.execute('INSERT INTO custom_scripts VALUES (?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,description=excluded.description,revision=excluded.revision,updated=excluded.updated,actor=excluded.actor',
                       (identifier,name.strip(),description,revision,now,actor['username']))
        self.cloud.audit(actor['username'],'script-save',identifier+'@'+str(revision),'succeeded')
        return self.get(identifier)

    def reviewed(self,data):
        item=self.get(data.get('id'))
        if (data.get('revision')!=item['revision'] or data.get('sha256')!=item['sha256']):raise Problem('Script changed. Reload it before saving or running.')
        if data.get('confirmation')!=item['id']:raise Problem('Type the script ID to confirm host execution.')
        return item

    def enqueue(self,item,actor,trigger='manual',db=None):
        if db is None:
            with self.cloud.db() as db:
                db.execute('BEGIN IMMEDIATE');return self.enqueue(item,actor,trigger,db)
        if db.execute("SELECT COUNT(*) FROM script_runs WHERE status='queued'").fetchone()[0]>=20:raise Problem('Script queue is full. Try again later.')
        if db.execute("SELECT 1 FROM script_runs WHERE script_id=? AND status IN ('queued','running')",(item['id'],)).fetchone():raise Problem('This script is already queued or running.')
        identifier=secrets.token_hex(12)
        db.execute('INSERT INTO script_runs (id,script_id,revision,sha256,actor_uid,actor,trigger,created,status) VALUES (?,?,?,?,?,?,?,?,?)',
                   (identifier,item['id'],item['revision'],item['sha256'],actor['uid'],actor['username'],trigger,self.cloud.clock(),'queued'))
        return identifier

    def run(self,data,actor):
        item=self.reviewed(data);identifier=self.enqueue(item,actor)
        self.cloud.audit(actor['username'],'script-run',item['id']+'@'+str(item['revision']),'queued')
        return {'run':identifier}

    def schedule(self,data,actor):
        item=self.reviewed(data);kind=data.get('kind');expression=str(data.get('expression','')).strip()
        if kind=='interval':
            if not re.fullmatch(r'[1-9][0-9]{0,4}',expression) or int(expression)>10080:raise Problem('Interval must be 1–10080 minutes.')
            next_run=self.cloud.clock()+int(expression)*60
        elif kind=='cron':next_run=next_cron(expression,self.cloud.clock(),self.timezone)
        else:raise Problem('Select an interval or cron schedule.')
        enabled=data.get('enabled')
        if not isinstance(enabled,bool):raise Problem('Invalid schedule state.')
        now=self.cloud.clock()
        with self.cloud.db() as db:db.execute('INSERT INTO script_schedules VALUES (?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(script_id) DO UPDATE SET revision=excluded.revision,kind=excluded.kind,expression=excluded.expression,timezone=excluded.timezone,enabled=excluded.enabled,next_run=excluded.next_run,actor_uid=excluded.actor_uid,actor=excluded.actor,updated=excluded.updated,message=excluded.message',
            (item['id'],item['revision'],kind,expression,self.timezone,int(enabled),next_run if enabled else None,actor['uid'],actor['username'],now,''))
        self.cloud.audit(actor['username'],'script-schedule',item['id'],'enabled' if enabled else 'paused')
        return {'ok':True}

    def pause(self,identifier,actor):
        self.get(identifier)
        with self.cloud.db() as db:db.execute('UPDATE script_schedules SET enabled=0,next_run=NULL,updated=? WHERE script_id=?',(self.cloud.clock(),identifier))
        self.cloud.audit(actor['username'],'script-schedule',identifier,'paused')
        return {'ok':True}

    def runs(self,identifier='',before=''):
        if identifier:self.get(identifier)
        clauses=[];params=[]
        if identifier:clauses.append('script_id=?');params.append(identifier)
        if before:
            try:timestamp,run_id=before.split(':');timestamp=float(timestamp)
            except (ValueError,AttributeError):raise Problem('Invalid run cursor.') from None
            if not __import__('math').isfinite(timestamp) or not RUN_ID.fullmatch(run_id):raise Problem('Invalid run cursor.')
            clauses.append('(created<? OR (created=? AND id<?))');params.extend([timestamp,timestamp,run_id])
        query='SELECT * FROM script_runs'+(' WHERE '+' AND '.join(clauses) if clauses else '')+' ORDER BY created DESC,id DESC LIMIT 51'
        with self.cloud.db() as db:rows=[dict(r) for r in db.execute(query,params)]
        more=len(rows)>50;rows=rows[:50]
        return {'runs':rows,'next':str(rows[-1]['created'])+':'+rows[-1]['id'] if more else ''}

    def result(self,identifier):
        if not isinstance(identifier,str) or not RUN_ID.fullmatch(identifier):raise Problem('Invalid run ID.')
        with self.cloud.db() as db:row=db.execute('SELECT * FROM script_runs WHERE id=?',(identifier,)).fetchone()
        if not row:raise Problem('Script run not found.')
        path=self.directory/identifier/'output.log';output=''
        if path.exists():
            with path.open('rb') as file:
                file.seek(max(0,path.stat().st_size-128*1024));output=file.read(128*1024).decode('utf-8',errors='replace')
        return {**dict(row),'output':output,'tailOnly':path.exists() and path.stat().st_size>128*1024}

    def cancel(self,identifier,actor):
        self.result(identifier);now=self.cloud.clock()
        with self.cloud.db() as db:
            db.execute("UPDATE script_runs SET status='cancelled',finished=?,message='Cancelled before execution.' WHERE id=? AND status='queued'",(now,identifier))
            db.execute("UPDATE script_runs SET cancel_requested=1 WHERE id=? AND status='running'",(identifier,))
        self.cloud.audit(actor['username'],'script-cancel',identifier,'requested')
        return {'ok':True}
