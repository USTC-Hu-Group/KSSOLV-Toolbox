const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const vm = require('node:vm');
const publicRoot = join(__dirname, '../../../server/portal/public');

async function page(initialState) {
  const elements = new Map(), requests = [];
  for (const match of readFileSync(join(publicRoot, 'index.html'), 'utf8').matchAll(/<[^>]+\bid="([^"]+)"[^>]*>/g)) {
    const classes = new Set();
    elements.set(match[1], {value:'', hidden:/\bhidden\b/.test(match[0]), required:/\brequired\b/.test(match[0]),
      sheet:{}, disabled:false, readOnly:false, textContent:'',
      classList:{add:name=>classes.add(name),remove:name=>classes.delete(name),toggle:(name,on)=>on?classes.add(name):classes.delete(name)},
      addEventListener(){}, setAttribute(){}, removeAttribute(){}, focus(){}, reset(){}, close(){}});
  }
  const classes = new Set(['booting']);
  let respond = async name => name==='me' && initialState ? {ok:true,data:initialState} : {ok:false,status:401,data:{error:'请重新登录。'}};
  const context = vm.createContext({URL, Map, Error, JSON, String, Math,
    document:{getElementById:id=>elements.get(id), addEventListener(){},
      body:{classList:{add:name=>classes.add(name), remove:name=>classes.delete(name), contains:name=>classes.has(name)}}},
    window:{addEventListener(){}}, history:{replaceState(){}}, location:{href:'https://example.org/online',pathname:'/online',search:''},
    setTimeout(){}, clearTimeout(){},
    fetch:async(url,options)=>{
      const name=url.split('/').at(-1), data=options.body ? JSON.parse(options.body) : undefined;
      requests.push({name,data}); const result=await respond(name,data);
      return {ok:result.ok,status:result.status||200,json:async()=>result.data};
    }});
  await vm.runInContext(readFileSync(join(publicRoot,'app.js'),'utf8'),context);
  return {$:id=>elements.get(id),requests,respond:callback=>{respond=callback;},
    submit:id=>elements.get(id).onsubmit({preventDefault(){}})};
}

test('registration requires confirmation, sends recovery fields and clears secret inputs', async()=>{
  const p=await page(); assert.equal(p.$('username-help').hidden,true); p.$('register-tab').onclick(); assert.equal(p.$('username-help').hidden,false);
  for(const id of ['password-confirmation','recovery-question-input','recovery-answer','invitation']) assert.equal(p.$(id).required,true);
  p.$('username').value='alice'; p.$('password').value='test-password-12345'; p.$('password-confirmation').value='different';
  await p.submit('account-form');
  assert.match(p.$('message').textContent,/不一致/); assert.equal(p.requests.length,1);
  p.$('password-confirmation').value=p.$('password').value;
  p.$('recovery-question-input').value='My private question?'; p.$('recovery-answer').value='test-answer'; p.$('invitation').value='test-invitation';
  p.respond(async()=>({ok:true,data:{}})); await p.submit('account-form');
  assert.deepEqual(p.requests.at(-1),{name:'register',data:{username:'alice',password:'test-password-12345',passwordConfirmation:'test-password-12345',
    invitation:'test-invitation',recoveryQuestion:'My private question?',recoveryAnswer:'test-answer'}});
  assert.equal(p.$('password').value,''); assert.equal(p.$('password-confirmation').value,''); assert.equal(p.$('recovery-answer').value,'');
  assert.equal(p.$('username-help').hidden,true);
  assert.equal(p.$('forgot-password').hidden,false); assert.match(p.$('message').textContent,/注册成功/);
  assert.equal(p.$('recovery-question-input').disabled,true,'hidden registration constraints must not block login');
});

test('forgot password binds the displayed question to the chosen account and returns to login after reset', async()=>{
  const p=await page(); p.$('username').value='alice'; p.$('forgot-password').onclick();
  assert.equal(p.$('recovery-username').value,'alice'); assert.equal(p.$('account').hidden,true);
  p.respond(async name=>name==='recovery-question'?{ok:true,data:{question:'<img onerror=evil()> A question?'}}:{ok:true,data:{message:'密码已重置，请登录。'}});
  await p.submit('recovery-form');
  assert.equal(p.$('recovery-question').textContent,'<img onerror=evil()> A question?');
  assert.equal(p.$('recovery-username').readOnly,true);
  p.$('reset-password').value='new-test-password-123'; p.$('reset-confirmation').value='different';
  await p.submit('recovery-form'); assert.match(p.$('message').textContent,/不一致/); assert.equal(p.requests.length,2);
  p.$('reset-confirmation').value=p.$('reset-password').value; p.$('reset-answer').value='private-answer';
  // Even a script changing the read-only input cannot redirect the already displayed question.
  p.$('recovery-username').value='bob'; await p.submit('recovery-form');
  assert.equal(p.requests.at(-1).data.username,'alice'); assert.equal(p.$('username').value,'alice');
  assert.equal(p.$('password-recovery').hidden,true); assert.equal(p.$('account').hidden,false);
  for(const id of ['reset-answer','reset-password','reset-confirmation']) assert.equal(p.$(id).value,'');
  assert.match(p.$('message').textContent,/密码已重置/);
  assert.equal(p.requests.filter(r=>r.name==='login').length,0,'reset does not automatically sign in');
});

