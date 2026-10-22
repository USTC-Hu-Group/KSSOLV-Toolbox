// The hub owns the tab icon. Workspace status arrives only through its
// authenticated tenant frame; probes never count as human activity.
(() => {
  if(window !== window.top || window.KSSOLVFavicon) return;
  let phase='idle', network='idle', lastReport=Date.now(), revision=0, probing=false, shown;
  let icon=document.getElementById('connection-icon');
  if(!icon) {
    icon=document.createElement('link'); icon.id='connection-icon'; icon.rel='icon'; icon.type='image/svg+xml';
    document.head.appendChild(icon);
  }
  function paint() {
    const state=phase==='error'?'inactive':navigator.onLine===false?'disconnected':network==='disconnected'?'disconnected':
      phase==='loading' || phase==='inactive'?'inactive':phase==='active'?network:
      network==='slow'?'slow':'idle';
    if(state===shown) return;
    shown=state; icon.href='/_portal/favicon.svg?state='+state;
  }
  async function probe() {
    if(probing || phase!=='idle' || navigator.onLine===false) return;
    probing=true;
    const current=revision, started=Date.now(), controller=new AbortController();
    const timeout=setTimeout(()=>controller.abort(),5000);
    try {
      const response=await fetch('/healthz',{cache:'no-store',credentials:'same-origin',signal:controller.signal});
      if(!response.ok) throw new Error('Connection unavailable');
      await response.json();
      if(current===revision) network=Date.now()-started>=1500?'slow':'idle';
    } catch { if(current===revision) network='disconnected'; }
    finally { clearTimeout(timeout); probing=false; paint(); }
  }
  window.KSSOLVFavicon={
    workspace(value) {
      if(!['idle','loading','active','inactive','error'].includes(value)) return;
      if(phase!==value) { revision++; network=value==='active'?'inactive':'idle'; lastReport=Date.now(); }
      phase=value; paint();
      if(phase==='idle') probe();
    },
    report(value) {
      if(!['connected','slow','disconnected','inactive'].includes(value) || phase!=='active') return;
      lastReport=Date.now(); network=value; paint();
    }
  };
  window.addEventListener('offline',paint);
  window.addEventListener('online',()=>{
    network=phase==='active'?'inactive':'idle'; lastReport=Date.now(); paint(); probe();
  });
  setInterval(()=>{
    if(phase==='active' && Date.now()-lastReport>25000) {network='disconnected';paint();}
    probe();
  },5000);
  paint(); probe();
})();
