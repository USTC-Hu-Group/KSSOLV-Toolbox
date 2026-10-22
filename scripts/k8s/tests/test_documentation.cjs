const {test}=require('node:test'), assert=require('node:assert/strict');
const fs=require('node:fs'), vm=require('node:vm'), path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../../../server/portal/public/bridge.js'),'utf8')
  .replace('__PORTAL_ORIGIN__',JSON.stringify('https://custom.example.org'));
function fixture(label) {
  const listeners={},opened=[];
  const docs={textContent:label,getAttribute:name=>name==='data-tag'?'ResourceSection_ResourceDocumentation':null};
  const document={querySelector:()=>docs,body:{appendChild(){}},createElement:()=>({
    click(){opened.push({url:this.href,target:this.target,rel:this.rel});},remove(){}})};
  const window={addEventListener:(type,fn)=>listeners[type]=fn};window.parent=window;
  vm.runInNewContext(source,{window,document,location:{pathname:'/toolbox/app.html'}});
  function fire({tag='ResourceSection_ResourceDocumentation',type='click',key='',trusted=true,disabled=false}={}) {
    let prevented=false,stopped=false;
    const button=tag==='ResourceSection_ResourceDocumentation'?docs:{getAttribute:name=>name==='data-tag'?tag:null};
    const attrs=button.getAttribute;
    const target={closest:()=>({...button,getAttribute:name=>name==='aria-disabled'?String(disabled):attrs(name)})};
    listeners[type]({isTrusted:trusted,type,key,target,preventDefault(){prevented=true},stopImmediatePropagation(){stopped=true}});
    return {prevented,stopped};
  }
  return {opened,fire};
}
test('Toolbox locale selects the bundled PDF on a custom portal origin, in a new tab',()=>{
  for (const [label,locale] of [['文档','zh-CN'],['Documentation','en-US']]) {
    const f=fixture(label);
    assert.deepEqual(f.fire(),{prevented:true,stopped:true});
    assert.deepEqual(f.opened,[{url:`https://custom.example.org/online/docs/${locale}.pdf`,target:'_blank',rel:'noopener'}]);
    f.fire({tag:'QABHelpButton',type:'keydown',key:'Enter'});
    assert.equal(f.opened.length,2);assert.equal(f.opened[1].url,f.opened[0].url);
  }
});
test('synthetic events, other buttons, disabled controls and unrelated keys do not open manuals',()=>{
  const f=fixture('Documentation');
  for(const options of [{trusted:false},{disabled:true},{tag:'ResourceSection_OfficialSite'},{type:'keydown',key:'Tab'}])
    assert.deepEqual(f.fire(options),{prevented:false,stopped:false});
  assert.equal(f.opened.length,0);
  f.fire({type:'keydown',key:' '});assert.equal(f.opened.length,1);
});
