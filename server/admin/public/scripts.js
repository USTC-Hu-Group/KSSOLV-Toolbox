/* Host Shell management: all execution uses immutable, explicitly reviewed revisions. */
window.KSSOLVScripts={create({api:baseApi,poll,message,table,button,menu,el,date}){
  const $=id=>document.getElementById(id),i18n=window.KSSOLVI18n,t=(s,v)=>i18n.t(s,v),text=(id,s,v)=>s?.startsWith('Shell syntax error: ')?i18n.setText($(id),'Shell 语法错误：{detail}',{detail:s.slice(20)}):i18n.setText($(id),s,v);
  const errors={"Invalid script ID.": "脚本标识无效。", "Script not found.": "未找到脚本。", "Script revision not found.": "未找到脚本版本。", "Use 2–40 lowercase letters, numbers or hyphens for the script ID.": "标识以小写字母开头，可用小写字母、数字和连字符（2–40 个字符）。", "Invalid script description.": "请填写脚本名称，说明最多 500 个字符。", "Shell source is required.": "请填写 Shell 内容。", "Use a UTF-8 Shell script of at most 128 KiB.": "请使用非空 UTF-8 Shell 内容（最多 128 KiB）。", "Timeout must be 1–86400 seconds.": "超时需为 1–86400 秒的整数。", "Script changed. Reload it before saving or running.": "脚本已更改，请重新加载后保存或执行。", "Type the script ID to confirm host execution.": "请输入正确的脚本标识，确认在宿主机执行。", "Interval must be 1–10080 minutes.": "间隔需为 1–10080 分钟的整数。", "Invalid cron expression.": "Cron 表达式无效。", "Cron requires minute, hour, day, month and weekday.": "Cron 需包含分、时、日、月、周五个字段。", "Use cron numbers, *, ranges, lists and steps.": "Cron 可用数字、星号、范围、列表和步长。", "Invalid cron step.": "Cron 步长无效。", "Cron value is outside its allowed range.": "Cron 数值超出范围。", "Cron expression has no occurrence within eight years.": "此 Cron 在未来八年内无执行时间。", "Invalid schedule timezone.": "计划时区无效。", "Select an interval or cron schedule.": "请选择间隔或 Cron 计划。", "Script run not found.": "未找到运行记录。", "Invalid run ID.": "运行标识无效。", "Invalid run cursor.": "运行记录分页无效。", "Invalid schedule state.": "计划状态无效。", "This script is already queued or running.": "此脚本正在排队或运行。", "Script queue is full. Try again later.": "执行队列已满，请稍后重试。"};
  async function api(...args){try{return await baseApi(...args);}catch(error){error.message=errors[error.message] || error.message;throw error;}}
  let inventory={},current=null,dirty=false,confirmation=null,discard=null,rows=[],next='',paged=false,result=null,request=0,resultRequest=0,session=0;
  let editorEpoch=0,editorPending=null,confirmLoading=null,confirmPending=null,historyPending=null,resultPending=null,resultData=null,resultActive=false,editorStale=false,legacyScripts=[];
  const editorFields=['script-id','script-name','script-description','script-timeout','script-source'],cancelling=new Set();
  const statuses={queued:'排队中',running:'运行中',succeeded:'成功',failed:'失败',cancelled:'已取消',timed_out:'已超时',interrupted:'已中断',blocked:'权限已失效',skipped:'已跳过'};
  const reasons={'Completed.':'执行完成。','Shell returned a nonzero exit code.':'脚本返回非零退出码。','Execution time limit exceeded.':'已超过执行时间限制。','Stopped by an administrator.':'管理员已停止执行。','Cancelled before execution.':'已在执行前取消。','Executor restarted; execution was not resumed.':'执行服务已重启，本次运行未恢复。','Executor stopped; execution was not resumed.':'执行服务已停止，本次运行未恢复。','Creator no longer has administrator access.':'创建者已失去管理员权限。','This script is already queued or running.':'此脚本正在排队或运行。','Script queue is full. Try again later.':'执行队列已满，请稍后重试。'};
  const duration=r=>r.started?Math.max(0,(r.finished || Date.now()/1000)-r.started).toFixed(1)+' s':'—';
  const caught=fn=>async(...args)=>{const generation=session;try{return await fn(...args);}catch(error){if(generation===session)message(error.message,true);}};
  function hostText(){return t('脚本以 {user} 身份在宿主机 {host} 执行，可修改宿主机和集群。',{user:inventory.executionUser || 'root',host:inventory.executionHost || '—'});}
  function editorStatus(){
    const newer=editorStale || current && (inventory.scripts || []).some(s=>s.id===current.id && s.revision>current.revision),busy=Boolean(editorPending);
    text('script-editor-status',busy?(editorPending.kind==='save'?'正在保存脚本…':editorPending.kind==='leave'?'正在退出管理…':'正在加载'):dirty?'有未保存的修改。':newer?'已有更新版本，请重新加载后编辑或执行。':'');
    for(const id of editorFields)$(id).disabled=busy;
    $('script-new').disabled=$('script-upload').disabled=$('script-save').disabled=busy;
    $('script-run').disabled=$('script-schedule').disabled=busy || !current || dirty || newer;
  }
  function editorTask(kind){const task={kind,epoch:++editorEpoch,session};editorPending=task;editorStatus();return task;}
  function editorCurrent(task){return task===editorPending && task.session===session && task.epoch===editorEpoch;}
  function editorDone(task){if(task===editorPending){editorPending=null;editorStatus();}}
  function edit(item){editorEpoch++;current=item;dirty=false;editorStale=false;$('script-id').value=item?.id || '';$('script-id').readOnly=Boolean(item);$('script-name').value=item?.name || '';$('script-description').value=item?.description || '';$('script-timeout').value=item?.timeout || 300;$('script-source').value=item?.source || '#!/bin/bash\nset -euo pipefail\n\n';$('script-version').textContent=item?'v'+item.revision+' · SHA-256 '+item.sha256:'';text('script-form-error','');editorStatus();}
  function guarded(fn){if(editorPending || confirmLoading || confirmPending)return;if(!dirty)return fn();discard=fn;$('script-discard-dialog').showModal();}
  function guardLeave(fn){
    if(editorPending || confirmLoading || confirmPending){message('脚本操作正在进行，请稍候再退出管理。',true);return;}
    return guarded(async()=>{const task=editorTask('leave');try{return await fn();}finally{editorDone(task);}});
  }
  async function load(id){if(editorPending)return;const task=editorTask('load');try{const item=await api('scripts/source?id='+encodeURIComponent(id));if(editorCurrent(task))edit(item);}finally{editorDone(task);}}
  function render(value,legacy=legacyScripts){inventory=value;legacyScripts=legacy;
    $('script-host').textContent=hostText();text('script-runner-status',value.runnerReady?'执行服务在线':'执行服务离线，任务将保留在队列中。');
    table('script-table',['标识','名称','版本','执行计划','下次执行','操作'],(value.scripts || []).map(s=>{const schedule=s.schedule;
      const actions=[['编辑脚本',()=>guarded(()=>load(s.id))],['查看运行记录',()=>{$('script-run-filter').value=s.id;refresh();}],['立即执行',()=>openConfirm(s.id,'run')],['定期执行',()=>openConfirm(s.id,'schedule')]];
      if(schedule?.enabled)actions.push(['暂停计划',async()=>{await api('scripts/pause',{id:s.id});await poll();}]);
      return [s.id,s.name,'v'+s.revision,schedule?(t(schedule.enabled?'已启用':'已暂停')+' · v'+schedule.revision+' · '+(schedule.kind==='interval'?t('每 {minutes} 分钟',{minutes:schedule.expression}):schedule.expression)+' · '+schedule.timezone+(schedule.message?' · '+t(reasons[schedule.message] || schedule.message):'')):t('未设置'),date(schedule?.next_run),menu(actions)];}));
    const filter=$('script-run-filter'),selected=filter.value,desired=JSON.stringify((value.scripts || []).map(s=>[s.id,s.name]));
    if(filter.dataset.items!==desired){filter.dataset.items=desired;filter.replaceChildren();const all=el('option',t('全部脚本'));all.value='';filter.append(all);for(const s of value.scripts || []){const o=el('option',s.name+' ('+s.id+')');o.value=s.id;filter.append(o);}filter.value=selected;}else if(filter.options[0])filter.options[0].textContent=t('全部脚本');
    $('legacy-scripts').hidden=!legacy.length;if(legacy.length)table('legacy-script-table',['标识','名称','绝对路径','说明'],legacy.map(s=>[s.id,s.name,s.path,s.description]));
    editorStatus();
    renderRuns();
  }
  function renderRuns(){table('script-runs-table',['创建时间','脚本','版本','触发方式','状态','耗时','退出码','操作者','操作'],rows.map(r=>[date(r.created),r.script_id,'v'+r.revision,t(r.trigger==='manual'?'手动':'定时'),t(r.cancel_requested && r.status==='running'?'停止中':statuses[r.status] || r.status),duration(r),r.exit_code??'—',r.actor,menu([['查看结果',()=>showResult(r.id)],...(['queued','running'].includes(r.status) && !r.cancel_requested?[['停止执行',()=>cancelRun(r.id)]]:[])]) ]));}
  async function refresh(reset=true,more=false){
    if((!reset && paged && !more) || (historyPending && (!reset || more)))return;
    const generation=++request,q=new URLSearchParams({id:$('script-run-filter').value});if(more && next){q.set('before',next);paged=true;}else if(reset)paged=false;
    historyPending=generation;$('script-runs-more').disabled=true;text('script-history-status','正在加载');
    try{const data=await api('scripts/runs?'+q);if(generation!==request)return;rows=more?[...rows,...data.runs]:data.runs;next=data.next;$('script-runs-more').hidden=!next;renderRuns();text('script-history-status','');}
    catch(error){if(generation===request)text('script-history-status',error.message);}
    finally{if(historyPending===generation){historyPending=null;$('script-runs-more').disabled=false;}}
  }
  function setConfirmationBusy(busy){for(const id of ['script-confirm-submit','script-confirm-cancel','script-confirmation','script-schedule-kind','script-schedule-expression'])$(id).disabled=busy;}
  async function openConfirm(id,mode){
    if(editorPending || confirmPending || confirmLoading)return;
    if(dirty && id===current?.id)throw new Error('请先保存脚本修改。');
    const task={session,epoch:editorEpoch,revision:current?.id===id?current.revision:null,sha256:current?.id===id?current.sha256:null};confirmLoading=task;
    try{
      const item=await api('scripts/source?id='+encodeURIComponent(id));if(task!==confirmLoading || task.session!==session || task.epoch!==editorEpoch)return;
      if(task.revision!=null && (item.revision!==task.revision || item.sha256!==task.sha256)){editorStale=true;editorStatus();throw new Error('已有更新版本，请重新加载后编辑或执行。');}
      confirmation={item,mode};setConfirmationBusy(false);
      text('script-confirm-title',mode==='run'?'立即执行':'定期执行');$('script-confirm-host').textContent=hostText();$('script-confirm-version').textContent=item.id+' · v'+item.revision+'\nSHA-256 '+item.sha256+'\n'+t('超时（秒）：')+' '+item.timeout;$('script-confirm-source').textContent=item.source;$('script-confirmation').value='';$('script-confirmation').placeholder=item.id;text('script-confirm-error','');
      $('script-schedule-fields').hidden=$('script-schedule-note').hidden=mode!=='schedule';text('script-confirm-submit',mode==='run'?'确认并执行':'保存并启用');$('script-timezone').textContent=inventory.timezone;
      const schedule=(inventory.scripts || []).find(s=>s.id===id)?.schedule;
      const daily=schedule?.kind==='cron' && /^(\d{1,2}) (\d{1,2}) \* \* \*$/.exec(schedule.expression);
      const validDaily=daily && Number(daily[1])<60 && Number(daily[2])<24;
      $('script-schedule-kind').value=validDaily?'daily':schedule?.kind || 'interval';scheduleKind();
      $('script-schedule-expression').value=validDaily?daily[2].padStart(2,'0')+':'+daily[1].padStart(2,'0'):schedule?.expression || '60';$('script-confirm-dialog').showModal();
    }finally{if(confirmLoading===task)confirmLoading=null;}
  }
  function scheduleKind(){const kind=$('script-schedule-kind').value,input=$('script-schedule-expression');input.type=kind==='daily'?'time':kind==='interval'?'number':'text';input.removeAttribute('min');input.removeAttribute('max');
    if(kind==='interval'){input.min='1';input.max='10080';input.step='1';input.value='60';text('script-schedule-label','间隔（分钟）：');}
    else if(kind==='daily'){input.value='09:00';text('script-schedule-label','执行时间：');}
    else{input.value='0 9 * * *';text('script-schedule-label','Cron（分 时 日 月 周）：');}}
  async function showResult(id){
    result=id;resultActive=true;resultData=null;resultPending=null;++resultRequest;text('script-result-error','');$('script-output').textContent='';$('script-result-info').replaceChildren();$('script-result-message').textContent='';text('script-result-warning','');$('script-log-download').removeAttribute('href');$('script-result-stop').hidden=true;$('script-result-source').disabled=true;$('script-result-snapshot').hidden=true;$('script-result-snapshot').textContent='';$('script-result-dialog').showModal();await updateResult();
  }
  function renderResult(r){
    const info=$('script-result-info');info.replaceChildren();
    for(const [key,value] of [['脚本',r.script_id+' · v'+r.revision],['状态',t(r.cancel_requested && r.status==='running'?'停止中':statuses[r.status] || r.status)],['操作者',r.actor],['触发方式',t(r.trigger==='manual'?'手动':'定时')],['创建时间',date(r.created)],['开始时间',date(r.started)],['结束时间',date(r.finished)],['耗时',duration(r)],['退出码',r.exit_code??'—'],['SHA-256',r.sha256]]){
      const pair=el('div');if(key==='SHA-256')pair.className='wide';pair.append(el('dt',t(key)),el('dd',value));info.append(pair);
    }
    $('script-result-message').textContent=t(reasons[r.message] || r.message);
    const output=$('script-output'),bottom=output.scrollHeight-output.scrollTop-output.clientHeight<30,content=r.output || t('暂无输出');
    if(output.textContent!==content){output.textContent=content;if(bottom)output.scrollTop=output.scrollHeight;}
    const warnings=[];if(r.truncated)warnings.push(t('日志已达到 4 MiB 上限，后续输出未保存。'));if(r.tailOnly)warnings.push(t('当前显示日志末尾 128 KiB，可下载完整日志。'));
    $('script-result-warning').textContent=warnings.join(' ');$('script-log-download').href='/online/admin/api/scripts/log?id='+r.id;$('script-result-stop').hidden=!['queued','running'].includes(r.status);$('script-result-stop').disabled=Boolean(r.cancel_requested) || cancelling.has(r.id);$('script-result-source').disabled=false;$('script-result-source').dataset.script=r.script_id;$('script-result-source').dataset.revision=String(r.revision);text('script-result-error','');
  }
  async function updateResult(){
    if(!result || !$('script-result-dialog').open || resultPending)return;
    const task={id:result,request:++resultRequest,session};resultPending=task;
    try{const r=await api('scripts/result?id='+task.id);if(task.id!==result || task.session!==session || task.request!==resultRequest)return;resultData=r;resultActive=['queued','running'].includes(r.status);renderResult(r);}
    catch(error){if(task.id===result && task.session===session && task.request===resultRequest)text('script-result-error',error.message);}
    finally{if(resultPending===task)resultPending=null;}
  }
  async function cancelRun(id){
    if(cancelling.has(id))return;const generation=session;cancelling.add(id);if(result===id)$('script-result-stop').disabled=true;
    try{await api('scripts/cancel',{id});if(generation!==session)return;if(result===id)await updateResult();await refresh();}
    finally{if(generation===session){cancelling.delete(id);if(result===id)$('script-result-stop').disabled=Boolean(resultData?.cancel_requested);}}
  }
  $('script-form').onsubmit=caught(async event=>{
    event.preventDefault();if(editorPending)return;
    const data={id:$('script-id').value.trim(),name:$('script-name').value,description:$('script-description').value,source:$('script-source').value,timeout:Number($('script-timeout').value),expectedRevision:current?.revision || 0},task=editorTask('save');text('script-form-error','');
    try{const item=await api('scripts/save',data);if(!editorCurrent(task))return;edit(item);message('脚本版本已保存。');await poll();}
    catch(error){if(task.session===session && task===editorPending)text('script-form-error',error.message);}
    finally{editorDone(task);}
  });
  for(const id of editorFields)$(id).oninput=()=>{editorEpoch++;dirty=true;text('script-form-error','');editorStatus();};
  $('script-new').onclick=()=>guarded(()=>edit(null));$('script-upload').onclick=()=>guarded(()=>$('script-file').click());
  $('script-file').onchange=caught(async()=>{
    const file=$('script-file').files[0];$('script-file').value='';if(!file || editorPending)return;
    const task=editorTask('upload');
    try{
      if(file.size>128*1024)throw new Error('脚本文件不能超过 128 KiB。');
      let source;try{source=new TextDecoder('utf-8',{fatal:true}).decode(await file.arrayBuffer());}catch{throw new Error('请上传 UTF-8 编码的 Shell 文件。');}
      if(!editorCurrent(task))return;if(source.includes('\x00'))throw new Error('请上传 UTF-8 编码的 Shell 文件。');
      edit(null);$('script-id').value=file.name.replace(/\.(sh|bash)$/i,'').toLowerCase().replace(/[^a-z0-9-]/g,'-').slice(0,40);$('script-name').value=file.name.replace(/\.(sh|bash)$/i,'').slice(0,80);$('script-source').value=source;dirty=true;editorStatus();
    }finally{editorDone(task);}
  });
  $('script-run').onclick=caught(()=>openConfirm(current.id,'run'));$('script-schedule').onclick=caught(()=>openConfirm(current.id,'schedule'));$('script-schedule-kind').onchange=scheduleKind;
  $('script-confirm-form').onsubmit=caught(async event=>{
    event.preventDefault();if(confirmPending || !confirmation)return;
    const task={session,confirmation}, {item,mode}=confirmation,data={id:item.id,revision:item.revision,sha256:item.sha256,confirmation:$('script-confirmation').value};confirmPending=task;setConfirmationBusy(true);
    try{
      if(mode==='schedule'){let kind=$('script-schedule-kind').value,expression=$('script-schedule-expression').value;if(kind==='daily'){if(!/^\d{2}:\d{2}$/.test(expression))throw new Error('请填写执行时间。');const [h,m]=expression.split(':').map(Number);if(h>23 || m>59)throw new Error('请填写执行时间。');kind='cron';expression=m+' '+h+' * * *';}Object.assign(data,{kind,expression,enabled:true});}
      const response=await api('scripts/'+(mode==='run'?'run':'schedule'),data);if(task.session!==session || task!==confirmPending)return;
      $('script-confirm-dialog').close();confirmation=null;message(mode==='run'?'脚本已加入执行队列。':'执行计划已保存并启用。');await poll();if(task.session!==session)return;await refresh();if(task.session===session && mode==='run')await showResult(response.run);
    }catch(error){if(task.session===session && task===confirmPending)text('script-confirm-error',error.message);}
    finally{if(task===confirmPending){confirmPending=null;setConfirmationBusy(false);}}
  });
  $('script-confirm-cancel').onclick=()=>{if(confirmPending)return;$('script-confirm-dialog').close();confirmation=null;};$('script-confirm-dialog').oncancel=event=>{if(confirmPending){event.preventDefault();return;}confirmation=null;};
  $('script-discard-cancel').onclick=()=>{$('script-discard-dialog').close();discard=null;};$('script-discard-dialog').oncancel=()=>{discard=null;};$('script-discard-yes').onclick=caught(async()=>{const fn=discard;discard=null;edit(current);$('script-discard-dialog').close();if(fn)await fn();});
  $('script-run-filter').onchange=$('script-runs-refresh').onclick=caught(()=>refresh());$('script-runs-more').onclick=caught(()=>refresh(false,true));
  $('script-result-close').onclick=()=>{$('script-result-dialog').close();result=null;resultData=null;resultActive=false;resultPending=null;resultRequest++;};$('script-result-dialog').oncancel=()=>{result=null;resultData=null;resultActive=false;resultPending=null;resultRequest++;};
  $('script-result-stop').onclick=caught(()=>cancelRun(result));
  $('script-result-source').onclick=caught(async()=>{const id=result,generation=session;const data=await api('scripts/source?id='+encodeURIComponent($('script-result-source').dataset.script)+'&revision='+$('script-result-source').dataset.revision);if(id!==result || generation!==session)return;$('script-result-snapshot').textContent=data.source;$('script-result-snapshot').hidden=false;});
  setInterval(()=>{if(result && resultActive)return updateResult();},2000);
  window.addEventListener('beforeunload',event=>{if(dirty){event.preventDefault();event.returnValue='';}});
  i18n.onChange(()=>{if(inventory.scripts)render(inventory);editorStatus();if(confirmation){const item=confirmation.item;$('script-confirm-host').textContent=hostText();$('script-confirm-version').textContent=item.id+' · v'+item.revision+'\nSHA-256 '+item.sha256+'\n'+t('超时（秒）：')+' '+item.timeout;}if(resultData)renderResult(resultData);});
  edit(null);
  return {render,refresh,guardLeave,clear(){session++;request++;resultRequest++;editorEpoch++;editorPending=null;confirmLoading=null;confirmPending=null;historyPending=null;resultPending=null;resultData=null;resultActive=false;cancelling.clear();legacyScripts=[];setConfirmationBusy(false);$('script-runs-more').hidden=true;$('script-runs-more').disabled=false;$('script-result-source').disabled=true;rows=[];next='';paged=false;result=null;confirmation=null;discard=null;inventory={};edit(null);$('script-file').value='';$('script-runs-table').replaceChildren();$('script-run-filter').replaceChildren();delete $('script-run-filter').dataset.items;$('script-output').textContent='';$('script-result-info').replaceChildren();$('script-result-message').textContent='';text('script-result-warning','');$('script-log-download').removeAttribute('href');$('script-result-snapshot').textContent='';$('script-confirm-source').textContent='';for(const id of ['script-confirm-dialog','script-result-dialog','script-discard-dialog'])$(id).close();}};
}};
