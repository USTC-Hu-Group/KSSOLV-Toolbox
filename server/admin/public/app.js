(() => {
  const $=id=>document.getElementById(id),i18n=window.KSSOLVI18n,t=(source,values)=>i18n.t(source,values);
  let csrf='',state=null,activeTab='pods',operation=null,monitor=null,polling=false;
  let eventRows=[],eventNext='',eventRequest=0,eventSelection='',eventPaged=false;
  let selectedUser='',sessionGeneration=0,operationRequest=0,operationBusy=false,monitorRequest=0,operationWrite=false;
  const copy=window.KSSOLVAdminCopy || {};
  const actionLabel=action=>copy.actions?.[action] || action;
  const stateLabel=value=>copy.statuses?.[value] || ({Running:'运行中',Pending:'等待调度',Terminating:'正在终止',Failed:'异常',Succeeded:'已结束',Unknown:'未知'}[value]) || value;
  function detailText(value){if(!value)return '';if(copy.messages?.[value])return t(copy.messages[value]);for(const pattern of copy.patterns || [])if(value.startsWith(pattern.prefix))return t(pattern.key,{[pattern.parameter]:value.slice(pattern.prefix.length)});return value;}
  function targetLabel(target){return (state?.users || []).find(u=>'kssolv-u-'+u.uid===target)?.username || target;}
  const staleMetric=item=>Boolean(state?.stale || item?.stale);
  function setOperationBusy(busy,write=false){operationBusy=busy;operationWrite=busy&&write;$('operation-submit').disabled=busy;$('operation-cancel').disabled=operationWrite;}
  function el(tag,text,className){const node=document.createElement(tag);if(text!==undefined)node.textContent=text;if(className)node.className=className;return node;}
  function clearSession(){sessionGeneration++;operationRequest++;monitorRequest++;operation=null;setOperationBusy(false);for(const host of document.querySelectorAll('.table-scroll')){delete host._pendingTable;host.replaceChildren();}scripts.clear();$('admin-identity').textContent='';csrf='';state=null;monitor=null;selectedUser='';$('user-filter').value='';$('user-access-filter').value='';eventRequest++;eventRows=[];eventNext='';eventSelection='';eventPaged=false;$('event-table').replaceChildren();$('event-user').replaceChildren();i18n.setText($('event-status'),'');$('event-more').hidden=true;$('console').hidden=true;$('sign-in').hidden=false;for(const id of ['profile-table','pod-table','workload-table','node-table','user-table','user-workspace-table','user-workspace-info','user-workspace-actions','audit-table','job-table','script-table','monitor-charts','operation-fields'])$(id).replaceChildren();$('user-workspace-owner').textContent='';$('user-workspace-status').replaceChildren();i18n.setText($('user-workspace-note'),'');$('monitor-detail').textContent='';$('operation-dialog').close();$('monitor-dialog').close();}
  function message(source,error=false){$('message').classList.toggle('error',error);$('message').setAttribute('role',error?'alert':'status');i18n.setText($('message'),source || '');}
  async function api(path,data){
    const generation=sessionGeneration;
    const response=await fetch('/online/admin/api/'+path,{credentials:'same-origin',...(data===undefined?{}:{method:'POST',headers:{'Content-Type':'application/json','X-CSRF-Token':csrf},body:JSON.stringify(data)})});
    const result=await response.json();
    if(generation!==sessionGeneration)throw new Error('');
    if(!response.ok){if(response.status===401){clearSession();}throw new Error(({'Workspace sizes changed. Refresh and try again.':'档位配置已更新，请刷新后重试。','Profiles require positive whole CPU cores and Gi memory':'CPU 核数和内存必须为正整数。','Workspace resources require positive whole CPU cores and Gi memory':'CPU 核数和内存必须为正整数。','Each workspace requires CPU and memory':'请填写全部字段。','Exactly small, medium and large profiles are required':'请完整填写小、中、大三档配置。','Each profile requires CPU and memory':'请完整填写小、中、大三档配置。','Another management operation is in progress.':'有管理任务正在执行，请稍后重试。','Invalid administrator credentials.':'管理员账号或密码不正确，或尚未获得授权。','Administrator sign-in required.':'管理会话已失效，请重新登录。','Only the superadministrator can manage administrator roles.':'只有超级管理员可以管理管理员权限。','The superadministrator account is protected.':'超级管理员账号受保护。','Restore the frozen account before granting administrator access.':'请先恢复被冻结的账号，再授予管理员权限。','Confirmation text does not match the target.':'确认名称与目标不一致。'})[result.error] || result.error || 'Request failed.');}
    return result;
  }
  const number=value=>value==null?'—':Number(value).toLocaleString(undefined,{maximumFractionDigits:2});
  const hoursNumber=value=>Number(value || 0).toLocaleString(undefined,{maximumFractionDigits:4});
  const gib=value=>value==null?'—':value<1024**3?number(value/1024**2)+' MiB':number(value/1024**3)+' GiB';
  const cpuUsage=(used,total)=>used==null?'—':number(used)+'CPU'+(total>0?' ('+number(used/total*100)+'%)':'');
  const date=value=>value?new Date(value*1000).toLocaleString(i18n.language==='en'?'en-GB':'zh-CN'):'—';
  function button(label,fn){const node=el('button',t(label));node.type='button';node.addEventListener('click',()=>Promise.resolve().then(fn).catch(error=>message(error.message,true)));return node;}
  function menu(actions){const select=el('select');select.className='action-menu';select.setAttribute('aria-label',t('操作'));const blank=el('option',t('操作'));blank.value='';select.append(blank);
    for(const [label,fn] of actions){const option=el('option',t(label));option.value=String(select.options.length);option._action=fn;select.append(option);}
    select.addEventListener('change',()=>{const option=select.selectedOptions[0];select.value='';if(option?._action)Promise.resolve().then(()=>option._action()).catch(error=>{message(error.message,true);if($('operation-dialog').open)i18n.setText($('operation-error'),error.message);});});return select;
  }
  function table(target,headers,rows){const host=$(target);if(host.closest('.tab-panel')?.hidden)return;if(host.contains(document.activeElement)){host._pendingTable=[headers,rows];if(!host._waitForBlur){host._waitForBlur=true;host.addEventListener('focusout',()=>queueMicrotask(()=>{if(!host.contains(document.activeElement) && host._pendingTable){const pending=host._pendingTable;delete host._pendingTable;table(target,...pending);}}));}return;}delete host._pendingTable;const node=el('table'),head=el('thead'),tr=el('tr');for(const label of headers){const th=el('th',t(label));th.scope='col';tr.append(th);}head.append(tr);node.append(head);const body=el('tbody');
    if(!rows.length){const td=el('td',t('暂无数据'));td.colSpan=headers.length;const row=el('tr');row.append(td);body.append(row);}
    for(const values of rows){const row=el('tr');for(const value of values){const cell=el('td');cell.append(value instanceof Node?value:document.createTextNode(String(value??'—')));row.append(cell);}body.append(row);}node.append(body);host.replaceChildren(node);
  }
  const scripts=window.KSSOLVScripts.create({api,poll,message,table,button,menu,el,date});
  function status(label,ready){const node=el('span');node.append(el('span',undefined,'status-dot '+(typeof ready==='string'?ready:ready?'good':'bad')),document.createTextNode(t(label)));return node;}
  function roleName(role){return t({user:'普通用户',admin:'普通管理员',superadmin:'超级管理员'}[role] || '普通用户');}
  function profileName(key){return t({small:'小',medium:'中',large:'大',legacy:'自定义',custom:'自定义'}[key] || key || '—');}
  const eventNames={login:'登录',logout:'登出',admin_login:'登录管理页',admin_logout:'退出管理页',
    start_requested:'提交启动',restart_requested:'提交重启',start_failed:'启动失败',workspace_ready:'工作空间已就绪',
    stop_requested:'提交停止',stop_failed:'停止失败',workspace_stopped:'工作空间已关闭',workspace_left:'返回入口',
    resources_changed:'配置已调整',account_frozen:'账号已冻结',account_restored:'账号已恢复',
    pod_created:'Pod 已创建',pod_started:'Pod 已启动',pod_stopped:'Pod 已停止',pod_restarted:'容器已重启',pod_resized:'Pod 配置已变更',pod_terminating:'Pod 正在终止'};
  const categoryNames={authentication:'登录与账户',workspace:'工作空间',pod:'Pod 生命周期',configuration:'配置变更'};
  const eventStatuses={requested:'已请求',succeeded:'成功',failed:'失败',observed:'已观察'};
  const eventActors={system:'系统',administrator:'管理员'};
  const eventDetails={'First observation; creation time comes from Kubernetes.':'首次观察；创建时间来自 Kubernetes。',
    'Resource configuration change observed.':'已观察到资源配置变更。',
    'Container termination time from Kubernetes.':'终止时间来自 Kubernetes。',
    'Pod no longer observed; exact termination time is unavailable. This is the observation time.':'已观察到 Pod 消失；无法取得准确终止时间，此处为观察时间。'};
  function eventUsers(){
    const selected=$('event-user').value,select=$('event-user');
    const desired=JSON.stringify((state.users || []).map(u=>[u.uid,u.username]));
    if(eventSelection!==desired || !select.options.length){eventSelection=desired;select.replaceChildren();
      const all=el('option',t('全部用户'));all.value='';select.append(all);
      for(const user of state.users || []){const option=el('option',user.username);option.value=user.uid;select.append(option);}
      if([...select.options].some(o=>o.value===selected))select.value=selected;
    } else select.options[0].textContent=t('全部用户');
  }
  function renderEvents(){table('event-table',['时间','账户','分类','事件','结果','配置','Pod','操作者','说明'],eventRows.map(e=>[
    date(e.timestamp),e.username,t(categoryNames[e.category] || e.category),t(eventNames[e.action] || e.action),t(eventStatuses[e.status] || e.status),
    e.cpu&&e.memory?e.cpu+'CPU / '+e.memory.replace(/Gi$/,'GB'):'—',e.pod || '—',t(eventActors[e.actor] || e.actor),t(eventDetails[e.detail] || e.detail || '')]));}
  async function loadEvents(more=false){
    if(!csrf)return;
    const request=++eventRequest,query=new URLSearchParams({uid:$('event-user').value,category:$('event-category').value});
    if(more && eventNext){query.set('before',eventNext);eventPaged=true;}
    else eventPaged=false;
    if(!more){eventRows=[];eventNext='';$('event-more').hidden=true;renderEvents();}
    i18n.setText($('event-status'),'正在加载');$('event-more').disabled=true;
    try{const result=await api('user-events?'+query);
      if(request!==eventRequest || !csrf)return;
      eventRows=more?[...eventRows,...result.events]:result.events;eventNext=result.next;renderEvents();
      i18n.setText($('event-status'),'');$('event-more').hidden=!eventNext;
    }catch(error){if(request===eventRequest)i18n.setText($('event-status'),error.message);}
    finally{if(request===eventRequest)$('event-more').disabled=false;}
  }
  function selectTab(name){activeTab=name;for(const tab of document.querySelectorAll('[data-tab]')){
    tab.classList.toggle('selected',tab.dataset.tab===name);tab.setAttribute('aria-selected',String(tab.dataset.tab===name));tab.tabIndex=tab.dataset.tab===name?0:-1;$(tab.dataset.tab).hidden=tab.dataset.tab!==name;if(tab.dataset.tab===name)tab.scrollIntoView({block:'nearest',inline:'nearest'});
  }render();if(name==='events')loadEvents();if(name==='scripts')scripts.refresh();}
  function showUserEvents(uid){eventUsers();$('event-user').value=uid;$('event-category').value='';selectTab('events');}
  function renderUserManagement(){
    if(activeTab!=='users')return;
    const users=state.users || [],query=$('user-filter').value.trim().toLowerCase(),access=$('user-access-filter').value;
    const visible=users.filter(u=>u.username.toLowerCase().includes(query) && (!access || Boolean(u.frozen)===(access==='frozen')));
    if(!visible.some(u=>u.uid===selectedUser))selectedUser=(visible.find(u=>u.uid===state.viewer?.uid) || visible[0])?.uid || '';
    table('user-table',['账户','角色','登录权限','账号操作'],visible.map(u=>{
      const name=el('button',u.username);name.type='button';name.addEventListener('click',()=>{selectedUser=u.uid;renderUserManagement();});name.className='user-selector';name.setAttribute('aria-pressed',String(u.uid===selectedUser));
      const actions=[['用户日志',()=>showUserEvents(u.uid)],['核时统计',()=>showMonitor('user',u.uid,u.username,u)]];
      if(u.role!=='superadmin')actions.push([u.frozen?'恢复账号':'冻结账号',()=>openOperation({action:u.frozen?'restore':'freeze',target:'kssolv-u-'+u.uid})]);
      if(state.viewer?.role==='superadmin' && u.role!=='superadmin' && (u.role==='admin' || !u.frozen))actions.push([u.role==='admin'?'撤销管理员权限':'授予管理员权限',()=>openRole(u)]);
      return [name,roleName(u.role),status(u.frozen?'已冻结':'可登录',!u.frozen),menu(actions)];
    }));
    const user=users.find(u=>u.uid===selectedUser),actions=$('user-workspace-actions'),info=$('user-workspace-info');
    if(actions.contains(document.activeElement))return;
    actions.replaceChildren();info.replaceChildren();$('user-workspace-table').replaceChildren();
    $('user-workspace-owner').textContent=user?.username || '';
    i18n.setText($('user-workspace-status'),'');i18n.setText($('user-workspace-note'),'');
    if(!user){i18n.setText($('user-workspace-note'),'没有符合条件的用户。');return;}
    const pods=state.pods.filter(p=>p.managed && p.owner===user.uid),target='kssolv-u-'+user.uid;
    const busy=['starting','restarting','stopping'].includes(user.state),active=busy || user.state==='running' || pods.length>0;
    const names={running:'运行中',starting:'启动中',restarting:'重启中',stopping:'停止中',stopped:'已停止',error:'异常'};
    $('user-workspace-status').replaceChildren(status(names[user.state] || stateLabel(user.state),user.state==='error'?'bad':busy?'warn':user.state==='running'?(pods.some(p=>p.ready)&&!state.stale?'good':'warn'):'neutral'));
    if(!busy && !user.frozen && !['running','starting','restarting'].includes(user.state)){
      const start=button('启动工作空间',()=>openOperation({action:'start',target}));start.className='primary';actions.append(start);
    }
    const controls=[];
    if(!busy)controls.push(['调整配置',()=>openOperation({action:'resize',target})]);
    if(active)controls.push(['关闭实例',()=>openOperation({action:'stop',target})]);
    if(active && !busy && !user.frozen)controls.push(['重启实例',()=>openOperation({action:'restart',target})]);
    if(active || user.started>0)controls.push(['销毁实例（保留数据）',()=>openOperation({action:'destroy',target})]);
    if(controls.length)actions.append(menu(controls));
    function fact(label,value){info.append(el('dt',t(label)),el('dd',value));}
    if(!pods.length){
      const cpu=user.resource_cpu || state.defaultResources?.cpu,mem=user.resource_memory || state.defaultResources?.memory;
      fact(active?'目标配置':'下次启动配置',cpu&&mem?cpu+'CPU / '+mem.replace(/Gi$/,'GB'):'—');
      i18n.setText($('user-workspace-note'),active?'正在等待 Pod 信息，请稍后刷新。':'当前没有运行中的 Pod。');
    }
    if(user.started>0)fact('最近活动',date(user.last_human));
    if(pods.length){
      if(state.stale || pods.some(p=>p.stale))i18n.setText($('user-workspace-note'),'监控数据已过期，暂不显示实时用量。');
      const size=(cpu,memory)=>number(cpu)+'CPU / '+number(memory/1024**3)+'GB';
      table('user-workspace-table',['Pod','运行状态','配置','CPU 使用','内存使用','操作'],pods.map(p=>{
        const cpu=p.actualResources?.cpu || p.requests.cpu,mem=p.actualResources?.memory || p.requests.memory;
        const config=el('div',size(cpu,mem));
        if(cpu!==p.requests.cpu || mem!==p.requests.memory)config.append(el('div',t('目标配置')+': '+size(p.requests.cpu,p.requests.memory),'muted'));
        const stale=state.stale || p.stale,ready=p.ready && p.phase==='Running';
        const usedCpu=stale||p.cpu==null?'—':number(p.cpu)+'CPU'+(cpu>0?' ('+number(p.cpu/cpu*100)+'%)':'');
        const phase=ready?'已就绪':({Running:'尚未就绪',Pending:'等待调度',Terminating:'正在终止',Failed:'异常',Succeeded:'已结束'}[p.phase] || p.phase);
        const details=button('监控详情',()=>showMonitor('pod',p.uid,p.name,p));details.className='action-button';
        return [p.name,status(phase,ready?'good':p.phase==='Failed'?'bad':'warn'),config,
          usedCpu,stale||p.memory==null?'—':gib(p.memory)+' / '+gib(mem),details];
      }));
    }
  }
  function render(){if(!state)return;
    eventUsers();renderEvents();
    $('admin-identity').textContent=state.viewer?state.viewer.username+' · '+roleName(state.viewer.role):'';
    i18n.setText($('summary'),'每 15 秒更新；{nodes} 个节点，{pods} 个 Pod',{nodes:state.nodes.length,pods:state.pods.length});
    $('metric-warning').hidden=!state.stale && !state.metricErrors?.length && !state.accountError;
    $('metric-warning').textContent=(state.stale?t('数据已过期')+'。 ':'')+([...(state.metricErrors || []),...(state.accountError?[state.accountError]:[])].map(detailText).join('\n') || t('未获取到实时指标，请查看节点连接状态。'));
    if($('operation-dialog').open)return;
    const filter=$('pod-filter').value.toLowerCase();
    const pods=state.pods.filter(p=>[p.name,p.namespace,p.node,(state.users || []).find(u=>u.uid===p.owner)?.username || ''].some(value=>value.toLowerCase().includes(filter)));
    table('pod-table',['名称','账户','命名空间','节点','状态','CPU 配置（当前 / 目标）','内存配置（当前 / 目标）','CPU 使用','内存使用','重启次数','操作'],pods.map(p=>{
      let actions=[['监控详情',()=>showMonitor('pod',p.uid,p.name,p)]];
      if(p.managed){for(const [label,action] of [['调整配置','resize'],['关闭实例','stop'],['重启实例','restart'],['销毁实例（保留数据）','destroy']])actions.push([label,()=>openOperation({action,target:p.namespace})]);}
      else if(p.static){actions.push(['静态 Pod：使用节点或集群重启',()=>showMonitor('node',p.node,p.node,state.nodes.find(n=>n.name===p.node))]);}
      else {for(const [label,action] of [['调整工作负载配置','workload-resize'],['重启工作负载','workload-restart'],['关闭工作负载','workload-stop'],['销毁工作负载','workload-destroy']]) actions.push([label,()=>openOperation({action,target:p.namespace+'/'+p.name,containers:p.containers})]);}
      return [p.name,(state.users || []).find(u=>u.uid===p.owner)?.username || '—',p.namespace,p.node,status(stateLabel(p.phase),p.ready),number(p.actualResources?.cpu)+' / '+number(p.requests.cpu),gib(p.actualResources?.memory)+' / '+gib(p.requests.memory),cpuUsage(staleMetric(p)?null:p.cpu,p.actualResources?.cpu || p.limits.cpu || p.requests.cpu),gib(staleMetric(p)?null:p.memory),p.restarts,menu(actions)];
    }));
    table('workload-table',['名称','命名空间','就绪副本 / 目标副本','操作'],(state.workloads || []).map(w=>[w.name,w.namespace,String(w.ready)+' / '+String(w.replicas),menu([['启动工作负载',()=>openOperation({action:'workload-start',target:w.namespace+'/'+w.kind+'/'+w.name})],['关闭工作负载',()=>openOperation({action:'workload-stop',target:w.namespace+'/'+w.kind+'/'+w.name})],['重启工作负载',()=>openOperation({action:'workload-restart',target:w.namespace+'/'+w.kind+'/'+w.name})],['调整工作负载配置',()=>openOperation({action:'workload-resize',target:w.namespace+'/'+w.kind+'/'+w.name,containers:w.containers})],['销毁工作负载',()=>openOperation({action:'workload-destroy',target:w.namespace+'/'+w.kind+'/'+w.name})]])]));
    renderUserManagement();
    table('profile-table',['配置','CPU 核数','内存 GiB'],['small','medium','large'].filter(key=>state.profiles?.[key]).map(key=>[profileName(key),state.profiles[key].cpu,state.profiles[key].memory.replace(/Gi$/,'')]));
    $('profiles-edit').disabled=!state.profiles?.small;
    table('node-table',['名称','节点角色','状态','虚拟机 CPU','虚拟机内存','系统内存容量','CPU 使用','内存使用','操作'],state.nodes.map(n=>[n.name,t(n.worker?'工作节点':'控制平面'),status(n.ready?'已就绪':'尚未就绪',n.ready),number(n.vmCpu),gib(n.vmMemory),gib(n.memory),cpuUsage(staleMetric(n)?null:n.usedCpu,n.cpu),gib(staleMetric(n)?null:n.usedMemory),menu([['监控详情',()=>showMonitor('node',n.name,n.name,n)],...(n.worker?[
      ['修改节点配置',()=>openOperation({action:'worker-resize',target:n.name,cpu:n.vmCpu,memoryGiB:Math.round(n.vmMemory/1024**3)})],['重启节点',()=>openOperation({action:'worker-restart',target:n.name})]]:[])])]));
    table('job-table',['创建时间','任务','目标','状态','结果'],state.jobs.map(j=>[date(j.timestamp),t(actionLabel(j.body.action)),targetLabel(j.body.target),t(stateLabel(j.state)),detailText(j.message)]));
    table('audit-table',['创建时间','操作者','操作','目标','结果'],state.audit.map(a=>[date(a.timestamp),a.actor,t(actionLabel(a.action)),targetLabel(a.target),t(stateLabel(a.status))]));
    scripts.render(state.customScripts || {},state.scripts || []);
  }
  async function poll(){if(polling || !csrf)return;const generation=sessionGeneration;polling=true;try{const snapshot=await api('state');if(generation!==sessionGeneration || !csrf)return;state=snapshot;render();if(activeTab==='events' && !eventPaged)await loadEvents();if(monitor && $('monitor-dialog').open)await updateMonitor();if(activeTab==='scripts')await scripts.refresh(false);}catch(error){message(error.message,true);}finally{polling=false;}}
  $('login-form').onsubmit=async event=>{event.preventDefault();$('login-submit').disabled=true;message('');try{const result=await api('login',{username:$('admin-name').value,password:$('admin-password').value});csrf=result.csrf;$('admin-password').value='';$('sign-in').hidden=true;$('console').hidden=false;await poll();}catch(error){message(error.message,true);}finally{$('login-submit').disabled=false;}};
  $('sign-out').onclick=()=>{const exit=async()=>{try{await api('logout',{});clearSession();message('');}catch(error){message(error.message,true);}};return scripts.guardLeave?scripts.guardLeave(exit):exit();};
  $('refresh').onclick=poll;$('pod-filter').oninput=render;
  for(const tab of document.querySelectorAll('[data-tab]')){tab.onclick=()=>selectTab(tab.dataset.tab);tab.addEventListener('keydown',event=>{const tabs=[...document.querySelectorAll('[data-tab]')],index=tabs.indexOf(tab);let next;if(event.key==='ArrowRight')next=(index+1)%tabs.length;else if(event.key==='ArrowLeft')next=(index+tabs.length-1)%tabs.length;else if(event.key==='Home')next=0;else if(event.key==='End')next=tabs.length-1;else return;event.preventDefault();selectTab(tabs[next].dataset.tab);tabs[next].focus();});}
  $('event-user').onchange=$('event-category').onchange=$('event-refresh').onclick=()=>loadEvents();
  $('event-more').onclick=()=>loadEvents(true);
  $('user-filter').oninput=$('user-access-filter').onchange=()=>renderUserManagement();
  function field(id,label,type='text',value='') {const input=el(type==='select'?'select':'input');input.id=id;if(type!=='select')input.type=type;input.value=value;input.autocomplete='off';const lab=el('label');i18n.setText(lab,label);lab.htmlFor=id;$('operation-fields').append(lab,input);return input;}
  function sizeField(body){
    const input=field('operation-profile','实例类型：','select');
    for(const key of ['custom',...Object.keys(state.profiles || {})]){const size=state.profiles?.[key],option=el('option',profileName(key)+(size?' ('+size.cpu+'CPU / '+size.memory.replace(/Gi$/,'GB')+')':''));option.value=key;input.append(option);}
    const user=(state.users || []).find(u=>'kssolv-u-'+u.uid===body.target);
    const current={cpu:user?.resource_cpu || state.defaultResources?.cpu || state.profiles?.medium?.cpu || '4',memory:user?.resource_memory || state.defaultResources?.memory || state.profiles?.medium?.memory || '24Gi'};
    const cpu=field('operation-workspace-cpu','CPU 核数：','number',current.cpu),memory=field('operation-workspace-memory','内存 GiB：','number',current.memory.replace(/Gi$/,''));
    cpu.min=memory.min='1';cpu.step=memory.step='1';cpu.max='999';memory.max='9999';input.value='custom';
    input.onchange=()=>{const size=state.profiles?.[input.value];if(size){cpu.value=size.cpu;memory.value=size.memory.replace(/Gi$/,'');}};
    cpu.oninput=memory.oninput=()=>{input.value='custom';};
  }
  async function openOperation(body){message('');operationRequest++;setOperationBusy(false);operation={body,phase:'size'};i18n.setText($('operation-error'),'');$('operation-fields').replaceChildren();i18n.setText($('operation-title'),actionLabel(body.action) || '确认管理操作');$('operation-target').textContent=targetLabel(body.target)+(targetLabel(body.target)!==body.target?'\n'+body.target:'');i18n.setText($('operation-impact'),'');i18n.setText($('operation-submit'),'继续');
    if(['resize','start'].includes(body.action))sizeField(body);
    else if(body.action==='worker-resize'){field('operation-cpu','CPU 核数：','number',body.cpu);field('operation-memory','内存 GiB：','number',body.memoryGiB);}
    else if(body.action==='workload-resize'){
      const input=field('operation-container','容器：','select');for(const c of (body.containers || [])){const option=el('option',c.name);option.value=c.name;input.append(option);}
      for(const [id,label] of [['operation-cpu-request','请求 CPU（核）：'],['operation-cpu-limit','CPU 上限（核）：'],['operation-memory-request','请求内存（MiB）：'],['operation-memory-limit','内存上限（MiB）：']])field(id,label,'number');
      const cpu=value=>value==null?'':String(value).endsWith('m')?Number(String(value).slice(0,-1))/1000:Number(value);
      const memory=value=>value==null?'':Number(String(value).replace(/[A-Za-z]+$/,''))*({'Ki':1/1024,'Mi':1,'Gi':1024,'Ti':1048576}[String(value).match(/[A-Za-z]+$/)?.[0]] || 1/1048576);
      const fill=()=>{const resources=body.containers?.find(c=>c.name===input.value)?.resources || {};for(const group of ['request','limit']){const values=resources[group+'s'] || {};$('operation-cpu-'+group).value=cpu(values.cpu);$('operation-cpu-'+group).step='0.001';$('operation-memory-'+group).value=memory(values.memory);$('operation-memory-'+group).step='1';}};
      for(const id of ['operation-cpu-limit','operation-memory-limit'])$(id).placeholder=t('留空表示不设上限');input.onchange=fill;fill();
    }
    else {operation.phase='propose';}
    $('operation-dialog').showModal();if(operation.phase==='propose'){const current=operation;setOperationBusy(true);try{await propose();}catch(error){if(operation===current)i18n.setText($('operation-error'),error.message);}finally{if(operation===current)setOperationBusy(false);}}
  }
  function impactText(action,fallback){
    if(i18n.language!=='zh-CN')return fallback;
    if(action.startsWith('workload-'))return '此操作影响该工作负载的全部副本，依赖它的服务可能暂时不可用。更改控制器资源可能重建 Pod；独立 Pod 将请求原地调整。保留数据卷。';
    if(action.startsWith('worker-'))return '将优雅关闭并重新启动该工作节点，保留虚拟磁盘。请先关闭其用户工作空间。';
    if(action==='cluster-restart')return t('用户工作空间将停止，随后重启 Kubernetes 虚拟机。完成后需由用户重新启动工作空间。未保存内容会丢失，已保存文件和磁盘保留。管理页面仍可访问。');
    if(action==='resize')return '请求原地调整 CPU 和内存，并同步未来重建配置。缩小内存可能中断计算；采样过期或内存余量不足时将拒绝操作，不会自动改为重启。';
    if(action==='restore')return '解除账号冻结，用户可重新登录，不会自动创建实例。';
    if(action==='start')return '按选择的配置启动实例；已运行实例继续使用原配置。';
    return '当前实例会关闭，未保存内容将丢失，已保存文件和数据卷保留。'+(action==='freeze'?'冻结还会撤销全部账号会话。':action==='destroy'?'将删除计算实例，账号和数据卷仍可重新使用。':'');
  }
  function describeOperation(result){
    const body=result.operation,target=targetLabel(body.target),lines=[target];
    if(target!==body.target)lines.push(body.target);
    const size=body.profile==='custom'?body.resources:body.profileResources;
    if(body.profile)lines.push(t('配置')+': '+profileName(body.profile)+(size?' ('+size.cpu+'CPU / '+size.memory.replace(/Gi$/,'GB')+')':''));
    if(body.resources && !body.profile)lines.push(t('容器：')+' '+body.container,t('请求')+': CPU '+(body.resources.requests.cpu ?? '—')+' / '+(body.resources.requests.memory ?? '—'),t('上限')+': CPU '+(body.resources.limits.cpu ?? t('不设上限'))+' / '+(body.resources.limits.memory ?? t('不设上限')));
    if(body.cpu)lines.push(body.cpu+'CPU / '+body.memoryGiB+'GB');
    $('operation-target').textContent=lines.join('\n');i18n.setText($('operation-impact'),impactText(body.action,result.impact));
  }
  async function propose(){
    const current=operation,generation=++operationRequest,result=await api('propose',current.body);
    if(operation!==current || generation!==operationRequest || !$('operation-dialog').open)return;
    current.preview=result;current.phase='confirm';const body=result.operation,target=targetLabel(body.target);describeOperation(result);$('operation-fields').replaceChildren();
    // Account owners confirm their readable username. The backend still receives its bound target.
    current.confirmationText=target;const input=field('operation-confirmation',target!==body.target?'请输入账户名确认：':'请输入目标名称确认：');input.placeholder=target;input.spellcheck=false;i18n.setText($('operation-submit'),'确认并执行');input.focus();
  }
  $('operation-form').onsubmit=async event=>{event.preventDefault();if(operationBusy || !operation)return;const current=operation;setOperationBusy(true,!['size','propose'].includes(operation.phase));i18n.setText($('operation-error'),'');try{
    if(operation.phase==='size' || operation.phase==='propose'){
      if($('operation-profile')){delete operation.body.resources;operation.body.profile=$('operation-profile').value;if(operation.body.profile==='custom'){const cpu=$('operation-workspace-cpu').value,memory=$('operation-workspace-memory').value;if(!/^[1-9][0-9]{0,2}$/.test(cpu) || !/^[1-9][0-9]{0,3}$/.test(memory))throw new Error('CPU 核数和内存必须为正整数。');operation.body.resources={cpu,memory:memory+'Gi'};}}
      if($('operation-container')){operation.body.container=$('operation-container').value;operation.body.resources={};for(const group of ['request','limit']){const values={};if($('operation-cpu-'+group).value!=='')values.cpu=$('operation-cpu-'+group).value;if($('operation-memory-'+group).value!=='')values.memory=$('operation-memory-'+group).value+'Mi';operation.body.resources[group+'s']=values;}}
      if($('operation-cpu')){operation.body.cpu=Number($('operation-cpu').value);operation.body.memoryGiB=Number($('operation-memory').value);}
      await propose();return;
    }
    if(operation.phase==='role'){
      await api('roles',{uid:operation.uid,role:operation.role,confirmation:$('operation-confirmation').value});message('管理员权限已更新。');
    } else if(operation.phase==='profiles'){
      const profiles={};for(const key of ['small','medium','large']){const cpu=$('profile-'+key+'-cpu').value,memory=$('profile-'+key+'-memory').value;if(!/^[1-9][0-9]{0,2}$/.test(cpu) || !/^[1-9][0-9]{0,3}$/.test(memory))throw new Error('CPU 核数和内存必须为正整数。');profiles[key]={cpu,memory:memory+'Gi'};}
      await api('profiles',{profiles,expected:operation.expected});message('档位配置已保存。');
    } else if(operation.phase==='invitation'){
      await api('invitation',{value:$('operation-invitation').value,confirmation:$('operation-confirmation').value});message('邀请码已更新。');
    } else {const value=$('operation-confirmation').value;if(value!==operation.confirmationText)throw new Error('确认名称与目标不一致。');await api('confirm',{token:operation.preview.token,confirmation:operation.preview.confirmationText});message('管理操作已提交。');}
    $('operation-dialog').close();operation=null;await poll();
  }catch(error){if(operation===current)i18n.setText($('operation-error'),error.message);}finally{if(operation===current || !operation)setOperationBusy(false);}};
  function closeOperation(){if(operationWrite)return;operationRequest++;operation=null;setOperationBusy(false);$('operation-fields').replaceChildren();$('operation-dialog').close();render();}
  $('operation-cancel').onclick=closeOperation;$('operation-dialog').oncancel=event=>{if(operationWrite)event.preventDefault();else closeOperation();};
  $('cluster-restart').onclick=()=>openOperation({action:'cluster-restart',target:'CLUSTER'}).catch(error=>message(error.message,true));
  function openRole(user){setOperationBusy(false);operationRequest++;operation={phase:'role',uid:user.uid,role:user.role==='admin'?'user':'admin'};i18n.setText($('operation-title'),operation.role==='admin'?'授予管理员权限':'撤销管理员权限');$('operation-target').textContent=user.username;i18n.setText($('operation-impact'),operation.role==='admin'?'授权后，该用户可管理账户、工作空间和集群，并以 root 身份执行宿主机脚本。仅超级管理员可授予或撤销管理员权限。':'撤销后，该用户的管理会话立即失效，工作空间账号和数据保留。');$('operation-fields').replaceChildren();field('operation-confirmation','请输入目标名称确认：').placeholder=user.username;i18n.setText($('operation-error'),'');i18n.setText($('operation-submit'),'确认并执行');$('operation-dialog').showModal();}
  $('profiles-edit').onclick=()=>{setOperationBusy(false);operationRequest++;operation={phase:'profiles',expected:JSON.parse(JSON.stringify(state.profiles))};i18n.setText($('operation-title'),'修改档位配置');$('operation-target').textContent='';i18n.setText($('operation-impact'),'保存后用于新建和主动调整工作空间，已有实例保持当前资源。存储配置不变。');$('operation-fields').replaceChildren();
    for(const key of ['small','medium','large']){for(const [resource,max] of [['cpu',999],['memory',9999]]){const input=field('profile-'+key+'-'+resource,resource==='cpu'?{small:'小 CPU 核数：',medium:'中 CPU 核数：',large:'大 CPU 核数：'}[key]:{small:'小内存 GiB：',medium:'中内存 GiB：',large:'大内存 GiB：'}[key],'number',state.profiles[key][resource].replace(/Gi$/,''));input.min='1';input.max=String(max);input.step='1';}}
    i18n.setText($('operation-error'),'');i18n.setText($('operation-submit'),'保存配置');$('operation-dialog').showModal();};
  $('invitation-reset').onclick=()=>{setOperationBusy(false);operationRequest++;operation={phase:'invitation'};i18n.setText($('operation-title'),'重置邀请码');$('operation-target').textContent='registration';i18n.setText($('operation-impact'),'确认后将替换邀请码，旧邀请码立即失效。现有账号不受影响。');$('operation-fields').replaceChildren();field('operation-invitation','新邀请码：','password');field('operation-confirmation','确认字符串：').placeholder='ROTATE';i18n.setText($('operation-error'),'');i18n.setText($('operation-submit'),'确认并执行');$('operation-dialog').showModal();};

  function chart(title,points,key,unit){const host=el('section',undefined,'chart');host.append(el('h2',title));if(!points.length){host.append(el('p',t('尚无历史采样')));return host;}
    const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('viewBox','0 0 800 180');svg.setAttribute('role','img');svg.setAttribute('aria-label',title);
    const values=points.map(p=>p[key]==null?null:Number(p[key]));if(!values.some(Number.isFinite)){host.append(el('p',t('尚无历史采样')));return host;}const max=Math.max(...values.filter(Number.isFinite),.001),start=points[0].timestamp,end=points.at(-1).timestamp;
    for(let i=0;i<4;i++){const line=document.createElementNS(svg.namespaceURI,'line');line.setAttribute('x1','45');line.setAttribute('x2','790');line.setAttribute('y1',String(20+i*45));line.setAttribute('y2',String(20+i*45));line.setAttribute('stroke','#d9d9d9');svg.append(line);}
    let segments=[],segment=[];for(let i=0;i<points.length;i++){if(!Number.isFinite(values[i]) || (i>0 && points[i].timestamp-points[i-1].timestamp>(monitor?.kind==='user'?3600:60))){if(segment.length)segments.push(segment);segment=[];}if(Number.isFinite(values[i]))segment.push([45+(points[i].timestamp-start)/Math.max(end-start,1)*745,155-values[i]/max*135]);}if(segment.length)segments.push(segment);for(const points of segments){const line=document.createElementNS(svg.namespaceURI,points.length===1?'circle':'polyline');if(points.length===1){line.setAttribute('cx',String(points[0][0]));line.setAttribute('cy',String(points[0][1]));line.setAttribute('r','3');line.setAttribute('fill','#0072bd');}else{line.setAttribute('points',points.map(p=>p.join(',')).join(' '));line.setAttribute('fill','none');line.setAttribute('stroke','#0072bd');line.setAttribute('stroke-width','2');}svg.append(line);}

    for(let i=0;i<4;i++){const label=document.createElementNS(svg.namespaceURI,'text');label.setAttribute('x','0');label.setAttribute('y',String(24+i*45));label.setAttribute('fill','#616161');label.textContent=hoursNumber(max*(1-i/3));svg.append(label);}host.append(el('p',unit,'muted'),svg);
    const caption=el('div',undefined,'chart-caption');caption.append(el('span',date(start)),el('span',date(end)));host.append(caption);const data=el('details',undefined,'chart-data');data.append(el('summary',t('采样明细')));data.addEventListener('toggle',()=>{if(!data.open || data.dataset.loaded)return;data.dataset.loaded='true';const wrap=el('div',undefined,'table-scroll'),node=el('table'),head=el('tr');for(const key of [t('时间'),title+' ('+unit+')']){const th=el('th',key);th.scope='col';head.append(th);}node.append(head);for(const point of points.slice(-200)){const row=el('tr');row.append(el('td',date(point.timestamp)),el('td',point[key]==null?'—':hoursNumber(point[key])));node.append(row);}wrap.append(node);data.append(el('p',t('显示最近 200 条采样；图表覆盖所选时间范围。'),'muted'),wrap);});host.append(data);return host;
  }
  async function showMonitor(kind,id,title,detail){monitorRequest++;$('history-hours').querySelector('option[value="720"]').hidden=kind!=='user';if(kind!=='user' && $('history-hours').value==='720')$('history-hours').value='168';i18n.setText($('monitor-error'),'');monitor={kind,id,title,detail};$('monitor-title').textContent=title;$('monitor-detail').textContent=JSON.stringify(detail,null,2);$('monitor-charts').replaceChildren();i18n.setText($('monitor-status'),'正在加载');$('monitor-dialog').showModal();await updateMonitor();}
  async function updateMonitor(){const current=monitor,generation=++monitorRequest;if(!current)return;try{const result=await api('history?kind='+encodeURIComponent(current.kind)+'&id='+encodeURIComponent(current.id)+'&hours='+$('history-hours').value);if(current!==monitor || generation!==monitorRequest)return;
    const detail=current.kind==='pod'?state.pods.find(p=>p.uid===current.id):current.kind==='node'?state.nodes.find(n=>n.name===current.id):state.users.find(u=>u.uid===current.id);
    if(detail)$('monitor-detail').textContent=JSON.stringify(detail,null,2);
    const points=result.points,charts=$('monitor-charts');charts.replaceChildren();
    if(current.kind==='user'){
      const usage=state.usage[current.id],summary=el('dl',undefined,'usage-summary');
      for(const [label,value] of [['累计分配核时',usage?.allocatedHours],['累计实际 CPU 核时',usage?.cpuHours],['采样覆盖时长',usage?usage.coverageSeconds/3600:null]]){
        const item=el('div');item.append(el('dt',t(label)),el('dd',value==null?'—':hoursNumber(value)+(label==='采样覆盖时长'?' h':' core h')));summary.append(item);
      }
      charts.append(summary,el('p',t('累计统计覆盖保留期内的已记录数据，图表按所选时间范围显示。缺失采样不计入统计。'),'muted'),chart(t('分配核时'),points,'allocatedHours','core h'),chart(t('实际 CPU 核时'),points,'cpuHours','core h'));
    }
    else {charts.append(chart(t('CPU 使用'),points,'cpu','CPU'),chart(t('内存使用'),points.map(p=>({...p,memoryGiB:p.memory==null?null:p.memory/1024**3})),'memoryGiB','GiB'));}
    i18n.setText($('chart-status'),'实时采样：{time}',{time:date(state.timestamp)});i18n.setText($('monitor-status'),'Pod 和节点保留最近 7 天采样，用户核时保留最近 366 天。缺失采样不连线。');i18n.setText($('monitor-error'),'');
    }catch(error){if(current===monitor && generation===monitorRequest)i18n.setText($('monitor-error'),error.message);}
  }
  $('history-hours').onchange=()=>{$('monitor-charts').replaceChildren();i18n.setText($('monitor-status'),'正在加载');updateMonitor();};$('monitor-close').onclick=()=>{$('monitor-dialog').close();monitor=null;monitorRequest++;};
  $('monitor-dialog').oncancel=()=>{monitor=null;monitorRequest++;};
  i18n.onChange(()=>{render();if(operation?.preview)describeOperation(operation.preview);if(monitor)updateMonitor().catch(error=>message(error.message));});
  setInterval(poll,15000);
  api('me').then(result=>{csrf=result.csrf;$('sign-in').hidden=true;$('console').hidden=false;poll();}).catch(()=>{});
})();
