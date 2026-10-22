const {test}=require('node:test'), assert=require('node:assert/strict');
const vm=require('node:vm'), fs=require('node:fs'), path=require('node:path');
const {webcrypto}=require('node:crypto');
const source=fs.readFileSync(path.join(__dirname,'../../../server/portal/public/app.js'),'utf8');
const origin='https://u-alice.example.org';
const flush=()=>new Promise(resolve=>setImmediate(resolve));
test('username pattern supports HTML Unicode Sets validation in Chrome',()=>{
  const html=fs.readFileSync(path.join(__dirname,'../../../server/portal/public/index.html'),'utf8');
  const pattern=html.match(/id="username"[^>]*pattern="([^"]+)"/)[1];
  const allowed=new RegExp('^(?:'+pattern+')$','v');
  for(const name of ['alice','qa-web-alice','a12']) assert.equal(allowed.test(name),true);
  for(const name of ['ab','Alice','a.b','a/b','用户','a'.repeat(33)]) assert.equal(allowed.test(name),false);
});
function fixture(themeLoaded=true, pickers={}, connectionError='') {
  const listeners={}, documentListeners={}, elements=new Map(), classes=new Set(['booting']), replies=[], timers=new Map(); let timerID=0, runtimeInstance='instance-a', networkError=false;
  let launches=0, resumes=0, restarts=0, stateOverride='', authenticated=true, ready=true, resumeError=false; const icons=[];
  function element(id) {
    if(!elements.has(id)) elements.set(id,{hidden:true,textContent:'',value:'',
      classList:{toggle(){},add(){},remove(){}},setAttribute(){},focus(){},showModal(){this.hidden=false;},close(){this.hidden=true;},
      events:{},addEventListener(name,fn){this.events[name]=fn;},removeAttribute(name){delete this[name];}});
    return elements.get(id);
  }
  const shell={}; shell.parent=shell;
  const tenant={parent:shell,postMessage:(data,origin)=>replies.push({data,origin})};element('tenant-workspace').contentWindow=tenant;
  if(themeLoaded) element('portal-style').sheet={};
  const document={getElementById:element,addEventListener:(name,fn)=>documentListeners[name]=fn,body:{classList:{
    add:name=>classes.add(name),remove:name=>classes.delete(name),contains:name=>classes.has(name)}}};
  const fetch=async url=>{
    if(url.endsWith('/restart')) {restarts++;ready=false;stateOverride='restarting';connectionError='';return {ok:true,json:async()=>({ok:true})};}
    if(url.endsWith('/resume')) {resumes++;if(resumeError) throw new TypeError('Network unavailable');return {ok:ready,status:ready?200:409,json:async()=>ready?{runtimeInstance}:{error:'Workspace stopped'}};}
    if(url.endsWith('/launch')) return {ok:true,json:async()=>({url:origin+'/_portal/claim?code='+ ++launches,runtimeInstance})};
    if(networkError) throw new TypeError('Network unavailable');
    return {ok:authenticated,status:authenticated?200:401,
      json:async()=>authenticated?{username:'alice',ready,runtimeInstance:ready?runtimeInstance:'',state:stateOverride||(ready?'running':'stopped'),connectionError,canRestart:!!connectionError,idleSeconds:1800,recoveryConfigured:true}:{error:'Signed out'}};
  };
  vm.runInNewContext(source,{document,window:{addEventListener:(name,fn)=>listeners[name]=fn,KSSOLVFavicon:{workspace:value=>icons.push(value)},...pickers},
    location:{href:'https://kssolv.example.org/online',pathname:'/online'},history:{replaceState(){}},
    fetch,URL,Blob,DOMException,AbortController,crypto:webcrypto,
    setTimeout(fn,delay){timers.set(++timerID,{fn,delay});return timerID;},clearTimeout(id){timers.delete(id);}});
  return {element,tenant,shell,classes,listeners,documentListeners,replies,elements,icons,get restarts(){return restarts;},failEntry(message){connectionError=message;},get launches(){return launches;},get resumes(){return resumes;},stop(){ready=false;},failResume(value){resumeError=value;},
    signOut(){authenticated=false;},networkFail(value){networkError=value;},
    instance(value,isReady=true){runtimeInstance=value;ready=isReady;stateOverride='running';},
    async poll(){const entry=[...timers].find(([,t])=>t.fn.name==='checkRuntime');if(entry){timers.delete(entry[0]);await entry[1].fn();}await flush();},
    send(data,sender=tenant,from=origin){return listeners.message({data,source:sender,origin:from});}};
}
test('runtime replacement reloads once after readiness, including a restart missed between polls',async()=>{
  const f=fixture();await flush();const first=f.element('tenant-workspace').src;
  await f.poll();assert.equal(f.launches,1);
  f.instance('instance-b',false);await f.poll();assert.equal(f.launches,1);
  f.instance('instance-b');await f.poll();assert.equal(f.launches,2);
  assert.notEqual(f.element('tenant-workspace').src,first);
  await f.poll();assert.equal(f.launches,2);
  f.instance('instance-c');await f.poll();assert.equal(f.launches,3);
  assert.equal(f.restarts,0,'reconnection never restarts the Runtime');
});
test('network failures and unchanged instance identity preserve the workspace',async()=>{
  const f=fixture();await flush();const original=f.element('tenant-workspace').src;
  f.networkFail(true);await f.poll();assert.equal(f.launches,1);
  f.networkFail(false);await f.poll();await f.listeners.online();await flush();
  assert.equal(f.launches,1);assert.equal(f.element('tenant-workspace').src,original);
});
test('an entry error can recover automatically only after the instance changes',async()=>{
  const f=fixture();await flush();await f.send({type:'kssolv-entry-error'});await flush();
  await f.poll();assert.equal(f.launches,1);
  f.instance('instance-b');await f.poll();assert.equal(f.launches,2);
  assert.equal(f.classes.has('connected'),true);
});
test('parked workspaces stay parked, but manual resume reloads a replaced Runtime',async()=>{
  const f=fixture();await flush();await f.send({type:'kssolv-workspace-exited'},{parent:f.tenant});await flush();
  f.instance('instance-b');await f.poll();assert.equal(f.launches,1);
  await f.element('open').onclick();assert.equal(f.launches,2);
});
test('expired login stops recovery without creating another workspace',async()=>{
  const f=fixture();await flush();f.signOut();await f.poll();
  assert.equal(f.classes.has('connected'),false);assert.equal(f.launches,1);
  f.instance('instance-b');await f.poll();assert.equal(f.launches,1);assert.equal(f.restarts,0);
});
test('rejected Connector entry retries once then returns to the recovery UI without restarting the instance',async()=>{
  const f=fixture();await flush();
  await f.send({type:'kssolv-runtime-entry-rejected'},f.tenant,'https://evil.invalid');
  await f.send({type:'kssolv-runtime-entry-rejected'},{parent:f.tenant});
  assert.equal(f.launches,1,'only the authenticated tenant wrapper can retry');
  await f.send({type:'kssolv-runtime-entry-rejected'});assert.equal(f.launches,2);
  await f.send({type:'kssolv-runtime-entry-rejected'});await flush();
  assert.equal(f.launches,2,'persistent failures cannot loop');assert.equal(f.restarts,0);
  assert.equal(f.classes.has('connected'),false);assert.equal(f.element('tenant-workspace').hidden,true);
  assert.equal(f.icons.at(-1),'error');assert.match(f.element('state').textContent,/重试连接/);
  await f.element('open').onclick();assert.equal(f.launches,3,'manual reconnect starts a new bounded attempt');
});
test('only frame CSP failures are described as workspace loading errors',async()=>{
  const f=fixture();await flush();
  const csp=f.documentListeners.securitypolicyviolation;
  csp({effectiveDirective:'img-src',violatedDirective:'img-src',blockedURI:'data'});
  assert.equal(f.element('message').textContent,'');
  csp({effectiveDirective:'frame-src',violatedDirective:'frame-src',blockedURI:origin});
  assert.match(f.element('message').textContent,/工作空间加载/);
});
test('account reconnect accepts only the current tenant and its same-origin nested uihtml',async()=>{
  const f=fixture();await flush();assert.equal(f.launches,1);
  const nested={parent:{parent:f.tenant}};
  await f.send({type:'kssolv-session-reconnect'},nested,'https://u-bob.example.org');
  await f.send({type:'kssolv-session-reconnect'},{parent:f.shell});await flush();
  assert.equal(f.launches,1,'other tenants and detached/stale frames cannot reconnect');
  await f.send({type:'kssolv-session-reconnect'},nested);await flush();
  assert.equal(f.launches,2,'the actual uihtml window is a valid account source');
  await f.send({type:'kssolv-file-request',id:'nested',operation:'open',args:{}},nested);
  assert.equal(f.replies.length,0,'file requests still require the exact tenant root');
});
test('nested logout returns to the login page while unrelated frames cannot disconnect it',async()=>{
  const f=fixture();await flush();
  await f.send({type:'kssolv-session-ended',reason:'logout'},{parent:f.shell});
  assert.equal(f.classes.has('connected'),true);
  f.signOut();await f.send({type:'kssolv-session-ended',reason:'logout'},{parent:f.tenant});await flush();
  assert.equal(f.classes.has('connected'),false);assert.equal(f.element('tenant-workspace').hidden,true);
  assert.equal(f.element('account').hidden,false);assert.match(f.element('message').textContent,/已退出登录/);
});
test('initial loader stays visible until theme and workspace frame have loaded',async()=>{
  const f=fixture(false);await flush();
  assert.equal(f.launches,0);assert.equal(f.classes.has('booting'),true);
  f.element('portal-style').events.load();await flush();
  assert.equal(f.launches,1);assert.equal(f.element('portal-style').media,'all');
  assert.equal(f.classes.has('booting'),true,'iframe loading must not expose an empty workspace');
  f.element('tenant-workspace').events.load();assert.equal(f.classes.has('booting'),false);
});
test('workspace exit and reconnect preserve the exact iframe without issuing a new claim',async()=>{
  const f=fixture();await flush();
  const original=f.element('tenant-workspace').src;
  await f.send({type:'kssolv-workspace-exited'},{parent:f.tenant});await flush();
  assert.equal(f.classes.has('connected'),false);
  assert.equal(f.element('account').hidden,true,'exit does not show the logged-out form');
  assert.equal(f.element('workspace').hidden,false);
  assert.equal(f.element('message').textContent,'');
  assert.match(f.element('state').textContent,/仍在运行/);
  assert.equal(f.element('tenant-workspace').hidden,false);
  assert.equal(f.element('tenant-workspace').inert,true);
  assert.equal(f.element('tenant-workspace').src,original);
  await f.element('open').onclick();
  assert.equal(f.resumes,1);assert.equal(f.launches,1);
  assert.equal(f.element('tenant-workspace').src,original);
  assert.equal(f.element('tenant-workspace').inert,false);
  assert.equal(f.classes.has('connected'),true);
});

