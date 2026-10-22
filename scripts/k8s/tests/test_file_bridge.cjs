// Run locally with Node; exercises origin/source rejection and opaque save handles.
const {test}=require('node:test'), assert=require('node:assert/strict');
const vm=require('node:vm'), fs=require('node:fs'), {webcrypto}=require('node:crypto');
const source=fs.readFileSync(require('node:path').join(__dirname,'../../../server/portal/public/bridge.js'),'utf8')
  .replace('__PORTAL_ORIGIN__',JSON.stringify('https://kssolv.example.org'));
function fixture() {
  const messages=[],listeners={};
  const parent={postMessage:(data,origin)=>messages.push({data,origin})};
  Object.defineProperty(parent,'location',{get:()=>{throw new DOMException('Cross origin','SecurityError')}});
  const root={parent,location:{origin:'https://u-alice.kssolv.example.org'},
    addEventListener:(type,handler)=>listeners[type]=handler,
    showOpenFilePicker(){},showSaveFilePicker(){}};
  vm.runInNewContext(source,{window:root,location:root.location,crypto:webcrypto,Blob,DOMException});
  const reply=(id,result,origin='https://kssolv.example.org',sender=parent)=>listeners.message({origin,source:sender,data:{type:'kssolv-file-result',id,result}});
  return {root,parent,messages,reply};
}
test('open only accepts the exact shell origin and window, returning File facades',async()=>{
  const f=fixture(),pending=f.root.showOpenFilePicker({multiple:false});
  const {id}=f.messages[0].data; let settled=false;pending.then(()=>settled=true);
  f.reply(id,[],'https://evil.invalid');f.reply(id,[],'https://kssolv.example.org',{});
  await Promise.resolve();assert.equal(settled,false);
  const blob=new Blob(['structure']);blob.name='中文.cif';f.reply(id,[blob]);
  const [handle]=await pending;assert.equal(handle.name,'中文.cif');assert.equal(await(await handle.getFile()).text(),'structure');
  assert.equal(f.messages[0].origin,'https://kssolv.example.org');
});
test('save sends data only on close and abort discards it',async()=>{
  const f=fixture(),pick=f.root.showSaveFilePicker({suggestedName:'project.ks'});
  f.reply(f.messages[0].data.id,{id:'opaque',name:'project.ks'});
  const writer=await(await pick).createWritable();await writer.write(new Blob(['project']));
  assert.equal(f.messages.length,1);
  const close=writer.close(),commit=f.messages[1].data;
  assert.equal(commit.operation,'commit');assert.equal(commit.args.handle,'opaque');
  assert.equal(await commit.args.data.text(),'project');f.reply(commit.id,{});await close;
  const second=f.root.showSaveFilePicker({});f.reply(f.messages[2].data.id,{id:'cancelled',name:'cancel.ks'});
  const cancelled=await(await second).createWritable();await cancelled.write('discard');
  const abort=cancelled.abort();assert.equal(f.messages[3].data.operation,'abort');f.reply(f.messages[3].data.id,{});await abort;
});
