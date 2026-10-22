const {test}=require('node:test'), assert=require('node:assert/strict');
const vm=require('node:vm'), fs=require('node:fs'), path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../../../+kssolv/+ui/resources/browser/online-actions.html'),'utf8')
  .match(/<script>([\s\S]*?)<\/script>/)[1];
const state={username:'qa-alice',idleSeconds:1800,ready:true,portalOrigin:'https://kssolv.example.org'};
const flush=()=>new Promise(resolve=>setImmediate(resolve));
function fixture(fetcher) {
  const calls=[],events=[],messages=[],componentEvents=new Map(),lifecycle=new Map();
  const shell={postMessage:(data,origin)=>messages.push({data,origin})};
  Object.defineProperty(shell,'location',{get(){throw new DOMException('Cross origin','SecurityError');}});
  const entry={parent:shell,location:{origin:'https://u-alice.example.org'}};
  const host={parent:entry,location:entry.location,document:{addEventListener(){},removeEventListener(){}},
    fetch:async(url,options)=>{calls.push({url,options});return fetcher?fetcher(url,options):{ok:true,json:async()=>state};}};
  const component={Data:{links:[]},sendEventToMATLAB:(name,data)=>events.push({name,data}),
    addEventListener:(name,handler)=>componentEvents.set(name,handler),
    removeEventListener:(name,handler)=>{if(componentEvents.get(name)===handler)componentEvents.delete(name);}};
  const context={window:{parent:host,addEventListener:(name,handler)=>lifecycle.set(name,handler)},
    AbortController,URL,setTimeout,clearTimeout};
  vm.runInNewContext(source,context);context.setup(component);
  return {calls,events,messages,componentEvents,lifecycle};
}
test('native account identity uses tenant cookies and reconnect targets the exact shell origin',async()=>{
  const f=fixture();await flush();
  assert.equal(f.calls[0].url,'/_portal/api/session');
  assert.equal(f.calls[0].options.credentials,'same-origin');
  assert.equal(f.events[0].name,'accountState');assert.equal(f.events[0].data.username,'qa-alice');
  await f.componentEvents.get('accountAction')({Data:{action:'reconnect'}});
  assert.equal(f.messages[0].origin,state.portalOrigin);
  assert.equal(f.messages[0].data.type,'kssolv-session-reconnect');
  f.lifecycle.get('unload')();assert.equal(f.componentEvents.size,0);
});
test('confirmed logout posts only to the authenticated tenant and reports sign-out to its shell',async()=>{
  const f=fixture();await flush();
  await f.componentEvents.get('accountAction')({Data:{action:'logout'}});
  const request=f.calls[1];assert.equal(request.url,'/_portal/api/logout');
  assert.equal(request.options.method,'POST');assert.equal(request.options.body,'{}');
  assert.equal(request.options.credentials,'same-origin');
  assert.equal(f.messages[0].data.reason,'logout');assert.equal(f.messages[0].origin,state.portalOrigin);
  f.lifecycle.get('unload')();
});
test('standalone identity failure shows logged-out state; logout errors do not claim success',async()=>{
  const f=fixture(async()=>({ok:false,status:404}));await flush();
  assert.equal(f.events[0].data.username,'');
  await f.componentEvents.get('accountAction')({Data:{action:'logout'}});
  assert.equal(f.events.at(-1).name,'accountError');assert.equal(f.messages.length,0);
  f.lifecycle.get('unload')();
});
test('discarded UI cannot publish late identity or logout actions',async()=>{
  let finish;
  const f=fixture(()=>new Promise(resolve=>finish=resolve));
  f.lifecycle.get('unload')();finish({ok:true,json:async()=>state});await flush();
  assert.equal(f.events.length,0);assert.equal(f.messages.length,0);
});
test('workspace exit uses its own authenticated endpoint and does not claim account logout',async()=>{
  const f=fixture();await flush();
  await f.componentEvents.get('accountAction')({Data:{action:'exit'}});
  assert.equal(f.calls[1].url,'/_portal/api/exit');assert.equal(f.calls[1].options.method,'POST');
  assert.equal(f.messages[0].data.type,'kssolv-workspace-exited');
  assert.equal(f.events.at(-1).name,'accountState');
  assert.equal(f.events.at(-1).data.username,'qa-alice');
  assert.equal(f.messages[0].origin,state.portalOrigin);
  f.lifecycle.get('unload')();
});
