"""Host-side inventory, private portal bridge and durable resource accounting."""
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
import datetime
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import subprocess
import threading
import time
import xml.etree.ElementTree as ET
from urllib.error import HTTPError
from urllib.request import Request,urlopen

UID=re.compile(r'^[a-f0-9]{24}$')
LABEL='app.kubernetes.io/managed-by'
class Problem(Exception): pass

def kssolv_related(item):
    meta=item.get('metadata',{});labels=meta.get('labels',{})
    return (meta.get('namespace')=='kssolv-system' or labels.get(LABEL)=='kssolv-portal'
            or labels.get('app')=='kssolv-portal')

def quantity(value):
    match=re.fullmatch(r'([0-9]+(?:\.[0-9]+)?)([a-zA-Z]*)',str(value or 0))
    if not match: return 0
    return float(match[1])*{'n':1e-9,'u':1e-6,'m':1e-3,'':1,'Ki':1024,'Mi':1024**2,'Gi':1024**3,'Ti':1024**4,'k':1000,'M':1e6,'G':1e9}.get(match[2],1)

class Cloud:
    def __init__(self,config,clock=time.time):
        self.config,self.clock=config,clock
        self.directory=Path(config['state_dir']);self.directory.mkdir(parents=True,exist_ok=True,mode=0o700)
        self.dbfile=self.directory/'management.sqlite3';self.cache={};self.cache_lock=threading.Lock();self.mutation=threading.Lock()
        self.collection_lock=threading.Lock()
        with self.db() as db:
            db.executescript('''PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS admin_sessions (token TEXT PRIMARY KEY, csrf TEXT NOT NULL, expires REAL NOT NULL);
CREATE TABLE IF NOT EXISTS attempts (identity TEXT, timestamp REAL);
CREATE TABLE IF NOT EXISTS audit (timestamp REAL, actor TEXT, action TEXT, target TEXT, status TEXT);
CREATE TABLE IF NOT EXISTS confirmations (token TEXT PRIMARY KEY, session TEXT, body TEXT, expires REAL);
CREATE TABLE IF NOT EXISTS jobs (id TEXT PRIMARY KEY, timestamp REAL, actor TEXT, body TEXT, state TEXT, message TEXT);
CREATE TABLE IF NOT EXISTS scripts (id TEXT PRIMARY KEY, name TEXT, path TEXT, description TEXT);
CREATE TABLE IF NOT EXISTS samples (timestamp REAL, kind TEXT, identity TEXT, owner TEXT, cpu REAL, memory REAL, allocated_cpu REAL, allocated_memory REAL, counter REAL);
CREATE INDEX IF NOT EXISTS sample_target ON samples(kind,identity,timestamp);
CREATE TABLE IF NOT EXISTS usage_hourly (owner TEXT, hour INTEGER, cpu_seconds REAL, allocated_core_seconds REAL, coverage_seconds REAL, PRIMARY KEY(owner,hour));
CREATE TABLE IF NOT EXISTS sample_heads (identity TEXT PRIMARY KEY,timestamp REAL,counter REAL,allocated REAL);
CREATE TABLE IF NOT EXISTS observed_pods (identity TEXT PRIMARY KEY, body TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS pod_event_outbox (identity TEXT PRIMARY KEY, body TEXT NOT NULL);
''')
            columns={row['name'] for row in db.execute('PRAGMA table_info(admin_sessions)')}
            for name in ('uid','auth_token'):
                if name not in columns:db.execute('ALTER TABLE admin_sessions ADD COLUMN '+name+" TEXT NOT NULL DEFAULT ''")
            db.execute("DELETE FROM admin_sessions WHERE uid='' OR auth_token=''")
        self.dbfile.chmod(0o600)
    @contextmanager
    def db(self):
        db=sqlite3.connect(self.dbfile,timeout=15);db.row_factory=sqlite3.Row
        try:
            with db: yield db
        finally: db.close()
    def command(self,args,timeout=30,input=None):
        result=subprocess.run(args,input=input,text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=timeout)
        if result.returncode: raise Problem((result.stderr or result.stdout or 'Command failed')[-1500:])
        return result.stdout
    def kub(self,*args,**kwargs):
        return self.command(['kubectl','--kubeconfig',self.config['kubeconfig'],'--cache-dir',str(self.directory/'kube-cache'),*args],**kwargs)
    def get(self,kind,*args): return json.loads(self.kub('get',kind,*args,'-o','json'))
    def patch(self,kind,name,patch,namespace=None,subresource=None):
        args=['patch',kind,name,'--type=merge','-p',json.dumps(patch)]
        if namespace: args+=['-n',namespace]
        if subresource: args+=['--subresource',subresource]
        return json.loads(self.kub(*args,'-o','json'))
    def bridge(self,operation,data=None):
        token=Path(self.config['bridge_token_file']).read_text().strip()
        headers={'Host':self.config['origin'].split('://',1)[1],'Authorization':'Bearer '+token,'Origin':self.config['origin'],'Content-Type':'application/json'}
        request=Request(self.config['portal_url']+'/_portal/internal-admin/'+operation,headers=headers,data=None if data is None else json.dumps(data).encode())
        try:
            with urlopen(request,timeout=5 if data is None else 20) as response:return json.load(response)
        except HTTPError as error:
            try:
                with error:message=json.load(error)['error']
            except Exception:message='Portal control request failed.'
            if error.code in (401,403) and operation in ('admin-login','admin-session'):raise PermissionError(message) from None
            raise Problem(message) from None
    def audit(self,actor,action,target,status):
        with self.db() as db: db.execute('INSERT INTO audit VALUES (?,?,?,?,?)',(self.clock(),actor,action,target,status))
    def managed(self,namespace):
        if not re.fullmatch(r'kssolv-u-[a-f0-9]{24}',str(namespace)):raise Problem('Only KSSOLV workspaces can be changed.')
        uid=namespace.removeprefix('kssolv-u-')
        ns=self.get('namespace',namespace)
        labels=ns['metadata'].get('labels',{})
        if labels.get(LABEL)!='kssolv-portal' or labels.get('kssolv-user')!=uid:raise Problem('Tenant ownership verification failed.')
        return uid
    def runtime(self,namespace):
        uid=self.managed(namespace);item=self.get('deployment','runtime','-n',namespace)
        if item['metadata'].get('labels',{}).get('kssolv-user')!=uid:raise Problem('Deployment ownership verification failed.')
        return uid,item
    def collect(self):
        with self.collection_lock:return self._collect()
    def _collect(self):
        now=self.clock();nodes=self.get('nodes')['items'];pods=self.get('pods','-A')['items'];metrics={};errors=[]
        def summary(node):
            return json.loads(self.kub('get','--raw','/api/v1/nodes/'+node+'/proxy/stats/summary',timeout=12))
        with ThreadPoolExecutor(max_workers=4) as pool:
            futures={pool.submit(summary,n['metadata']['name']):n['metadata']['name'] for n in nodes}
            for future,node in futures.items():
                try:
                    item=future.result();metrics[('node',node)]=item['node']
                    for pod in item.get('pods',[]):
                        metrics[('pod',pod['podRef']['uid'])]=pod
                        metrics[('pod-name',pod['podRef']['namespace']+'/'+pod['podRef']['name'])]=pod
                except Exception as error:errors.append(node+': '+str(error)[:160])
        records=[];view_nodes=[];view_pods=[]
        def add(kind,identity,owner,raw,cpu,memory):
            source=metrics.get((kind,identity))
            if source is None and kind=='pod' and 'kubernetes.io/config.mirror' in raw.get('metadata',{}).get('annotations',{}):
                source=metrics.get(('pod-name',raw['metadata']['namespace']+'/'+raw['metadata']['name']))
            usage=source.get('cpu',{}) if source else {};mem=source.get('memory',{}) if source else {}
            stamp=usage.get('time')
            try:timestamp=datetime.datetime.fromisoformat(stamp.replace('Z','+00:00')).timestamp()
            except (ValueError,AttributeError):timestamp=0
            fresh=abs(now-timestamp)<60
            measurement={'cpu':usage['usageNanoCores']/1e9 if fresh and usage.get('usageNanoCores') is not None else None,'memory':mem.get('workingSetBytes') if fresh else None,'timestamp':timestamp or None,'stale':not fresh}
            if fresh and measurement['cpu'] is not None and measurement['memory'] is not None:
                records.append((timestamp,kind,identity,owner,measurement['cpu'],measurement['memory'],cpu,memory,float(usage.get('usageCoreNanoSeconds',0))/1e9))
            return measurement
        for node in nodes:
            name=node['metadata']['name'];cap=node['status']['capacity'];alloc=node['status']['allocatable']
            value={'name':name,'cpu':quantity(cap['cpu']),'memory':quantity(cap['memory']),'allocatableCpu':quantity(alloc['cpu']),'allocatableMemory':quantity(alloc['memory']),
                   'ready':any(c['type']=='Ready' and c['status']=='True' for c in node['status']['conditions']),'unschedulable':node['spec'].get('unschedulable',False),'version':node['status']['nodeInfo']['kubeletVersion'],'worker':name in self.config['workers']}
            value.update(vmCpu=None,vmMemory=None)
            if name in [self.config.get('control_plane'),*self.config['workers']]:
                try:
                    vm=ET.fromstring(self.command(['virsh','dumpxml','--inactive',name]))
                    value['vmCpu']=int(vm.find('vcpu').text)
                    memory=vm.find('memory');unit=memory.get('unit','KiB')
                    value['vmMemory']=int(memory.text)*{'KiB':1024,'MiB':1024**2,'GiB':1024**3,'bytes':1}.get(unit,1024)
                except Exception:value['vmConfigUnavailable']=True
            measurement=add('node',name,'',node,value['cpu'],value['memory']);value.update(usedCpu=measurement['cpu'],usedMemory=measurement['memory'],timestamp=measurement['timestamp'],stale=measurement['stale']);view_nodes.append(value)
        for pod in pods:
            meta=pod['metadata'];namespace=meta['namespace'];labels=meta.get('labels',{});owner=labels.get('kssolv-user','')
            limits={key:sum(quantity(c.get('resources',{}).get('limits',{}).get(key,0)) for c in pod['spec']['containers']) for key in ['cpu','memory']}
            requests={key:sum(quantity(c.get('resources',{}).get('requests',{}).get(key,0)) for c in pod['spec']['containers']) for key in ['cpu','memory']}
            managed=bool(UID.fullmatch(owner)) and namespace=='kssolv-u-'+owner and labels.get(LABEL)=='kssolv-portal'
            statuses=pod['status'].get('containerStatuses',[])
            value={'uid':meta['uid'],'name':meta['name'],'namespace':namespace,'owner':owner if managed else '', 'node':pod['spec'].get('nodeName',''), 'phase':'Terminating' if meta.get('deletionTimestamp') else pod['status'].get('phase','Unknown'),
                   'actualResources':{key:sum(quantity(c.get('resources',{}).get('requests',c.get('allocatedResources',{})).get(key,0)) for c in statuses) for key in ['cpu','memory']},'managed':managed,'static':'kubernetes.io/config.mirror' in meta.get('annotations',{}),'requests':requests,'limits':limits,'restarts':sum(c['restartCount'] for c in statuses),'ready':bool(statuses) and all(c.get('ready') for c in statuses),
                   'conditions':[{'type':c['type'],'status':c['status'],'reason':c.get('reason',''),'message':c.get('message','')[:400]} for c in pod['status'].get('conditions',[])],
                   'containers':[{'name':c['name'],'image':c['image'],'resources':c.get('resources',{})} for c in pod['spec']['containers']],
                   'allocated':[{'name':c['name'],'resources':c.get('resources',c.get('allocatedResources',{}))} for c in statuses]}
            value.update(add('pod',meta['uid'],value['owner'],pod,requests['cpu'],requests['memory']))
            if kssolv_related(pod):view_pods.append(value)
        self.observe_pods(pods,now)
        try:self.flush_pod_events()
        except Exception:errors.append('Pod activity delivery pending; events remain queued on the host.')
        self.record(records,now)
        controllers=self.get('deployments,statefulsets,daemonsets','-A')['items']
        workloads=[{'name':w['metadata']['name'],'namespace':w['metadata']['namespace'],'kind':w['kind'].lower(),
                    'replicas':w['spec'].get('replicas',w.get('status',{}).get('desiredNumberScheduled',0)),
                    'ready':w.get('status',{}).get('readyReplicas',w.get('status',{}).get('numberReady',0)),
                    'suspended':bool(w['spec'].get('template',{}).get('spec',{}).get('nodeSelector',{}).get('kssolv-admin/disabled')),
                    'containers':[{'name':c['name'],'resources':c.get('resources',{})} for c in w['spec']['template']['spec']['containers']]}
                   for w in controllers if kssolv_related(w) and not w['metadata']['namespace'].startswith('kssolv-u-')]
        snapshot={'workloads':workloads,'timestamp':now,'nodes':view_nodes,'pods':view_pods,'metricErrors':errors}
        with self.cache_lock:self.cache=snapshot
        return snapshot

    def observe_pods(self,pods,now):
        def stamp(value):
            try:return datetime.datetime.fromisoformat(value.replace('Z','+00:00')).timestamp()
            except (ValueError,AttributeError):return now
        with self.db() as db:
            previous={r['identity']:json.loads(r['body']) for r in db.execute('SELECT * FROM observed_pods')}
            current={}
            def emit(item,action,when,detail=''):
                body={'uid':item['owner'],'namespace':item['namespace'],'pod':item['name'],
                      'resources':item['resources'],'action':action,'timestamp':when,'status':'observed','detail':detail}
                identity=item['identity']+':'+action+':'+hashlib.sha256(json.dumps(body,sort_keys=True).encode()).hexdigest()
                body['key']=identity
                db.execute('INSERT OR IGNORE INTO pod_event_outbox VALUES (?,?)',(identity,json.dumps(body)))
            for pod in pods:
                meta=pod['metadata'];owner=meta.get('labels',{}).get('kssolv-user','')
                if (not UID.fullmatch(owner) or meta['namespace']!='kssolv-u-'+owner
                        or meta.get('labels',{}).get(LABEL)!='kssolv-portal'):continue
                containers=pod['spec']['containers'];runtime=next((c for c in containers if c['name']=='runtime'),containers[0])
                resources=runtime.get('resources',{});size=resources.get('limits') or resources.get('requests',{})
                statuses=pod.get('status',{}).get('containerStatuses',[])
                status=next((c for c in statuses if c['name']==runtime['name']),{})
                running=status.get('state',{}).get('running',{})
                terminated=status.get('state',{}).get('terminated',{})
                item={'identity':meta['uid'],'owner':owner,'namespace':meta['namespace'],'name':meta['name'],
                      'resources':{k:str(size.get(k,'')) for k in ('cpu','memory')},
                      'phase':pod.get('status',{}).get('phase','Unknown'),'container':status.get('containerID',''),
                      'restarts':status.get('restartCount',0),'terminating':meta.get('deletionTimestamp',''),
                      'running':bool(running),'finished':terminated.get('finishedAt','')}
                old=previous.get(meta['uid']);current[meta['uid']]=item
                if old is None:emit(item,'pod_created',stamp(meta.get('creationTimestamp')), 'First observation; creation time comes from Kubernetes.')
                if running and (old is None or not old['running'] or old['container']!=item['container']):
                    emit(item,'pod_restarted' if old and old['container'] else 'pod_started',stamp(running.get('startedAt')))
                if old and old['resources']!=item['resources']:emit(item,'pod_resized',now,'Resource configuration change observed.')
                if item['terminating'] and (not old or not old['terminating']):emit(item,'pod_terminating',stamp(item['terminating']))
                if item['finished'] and (not old or old['finished']!=item['finished']):emit(item,'pod_stopped',stamp(item['finished']),'Container termination time from Kubernetes.')
                db.execute('INSERT OR REPLACE INTO observed_pods VALUES (?,?)',(meta['uid'],json.dumps(item)))
            for identity,item in previous.items():
                if identity not in current:
                    if not item['finished']:emit(item,'pod_stopped',now,'Pod no longer observed; exact termination time is unavailable. This is the observation time.')
                    db.execute('DELETE FROM observed_pods WHERE identity=?',(identity,))

    def flush_pod_events(self):
        # Bounded batches stay queued across host/Portal restarts. The Portal
        # deduplicates source keys if delivery succeeded before a disconnect.
        with self.db() as db:rows=list(db.execute('SELECT * FROM pod_event_outbox ORDER BY rowid LIMIT 50'))
        if not rows:return
        result=self.bridge('record-pod-events',{'events':[json.loads(row['body']) for row in rows]})
        if result.get('ok') is not True:raise Problem('Pod activity delivery failed.')
        with self.db() as db:db.executemany('DELETE FROM pod_event_outbox WHERE identity=?',[(r['identity'],) for r in rows])

    def user_events(self,query):
        self.flush_pod_events()
        return self.bridge('events',query)
    def record(self,records,now):
        with self.db() as db:
            for row in records:
                timestamp,kind,identity,owner,cpu,memory,allocated_cpu,allocated_memory,counter=row
                previous=db.execute('SELECT * FROM sample_heads WHERE identity=?',(kind+':'+identity,)).fetchone()
                if previous and timestamp<=previous['timestamp']:continue
                db.execute('INSERT INTO samples VALUES (?,?,?,?,?,?,?,?,?)',row)
                if owner and previous:
                    dt=timestamp-previous['timestamp'];used=counter-previous['counter']
                    if 0<dt<=60 and 0<=used<=dt*max(previous['allocated'],allocated_cpu,1)*1.5:
                        # Split intervals at UTC hour boundaries, including proportional CPU time.
                        cursor=previous['timestamp']
                        while cursor<timestamp:
                            hour=int(cursor//3600)*3600;end=min(timestamp,hour+3600);part=end-cursor
                            db.execute('INSERT INTO usage_hourly VALUES (?,?,?,?,?) ON CONFLICT(owner,hour) DO UPDATE SET cpu_seconds=cpu_seconds+excluded.cpu_seconds,allocated_core_seconds=allocated_core_seconds+excluded.allocated_core_seconds,coverage_seconds=coverage_seconds+excluded.coverage_seconds',
                                       (owner,hour,used*part/dt,previous['allocated']*part,part));cursor=end
                db.execute('INSERT OR REPLACE INTO sample_heads VALUES (?,?,?,?)',(kind+':'+identity,timestamp,counter,allocated_cpu))
            db.execute('DELETE FROM samples WHERE timestamp<?',(now-7*86400,))
            db.execute('DELETE FROM usage_hourly WHERE hour<?',(now-366*86400,))
            db.execute('DELETE FROM admin_sessions WHERE expires<?',(now,));db.execute('DELETE FROM confirmations WHERE expires<?',(now,));db.execute('DELETE FROM attempts WHERE timestamp<?',(now-3600,))
    def history(self,kind,identity,hours=24):
        if kind not in ('node','pod','user'):raise Problem('Invalid chart type.')
        if kind=='user':
            if not UID.fullmatch(identity):raise Problem('Invalid user identity.')
            query='SELECT hour AS timestamp,cpu_seconds/3600 AS cpuHours,allocated_core_seconds/3600 AS allocatedHours,coverage_seconds FROM usage_hourly WHERE owner=? AND hour>? ORDER BY hour'
            params=(identity,self.clock()-hours*3600)
        else:
            query='SELECT CAST(timestamp/60 AS INTEGER)*60 AS timestamp,AVG(cpu) AS cpu,AVG(memory) AS memory,MAX(allocated_cpu) AS allocatedCpu,MAX(allocated_memory) AS allocatedMemory FROM samples WHERE kind=? AND identity=? AND timestamp>? GROUP BY CAST(timestamp/60 AS INTEGER) ORDER BY timestamp'
            params=(kind,identity,self.clock()-hours*3600)
        with self.db() as db:return [dict(row) for row in db.execute(query,params)]
    def snapshot(self):
        with self.cache_lock:state=dict(self.cache)
        if not state:state={'timestamp':None,'nodes':[],'pods':[],'workloads':[],'metricErrors':['Waiting for first collection.']}
        try:accounts=self.bridge('users')
        except Exception as error:accounts={'users':[],'profiles':{},'accountError':str(error)}
        with self.db() as db:
            usage={row['owner']:dict(row) for row in db.execute('SELECT owner,SUM(cpu_seconds)/3600 AS cpuHours,SUM(allocated_core_seconds)/3600 AS allocatedHours,SUM(coverage_seconds) AS coverageSeconds,MIN(hour) AS since FROM usage_hourly GROUP BY owner')}
            jobs=[dict(r) for r in db.execute('SELECT * FROM jobs ORDER BY timestamp DESC LIMIT 30')]
            audit=[dict(r) for r in db.execute('SELECT * FROM audit ORDER BY timestamp DESC LIMIT 100')]
            scripts=[dict(r) for r in db.execute('SELECT * FROM scripts ORDER BY id')]
        for job in jobs:job['body']=json.loads(job['body'])
        state.update(accounts);state.update(usage=usage,jobs=jobs,audit=audit,scripts=scripts,scriptDirectory=self.config['script_dir'],collectionSeconds=15,stale=not state['timestamp'] or self.clock()-state['timestamp']>45)
        return state
