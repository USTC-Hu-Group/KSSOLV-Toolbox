// File System Access APIs require a top-level origin. Relay to the authenticated
// shell, which opens the native picker using the workspace click's activation.
(() => {
  const portal = __PORTAL_ORIGIN__;
  // Installed before the compiled application's handlers, so existing Runtime
  // images also use bundled manuals. Read the Toolbox's localized toolstrip,
  // not the independently selected Portal/browser language.
  const documentationTag = 'ResourceSection_ResourceDocumentation';
  function openDocumentation(event) {
    if (!event.isTrusted || (event.type === 'keydown' && !['Enter',' '].includes(event.key))) return;
    const button = event.target?.closest?.('[data-tag]');
    if (!button || button.getAttribute('aria-disabled') === 'true') return;
    const tag = button.getAttribute('data-tag');
    if (![documentationTag, 'QABHelpButton'].includes(tag)) return;
    const docs = tag === documentationTag ? button : document.querySelector('[data-tag="' + documentationTag + '"]');
    const label = [docs?.textContent, docs?.getAttribute('aria-label'), docs?.getAttribute('title')].filter(Boolean).join(' ');
    const locale = /文档|文檔/.test(label) ? 'zh-CN' : 'en-US';
    event.preventDefault();
    event.stopImmediatePropagation();
    const link = document.createElement('a');
    link.href = portal + '/online/docs/' + locale + '.pdf';
    link.target = '_blank';
    link.rel = 'noopener';
    document.body.appendChild(link);
    link.click();
    link.remove();
  }
  window.addEventListener('click', openDocumentation, true);
  window.addEventListener('keydown', openDocumentation, true);
  if(location.pathname==='/_portal/claim') history.replaceState(null,'','/online');
  let root = window;
  try { while (root.parent !== root && root.parent.location.origin === location.origin) root=root.parent; } catch {}
  if (root.parent === root) return;
  if (!root.__kssolvFiles) {
    const waiting = new Map();
    root.__kssolvFiles = (operation, args) => new Promise((resolve,reject) => {
      const id=crypto.randomUUID(); waiting.set(id,{resolve,reject});
      root.parent.postMessage({type:'kssolv-file-request',id,operation,args},portal);
    });
    root.addEventListener('message',event => {
      if(event.origin!==portal || event.source!==root.parent || event.data?.type!=='kssolv-file-result') return;
      const entry=waiting.get(event.data.id); if(!entry) return;
      waiting.delete(event.data.id);
      if(event.data.error) entry.reject(new DOMException(event.data.error.message,event.data.error.name));
      else entry.resolve(event.data.result);
    });
  }
  if(typeof window.showOpenFilePicker==='function') window.showOpenFilePicker = async options => {
    const files=await root.__kssolvFiles('open',options);
    return files.map(file => ({name:file.name,getFile:async()=>file}));
  };
  if(typeof window.showSaveFilePicker==='function') window.showSaveFilePicker = async options => {
    const handle=await root.__kssolvFiles('save',options);
    return {name:handle.name,createWritable:async()=>{
      let blob,closed=false;
      return {
        write:async data=>{ if(closed) throw new Error('File is closed'); blob=data instanceof Blob?data:new Blob([data]); if(blob.size>128*1024*1024) throw new Error('File exceeds 128 MiB'); },
        close:async()=>{if(closed) return; await root.__kssolvFiles('commit',{handle:handle.id,data:blob||new Blob()}); closed=true; blob=null;},
        abort:async()=>{closed=true;blob=null;await root.__kssolvFiles('abort',{handle:handle.id});}
      };
    }};
  };
})();
