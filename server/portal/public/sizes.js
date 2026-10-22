// The server owns the quantities; the browser submits only a profile ID.
(()=>{
  const i18n=window.KSSOLVI18n;
  async function refresh(){try {
    const response=await fetch('/_portal/api/profiles',{credentials:'same-origin'});
    if(!response.ok) return;
    const result=await response.json();
    for(const prefix of ['login-size','workspace-size']) for(const key of ['small','medium','large']) {
      const option=document.getElementById(prefix+'-'+key),size=result.profiles[key];
      if(option && size) i18n.setText(option,{'small':'小（{cpu}CPU / {memory}GB）','medium':'中（{cpu}CPU / {memory}GB）','large':'大（{cpu}CPU / {memory}GB）'}[key],
        {...size,memory:size.memory.replace(/Gi$/,'')});
    }
  } catch(_) { /* Profile IDs and server defaults remain usable offline. */ }}
  refresh();
  window.addEventListener('focus',refresh);
  document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh();});
  setInterval(()=>{if(!document.hidden)refresh();},30000);
})();
