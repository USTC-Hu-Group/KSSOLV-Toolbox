"""Explicit, audited operations on owned workspaces and configured KVM workers."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import secrets
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from decimal import Decimal, InvalidOperation
from cloud import Cloud,Problem,quantity
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'portal'))
from profiles import workspace_resources

class Operations:
    def __init__(self,cloud):self.cloud=cloud
    def validate(self,body):
        if not isinstance(body,dict):raise Problem('Invalid operation.')
        action=body.get('action');target=body.get('target','');profile=body.get('profile')
        allowed=('start','stop','restart','destroy','resize','freeze','restore','worker-resize','worker-restart','cluster-restart','workload-start','workload-stop','workload-restart','workload-resize','workload-destroy')
        if action not in allowed:raise Problem('Unknown operation.')
        clean={'action':action,'target':target};impact=''
        if action.startswith('workload-'):
            namespace,kind,item=self.workload(target)
            if body.get('workloadUid') and body['workloadUid']!=item['metadata']['uid']:raise Problem('Workload identity changed. Confirm a new operation.')
            if kind=='job' and action in ('workload-restart','workload-resize'):raise Problem('Job templates are immutable. Create a new Job from the original manifest.')
            if kind=='pod' and action in ('workload-start','workload-restart'):raise Problem('A standalone Pod has no restart/start controller. Recreate its original manifest.')
            clean.update(target=namespace+'/'+kind+'/'+item['metadata']['name'],workloadUid=item['metadata']['uid'])
            if action=='workload-resize':
                containers=item['spec']['containers'] if kind=='pod' else item['spec']['template']['spec']['containers']
                container=body.get('container') or (containers[0]['name'] if len(containers)==1 else '')
                if container not in [c['name'] for c in containers]:raise Problem('Select a container to resize.')
                requested=body.get('resources')
                if requested is None:
                    requested={'requests':{'cpu':str(body['cpu']),'memory':str(int(body['memoryGiB'])*1024)+'Mi'},'limits':{'cpu':str(body['cpu']),'memory':str(int(body['memoryGiB'])*1024)+'Mi'}}
                if not isinstance(requested,dict) or set(requested)-{'requests','limits'}:raise Problem('Invalid resource fields.')
                resources={}
                for group in ('requests','limits'):
                    values=requested.get(group,{})
                    if not isinstance(values,dict) or set(values)-{'cpu','memory'}:raise Problem('Only CPU and memory can be changed here.')
                    resources[group]={}
                    if values.get('cpu') not in (None,''):
                        try:cpu=Decimal(str(values['cpu']))
                        except InvalidOperation:raise Problem('Invalid CPU quantity.')
                        if not cpu.is_finite() or cpu<0 or cpu>128 or (cpu*1000)%1 or (group=='limits' and not cpu):raise Problem('CPU must be positive, at most 128 cores, with milllicore precision. Leave an unlimited limit blank.')
                        resources[group]['cpu']=format(cpu.normalize(),'f')
                    if values.get('memory') not in (None,''):
                        memory=str(values['memory'])
                        if not re.fullmatch(r'[0-9]+(?:Mi|Gi)',memory) or quantity(memory)>1024**4 or (group=='limits' and quantity(memory)<=0):raise Problem('Use positive Mi or Gi memory quantities; leave an unlimited limit blank.')
                        resources[group]['memory']=memory
                for key in ('cpu','memory'):
                    if key in resources['requests'] and key in resources['limits'] and quantity(resources['requests'][key])>quantity(resources['limits'][key]):raise Problem('A resource request cannot exceed its limit.')
                clean.update(resources=resources,container=container)
            impact='This operation affects every Pod managed by '+clean['target']+'. Services using this workload may be interrupted. Persistent volume claims are retained. Controller size changes may rebuild Pods; standalone Pods use in-place resize.'
        elif action.startswith('worker-'):
            if target not in self.cloud.config['workers']:raise Problem('Only configured workers can be managed.')
            if action=='worker-resize':
                try:cpu=int(body['cpu']);memory=int(body['memoryGiB'])
                except (ValueError,TypeError,KeyError):raise Problem('CPU and GiB memory must be whole numbers.')
                if cpu!=body['cpu'] or memory!=body['memoryGiB']:raise Problem('Worker CPU and GiB memory must be whole numbers.')
                if not 2<=cpu<=128 or not 4<=memory<=1024:raise Problem('Worker size is outside allowed limits.')
                clean.update(cpu=cpu,memoryGiB=memory)
            impact='The worker VM will shut down and restart. Disks are retained. Stop its user workspaces first.'
        elif action=='cluster-restart':
            if target!='CLUSTER':raise Problem('Type CLUSTER to select cluster restart.')
            impact='All user workspaces will stop, then the Kubernetes virtual machines will restart. Users must start their workspaces again afterward. Unsaved work is lost; saved files and disks are retained. The management page stays available.'
        else:
            uid=self.cloud.managed(target);users=self.cloud.bridge('users')
            user=next((u for u in users['users'] if u['uid']==uid),None)
            if not user:raise Problem('User does not exist.')
            if action=='freeze' and user.get('role')=='superadmin':raise Problem('The superadministrator account is protected.')
            if action in ('resize','start') or (action=='restart' and profile):
                if profile=='custom':
                    try:clean['resources']=workspace_resources(body.get('resources'))
                    except ValueError as error:raise Problem(str(error)) from None
                elif profile not in users['profiles'] or body.get('resources') is not None:raise Problem('Select a workspace size.')
                clean['profile']=profile
            if action=='resize':impact='CPU and memory will change in place when Kubernetes can apply the request. Memory shrink may be refused if usage is too high, and may interrupt the container if usage grows during the change. No automatic restart fallback.'
            if action in ('stop','restart','destroy','freeze'):impact='The current instance will close. Unsaved changes are lost. Saved files and storage are retained.'
            if action=='destroy':impact+=' The runtime Deployment is removed; the account and data volume remain available for a future start.'
            if action=='restore':impact='The account may sign in again. Its instance is not started automatically.'
            if action=='freeze':impact+=' All account sessions are revoked.'
        return clean,impact
    def run(self,body,progress=lambda message:None):
        body,_=self.validate(body);action=body['action'];target=body['target'];cloud=self.cloud
        if action.startswith('workload-'):return self.change_workload(body,progress)
        if action.startswith('worker-'):return self.worker(body,progress)
        if action=='cluster-restart':return self.cluster(progress)
        uid=cloud.managed(target)
        if action=='resize':return self.resize(target,body['profile'],progress,resources=body.get('resources'))
        if action=='destroy':
            cloud.bridge('stop',{'uid':uid});progress('Stopped instance. Removing compute Deployment; retaining PVC.')
            try:_,deployment=cloud.runtime(target)
            except Problem as error:
                if 'NotFound' not in str(error):raise
            else:
                cloud.kub('delete','deployment','runtime','-n',target,'--wait=true','--timeout=90s',timeout=100)
            return 'Compute destroyed. Account, saved files and PVC retained.'
        cloud.bridge(action,{'uid':uid,**({'profile':body['profile']} if body.get('profile') else {}),**({'resources':body['resources']} if body.get('resources') else {})})
        return 'Operation accepted by the workspace controller.'
    def resize(self,namespace,profile,progress,*,resources=None):
        cloud=self.cloud;uid,deployment=cloud.runtime(namespace)
        size=workspace_resources(resources) if profile=='custom' else cloud.bridge('users')['profiles'][profile]
        saved={'uid':uid,'profile':profile,**({'resources':size} if profile=='custom' else {})}
        pods=cloud.get('pods','-n',namespace,'-l','kssolv-user='+uid)['items']
        active=[p for p in pods if not p['metadata'].get('deletionTimestamp') and p['status'].get('phase')=='Running']
        if not active:
            cloud.bridge('resources',saved)
            # A stopped Deployment can be updated without starting it.
            containers=deployment['spec']['template']['spec']['containers']
            for c in containers:
                if c['name']=='runtime':
                    for key in ['requests','limits']:c['resources'][key].update(size)
            cloud.patch('deployment','runtime',{'spec':{'template':{'spec':{'containers':containers}}}},namespace)
            cloud.patch('resourcequota','tenant',{'spec':{'hard':{'limits.cpu':size['cpu'],'limits.memory':size['memory']}}},namespace)
            return 'Saved size for the next start. No instance was started.'
        if len(active)!=1:raise Problem('Wait until only one active runtime Pod exists.')
        pod=active[0];container=next(c for c in pod['spec']['containers'] if c['name']=='runtime');old=container['resources']['limits']
        if quantity(size['memory'])<quantity(old['memory']):
            with cloud.cache_lock:sample=next((p for p in cloud.cache.get('pods',[]) if p['uid']==pod['metadata']['uid']),None)
            if not sample or sample['stale'] or sample['memory'] is None or abs(cloud.clock()-(sample.get('timestamp') or 0))>60:raise Problem('Fresh memory usage is required before shrinking.')
            if quantity(size['memory'])<sample['memory']*1.2+128*1024**2:raise Problem('Memory usage is too close to the requested limit. Free memory or choose a larger size.')
        owner=next((r for r in pod['metadata'].get('ownerReferences',[]) if r['kind']=='ReplicaSet' and r.get('controller')),None)
        if not owner:raise Problem('Runtime ReplicaSet could not be verified.')
        replica=cloud.get('replicaset',owner['name'],'-n',namespace)
        if replica['metadata']['uid']!=owner['uid'] or replica['metadata'].get('labels',{}).get('kssolv-user')!=uid:raise Problem('ReplicaSet ownership verification failed.')
        # Keep the existing RS template equal to the Deployment template, so
        # unpausing does not create a replacement Pod after an in-place resize.
        if deployment['spec'].get('paused'):raise Problem('Deployment is already paused by another operation.')
        hard={'limits.cpu':str(max(quantity(old['cpu']),quantity(size['cpu']))),'limits.memory':str(int(max(quantity(old['memory']),quantity(size['memory']))))}
        cloud.patch('resourcequota','tenant',{'spec':{'hard':hard}},namespace)
        cloud.patch('deployment','runtime',{'spec':{'paused':True}},namespace)
        try:
            resources=json.loads(json.dumps(container['resources']))
            for key in ['requests','limits']:resources[key].update(size)
            containers=json.loads(json.dumps(pod['spec']['containers']))
            next(c for c in containers if c['name']=='runtime')['resources']=resources
            progress('Requesting Kubernetes in-place resize; existing Pod identity is retained.')
            cloud.patch('pod',pod['metadata']['name'],{'metadata':{'resourceVersion':pod['metadata']['resourceVersion']},'spec':{'containers':containers}},namespace,subresource='resize')
            for kind,name,item in [('replicaset',owner['name'],replica),('deployment','runtime',deployment)]:
                values=item['spec']['template']['spec']['containers']
                next(c for c in values if c['name']=='runtime')['resources']=resources
                cloud.patch(kind,name,{'spec':{'template':{'spec':{'containers':values}}}},namespace)
            cloud.bridge('resources',saved)
        finally:cloud.patch('deployment','runtime',{'spec':{'paused':False}},namespace)
        deadline=time.monotonic()+120
        while time.monotonic()<deadline:
            updated=cloud.get('pod',pod['metadata']['name'],'-n',namespace)
            if updated['metadata']['uid']!=pod['metadata']['uid']:raise Problem('Pod identity changed; review the monitoring page.')
            status=next((c for c in updated['status'].get('containerStatuses',[]) if c['name']=='runtime'),{})
            applied=status.get('resources',{}).get('limits',{})
            conditions=[c for c in updated['status'].get('conditions',[]) if c['type'] in ('PodResizePending','PodResizeInProgress') and c['status']=='True']
            if all(quantity(applied.get(key))==quantity(size[key]) for key in ['cpu','memory']) and not conditions:
                cloud.patch('resourcequota','tenant',{'spec':{'hard':{'limits.cpu':size['cpu'],'limits.memory':size['memory']}}},namespace)
                return 'Resize applied. Same Pod retained; check actual container resources in monitoring.'
            progress('Kubernetes resize pending: '+('; '.join(c.get('reason','')+': '+c.get('message','') for c in conditions) or 'waiting for kubelet'))
            time.sleep(3)
        return 'Resize requested but not yet applied. Kubernetes may be deferring it. Inspect actual and desired resources; no restart was performed.'
    def workload(self,target):
        cloud=self.cloud;parts=str(target).split('/')
        if len(parts) not in (2,3) or any(not re.fullmatch(r'[a-z0-9][a-z0-9.-]*',part) for part in parts):raise Problem('Invalid workload target.')
        namespace=parts[0]
        if namespace.startswith('kssolv-u-'):raise Problem('Use workspace operations for tenant workloads so account state remains consistent.')
        kind,name=('pod',parts[1]) if len(parts)==2 else (parts[1],parts[2])
        if kind not in ('pod','deployment','statefulset','daemonset','job'):raise Problem('Unsupported workload controller.')
        item=cloud.get(kind,name,'-n',namespace)
        if kind=='pod':
            if 'kubernetes.io/config.mirror' in item['metadata'].get('annotations',{}):raise Problem('Static control-plane Pods must use node or cluster restart.')
            owner=next((r for r in item['metadata'].get('ownerReferences',[]) if r.get('controller')),None)
            if owner:
                parent=cloud.get(owner['kind'],owner['name'],'-n',namespace)
                if parent['metadata']['uid']!=owner['uid']:raise Problem('Controller identity changed. Refresh before retrying.')
                if owner['kind']=='ReplicaSet':
                    owner=next((r for r in parent['metadata'].get('ownerReferences',[]) if r.get('controller')),None)
                    if not owner or owner['kind']!='Deployment':raise Problem('A standalone ReplicaSet is not supported. Manage its manifest on the host.')
                    parent=cloud.get('deployment',owner['name'],'-n',namespace)
                    if parent['metadata']['uid']!=owner['uid']:raise Problem('Deployment identity changed.')
                kind=owner['kind'].lower();item=parent
                if kind not in ('deployment','statefulset','daemonset','job'):raise Problem('This custom controller must be managed through its operator.')
        return namespace,kind,item
    def change_workload(self,body,progress):
        cloud=self.cloud;namespace,kind,item=self.workload(body['target']);name=item['metadata']['name'];action=body['action']
        if item['metadata']['uid']!=body['workloadUid']:raise Problem('Workload was recreated. Confirm a new operation.')
        if kind=='statefulset':cloud.patch(kind,name,{'spec':{'persistentVolumeClaimRetentionPolicy':{'whenDeleted':'Retain','whenScaled':'Retain'}}},namespace)
        if action!='workload-start':
            claims=cloud.get('pvc','-n',namespace)['items']
            if any(c['metadata'].get('ownerReferences') for c in claims):raise Problem('This namespace contains controller-owned PVCs. Review retention policies on the host before changing or stopping workloads.')
        def apply_resources(container):
            for group in ('requests','limits'):
                current=container.setdefault('resources',{}).setdefault(group,{})
                for key in ('cpu','memory'):
                    if key in body['resources'][group]:current[key]=body['resources'][group][key]
                    else:current.pop(key,None)
        if kind=='pod':
            if action=='workload-resize':
                containers=item['spec']['containers'];container=next(c for c in containers if c['name']==body['container'])
                apply_resources(container)
                cloud.patch('pod',name,{'metadata':{'resourceVersion':item['metadata']['resourceVersion']},'spec':{'containers':containers}},namespace,subresource='resize')
                return 'In-place resize requested for standalone Pod; review actual allocation in monitoring.'
            if action in ('workload-stop','workload-destroy'):
                cloud.kub('delete','pod',name,'-n',namespace,'--wait=true','--timeout=90s',timeout=100);return 'Standalone Pod removed. No controller will recreate it.'
            raise Problem('A standalone Pod has no restart/start controller. Recreate it from its original manifest.')
        if action=='workload-destroy':
            cloud.kub('delete',kind,name,'-n',namespace,'--cascade=foreground','--wait=true','--timeout=90s',timeout=100)
            return 'Workload and its Pods removed. Persistent volume claims retained.'
        if action in ('workload-start','workload-stop'):
            annotations=item['metadata'].get('annotations',{});stop=action=='workload-stop'
            if kind in ('deployment','statefulset'):
                previous=int(annotations.get('kssolv-admin/previous-replicas','1'))
                patch={'spec':{'replicas':0 if stop else max(1,previous)}}
                if stop and item['spec'].get('replicas',1)>0:patch['metadata']={'annotations':{'kssolv-admin/previous-replicas':str(item['spec'].get('replicas',1))}}
            elif kind=='daemonset':
                patch={'spec':{'template':{'spec':{'nodeSelector':{'kssolv-admin/disabled':secrets.token_hex(16) if stop else None}}}}}
            elif kind=='job':patch={'spec':{'suspend':stop}}
            cloud.patch(kind,name,patch,namespace);return 'Workload stop/start configuration applied.'
        if action=='workload-restart':
            if kind=='job':raise Problem('Jobs cannot be safely restarted in place. Create a new Job from the original manifest.')
            cloud.patch(kind,name,{'spec':{'template':{'metadata':{'annotations':{'kssolv-admin/restarted-at':str(time.time())}}}}},namespace)
            return 'Controller rolling restart requested; monitor readiness and events.'
        if action=='workload-resize':
            containers=item['spec']['template']['spec']['containers'];container=next(c for c in containers if c['name']==body['container'])
            apply_resources(container)
            if kind=='job':raise Problem('Job Pod templates are immutable; create a new Job with the new size.')
            cloud.patch(kind,name,{'spec':{'template':{'spec':{'containers':containers}}}},namespace)
            return 'Workload resources updated. Its controller will rebuild Pods according to its update strategy.'
        raise Problem('Unsupported workload operation.')

    def wait_vm_off(self,name,timeout=180):
        cloud=self.cloud
        state=cloud.command(['virsh','domstate',name]).strip()
        if state=='shut off':return
        cloud.command(['virsh','shutdown',name]);deadline=time.monotonic()+timeout
        while time.monotonic()<deadline:
            if cloud.command(['virsh','domstate',name]).strip()=='shut off':return
            time.sleep(2)
        raise Problem('Graceful shutdown timed out. No forced VM destruction was performed.')
    def worker(self,body,progress):
        cloud=self.cloud;name=body['target'];pods=cloud.get('pods','-A','--field-selector=spec.nodeName='+name)['items']
        if any(p['metadata']['namespace'].startswith('kssolv-u-') and p['status'].get('phase') in ('Running','Pending') for p in pods):raise Problem('Stop all user workspaces on this worker before changing or restarting it.')
        original_xml=cloud.command(['virsh','dumpxml','--inactive',name]);domain=ET.fromstring(original_xml)
        target_xml=None
        if body['action']=='worker-resize':
            host_memory=int(next(line.split()[1] for line in Path('/proc/meminfo').read_text().splitlines() if line.startswith('MemTotal:')))*1024
            other_memory=other_cpu=0
            for other in [cloud.config['control_plane'],*cloud.config['workers']]:
                if other==name:continue
                info=ET.fromstring(cloud.command(['virsh','dumpxml','--inactive',other]))
                other_memory+=int(info.find('memory').text)*1024
                other_cpu+=int(info.find('vcpu').text)
            if body['memoryGiB']*1024**3+other_memory>host_memory-4*1024**3:raise Problem('Requested size leaves less than 4 GiB for the host or overcommits configured VM memory.')
            if body['cpu']+other_cpu>(os.cpu_count() or 1):raise Problem('Requested size overcommits host CPU cores.')
            if domain.find('./cpu/numa') is not None:raise Problem('NUMA-configured VMs require a manual topology change.')
            domain.find('vcpu').text=str(body['cpu'])
            if 'current' in domain.find('vcpu').attrib:domain.find('vcpu').set('current',str(body['cpu']))
            topology=domain.find('./cpu/topology')
            if topology is not None:
                topology.attrib.clear();topology.attrib.update(sockets='1',dies='1',cores=str(body['cpu']),threads='1')
            for key in ['memory','currentMemory']:
                item=domain.find(key)
                if item is not None:item.set('unit','KiB');item.text=str(body['memoryGiB']*1048576)
            maximum=domain.find('maxMemory')
            if maximum is not None:maximum.set('unit','KiB');maximum.text=str(body['memoryGiB']*1048576)
            target_xml=ET.tostring(domain,encoding='unicode')
            (cloud.directory/(name+'-before-resize.xml')).write_text(original_xml)
        old_boot=cloud.get('node',name)['status']['nodeInfo']['bootID']
        cloud.patch('node',name,{'spec':{'unschedulable':True}})
        started=False
        try:
            progress('Shutting down worker gracefully; existing virtual disks are retained.');self.wait_vm_off(name)
            if target_xml:cloud.command(['virsh','define','/dev/stdin'],input=target_xml)
            progress('Starting worker.');cloud.command(['virsh','start',name]);started=True
            self.wait_node_boot(name,old_boot)
            return 'Worker is Ready with a new boot ID. Virtual disks were preserved.'
        except Exception:
            if target_xml and not started:
                cloud.command(['virsh','define','/dev/stdin'],input=original_xml)
                try:cloud.command(['virsh','start',name]);started=True
                except Exception:pass
            raise
        finally:
            if started:cloud.patch('node',name,{'spec':{'unschedulable':False}})
    def wait_node_boot(self,name,previous,timeout=300):
        deadline=time.monotonic()+timeout
        while time.monotonic()<deadline:
            try:
                item=self.cloud.get('node',name)
                if item['status']['nodeInfo']['bootID']!=previous and any(c['type']=='Ready' and c['status']=='True' for c in item['status']['conditions']):return
            except Exception:pass
            time.sleep(3)
        raise Problem('Node did not report a new boot ID and Ready status. Check host VM status.')
    def cluster(self,progress):
        cloud=self.cloud;users=cloud.bridge('users')['users']
        old_boot={n['metadata']['name']:n['status']['nodeInfo']['bootID'] for n in cloud.get('nodes')['items']}
        for user in users:
            if user['state'] in ('running','starting','restarting','stopping'):cloud.bridge('stop',{'uid':user['uid']})
        for node in cloud.config['workers']:
            progress('Shutting down '+node);self.wait_vm_off(node)
        control=cloud.config['control_plane'];progress('Shutting down '+control);self.wait_vm_off(control)
        progress('Starting control plane.');cloud.command(['virsh','start',control])
        deadline=time.monotonic()+240
        while True:
            try:
                if cloud.kub('get','--raw=/readyz',timeout=10).strip()=='ok':break
            except Exception:pass
            if time.monotonic()>deadline:raise Problem('Control plane did not become ready. Worker disks remain intact.')
            time.sleep(5)
        for node in cloud.config['workers']:
            progress('Starting '+node);cloud.command(['virsh','start',node])
        for name,boot in old_boot.items():self.wait_node_boot(name,boot)
        return 'Cluster nodes are Ready. Users can start their workspaces again.'

def script_path(cloud,path,require_file=False):
    root=Path(cloud.config['script_dir']).resolve();candidate=Path(path)
    if not candidate.is_absolute() or candidate.suffix not in ('.py','.sh') or candidate.is_symlink():raise Problem('Use an absolute .py or .sh path in the configured script directory.')
    resolved=candidate.resolve()
    if not resolved.is_relative_to(root) or resolved==root:raise Problem('Script path is outside the allowed directory.')
    if require_file:
        info=resolved.stat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid!=0 or info.st_mode & 0o022:raise Problem('Script must be a root-owned regular file without group/other write access.')
    return resolved

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--config',default='/etc/kssolv/admin.json');parser.add_argument('operation',choices=['run-script']);parser.add_argument('id');args=parser.parse_args()
    cloud=Cloud(json.loads(Path(args.config).read_text()))
    with cloud.db() as db:row=db.execute('SELECT * FROM scripts WHERE id=?',(args.id,)).fetchone()
    if not row:raise SystemExit('Unknown registered script')
    path=script_path(cloud,row['path'],True)
    # Opening without following symlinks and checking the same descriptor closes
    # the path replacement race before handing it to the interpreter.
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW)
    try:
        info=os.fstat(fd)
        if info.st_uid!=0 or info.st_mode & 0o022:raise Problem('Unsafe script ownership or permissions.')
        cloud.audit('host-cli','script-run',args.id,'started')
        result=subprocess.run(['/usr/bin/python3' if path.suffix=='.py' else '/bin/bash','/proc/self/fd/'+str(fd)],pass_fds=(fd,),cwd=cloud.config['script_dir'],env={'PATH':'/usr/sbin:/usr/bin:/sbin:/bin','LANG':'C.UTF-8'},timeout=3600)
        cloud.audit('host-cli','script-run',args.id,'exit '+str(result.returncode));raise SystemExit(result.returncode)
    finally:os.close(fd)
if __name__=='__main__':main()