test('upload opens the system picker directly without an extra web dialog',async()=>{
  const file=new Blob(['structure']);file.name='硅.cif';let calls=0;
  const f=fixture(true,{showOpenFilePicker:async options=>{
    calls++;assert.equal(options.multiple,true);return [{getFile:async()=>file}];
  }});await flush();
  await f.send({type:'kssolv-file-request',id:'open',operation:'open',args:{multiple:true}});
  assert.equal(calls,1);assert.equal(f.replies[0].data.result[0],file);
  assert.equal(f.replies[0].origin,origin);
  assert.equal(f.elements.has('file-dialog'),false);
  assert(!fs.readFileSync(path.join(__dirname,'../../../server/portal/public/index.html'),'utf8').includes('id="file-dialog"'));
});

test('expired activation and cancelling return to the existing transfer window',async()=>{
  let calls=0;
  const f=fixture(true,{showOpenFilePicker:async()=>{
    throw new DOMException('Picker requires a click',++calls===1?'SecurityError':'AbortError');
  }});await flush();
  const request={type:'kssolv-file-request',operation:'open',args:{}};
  await f.send({...request,id:'expired'});
  assert.equal(f.replies.at(-1).data.error.name,'SecurityError');
  await f.send({...request,id:'retry'});
  assert.equal(f.replies.at(-1).data.error.name,'AbortError');
  assert.equal(f.elements.has('file-dialog'),false);
});

