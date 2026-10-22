// Browser terminal contract: uihtml load order, command dispatch and shortcuts.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const root = path.resolve(__dirname, '../../..');
const html = fs.readFileSync(path.join(root,
  '+kssolv/+ui/+components/+databrowser/@CommandWindow/html/index.html'), 'utf8');
const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)]
  .map(match => match[1]).filter(source => source.trim());
(async () => {
  const { Window } = await import(pathToFileURL(require.resolve('happy-dom', {
    paths: [path.join(root, 'frontend/apps/crystal-viewer')],
  })).href);
  for (const early of [true, false]) {
    const window = new Window();
    window.document.write(html.replace(/<script\b[\s\S]*?<\/script>/g, '')
      .replace(/<link\b[^>]*>/g, ''));
    window.markdownit = () => ({ render: value => value });
    const listeners = new Map();
    const sent = [];
    const component = {
      Data: ['workspaceProbe'],
      sendEventToMATLAB: (name, data) => sent.push(JSON.parse(JSON.stringify({name, data}))),
      addEventListener(name, callback) {
        assert(!listeners.has(name), `duplicate ${name}`);
        listeners.set(name, callback);
      },
    };
    const input = window.document.getElementById('command-input');
    assert(input.disabled);
    window.eval(scripts[0]);
    if (early) window.setup(component);
    window.eval(scripts[1]);
    if (!early) { assert(input.disabled); window.setup(component); }
    assert(!input.disabled);
    window.setup(component); // The same bridge must not register listeners twice.
    const key = key => input.dispatchEvent(new window.KeyboardEvent('keydown',
      {key, bubbles: true, cancelable: true}));
    const enter = command => { input.value = command; key('Enter'); };
    enter('probe=6*7');
    assert.deepEqual(sent.pop(), {name:'CommandSubmitted', data:'probe=6*7'});
    enter("disp('clc')");
    assert.deepEqual(sent.pop(), {name:'CommandSubmitted', data:"disp('clc')"});
    enter('$ hello');
    assert.deepEqual(sent.pop(), {name:'UserPromptSubmitted', data:{prompt:'hello', useHistory:true}});
    assert(input.disabled);
    listeners.get('LLMStatusChanged')({Data:{Busy:true,Text:'Waiting for fixture-deepseek…'}});
    assert.equal(window.document.getElementById('llm-status').textContent,'Waiting for fixture-deepseek…');
    enter('$ duplicate');
    assert.equal(sent.length,0,'busy chat cannot submit a second request');
    listeners.get('LLMStatusChanged')({Data:{Busy:false,Text:''}});
    assert(!input.disabled);
    enter('$$ no history');
    assert.deepEqual(sent.pop(), {name:'UserPromptSubmitted', data:{prompt:'no history', useHistory:false}});
    listeners.get('LLMStatusChanged')({Data:{Busy:false,Text:''}});
    key('ArrowUp'); assert.equal(input.value, '$$ no history');
    key('ArrowDown'); assert.equal(input.value, '');
    input.value = 'workspaceP'; input.setSelectionRange(10, 10); key('Tab');
    assert.equal(input.value, 'workspaceProbe');
    listeners.get('ResultUpdated')({Data:'42'});
    assert(window.document.getElementById('terminal').textContent.includes('42'));
    enter('clc;');
    assert.equal(window.document.getElementById('terminal').textContent, '');
    assert.equal(sent.length, 0);
    await window.happyDOM.close();
  }
  // Online remounts replay state without executing commands or LLM requests.
  const window = new Window();
  window.document.write(html.replace(/<script\b[\s\S]*?<\/script>/g, '')
    .replace(/<link\b[^>]*>/g, ''));
  window.document.documentElement.dataset.kssolvOnline = 'true';
  window.markdownit = () => ({render:value=>value});
  window.hljs = {highlightAll() {}};
  const listeners = new Map();
  const sent = [];
  const component = {
    Data: [],
    sendEventToMATLAB:(name,data)=>sent.push(JSON.parse(JSON.stringify({name,data}))),
    addEventListener:(name,callback)=>listeners.set(name,callback),
  };
  window.eval(scripts[0]);
  window.setup(component);
  window.eval(scripts[1]);
  const input=window.document.getElementById('command-input');
  const terminal=window.document.getElementById('terminal');
  assert(input.disabled, 'must wait for authoritative Runtime state');
  assert.deepEqual(sent.splice(0),[{name:'TerminalReady'}]);
  const state={
    Commands:['x=42','$ hello'],Remote:true,Truncated:false,
    Records:[
      {Kind:'prompt',Data:'x=42',Remote:true},
      {Kind:'result',Data:'42'},
      {Kind:'prompt',Data:'$ hello',Remote:false},
      {Kind:'tokens',Data:'<think>'},
      {Kind:'tokens',Data:'reason'},
      {Kind:'tokens',Data:'</think>'},
      {Kind:'tokens',Data:'answer'},
    ],
  };
  listeners.get('RestoreTranscript')({Data:state});
  assert(!input.disabled);
  assert(terminal.textContent.includes('[remote] >> x=42'));
  assert(terminal.textContent.includes('answer'));
  assert(terminal.textContent.includes('reason'));
  assert.equal(sent.length,0,'replay must not invoke MATLAB');
  const first=terminal.textContent;
  listeners.get('RestoreTranscript')({Data:state});
  assert.equal(terminal.textContent,first,'repeated restore must be idempotent');
  const key=key=>input.dispatchEvent(new window.KeyboardEvent('keydown',{key,bubbles:true,cancelable:true}));
  key('ArrowUp'); assert.equal(input.value,'$ hello');
  key('ArrowUp'); assert.equal(input.value,'x=42');
  listeners.get('TokensStreamed')({Data:' continued'});
  await new Promise(resolve=>window.requestAnimationFrame(resolve));
  assert.equal(terminal.textContent.split('answer').length,2);
  assert(terminal.textContent.includes('answer continued'));
  input.value='2+2'; key('Enter');
  assert.deepEqual(sent.splice(0),[
    {name:'TerminalCommand',data:{Command:'2+2',Remote:true}},
    {name:'CommandSubmitted',data:'2+2'},
  ]);
  input.value='clc;';key('Enter');
  assert.equal(terminal.textContent,'');
  assert.deepEqual(sent.splice(0),[{name:'TerminalCommand',data:{Command:'clc;',Remote:true}}]);
  listeners.get('RestoreTranscript')({Data:{Commands:['clc;'],Records:[],Remote:false}});
  assert.equal(terminal.textContent,'');
  input.value="disp('<img src=x>')";key('Enter');
  assert.equal(terminal.querySelectorAll('img').length,0,'commands remain plain text');
  sent.splice(0);
  const links={Data:{Commands:[],Records:[
    {Kind:'result',Data:'<a href="matlab:disp(42)">help link</a>'},
    {Kind:'result',Data:'another output'},
  ]}};
  listeners.get('RestoreTranscript')(links);
  listeners.get('RestoreTranscript')(links);
  terminal.querySelector('a').dispatchEvent(new window.MouseEvent('click',{bubbles:true,cancelable:true}));
  assert.deepEqual(sent,[{name:'CommandSubmitted',data:'disp(42)'}], 'restored links execute once');
  await window.happyDOM.close();
  console.log('PASS Command Window: early/late bridge, commands, LLM prompt modes, history, completion, clear');
  console.log('PASS Online terminal: remount replay, no duplicate requests, think boundaries, recall, clear, continuation');
})().catch(error => { console.error(error); process.exitCode = 1; });
