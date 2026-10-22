// Error pages also work directly, without the hub shell or a Runtime.
(() => {
  const portalOrigin=__PORTAL_ORIGIN__;
  const i18n=window.KSSOLVI18n;
  const syncEntryLanguage=()=>{
    const form=document.querySelector('form');
    if(!form || !i18n) return;
    const target=new URL(form.action);
    target.searchParams.set('lang',i18n.language);
    form.action=target.href;
  };
  if(i18n) { syncEntryLanguage(); i18n.onChange(syncEntryLanguage); }
  if(window.parent===window) return;
  window.addEventListener('message',event=>{
    if(event.source!==window.parent || event.origin!==portalOrigin || event.data?.type!=='kssolv-language') return;
    window.KSSOLVI18n?.setLanguage(event.data.language);
  });
  window.parent.postMessage({type:'kssolv-language-request'},portalOrigin);
  window.parent.postMessage({type:'kssolv-entry-error',
    message:document.getElementById('entry-error-message')?.textContent || '工作空间暂时不可用。'},portalOrigin);
})();