test('save opens one system picker and writes only after receiving verified data',async()=>{
  let calls=0,writes=0,contents;
  const f=fixture(true,{showSaveFilePicker:async options=>{
    calls++;assert.equal(options.suggestedName,'project.ks');
    return {name:'chosen.ks',createWritable:async()=>({write:async data=>{writes++;contents=await data.text();},close:async()=>{},abort:async()=>{}})};
  }});await flush();
  await f.send({type:'kssolv-file-request',id:'save',operation:'save',args:{suggestedName:'project.ks'}});
  const handle=f.replies[0].data.result;
  assert.equal(handle.name,'chosen.ks');assert.equal(calls,1);assert.equal(writes,0);
  await f.send({type:'kssolv-file-request',id:'commit',operation:'commit',args:{handle:handle.id,data:new Blob(['project'])}});
  assert.equal(calls,1);assert.equal(writes,1);assert.equal(contents,'project');
  assert.equal(f.elements.has('file-dialog'),false);
});

test('a second picker is rejected without unlocking the pending operation',async()=>{
  let release,calls=0;
  const f=fixture(true,{showOpenFilePicker:()=>{calls++;return new Promise(resolve=>{release=resolve;});}});await flush();
  const request=id=>({type:'kssolv-file-request',id,operation:'open',args:{}});
  const pending=f.send(request('first'));
  await f.send(request('second'));await f.send(request('third'));
  assert.equal(calls,1);assert.equal(f.replies.length,2);
  assert(f.replies.every(reply=>reply.data.error.message.includes('pending')));
  release([]);await pending;
  assert.equal(f.replies.at(-1).data.id,'first');
});

