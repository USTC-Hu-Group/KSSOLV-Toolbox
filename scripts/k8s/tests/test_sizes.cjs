const {test}=require('node:test');
const assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');
const {join}=require('node:path');
const vm=require('node:vm');

test('open entry pages refresh edited size quantities without changing the selected profile',async()=>{
  const elements=new Map(),events={},timers=[];
  for(const prefix of ['login-size','workspace-size'])for(const key of ['small','medium','large'])elements.set(prefix+'-'+key,{});
  let cpu='2',calls=0;
  const context=vm.createContext({
    window:{KSSOLVI18n:{setText:(option,label,size)=>{option.textContent=label.replace('{cpu}',size.cpu).replace('{memory}',size.memory);}},addEventListener:(event,callback)=>events[event]=callback},
    document:{hidden:false,getElementById:id=>elements.get(id),addEventListener:(event,callback)=>events[event]=callback},
    setInterval:callback=>timers.push(callback),
    fetch:async()=>{calls++;return {ok:true,json:async()=>({profiles:{small:{cpu,memory:'8Gi'},medium:{cpu:'4',memory:'24Gi'},large:{cpu:'8',memory:'52Gi'}}})};}
  });
  vm.runInContext(readFileSync(join(__dirname,'../../../server/portal/public/sizes.js'),'utf8'),context);
  const tick=()=>new Promise(resolve=>setImmediate(resolve));await tick();
  assert.equal(elements.get('login-size-small').textContent,'小（2CPU / 8GB）');
  assert.equal(elements.get('login-size-medium').textContent,'中（4CPU / 24GB）');
  assert.equal(elements.get('login-size-large').textContent,'大（8CPU / 52GB）');
  cpu='3';events.focus();await tick();
  assert.equal(elements.get('login-size-small').textContent,'小（3CPU / 8GB）');
  assert.equal(elements.get('workspace-size-small').textContent,'小（3CPU / 8GB）');
  context.document.hidden=true;const before=calls;timers[0]();await tick();assert.equal(calls,before);
  context.document.hidden=false;cpu='5';events.visibilitychange();await tick();
  assert.equal(elements.get('workspace-size-small').textContent,'小（5CPU / 8GB）');
});
