const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../../../server/admin/public/scripts.js'),'utf8');
class Element{
  constructor(){this.value='';this.textContent='';this.disabled=false;this.hidden=false;this.dataset={};this.children=[];this.options=this.children;this.files=[];this.open=false;this.clicks=0;}
  append(...nodes){this.children.push(...nodes);}replaceChildren(...nodes){this.children.length=0;this.children.push(...nodes);}removeAttribute(key){delete this[key];}showModal(){this.open=true;}close(){this.open=false;}click(){this.clicks++;}
}
function fixture(api=async()=>({})){const nodes=new Map(),calls=[],tables=new Map(),intervals=[],listeners=[],get=id=>{if(!nodes.has(id))nodes.set(id,new Element());return nodes.get(id);};let message='';
 const window={KSSOLVI18n:{language:'zh-CN',t:(s,v={})=>s.replace(/\{(\w+)\}/g,(m,k)=>v[k]??m),setText:(n,s)=>{n.textContent=s;},onChange(fn){listeners.push(fn);}},addEventListener(){}};
 vm.runInNewContext(source,{window,document:{getElementById:get},TextDecoder,setInterval(fn){intervals.push(fn);},Date,URLSearchParams});
 const scripts=window.KSSOLVScripts.create({api:async(...args)=>{calls.push(args);return api(...args);},poll:async()=>{},message:s=>{message=s;},table:(id,headers,rows)=>tables.set(id,rows),button(){},menu:actions=>actions,el:(tag,text)=>{const node=new Element();if(text!==undefined)node.textContent=text;return node;},date:()=>''});
 return {scripts,get,calls,tables,intervals,listeners,get message(){return message;}};
}
const file=text=>({name:'health-check.sh',size:Buffer.byteLength(text),arrayBuffer:async()=>new TextEncoder().encode(text).buffer});
test('Shell upload populates the editor without saving or executing, and can open the native chooser directly',async()=>{
 const f=fixture();f.get('script-upload').onclick();assert.equal(f.get('script-file').clicks,1);
 f.get('script-file').files=[file('#!/bin/bash\nprintf hello\n')];await f.get('script-file').onchange();
 assert.equal(f.get('script-source').value,'#!/bin/bash\nprintf hello\n');assert.equal(f.get('script-id').value,'health-check');assert.equal(f.get('script-run').disabled,true);assert.equal(f.calls.length,0);
});
test('invalid UTF-8 and oversized uploads cannot replace editor contents',async()=>{
 const f=fixture(),before=f.get('script-source').value;
 f.get('script-file').files=[{name:'bad.sh',size:1,arrayBuffer:async()=>new Uint8Array([255]).buffer}];await f.get('script-file').onchange();assert.match(f.message,/UTF-8/);assert.equal(f.get('script-source').value,before);
 f.get('script-file').files=[{name:'big.sh',size:131073}];await f.get('script-file').onchange();assert.match(f.message,/128 KiB/);assert.equal(f.calls.length,0);
});
test('a delayed upload cannot restore source after signing out',async()=>{
 let finish;const f=fixture();f.get('script-file').files=[{name:'private.sh',size:4,arrayBuffer:()=>new Promise(resolve=>{finish=resolve;})}];
 const pending=f.get('script-file').onchange();f.scripts.clear();finish(new TextEncoder().encode('echo private').buffer);await pending;
 assert.doesNotMatch(f.get('script-source').value,/private/);assert.equal(f.get('script-id').value,'');
});
test('polling keeps an unsaved script, and save freezes controls until the reviewed revision is returned',async()=>{
 let finish;const f=fixture(async(p,data)=>new Promise(resolve=>{finish=()=>resolve({...data,revision:1,sha256:'a'.repeat(64)});}));
 for(const [id,value] of [['script-id','health-check'],['script-name','Health'],['script-description','Example'],['script-source','printf hello']]){f.get(id).value=value;f.get(id).oninput();}
 f.scripts.render({scripts:[],runnerReady:true});assert.equal(f.get('script-source').value,'printf hello');assert.equal(f.get('script-run').disabled,true);
 const pending=f.get('script-form').onsubmit({preventDefault(){}});assert.equal(f.get('script-source').disabled,true);finish();await pending;
 assert.equal(f.get('script-source').disabled,false);assert.equal(f.get('script-run').disabled,false);assert.equal(f.calls[0][0],'scripts/save');assert.equal(f.calls[0][1].expectedRevision,0);
 f.get('script-source').value='printf changed';f.get('script-source').oninput();f.get('script-new').onclick();assert.equal(f.get('script-discard-dialog').open,true);
 f.get('script-discard-cancel').onclick();assert.equal(f.get('script-source').value,'printf changed');
});
const event=()=>({preventDefault(){this.prevented=true;}});
const script=(revision=1)=>({id:'health-check',name:'Health',description:'Example',source:'printf version-'+revision,timeout:300,revision,sha256:String(revision).repeat(64)});
function scriptAction(f,label){return f.tables.get('script-table')[0].at(-1).find(a=>a[0]===label)[1]();}
const runResult=(id,status='succeeded',output='OK')=>({id,script_id:'health-check',revision:1,sha256:'1'.repeat(64),actor:'admin',trigger:'manual',status,created:100,started:101,finished:status==='succeeded'?102:null,exit_code:status==='succeeded'?0:null,output,message:'Completed.',tailOnly:false,truncated:false});
test('late script loading cannot overwrite newer editor input',async()=>{
 let finish;const f=fixture(()=>new Promise(resolve=>{finish=resolve;}));f.scripts.render({scripts:[script()],runnerReady:true});
 const pending=scriptAction(f,'编辑脚本');assert.equal(f.get('script-source').disabled,true);
 f.get('script-source').value='newer draft';f.get('script-source').oninput();finish(script());await pending;
 assert.equal(f.get('script-source').value,'newer draft');assert.equal(f.get('script-source').disabled,false);assert.equal(f.get('script-run').disabled,true);
});
test('save is single-flight, blocks new/upload controls and reports validation beside the editor',async()=>{
 let finish;const f=fixture(()=>new Promise(resolve=>{finish=resolve;}));f.get('script-source').value='printf draft';f.get('script-source').oninput();
 const first=f.get('script-form').onsubmit(event());const second=f.get('script-form').onsubmit(event());
 assert.equal(f.calls.length,1);assert.equal(f.get('script-new').disabled,true);assert.equal(f.get('script-upload').disabled,true);
 f.get('script-new').onclick();assert.equal(f.get('script-source').value,'printf draft');assert.equal(f.get('script-discard-dialog').open,false);
 finish(script());await Promise.all([first,second]);assert.equal(f.get('script-new').disabled,false);
 const error=fixture(async()=>{throw new Error('Timeout must be 1–86400 seconds.');});await error.get('script-form').onsubmit(event());
 assert.match(error.get('script-form-error').textContent,/1–86400/);assert.equal(error.get('script-save').disabled,false);
});
test('late upload reading cannot replace newer text and never executes uploaded source',async()=>{
 let finish;const f=fixture();f.get('script-file').files=[{name:'health.sh',size:10,arrayBuffer:()=>new Promise(resolve=>{finish=resolve;})}];
 const pending=f.get('script-file').onchange();assert.equal(f.get('script-new').disabled,true);
 f.get('script-source').value='more recent draft';f.get('script-source').oninput();finish(new TextEncoder().encode('printf uploaded').buffer);await pending;
 assert.equal(f.get('script-source').value,'more recent draft');assert.equal(f.calls.length,0);
});
test('execution refuses to switch silently from an open editor revision to a newer server revision',async()=>{
 let version=1;const f=fixture(async()=>script(version));f.scripts.render({scripts:[script()],runnerReady:true});await scriptAction(f,'编辑脚本');
 version=2;await f.get('script-run').onclick();assert.equal(f.get('script-confirm-dialog').open,false);assert.match(f.message,/更新版本/);assert.equal(f.get('script-source').value,'printf version-1');assert.equal(f.get('script-run').disabled,true);
 await scriptAction(f,'编辑脚本');await f.get('script-run').onclick();assert.equal(f.get('script-confirm-dialog').open,true);assert.equal(f.get('script-confirm-source').textContent,'printf version-2');
 f.scripts.render({scripts:[script(3)],runnerReady:true});assert.equal(f.get('script-run').disabled,true);
});
test('daily schedules reopen as a daily time and retain their cron semantics on save',async()=>{
 const item=script(),schedule={kind:'cron',expression:'15 9 * * *',revision:1,enabled:true,timezone:'Asia/Shanghai'};
 const f=fixture(async(path,data)=>path.startsWith('scripts/source')?item:path==='scripts/schedule'?{ok:true}:{runs:[],next:''});
 f.scripts.render({scripts:[{...item,schedule}],timezone:'Asia/Shanghai',runnerReady:true});await scriptAction(f,'定期执行');
 assert.equal(f.get('script-schedule-kind').value,'daily');assert.equal(f.get('script-schedule-expression').value,'09:15');
 f.get('script-confirmation').value=item.id;await f.get('script-confirm-form').onsubmit(event());
 const data=f.calls.find(([path])=>path==='scripts/schedule')[1];assert.equal(data.kind,'cron');assert.equal(data.expression,'15 9 * * *');assert.equal(data.revision,1);
});
test('execution confirmation is single-flight and a late response cannot reopen a signed-out session',async()=>{
 let finish;const item=script(),f=fixture(async(path)=>path.startsWith('scripts/source')?item:path==='scripts/run'?new Promise(resolve=>{finish=resolve;}):{runs:[],next:''});
 f.scripts.render({scripts:[item],runnerReady:true});await scriptAction(f,'立即执行');f.get('script-confirmation').value=item.id;
 const pending=f.get('script-confirm-form').onsubmit(event());await f.get('script-confirm-form').onsubmit(event());assert.equal(f.calls.filter(([p])=>p==='scripts/run').length,1);
 assert.equal(f.get('script-confirm-cancel').disabled,true);f.get('script-confirm-cancel').onclick();assert.equal(f.get('script-confirm-dialog').open,true);
 const escape=event();f.get('script-confirm-dialog').oncancel(escape);assert.equal(escape.prevented,true);
 f.scripts.clear();finish({run:'old-run'});await pending;assert.equal(f.get('script-result-dialog').open,false);assert.equal(f.get('script-confirm-dialog').open,false);assert.equal(f.calls.filter(([p])=>p.startsWith('scripts/result')).length,0);
});
test('result polling avoids overlap, stops after completion and renders paired metadata',async()=>{
 let finish,results=0;const f=fixture(async path=>{
  if(path.startsWith('scripts/runs'))return {runs:[runResult('run-one','queued')],next:''};
  if(path.startsWith('scripts/result')){results++;return results===1?new Promise(resolve=>{finish=resolve;}):runResult('run-one');}
 });
 await f.scripts.refresh();const view=f.tables.get('script-runs-table')[0].at(-1).find(a=>a[0]==='查看结果')[1];
 const pending=view();await f.intervals[0]();await f.intervals[0]();assert.equal(results,1);
 finish(runResult('run-one','queued','waiting'));await pending;await f.intervals[0]();assert.equal(results,2);assert.equal(f.get('script-output').textContent,'OK');
 await f.intervals[0]();for(const listener of f.listeners)listener();assert.equal(results,2);
 const pairs=f.get('script-result-info').children;assert.equal(pairs.length,10);assert.equal(pairs.every(p=>p.children.length===2),true);assert.equal(pairs.at(-1).className,'wide');
});
test('stale result responses cannot replace another result or restore content after sign-out',async()=>{
 const completions=new Map(),f=fixture(async path=>path.startsWith('scripts/runs')?{runs:[runResult('first'),runResult('second')],next:''}:new Promise(resolve=>{completions.set(path,resolve);}));
 await f.scripts.refresh();
 const actions=f.tables.get('script-runs-table').map(r=>r.at(-1).find(a=>a[0]==='查看结果')[1]);
 const first=actions[0]();f.get('script-result-close').onclick();const second=actions[1]();completions.get('scripts/result?id=second')(runResult('second','succeeded','second-output'));await second;
 completions.get('scripts/result?id=first')(runResult('first','succeeded','first-output'));await first;assert.equal(f.get('script-output').textContent,'second-output');
 f.get('script-result-close').onclick();const again=actions[0]();f.scripts.clear();completions.get('scripts/result?id=first')(runResult('first','succeeded','private-output'));await again;assert.equal(f.get('script-output').textContent,'');
});
test('leaving management confirms unsaved drafts and cannot interrupt a pending script save or sign-out',async()=>{
 let completeLeave,leaves=0;const f=fixture(),leave=()=>{leaves++;return new Promise(resolve=>{completeLeave=resolve;});};
 f.get('script-source').value='unsaved important source';f.get('script-source').oninput();f.scripts.guardLeave(leave);
 assert.equal(leaves,0);assert.equal(f.get('script-discard-dialog').open,true);f.get('script-discard-cancel').onclick();
 assert.equal(f.get('script-source').value,'unsaved important source');assert.equal(leaves,0);
 f.scripts.guardLeave(leave);const pending=f.get('script-discard-yes').onclick();assert.equal(leaves,1);assert.equal(f.get('script-source').disabled,true);
 f.scripts.guardLeave(leave);assert.equal(leaves,1);assert.match(f.message,/稍候再退出/);completeLeave();await pending;assert.equal(f.get('script-source').disabled,false);
 let completeSave;const saving=fixture(()=>new Promise(resolve=>{completeSave=resolve;}));
 saving.get('script-source').value='printf draft';saving.get('script-source').oninput();const saved=saving.get('script-form').onsubmit(event());
 saving.scripts.guardLeave(()=>{leaves++;});assert.equal(leaves,1);assert.equal(saving.get('script-source').value,'printf draft');assert.match(saving.message,/稍候再退出/);
 completeSave(script());await saved;
});
