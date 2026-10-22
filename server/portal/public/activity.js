(() => {
  try { if (window !== window.top && window.parent.location.origin === location.origin) return; } catch {}
  if (window.__kssolvActivityInstalled) return;
  window.__kssolvActivityInstalled = true;
  const portal = __PORTAL_ORIGIN__, documents = new WeakSet(), frames = new WeakSet();
  let dirty = false, pending = false, deadline = 0, ended = false, rejected = false, banner;
  function connection(state) {
    if(window !== window.top) window.parent.postMessage({type:'kssolv-connection-status',state},portal);
    else window.KSSOLVFavicon?.report(state);
  }
  function expire() { if (!ended) { ended=true; if(window !== window.top) window.parent.postMessage({type:'kssolv-session-ended'},portal); else location.replace(portal + '/online?ended=1'); } }
  async function report(activity = false) {
    if (pending || ended || rejected) return;
    pending = true;
    const started=Date.now(), controller=new AbortController();
    const timeout=setTimeout(()=>controller.abort(),5000);
    try {
      const response = await fetch('/_portal/api/' + (activity ? 'activity' : 'session'), {
        credentials:'same-origin', cache:'no-store', signal:controller.signal, ...(activity ? {method:'POST',headers:{'Content-Type':'application/json'},body:'{}'} : {})});
      if (response.status === 401) return expire();
      if (!response.ok) throw new Error('Connection unavailable');
      const state = await response.json(); deadline=Date.now()+state.idleRemaining*1000; if(activity) dirty=false;
      connection(!state.ready?'inactive':Date.now()-started>=1500?'slow':'connected');
    } catch { connection('disconnected'); }
    finally { clearTimeout(timeout); pending=false; }
  }
  function input(event) { if(event.isTrusted) dirty=true; }
  function attach(doc) {
    // Connector's nonce is single-use. A stale/replayed entry can be a plain
    // 403 document with no bridge script; its same-origin wrapper can detect
    // it and ask the authenticated shell for one fresh entry URL.
    if(doc && /^\/static\/[^/]+\/AppContainerWebPath\/index\.html$/.test(doc.location?.pathname || '') &&
        doc.body?.textContent.trim()==='Forbidden') {
      if(!rejected) {
        rejected=true;
        window.parent.postMessage({type:'kssolv-runtime-entry-rejected'},portal);
      }
      return;
    }
    if (!doc || documents.has(doc)) return;
    documents.add(doc);
    for(const type of ['pointerdown','keydown','wheel','touchstart']) doc.addEventListener(type,input,{capture:true,passive:true});
    function scan() {
      for(const frame of doc.querySelectorAll('iframe')) {
        if(!frames.has(frame)) { frames.add(frame); frame.addEventListener('load',()=>{try{attach(frame.contentDocument)}catch{}}); }
        try { attach(frame.contentDocument); } catch {}
      }
    }
    new MutationObserver(scan).observe(doc.documentElement,{childList:true,subtree:true}); scan();
  }
  window.addEventListener('offline',()=>connection('disconnected'));
  window.addEventListener('online',()=>report());
  if(window === window.top) window.KSSOLVFavicon?.workspace('active');
  attach(document); report();
  setInterval(()=>report(dirty),15000);
  setInterval(()=>{
    if(!deadline || ended) return;
    const seconds=Math.ceil((deadline-Date.now())/1000);
    if(!banner) { banner=document.createElement('div'); banner.style.cssText='position:fixed;top:8px;left:50%;transform:translateX(-50%);z-index:2147483647;background:#fff4d6;color:#674c10;border:1px solid #e5cd89;border-radius:7px;padding:10px 18px;font:14px system-ui;box-shadow:0 2px 12px #0002';document.body.appendChild(banner); }
    banner.hidden=seconds>120 || dirty;
    banner.textContent=seconds>0 ? `工作空间将在 ${seconds} 秒后因无操作而释放。请保存项目；继续操作可保持连接。` : '正在断开空闲工作空间；已保存文件和设置保留。';
  },1000);
})();
