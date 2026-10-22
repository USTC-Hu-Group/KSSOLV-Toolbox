(async () => {
  const $ = id => document.getElementById(id);
  let register = false, timer, launching = false, signedIn = false, entryRetries = 0;
  let tenantOrigin = '', activePicker = null, recoveryUser = '', skipRecoverySetup = false, parked = false, entryFailed = false;
  let runtimeInstance = '', runtimeTimer, runtimeChecking = false, connectionRevision = 0, automaticEntry = false;
  const handles = new Map(), workspace = $('tenant-workspace');
  const icon = window.KSSOLVFavicon;
  const i18n = window.KSSOLVI18n;
  const t = (source,values={}) => i18n ? i18n.t(source,values) : source.replace(/\{(\w+)\}/g,(match,key)=>values[key] ?? match);
  const text = (id,source,values) => i18n ? i18n.setText($(id),source,values) : ($(id).textContent=t(source,values));
  const theme = $('portal-style');
  const themeReady = new Promise(resolve => {
    if(theme.sheet) return resolve();
    theme.addEventListener('load',resolve,{once:true});
    theme.addEventListener('error',resolve,{once:true});
  });
  const loaded = () => document.body.classList.remove('booting');
  workspace.addEventListener('load',loaded);
  document.addEventListener('securitypolicyviolation',event=>{
    if(event.effectiveDirective!=='frame-src' && event.violatedDirective!=='frame-src') return;
    const uri=event.blockedURI.startsWith('http')?new URL(event.blockedURI).origin:event.blockedURI;
    message('浏览器阻止工作空间加载：{directive} {uri}',{directive:event.violatedDirective,uri});
  });
  if(location.pathname!=='/online') history.replaceState(null,'','/online'+location.search);
  async function api(name, data, signal) {
    const response = await fetch('/_portal/api/' + name, {credentials:'same-origin',
      ...(signal ? {signal} : {}),
      ...(data === undefined ? {} : {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)})});
    const result = await response.json();
    if (!response.ok) throw Object.assign(new Error(result.error || '请求失败。'),{status:response.status});
    return result;
  }
  function message(text,values={}) {
    i18n ? i18n.setText($('message'),text || '',values) : ($('message').textContent=text || '');
    i18n ? i18n.setText($('session-error'),text || '',values) : ($('session-error').textContent=text || '');
    $('session-error').hidden = !text || !document.body.classList.contains('connected');
  }
  function mode(value) {
    register = value;
    if($('login-size-row')) $('login-size-row').hidden=value;
    for(const id of ['username-help','password-help']) $(id).hidden=!value;
    message(''); $('invite-row').hidden = !value; $('invitation').required = value; $('invitation').disabled = !value;
    $('account').hidden = false; $('password-recovery').hidden = true; $('recovery-setup').hidden = true;
    for(const [row,input] of [['confirm-row','password-confirmation'],['question-row','recovery-question-input'],['answer-row','recovery-answer']]) {
      $(row).hidden = !value; $(input).required = value; $(input).disabled = !value;
    }
    $('forgot-password').hidden = value;
    $('policy').hidden = value;
    for(const id of ['password','password-confirmation','recovery-answer']) $(id).value = '';
    clearRecovery();
    $('password').minLength = value ? 12 : 1; $('password').autocomplete = value ? 'new-password' : 'current-password';
    text('submit',value ? '注册账号' : '登录并打开工作空间');
    $('login-tab').classList.toggle('selected', !value); $('register-tab').classList.toggle('selected', value);
    $('login-tab').setAttribute('aria-selected',String(!value)); $('register-tab').setAttribute('aria-selected',String(value));
    $('login-tab').tabIndex = value ? -1 : 0; $('register-tab').tabIndex = value ? 0 : -1;
    $('account-form').setAttribute('aria-labelledby',value?'register-tab':'login-tab');
  }
  function watchingRuntime() {
    return signedIn && runtimeInstance && !parked &&
      (document.body.classList.contains('connected') || entryFailed);
  }
  function watchRuntime() {
    clearTimeout(runtimeTimer);
    if(watchingRuntime()) runtimeTimer=setTimeout(checkRuntime,5000);
  }
  async function checkRuntime() {
    clearTimeout(runtimeTimer);
    if(runtimeChecking || !watchingRuntime()) return;
    runtimeChecking=true;
    const revision=connectionRevision, controller=new AbortController();
    const timeout=setTimeout(()=>controller.abort(),6000);
    try {
      const state=await api('me',undefined,controller.signal);
      if(revision!==connectionRevision || !watchingRuntime()) return;
      if(!['running','starting','restarting'].includes(state.state)) { disconnect(); await refresh(); return; }
      if(!state.ready) { icon?.workspace('inactive'); return; }
      if(state.runtimeInstance && state.runtimeInstance!==runtimeInstance) {
        launching=false;
        await launch(false,true);
      }
    } catch(error) {
      if(revision===connectionRevision && error.status===401) {
        disconnect(); signedIn=false; await refresh();
      }
    } finally { clearTimeout(timeout); runtimeChecking=false; watchRuntime(); }
  }
  async function launch(retry = false, automatic = false) {
    if (launching) return;
    if(retry!==true) entryRetries=0;
    launching = true; entryFailed=false; icon?.workspace('loading');
    automaticEntry=automatic;
    if(parked) {
      try {
        const state=await api('resume',{});
        if(runtimeInstance && state.runtimeInstance && state.runtimeInstance!==runtimeInstance) {
          parked=false; workspace.classList.remove('parked'); workspace.inert=false;
          launching=false; return launch();
        }
        parked=false; workspace.classList.remove('parked'); workspace.inert=false;
        document.body.classList.add('connected'); icon?.workspace('active'); message(''); clearTimeout(timer); loaded(); watchRuntime();
      } catch(error) {
        if([401,409].includes(error.status)) { disconnect(); await refresh(); }
        message(error.status===409?'原工作空间已结束，请重新启动。':error.message);
        if(error.status===503) {entryFailed=true; icon?.workspace('error'); await refresh();}
      } finally { launching=false; }
      return;
    }
    document.body.classList.add('booting');
    connectionRevision++;
    try {
      const result=await api('launch', automatic?{automatic:true}:{}), url = new URL(result.url); handles.clear(); activePicker=null;
      runtimeInstance=result.runtimeInstance || runtimeInstance;
      if(i18n) url.searchParams.set('lang',i18n.language);
      tenantOrigin = url.origin; workspace.src = url.href; workspace.hidden = false;
      document.body.classList.add('connected'); icon?.workspace('active'); message('');
      history.replaceState(null,'','/online');
      watchRuntime();
    }
    catch (error) {
      launching = false;
      loaded(); icon?.workspace('error');
      entryFailed=true;
      if(error.status===401) { disconnect(); signedIn=false; $('account').hidden=false; $('workspace').hidden=true; }
      icon?.workspace('error'); message(error.message);
      watchRuntime();
    }
  }
  async function refresh(auto = false) {
    clearTimeout(timer);
    try {
      const state = await api('me'); signedIn = true;
      if(!runtimeInstance && state.ready) runtimeInstance=state.runtimeInstance || '';
      if(!state.recoveryConfigured && !skipRecoverySetup) {
        $('account').hidden = true; $('password-recovery').hidden = true; $('workspace').hidden = true;
        $('recovery-setup').hidden = false; loaded(); return;
      }
      $('recovery-setup').hidden = true;
      $('account').hidden = true; $('workspace').hidden = false;
      text('welcome','你好，{username}',{username:state.username});
      if(parked && !['running','starting'].includes(state.state)) disconnect();
      const failed = !!state.connectionError || entryFailed;
      text('state',failed ? (state.connectionError || '连接未完成，请重试连接。') : state.ready ? (parked?'已返回入口，工作空间仍在运行。':'工作空间已就绪。') : state.message || '正在启动你的独立工作空间，首次启动需要稍候。');
      text('policy','{minutes} 分钟无操作后实例自动释放。保留标签页可恢复原界面，关闭或刷新后将重建。请及时保存项目。',{minutes:Math.ceil(state.idleSeconds/60)});
      $('busy').hidden = !['starting','restarting'].includes(state.state);
      $('open').hidden = !state.ready && state.state!=='running'; $('start').hidden = ['starting','running','restarting','stopping'].includes(state.state);
      $('restart').hidden = !state.canRestart;
      if($('workspace-size-row')) $('workspace-size-row').hidden=$('start').hidden;
      text('open',failed?'重试连接':parked?'重连工作空间':'打开工作空间');
      if(!document.body.classList.contains('connected')) icon?.workspace(failed || state.state==='error'?'error':parked || ['starting','restarting','stopping'].includes(state.state)?'inactive':'idle');
      if (state.ready && auto && !failed) return launch();
      if (!state.ready && ['starting','restarting'].includes(state.state)) timer = setTimeout(() => refresh(auto), 2500);
      else if(parked) timer=setTimeout(()=>refresh(),15000);
    } catch (error) {
      if (error.status === 401) { disconnect(); signedIn = false; $('account').hidden = !$('password-recovery').hidden; $('workspace').hidden = true; $('recovery-setup').hidden = true; }
      else message(error.message);
    }
  }
  $('login-tab').onclick = () => mode(false); $('register-tab').onclick = () => mode(true);
  for(const id of ['login-tab','register-tab']) $(id).onkeydown = event => {
    if(!['ArrowLeft','ArrowRight','Home','End'].includes(event.key)) return;
    event.preventDefault(); mode(event.key==='Home'?false:event.key==='End'?true:!register);
    $(register?'register-tab':'login-tab').focus();
  };
  $('account-form').onsubmit = async event => {
    event.preventDefault(); $('submit').disabled = true; message('');
    try {
      const data = {username:$('username').value,password:$('password').value};
      if(register && !/^[a-z][a-z0-9-]{2,31}$/.test(data.username)) throw new Error('用户名需为 3–32 位小写字母、数字或连字符，以字母开头。');
      if (register) {
        if(data.password !== $('password-confirmation').value) throw new Error('两次输入的密码不一致。');
        Object.assign(data,{passwordConfirmation:$('password-confirmation').value,invitation:$('invitation').value,
          recoveryQuestion:$('recovery-question-input').value,recoveryAnswer:$('recovery-answer').value});
        await api('register',data); mode(false); message('注册成功，请登录。');
      }
      else { if($('login-size')?.value) data.profile=$('login-size').value; await api('login',data); $('password').value=''; skipRecoverySetup=false; await refresh(true); }
    } catch (error) { message(error.message); }
    finally { $('submit').disabled = false; }
  };
  function clearRecovery() {
    recoveryUser=''; $('recovery-fields').hidden=true; $('reset-policy').hidden=true;
    $('recovery-username').readOnly=false; $('recovery-question').textContent='';
    text('recovery-submit','获取备忘问题'); $('recovery-change').hidden=true;
    for(const id of ['reset-answer','reset-password','reset-confirmation']) { $(id).value=''; $(id).required=false; }
  }
  $('forgot-password').onclick=()=>{
    clearRecovery(); message(''); $('password').value=''; $('account').hidden=true;
    $('password-recovery').hidden=false; $('recovery-username').value=$('username').value; $('recovery-username').focus();
  };
  $('recovery-back').onclick=()=>{ $('username').value=$('recovery-username').value; mode(false); };
  $('recovery-change').onclick=()=>{ clearRecovery(); message(''); $('recovery-username').focus(); };
  $('recovery-form').onsubmit=async event=>{
    event.preventDefault(); $('recovery-submit').disabled=true; message('');
    try {
      if(!recoveryUser) {
        const username=$('recovery-username').value;
        const result=await api('recovery-question',{username});
        recoveryUser=username; $('recovery-question').textContent=result.question; $('recovery-username').readOnly=true;
        $('recovery-fields').hidden=false; $('reset-policy').hidden=false; $('recovery-change').hidden=false;
        for(const id of ['reset-answer','reset-password','reset-confirmation']) $(id).required=true;
        text('recovery-submit','重置密码'); $('reset-answer').focus();
      } else {
        if($('reset-password').value !== $('reset-confirmation').value) throw new Error('两次输入的密码不一致。');
        const result=await api('reset-password',{username:recoveryUser,recoveryAnswer:$('reset-answer').value,
          password:$('reset-password').value,passwordConfirmation:$('reset-confirmation').value});
        clearTimeout(timer); signedIn=false; disconnect(); $('username').value=recoveryUser; mode(false); message(result.message);
      }
    } catch(error) { message(error.message); }
    finally { $('recovery-submit').disabled=false; }
  };
  $('setup-skip').onclick=()=>{skipRecoverySetup=true; $('setup-form').reset(); refresh(true);};
  $('setup-form').onsubmit=async event=>{
    event.preventDefault(); $('setup-submit').disabled=true; message('');
    try {
      await api('recovery-setup',{password:$('setup-password').value,recoveryQuestion:$('setup-question').value,
        recoveryAnswer:$('setup-answer').value});
      $('setup-form').reset(); message(''); await refresh(true);
    } catch(error) { message(error.message); }
    finally { $('setup-submit').disabled=false; }
  };
  $('open').onclick = launch;
  $('start').onclick = async () => { try { await api('start',$('workspace-size')?.value?{profile:$('workspace-size').value}:{}); entryFailed=false; message(''); refresh(true); } catch(error) { message(error.message); } };
  $('restart').onclick=()=>$('restart-confirm').showModal();
  $('restart-cancel').onclick=()=>$('restart-confirm').close();
  $('restart-confirm-button').onclick=async()=>{
    $('restart-confirm-button').disabled=true;
    try {
      await api('restart',{}); disconnect(); entryFailed=false;
      $('restart-confirm').close(); message(''); refresh(true);
    } catch(error) { $('restart-confirm').close(); message(error.message); icon?.workspace('error'); }
    finally { $('restart-confirm-button').disabled=false; }
  };
  $('logout').onclick = async () => { try { await api('logout',{}); clearTimeout(timer); signedIn=false; launching=false; $('account').hidden=false; $('workspace').hidden=true; message('已退出登录，实例已释放。'); } catch(error) { message(error.message); } };
  if (new URL(location.href).searchParams.has('ended')) message('长时间未操作，实例已释放。请重新登录。');
  function disconnect(keepRuntime = false) {
    clearTimeout(runtimeTimer); connectionRevision++;
    if(!keepRuntime) runtimeInstance='';
    loaded(); icon?.workspace('idle');
    workspace.removeAttribute('src'); workspace.hidden=true; tenantOrigin=''; launching=false;
    document.body.classList.remove('connected'); $('session-error').hidden=true; handles.clear();
    activePicker=null;
    parked=false; workspace.classList.remove('parked'); workspace.inert=false;
  }
  const originalLogout = $('logout').onclick;
  $('logout').onclick = async () => { await originalLogout(); if(!signedIn) disconnect(); };
  function accountSource(source) {
    // uihtml sends from its own nested window, even when it calls a parent's
    // postMessage. Accept only descendants of the current tenant frame.
    for(let depth=0;source && depth<16;depth++) {
      if(source===workspace.contentWindow) return true;
      if(source.parent===source) break;
      source=source.parent;
    }
    return false;
  }
  function reply(request,result,error) {
    if(request.origin!==tenantOrigin) return;
    workspace.contentWindow.postMessage({type:'kssolv-file-result',id:request.data.id,result,
      ...(error ? {error:{name:error.name||'Error',message:error.message||'File operation failed'}} : {})},tenantOrigin);
  }
  window.addEventListener('message',async event => {
    if(!tenantOrigin || event.origin!==tenantOrigin) return;
    if(['kssolv-session-ended','kssolv-session-reconnect','kssolv-workspace-exited'].includes(event.data?.type)) {
      if(!accountSource(event.source)) return;
    } else if(event.source!==workspace.contentWindow) return;
    if(event.data?.type==='kssolv-language-request') {
      workspace.contentWindow.postMessage({type:'kssolv-language',language:i18n?.language || 'zh-CN'},tenantOrigin);
      return;
    }
    if(event.data?.type==='kssolv-runtime-entry-rejected') {
      if(entryFailed) return;
      if(entryRetries===0) {
        entryRetries=1; launching=false;
        await launch(true,automaticEntry);
      } else {
        disconnect(true); entryFailed=true; icon?.workspace('error'); watchRuntime();
        await refresh();
      }
      return;
    }
    if(event.data?.type==='kssolv-entry-error') {
      disconnect(true); entryFailed=true; icon?.workspace('error'); watchRuntime();
      message(''); refresh(); return;
    }
    if(event.data?.type==='kssolv-connection-status') {
      if(['connected','slow','disconnected','inactive'].includes(event.data.state)) icon?.report(event.data.state);
      return;
    }
    if(event.data?.type==='kssolv-session-ended') { disconnect(); message(event.data.reason==='logout'?'已退出登录，实例已释放。':'长时间未操作，实例已释放。请重新登录。'); refresh(); return; }
    if(event.data?.type==='kssolv-workspace-exited') {
      // Keep the same frame, viewport and WebSocket. Removing src or loading
      // a new claim URL would destroy browser-local panel/dialog state.
      loaded(); icon?.workspace('inactive'); parked=true; launching=false; workspace.classList.add('parked'); workspace.inert=true;
      clearTimeout(runtimeTimer);
      document.body.classList.remove('connected'); message(''); refresh(); return;
    }
    if(event.data?.type==='kssolv-session-reconnect') { launching=false; refresh(true); return; }
    if(event.data?.type!=='kssolv-file-request' || typeof event.data.id!=='string' || event.data.id.length>64) return;
    const {operation,args}=event.data;
    let picking=false;
    try {
      if(operation==='abort') { handles.delete(args?.handle); reply(event,{}); return; }
      if(operation==='commit') {
        const handle=handles.get(args?.handle); handles.delete(args?.handle);
        if(!handle || !(args.data instanceof Blob) || args.data.size>128*1024*1024) throw new Error('Invalid file transfer');
        const writable=await handle.createWritable();
        try { await writable.write(args.data); await writable.close(); }
        catch(error) { await writable.abort().catch(()=>{}); throw error; }
        reply(event,{}); return;
      }
      if(!['open','save'].includes(operation)) return;
      if(activePicker || handles.size>=8) throw new Error('Another file operation is pending');
      activePicker=event;
      picking=true;
      // A trusted click inside the workspace also activates its ancestors.
      // Invoke the top-level picker while that activation is still valid.
      // If it expired during server preparation, return SecurityError so the
      // existing transfer window can offer a single in-place retry button.
      if(operation==='open') {
        const selected=await window.showOpenFilePicker(args || {});
        const files=await Promise.all(selected.map(handle=>handle.getFile()));
        if(activePicker!==event) return;
        if(files.some(file=>file.size>128*1024*1024) || files.reduce((n,file)=>n+file.size,0)>128*1024*1024) throw new Error('Upload exceeds 128 MiB');
        reply(event,files);
      } else {
        const handle=await window.showSaveFilePicker(args || {});
        if(activePicker!==event) return;
        const id=crypto.randomUUID();
        handles.set(id,handle); reply(event,{id,name:handle.name});
      }
    } catch(error) { if(!picking || activePicker===event) reply(event,undefined,error); }
    finally { if(activePicker===event) activePicker=null; }
  });
  window.addEventListener('pageshow',event=>{if(event.persisted){launching=false;refresh(true);}});
  window.addEventListener('online',()=>{if(signedIn){if(watchingRuntime()) checkRuntime(); else {launching=false;refresh(!parked);}}});
  await themeReady;
  theme.media = 'all';
  await refresh(location.pathname==='/online');
  if(!document.body.classList.contains('connected')) loaded();
})();
