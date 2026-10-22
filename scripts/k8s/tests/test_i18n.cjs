const {test}=require('node:test'),assert=require('node:assert/strict');
const vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const root=path.join(__dirname,'../../../server/portal/public');
function fixture({saved,storageBlocked=false,language='zh-CN',query=''}={}) {
  const nodes=[],events={},writes=[],storage=new Map(saved?[['kssolv.portal.language',saved]]:[]);
  function element(textContent='',attrs={}) {
    const node={textContent,attrs,value:'',events:{},setAttribute(key,value){this.attrs[key]=value;},getAttribute(key){return this.attrs[key];},addEventListener(key,fn){this.events[key]=fn;}};
    nodes.push(node);return node;
  }
  for(const filename of ['index.html','entry-error.html']) {
    let html=fs.readFileSync(path.join(root,filename),'utf8').replace('__ERROR_TITLE__','连接已过期').replace('__ERROR_MESSAGE__','会话已结束，请重新登录。').replace('__RECONNECT_LABEL__','重新登录');
    for(const match of html.matchAll(/<([\w-]+)\b([^>]*\bdata-i18n(?:\s|>)[^>]*)>([^<]*)/g)) element(match[3],{'data-i18n':''});
    for(const match of html.matchAll(/<[^>]*\bdata-i18n-(aria-label|placeholder|title)[^>]*>/g)) {
      const attribute=match[1],value=match[0].match(new RegExp('(?:^|\\s)'+attribute+'="([^"]*)"'))[1];
      element('',{['data-i18n-'+attribute]:'',[attribute]:value});
    }
  }
  const selector=element(),document={documentElement:{lang:''},getElementById:()=>selector,
    querySelectorAll:query=>nodes.filter(node=>Object.hasOwn(node.attrs,query.slice(1,-1)))};
  const window={addEventListener:(key,fn)=>events[key]=fn};
  const context={window,document,history:{replaceState(){}},navigator:{language},location:{href:'https://hub.example.org/online'+query},URL,
    localStorage:{getItem:key=>{if(storageBlocked)throw Error('Disabled');return storage.get(key);},setItem:(key,value)=>{if(storageBlocked)throw Error('Disabled');writes.push([key,value]);storage.set(key,value);}}};
  vm.runInNewContext(fs.readFileSync(path.join(root,'i18n.js'),'utf8'),context);
  return {api:window.KSSOLVI18n,nodes,selector,document,events,writes,element,storage};
}
test('all marked account and error-page labels and tooltips have English translations',()=>{
  const f=fixture({saved:'en'});
  assert.equal(f.document.documentElement.lang,'en');assert.ok(f.nodes.length>45);
  for(const node of f.nodes) {
    if(Object.hasOwn(node.attrs,'data-i18n')) assert.doesNotMatch(node.textContent,/[\u4e00-\u9fff]/,node.textContent);
    for(const attribute of ['aria-label','placeholder','title']) if(Object.hasOwn(node.attrs,'data-i18n-'+attribute)) assert.doesNotMatch(node.attrs[attribute],/[\u4e00-\u9fff]/);
  }
});
test('switching re-renders dynamic warnings and templates without changing field values',()=>{
  const f=fixture(),warning=f.element(),welcome=f.element(),input=f.element(); input.value='private answer';
  f.api.setText(warning,'实例启动失败，请重试或联系管理员。');
  f.api.setText(welcome,'你好，{username}',{username:'alice<script>'});
  f.selector.value='en';f.selector.events.change();
  assert.match(warning.textContent,/failed to start/);assert.equal(welcome.textContent,'Hello, alice<script>');
  assert.equal(input.value,'private answer');assert.equal(f.storage.get('kssolv.portal.language'),'en');
  f.api.setLanguage('zh-CN');assert.match(warning.textContent,/实例启动失败/);
});
test('saved preference survives reload, and browser language is only the default',()=>{
  const first=fixture({language:'en-US'});assert.equal(first.api.language,'en');
  first.api.setLanguage('zh-CN');
  assert.equal(fixture({saved:first.storage.get('kssolv.portal.language'),language:'en-US'}).api.language,'zh-CN');
  assert.equal(fixture({saved:'invalid',language:'zh-TW'}).api.language,'zh-CN');
});
test('disabled storage, query propagation and cross-tab updates remain safe',()=>{
  const f=fixture({storageBlocked:true});assert.doesNotThrow(()=>f.api.setLanguage('en'));assert.equal(f.api.language,'en');
  assert.equal(fixture({saved:'zh-CN',query:'?lang=en'}).api.language,'en');
  const other=fixture();other.events.storage({key:'kssolv.portal.language',newValue:'en'});assert.equal(other.api.language,'en');
  other.events.storage({key:'kssolv.portal.language',newValue:'<script>'});assert.equal(other.api.language,'en');
});
test('every service-owned Chinese rejection and status message is translated',()=>{
  const f=fixture({saved:'en'}),source=fs.readFileSync(path.join(root,'../portal.py'),'utf8');
  const messages=[...source.matchAll(/(?:Rejected\([^,]+,\s*|message\s*=\s*|connection_error\s*=\s*connection_error\s*or\s*)["']([^"'\n]*[\u4e00-\u9fff][^"'\n]*)["']/g)].map(match=>match[1]);
  assert.ok(messages.length>20);for(const message of messages)assert.doesNotMatch(f.api.t(message),/[\u4e00-\u9fff]/,message);
});
