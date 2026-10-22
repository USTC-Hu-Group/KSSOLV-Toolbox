// Exercise shell lifecycle and coalesced uihtml updates without MATLAB/Java.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../../../+kssolv/+ui/resources/browser/online-modal.html'),'utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
function fixture() {
  const timers=new Map(), listeners=new Map(), lifecycle=new Map();
  const shells=[], observers=[]; let timer=0, destroyed=0;const sizes=[];
  class Element {
    constructor() { this.style={};this.dataset={};this.children=[];this.attributes={};this.inert=false; }
    appendChild(node) { node.remove();node.parent=this;this.children.push(node); }
    remove() { if(this.parent) this.parent.children=this.parent.children.filter(x=>x!==this);this.parent=null; }
    setAttribute(key,value) { this.attributes[key]=value; }
    getBoundingClientRect() { return {width:600,height:400}; }
    querySelector() { return this.body; }
  }
  const root=new Element(), styles=new Map();
  const document={getElementById:id=>id==='uiroot'?root:styles.get(id),createElement:()=>new Element(),
    head:{appendChild:e=>styles.set(e.id,e)}};
  const host={document,innerWidth:1000,innerHeight:800,getComputedStyle:()=>({backgroundColor:'#222'}),
    addEventListener(){},removeEventListener(){},requestAnimationFrame:fn=>fn(),
    MutationObserver:class { constructor(fn) { this.fn=fn;this.active=false;observers.push(this); }
      observe(){this.active=true;} disconnect(){this.active=false;} },
    require(names,fn) { fn({MODAL:'modal',createDialog(options) {
      const domNode=new Element();domNode.body=new Element();domNode.appendChild(options.content);
      const shell={domNode,title:options.title,focusCount:0,resizeTo(){},moveTo(){},bringToTop(options){
        assert.equal(domNode.inert,false,'focus must wait until the loading shield is removed');
        if(options.setFocus) this.focusCount++;
      },
        addControlNodeEventListener(){},close(){this.closed=true;}};
      shells.push(shell);return shell;
    }},class {createWidget({div}) { const node=new Element();div.appendChild(node);
      return {domNode:node,startup(){},resize(size){sizes.push(size);},destroyRecursive(){destroyed++;}};
    }},class {});},
  };
  const context={window:{parent:host,addEventListener:(n,fn)=>lifecycle.set(n,[...(lifecycle.get(n)||[]),fn])},
    setTimeout:fn=>{timers.set(++timer,fn);return timer;},clearTimeout:id=>timers.delete(id)};
  vm.runInNewContext(source,context);
  const component={Data:null,addEventListener:(name,fn)=>listeners.set(name,fn)};
  context.setup(component);
  let sequence=0;
  const send=data=>{component.Data={action:'show',visible:true,sequence:++sequence,title:'Settings',size:[600,400],closable:true,packet:{},busy:false,...data};listeners.get('DataChanged')();};
  const flush=()=>{for(const [id,fn] of [...timers]) {timers.delete(id);fn();}};
  return {send,flush,shells,observers,root,lifecycle,sizes,get destroyed(){return destroyed;}};
}
{
  const f=fixture();f.send({busy:true});f.flush();
  assert.equal(f.shells[0].domNode.attributes['aria-busy'],'true');
  assert.equal(f.root.inert,true);
  assert.equal(f.shells[0].focusCount,0,'building controls must not receive focus');
  const holder=f.shells[0].domNode.children[0], content=holder.children[0], spinner=holder.children[1];
  assert.equal(content.style.visibility,'hidden');assert.equal(spinner.hidden,false);
  f.send({action:'busy',busy:false});
  f.observers[0].fn();f.flush();
  assert.equal(f.shells[0].domNode.attributes['aria-busy'],'false');
  assert.equal(content.style.visibility,'visible');assert.equal(spinner.hidden,true);
  assert.equal(f.observers[0].active,false,'reveal must not retrigger its own observer');
  assert.equal(f.shells[0].focusCount,1,'ready dialog receives focus for immediate Esc handling');
  f.send({action:'hide',visible:false});assert.equal(f.root.inert,false);assert.equal(f.shells[0].closed,true);
  f.send({busy:true});f.flush();assert.equal(f.shells[1].domNode.attributes['aria-busy'],'true');
  f.send({action:'busy',busy:false});f.flush();
  assert.equal(f.shells[1].domNode.attributes['aria-busy'],'false');
  f.lifecycle.get('unload').forEach(fn=>fn());assert.equal(f.root.inert,false);assert.equal(f.destroyed,1);
}
{
  // DataChanged can coalesce show/update/busy while the iframe is loading.
  // The final ready packet still has to construct and reveal a shell.
  const f=fixture();f.send({action:'busy',busy:false});f.flush();
  assert.equal(f.shells.length,1);assert.equal(f.shells[0].domNode.attributes['aria-busy'],'false');
  f.send({action:'update',visible:false});
  assert.equal(f.shells[0].closed,true,'a coalesced hide/title update must still close');
  assert.equal(f.shells.length,1);
}
{
  const f=fixture();f.send({size:[600,1000]});f.flush();
  const holder=f.shells[0].domNode.children[0],content=holder.children[0];
  assert.equal(holder.style.height,'710px');
  assert.equal(content.style.height,'1000px');
  assert.equal(f.sizes.at(-1).h,1000,'native layout keeps its reachable footer');
}
console.log('PASS Online modal: construction shield, readiness, coalesced updates, reuse, observer and blocker cleanup');