test('incorrect answers remain on recovery form; changing user removes old question and secrets',async()=>{
  const p=await page(); p.$('forgot-password').onclick(); p.$('recovery-username').value='alice';
  p.respond(async name=>name==='recovery-question'?{ok:true,data:{question:'My test question?'}}:{ok:false,status:401,data:{error:'备忘答案不正确。'}});
  await p.submit('recovery-form');
  p.$('reset-answer').value='wrong-answer'; p.$('reset-password').value=p.$('reset-confirmation').value='new-test-password-123';
  await p.submit('recovery-form'); assert.match(p.$('message').textContent,/答案不正确/);
  assert.equal(p.$('password-recovery').hidden,false); assert.equal(p.$('recovery-submit').disabled,false);
  p.$('recovery-change').onclick(); assert.equal(p.$('recovery-question').textContent,'');
  assert.equal(p.$('reset-answer').value,''); assert.equal(p.$('recovery-username').readOnly,false);
  assert.equal(p.$('recovery-fields').hidden,true);
});

test('legacy login offers recovery setup before opening the tenant; authenticated setup then resumes',async()=>{
  const state={username:'legacy',recoveryConfigured:false,state:'running',ready:true,idleSeconds:1800};
  const p=await page(state); assert.equal(p.$('recovery-setup').hidden,false);
  assert.equal(p.requests.some(r=>r.name==='launch'),false);
  p.$('setup-password').value='old-test-password'; p.$('setup-question').value='My new question?'; p.$('setup-answer').value='private-answer';
  p.respond(async name=>({ok:true,data:name==='me'?{...state,recoveryConfigured:true}:name==='launch'?{url:'https://u-test.example.org/online'}:{ok:true}}));
  await p.submit('setup-form'); assert.deepEqual(p.requests.find(r=>r.name==='recovery-setup').data,
    {password:'old-test-password',recoveryQuestion:'My new question?',recoveryAnswer:'private-answer'});
  assert.equal(p.$('recovery-setup').hidden,true); assert.equal(p.$('tenant-workspace').hidden,false);
});

test('registration rejects more than 32 username characters before sending a request',async()=>{
  const p=await page();p.$('register-tab').onclick();p.$('username').value='a'.repeat(33);
  p.$('password').value=p.$('password-confirmation').value='test-password-12345';
  await p.submit('account-form');
  assert.match(p.$('message').textContent,/3–32/);
  assert.equal(p.requests.some(r=>r.name==='register'),false);
});

test('registration keeps only username/password help buttons and recovery examples belong to inputs',async()=>{
  const p=await page();const ids=['username-help','password-help'];
  for(const id of ids) assert.equal(p.$(id).hidden,true);
  p.$('register-tab').onclick();for(const id of ids) assert.equal(p.$(id).hidden,false);
  const html=readFileSync(join(publicRoot,'index.html'),'utf8');
  const registration=html.split('<section id="password-recovery"')[0];
  assert.equal((registration.match(/class="help-button"/g)||[]).length,2);
  for(const [input,example] of [['recovery-question-input','第一盆植物'],['recovery-answer','蓝色星云']]) {
    assert.match(registration,new RegExp('id="'+input+'"[^>]*aria-describedby="'+input+'-tooltip"'));
    assert.match(registration,new RegExp('id="'+input+'-tooltip"[^>]*>[^<]*'+example));
  }
  p.$('login-tab').onclick();for(const id of ids) assert.equal(p.$(id).hidden,true);
});

test('registration tooltips put length last and describe the actual case-sensitive password policy',()=>{
  const html=readFileSync(join(publicRoot,'index.html'),'utf8');
  for(const id of ['username-tooltip','password-help-tooltip','recovery-question-input-tooltip','recovery-answer-tooltip']){
    const text=html.match(new RegExp('id="'+id+'"[^>]*>([^<]+)'))[1];
    assert.match(text,/（\d+–\d+ 个字符）[。]?$/);
  }
  assert.match(html,/可用大小写字母、数字和特殊符号，区分大小写/);
});

test('login submits the selected size while registration hides the selector',async()=>{
  const p=await page();p.$('login-size').value='small';p.$('username').value='alice';p.$('password').value='test-password-12345';
  p.respond(async name=>name==='login'?{ok:true,data:{}}:{ok:false,status:401,data:{error:'请重新登录。'}});
  await p.submit('account-form');
  assert.equal(p.requests.find(request=>request.name==='login').data.profile,'small');
  p.$('register-tab').onclick();assert.equal(p.$('login-size-row').hidden,true);
  p.$('login-tab').onclick();assert.equal(p.$('login-size-row').hidden,false);
});
