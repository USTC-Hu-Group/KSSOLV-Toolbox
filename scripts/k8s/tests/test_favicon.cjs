const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../../../server/portal/public/favicon.js'),'utf8');
const flush=()=>new Promise(resolve=>setImmediate(resolve));
function fixture() {
  let now=0, mode='ok', delay=0, pending;
  const icon={},events={},intervals=[],navigator={onLine:true};
  const window={addEventListener:(name,fn)=>events[name]=fn};window.top=window;
  vm.runInNewContext(source,{window,navigator,document:{getElementById:()=>icon},
    Date:{now:()=>now},AbortController,setInterval:fn=>intervals.push(fn),setTimeout(){},clearTimeout(){},
    fetch:async()=>{now+=delay;if(mode==='error') throw Error('down');if(mode==='pending') await new Promise(r=>pending=r);
      return {ok:true,json:async()=>({ready:true})};}});
  return {icon,events,navigator,api:window.KSSOLVFavicon,tick:()=>intervals.forEach(fn=>fn()),
    advance:n=>now+=n,setMode:(m,d=0)=>{mode=m;delay=d;},release:()=>pending()};
}
test('entry, active, slow, disconnected, parked and recovered icons follow connection state',async()=>{
  const f=fixture();await flush();assert.match(f.icon.href,/state=idle$/);
  f.api.workspace('loading');assert.match(f.icon.href,/state=inactive$/);
  f.api.workspace('active');assert.match(f.icon.href,/state=inactive$/);
  for(const state of ['connected','slow','disconnected','connected']){
    f.api.report(state);assert.equal(f.icon.href,'/_portal/favicon.svg?state='+state);
  }
  f.api.workspace('inactive');assert.match(f.icon.href,/state=inactive$/);
  f.api.report('connected');assert.match(f.icon.href,/state=inactive$/,'parked workspace cannot turn green');
  f.navigator.onLine=false;f.events.offline();assert.match(f.icon.href,/state=disconnected$/);
  f.navigator.onLine=true;f.events.online();assert.match(f.icon.href,/state=inactive$/);
  f.api.workspace('active');f.api.report('connected');f.advance(26000);f.tick();
  assert.match(f.icon.href,/state=disconnected$/,'missing tenant heartbeats cannot stay green');
  f.api.report('connected');assert.match(f.icon.href,/state=connected$/);
});
test('entry probe detects slow/failed links and stale probe results cannot overwrite workspace status',async()=>{
  const f=fixture();await flush();f.setMode('ok',1600);f.tick();await flush();assert.match(f.icon.href,/state=slow$/);
  f.setMode('error');f.tick();await flush();assert.match(f.icon.href,/state=disconnected$/);
  f.setMode('pending');f.tick();await flush();f.api.workspace('active');f.api.report('connected');
  f.release();await flush();assert.match(f.icon.href,/state=connected$/);
});
test('activity probes publish latency and errors without extending idle time',async()=>{
  let now=0,mode='ok',delay=1600,request;
  const messages=[],timers=[],events={},parent={postMessage:m=>messages.push(m)};
  const document={documentElement:{},querySelectorAll:()=>[],addEventListener(){}};
  const window={parent,addEventListener:(n,f)=>events[n]=f};window.top=parent;
  const text=fs.readFileSync(path.join(__dirname,'../../../server/portal/public/activity.js'),'utf8').replace('__PORTAL_ORIGIN__','"https://example.org"');
  vm.runInNewContext(text,{window,document,location:{origin:'https://u.example.org'},Date:{now:()=>now},
    WeakSet,AbortController,MutationObserver:class{observe(){}},setInterval:f=>timers.push(f),setTimeout(){},clearTimeout(){},
    fetch:async(url,options)=>{request={url,options};now+=delay;if(mode==='error')throw Error('down');
      return {ok:true,status:200,json:async()=>({ready:true,idleRemaining:30})};}});
  await flush();assert.equal(messages.at(-1).state,'slow');assert.match(request.url,/\/session$/);
  assert.equal(request.options.method,undefined,'health probes must not keep workspaces alive');
  mode='error';await timers[0]();assert.equal(messages.at(-1).state,'disconnected');
  mode='ok';delay=1;await timers[0]();assert.equal(messages.at(-1).state,'connected');
});

test('the wrapper detects a plain Connector Forbidden page once and leaves unrelated documents alone',async()=>{
  const messages=[],events={};
  const child={location:{pathname:'/static/test/AppContainerWebPath/index.html'},body:{textContent:'Forbidden'},documentElement:{},querySelectorAll:()=>[],addEventListener(){}};
  const frame={contentDocument:child,addEventListener:(name,fn)=>events[name]=fn};
  const document={documentElement:{},querySelectorAll:()=>[frame],addEventListener(){}};
  const parent={postMessage:(data,origin)=>messages.push({data,origin})};
  const window={parent,top:parent,addEventListener(){}};
  const text=fs.readFileSync(path.join(__dirname,'../../../server/portal/public/activity.js'),'utf8').replace('__PORTAL_ORIGIN__','"https://hub.example.org"');
  vm.runInNewContext(text,{window,document,location:{origin:'https://u.example.org'},Date,WeakSet,AbortController,
    MutationObserver:class{observe(){}},setInterval(){},setTimeout(){},clearTimeout(){},
    fetch:async()=>{throw Error('rejected entry must not probe');}});
  assert.equal(messages.length,1);assert.equal(messages[0].data.type,'kssolv-runtime-entry-rejected');
  assert.equal(messages[0].origin,'https://hub.example.org');
  events.load();assert.equal(messages.length,1,'duplicate load events cannot trigger repeated retries');
});

test('the branded favicon has an explicit white background',()=>{
  const svg=fs.readFileSync(path.join(__dirname,'../../../server/portal/public/favicon.svg'),'utf8');
  assert.match(svg,/<path fill="white" d="M0 0h64v64H0z"\/>/);
});

test('failed Toolbox uses the grey H until an explicit new connection',async()=>{
  const f=fixture();await flush();f.api.workspace('active');f.api.report('connected');
  f.api.workspace('error');assert.match(f.icon.href,/state=inactive$/);
  f.api.report('connected');f.advance(60000);f.tick();assert.match(f.icon.href,/state=inactive$/);
  f.navigator.onLine=false;f.events.offline();assert.match(f.icon.href,/state=inactive$/);
  f.navigator.onLine=true;f.events.online();assert.match(f.icon.href,/state=inactive$/);
  f.api.workspace('active');f.api.report('connected');assert.match(f.icon.href,/state=connected$/);
});
test('entry error iframe informs only its configured portal shell',()=>{
  const sent=[],parent={postMessage:(data,origin)=>sent.push({data,origin})};
  const text=fs.readFileSync(path.join(__dirname,'../../../server/portal/public/entry-error.js'),'utf8').replace('__PORTAL_ORIGIN__','"https://hub.example.org"');
  vm.runInNewContext(text,{window:{parent,addEventListener(){}},document:{getElementById:()=>({textContent:'Runtime unavailable'})}});
  assert.equal(sent.length,2);assert.ok(sent.every(item=>item.origin==='https://hub.example.org'));
  assert.equal(sent[0].data.type,'kssolv-language-request');
  assert.equal(sent[1].data.type,'kssolv-entry-error');
});