test('picker results from a disconnected workspace cannot publish save handles',async()=>{
  let release;
  const f=fixture(true,{showSaveFilePicker:()=>new Promise(resolve=>{release=resolve;})});await flush();
  const pending=f.send({type:'kssolv-file-request',id:'stale',operation:'save',args:{}});
  f.signOut();await f.send({type:'kssolv-session-ended'},{parent:f.tenant});
  release({name:'stale.ks'});await pending;
  assert.equal(f.replies.length,0);
});

test('expired parked workspace is discarded and offered a fresh start',async()=>{
  const f=fixture();await flush();
  await f.send({type:'kssolv-workspace-exited'},{parent:f.tenant});await flush();
  f.stop();await f.element('open').onclick();
  assert.equal(f.launches,1);assert.equal(f.element('tenant-workspace').src,undefined);
  assert.equal(f.element('tenant-workspace').hidden,true);assert.equal(f.element('start').hidden,false);
  assert.match(f.element('message').textContent,/重新启动/);
});

test('temporary resume network failure keeps the original frame for a later retry',async()=>{
  const f=fixture();await flush();const original=f.element('tenant-workspace').src;
  await f.send({type:'kssolv-workspace-exited'},{parent:f.tenant});await flush();
  f.failResume(true);await f.element('open').onclick();
  assert.equal(f.element('tenant-workspace').src,original);
  assert.equal(f.element('tenant-workspace').inert,true);
  assert.equal(f.classes.has('connected'),false);
  f.failResume(false);await f.element('open').onclick();
  assert.equal(f.classes.has('connected'),true);assert.equal(f.launches,1);
});

test('entry failure stops automatic relaunch, shows recovery controls and keeps a grey icon',async()=>{
  const f=fixture();await flush();assert.equal(f.launches,1);
  await f.send({type:'kssolv-entry-error',message:'Failed'},{parent:f.shell});
  assert.equal(f.classes.has('connected'),true,'Unrelated frames cannot fail the current workspace');
  f.failEntry('工作空间未能响应。');
  await f.send({type:'kssolv-entry-error',message:'Failed'});await flush();
  assert.equal(f.classes.has('connected'),false);
  assert.equal(f.element('tenant-workspace').src,undefined);
  assert.equal(f.element('restart').hidden,false);
  assert.equal(f.element('open').textContent,'重试连接');
  assert.equal(f.element('busy').hidden,true);
  assert.equal(f.icons.at(-1),'error');assert.equal(f.launches,1);
  const restored=fixture(true,{},'Previous entry failed');await flush();
  assert.equal(restored.launches,0,'Refreshing an entry failure must not relaunch automatically');
  assert.equal(restored.icons.at(-1),'error');
  await f.element('restart').onclick();assert.equal(f.element('restart-confirm').hidden,false);
  await f.element('restart-cancel').onclick();assert.equal(f.restarts,0,'Cancel leaves Runtime intact');
  await f.element('restart').onclick();await f.element('restart-confirm-button').onclick();await flush();
  assert.equal(f.restarts,1);assert.equal(f.element('restart-confirm').hidden,true);
  assert.equal(f.element('busy').hidden,false);assert.equal(f.launches,1);
});
