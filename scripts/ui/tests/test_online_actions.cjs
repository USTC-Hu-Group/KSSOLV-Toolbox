// Protocol links must run in the actual client gesture, without server web().
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname,
  '../../../+kssolv/+ui/resources/browser/online-actions.html'),'utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
const listeners = new Map(), links = [], lifecycle = new Map(), shortcuts = [], history = [];
const document = {
  addEventListener(name, fn) { if (!listeners.has(name)) listeners.set(name,new Set()); listeners.get(name).add(fn); },
  removeEventListener(name,fn) { listeners.get(name)?.delete(fn); if (!listeners.get(name)?.size) listeners.delete(name); },
  createElement() { return {click() { links.push({href:this.href,target:this.target}); },remove() {}}; },
  body:{appendChild() {}},
  querySelector(selector) { return {getAttribute:()=> 'false',click:()=>history.push(selector)}; },
};
const context={window:{parent:{document}, addEventListener:(name,fn)=>lifecycle.set(name,fn)}};
vm.runInNewContext(source,context);
const component={sendEventToMATLAB:(name,data)=>shortcuts.push({name,...data}),Data:{links:[
  {tag:'support',url:'mailto:support@example.com?subject='+encodeURIComponent('KSSOLV V0.4.1 & 帮助')},
  {tag:'site',url:'https://example.com/official'},
  {tag:'docs',url:'https://example.com/docs'},
]}};
context.setup(component);
const priorCleanup=lifecycle.get('unload');
context.setup(component);
priorCleanup();
assert.equal(listeners.get('click').size,1);
assert.equal(listeners.get('keydown').size,1);
function fire(type,key,disabled=false,match=true,tag='support',isTrusted=true) {
  let prevented=false,stopped=false;
  for (const listener of listeners.get(type)) listener({type,key,isTrusted,target:{closest:()=>match ? {getAttribute:name=>name==='data-tag'?tag:String(disabled)} : null},
    preventDefault(){prevented=true;},stopImmediatePropagation(){stopped=true;}});
  return {prevented,stopped};
}
assert.deepEqual(fire('click'),{prevented:true,stopped:false});
assert.equal(links[0].target,'_blank');
const url=new URL(links[0].href);
assert.equal(decodeURIComponent(url.pathname),'support@example.com');
assert.equal(url.searchParams.get('subject'),'KSSOLV V0.4.1 & 帮助');
fire('keydown','Enter'); fire('keydown',' ');
assert.equal(links.length,3);
fire('keydown','Tab');fire('click',null,true);fire('click',null,false,false);
assert.equal(links.length,3);
fire('click',null,false,true,'site');fire('click',null,false,true,'docs');
assert.equal(links[3].href,'https://example.com/official');
assert.equal(links[4].href,'https://example.com/docs');
fire('click',null,false,true,'unhandled');assert.equal(links.length,5);
fire('click',null,false,true,'site',false);
fire('keydown','Enter',false,true,'site',false);
assert.equal(links.length,5,'native toolstrip synthetic events must not open another tab');
lifecycle.get('unload')();
assert.equal(listeners.size,0);
console.log('PASS Online links: trusted click/keyboard, synthetic click suppression, URI encoding, disabled state, repeated setup and cleanup');

context.setup(component);
function key(command, {ctrl=false,meta=false,shift=false,editable=false,modal=false,repeat=false,trusted=true}={}) {
  context.window.parent.__kssolvOnlineModals={count:modal?1:0};
  let prevented=false,stopped=false;
  const event={type:'keydown',key:command,ctrlKey:ctrl,metaKey:meta,shiftKey:shift,
    repeat,isTrusted:trusted,target:{isContentEditable:editable,closest:()=>editable?{}:null},
    preventDefault(){prevented=true;},stopImmediatePropagation(){stopped=true;}};
  context.window.parent.__kssolvOnlineShortcut(event);
  return {prevented,stopped};
}
assert.deepEqual(key('s',{meta:true}),{prevented:true,stopped:true});
assert.equal(shortcuts.at(-1).command,'save');
key('S',{ctrl:true,shift:true});assert.equal(shortcuts.at(-1).command,'saveAs');
key('o',{ctrl:true});assert.equal(shortcuts.at(-1).command,'open');
const before=shortcuts.length;
key('s',{meta:true,modal:true});key('s',{meta:true,repeat:true});key('s',{meta:true,trusted:false});
assert.equal(shortcuts.length,before,'modal/repeat/synthetic keys must not dispatch');
assert.deepEqual(key('z',{meta:true,editable:true}),{prevented:false,stopped:false});
key('z',{meta:true});key('z',{meta:true,shift:true});key('y',{ctrl:true});
assert.deepEqual(history.map(x=>x.includes('Undo')?'undo':'redo'),['undo','redo','redo']);
key('z',{meta:true,modal:true});assert.equal(history.length,3);
// The original event is forwarded from a child frame, preserving trust and
// preventing the viewer from also executing its local undo binding.
const relaySource=fs.readFileSync(path.join(__dirname,'../../../+kssolv/+ui/resources/browser/online-shortcuts.js'),'utf8');
const childListeners=new Map();
const childWindow={parent:context.window.parent,
  addEventListener:(name,fn)=>childListeners.set(name,fn),
  removeEventListener:(name,fn)=>{if(childListeners.get(name)===fn)childListeners.delete(name);}};
vm.runInNewContext(relaySource,{window:childWindow});
context.window.parent.__kssolvOnlineModals.count=0;
childListeners.get('keydown')({type:'keydown',key:'s',metaKey:true,ctrlKey:false,isTrusted:true,
  target:{closest:()=>null},preventDefault(){},stopImmediatePropagation(){}});
assert.equal(shortcuts.length,before+1);
childListeners.get('unload')();assert.equal(childListeners.has('keydown'),false);
lifecycle.get('unload')();assert.equal(context.window.parent.__kssolvOnlineShortcut,undefined);
console.log('PASS Online shortcuts: Ctrl/Meta save/open/history, iframe relay, editable undo, modal shielding, repeat and lifecycle cleanup');
