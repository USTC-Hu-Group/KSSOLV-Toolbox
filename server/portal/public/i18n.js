// Portal language is a browser preference, separate from Toolbox settings.
(() => {
  const translations = {
    '实例配置：':'Instance size:', '小':'Small', '中':'Medium', '大':'Large',
    '小（{cpu}CPU / {memory}GB）':'Small ({cpu}CPU / {memory}GB)',
    '中（{cpu}CPU / {memory}GB）':'Medium ({cpu}CPU / {memory}GB)',
    '大（{cpu}CPU / {memory}GB）':'Large ({cpu}CPU / {memory}GB)',
    '账号已冻结，请联系管理员。':'This account is frozen. Please contact the administrator.',
    '用户不存在。':'This user does not exist.', '工作空间配置无效。':'Invalid workspace size.',
    '管理员已关闭实例。':'An administrator stopped the instance.',
    '管理员正在重启实例。':'An administrator is restarting the instance.',
    '语言':'Language', '正在加载':'Loading', '账号':'Account', '登录':'Sign in', '注册账号':'Register',
    '用户名：':'Username:', '密码：':'Password:', '确认密码：':'Confirm password:',
    '用户名格式':'Username format', '密码说明':'Password requirements',
    '以小写字母开头，可用小写字母、数字和连字符（3–32 个字符）。':'Start with a lowercase letter. Use lowercase letters, numbers and hyphens (3–32 characters).',
    '可用大小写字母、数字和特殊符号，区分大小写（12–128 个字符）。':'Uppercase and lowercase letters, numbers and special characters are allowed. Passwords are case-sensitive (12–128 characters).',
    '备忘问题：':'Recovery question:', '备忘答案：':'Recovery answer:', '邀请码：':'Invitation code:',
    '输入备忘问题':'Enter a recovery question',
    '忘记密码时用于验证身份。例：我给第一盆植物起的昵称是什么？（4–200 个字符）':'Used to verify your identity if you forget your password. Example: What nickname did I give my first plant? (4–200 characters)',
    '例：蓝色星云。忽略大小写及首尾空白，请设置难猜的答案并牢记（2–128 个字符）。':'Example: Blue nebula. Case and surrounding spaces are ignored. Choose an answer that is hard to guess and remember it (2–128 characters).',
    '请联系管理员获取邀请码。':'Contact the administrator for an invitation code.',
    '忘记密码':'Forgot password', '登录并打开工作空间':'Sign in and open workspace',
    '新密码：':'New password:', '确认新密码：':'Confirm new password:',
    '答案忽略大小写及首尾空白。重置后退出所有会话并释放实例，已保存文件保留，未保存内容可能丢失。':'Answers ignore case and surrounding spaces. Resetting signs out all sessions and releases the instance. Saved files are kept; unsaved changes may be lost.',
    '返回登录':'Back to sign in', '更换用户名':'Change username', '获取备忘问题':'Get recovery question', '重置密码':'Reset password',
    '设置备忘问题':'Set recovery question',
    '此账号尚未设置备忘问题。设置后可在忘记密码时验证答案并重置。':'This account has no recovery question. Set one to reset your password by verifying your answer.',
    '当前密码：':'Current password:',
    '问题会公开显示，请使用非公开、难以猜测的答案；答案忽略大小写及首尾空白。':'The question is publicly visible. Choose a private answer that is hard to guess. Case and surrounding spaces are ignored.',
    '稍后设置':'Set up later', '保存并打开工作空间':'Save and open workspace',
    '工作空间':'Workspace', '正在准备工作空间…':'Preparing workspace…', '打开工作空间':'Open workspace',
    '启动工作空间':'Start workspace', '重启工作空间':'Restart workspace', '注销并释放实例':'Sign out and release instance',
    '空闲超时后实例自动释放，请及时保存项目。':'The instance is released after the inactivity limit. Save your project regularly.',
    '重启会关闭当前实例，未保存的内容可能丢失。已保存的文件和设置保留。':'Restarting closes the current instance. Unsaved changes may be lost. Saved files and settings are kept.',
    '是否继续重启？':'Restart this workspace?', '取消':'Cancel', '重启':'Restart', 'KSSOLV 独立工作空间':'KSSOLV private workspace',
    '连接已过期':'Connection expired', '暂时无法打开工作空间':'Unable to open workspace',
    '如仍无法连接，请稍后重试或联系管理员。':'If the connection still fails, try again later or contact the administrator.',
    '重新登录':'Sign in again', '重新连接':'Reconnect',
    '你好，{username}':'Hello, {username}',
    '{minutes} 分钟无操作后实例自动释放。保留标签页可恢复原界面，关闭或刷新后将重建。请及时保存项目。':'The instance is released after {minutes} minutes of inactivity. Keep this tab to return to the same interface; closing or refreshing rebuilds it. Save your project regularly.',
    '浏览器阻止工作空间加载：{directive} {uri}':'The browser blocked the workspace: {directive} {uri}',
    '请求失败。':'The request failed.', '原工作空间已结束，请重新启动。':'The previous workspace has ended. Start it again.',
    '连接未完成，请重试连接。':'The connection did not complete. Try reconnecting.',
    '已返回入口，工作空间仍在运行。':'You have returned to the entry page. The workspace is still running.',
    '工作空间已就绪。':'The workspace is ready.',
    '正在启动你的独立工作空间，首次启动需要稍候。':'Starting your private workspace. The first start may take a little longer.',
    '重试连接':'Retry connection', '重连工作空间':'Reconnect to workspace',
    '用户名需为 3–32 位小写字母、数字或连字符，以字母开头。':'Use lowercase letters, numbers or hyphens, starting with a letter (3–32 characters).',
    '两次输入的密码不一致。':'The passwords do not match.', '注册成功，请登录。':'Registration complete. Please sign in.',
    '已退出登录，实例已释放。':'Signed out. The instance has been released.',
    '长时间未操作，实例已释放。请重新登录。':'The instance was released due to inactivity. Please sign in again.',
    '密码需为 12–128 个字符。':'The password must contain 12–128 characters.',
    '备忘答案需为 2–128 个字符。':'The recovery answer must contain 2–128 characters.',
    '备忘问题需为 4–200 个字符。':'The recovery question must contain 4–200 characters.',
    '请重新登录。':'Please sign in again.', '操作过于频繁，请稍后再试。':'Too many attempts. Please try again later.',
    '邀请码无效。':'The invitation code is invalid.', '注册名额已满，请联系管理员。':'Registration is full. Please contact the administrator.',
    '用户名不可用。':'This username is unavailable.', '用户名或密码不正确。':'The username or password is incorrect.',
    '请输入有效的用户名。':'Enter a valid username.',
    '该账号未设置备忘问题或不可用，请联系管理员。':'This account has no recovery question or is unavailable. Please contact the administrator.',
    '当前密码不正确。':'The current password is incorrect.', '备忘问题已设置。':'A recovery question has already been set.',
    '会话已结束，请重新登录。':'Your session has ended. Please sign in again.',
    '用户名或备忘答案不正确，或该账号尚未设置备忘问题。':'The username or recovery answer is incorrect, or this account has no recovery question.',
    '账号信息已更新，请重新验证。':'Account details have changed. Please verify again.',
    '密码已重置，请重新登录。':'Your password has been reset. Please sign in again.',
    '当前实例名额已满，请稍后点击重连。':'All instance slots are in use. Try reconnecting later.',
    '工作空间正在启动或停止，请稍候。':'The workspace is starting or stopping. Please wait.',
    '实例启动失败，请重试或联系管理员。':'The instance failed to start. Try again or contact the administrator.',
    '工作空间暂时不可用，请重试连接；若持续失败，可重启工作空间。':'The workspace is temporarily unavailable. Try reconnecting; if it still fails, restart the workspace.',
    '实例仍在启动，请稍候。':'The instance is still starting. Please wait.',
    '登录跳转已过期，请返回入口重试。':'The sign-in link has expired. Return to the entry page and try again.',
    '原工作空间已不可用，请重新启动。':'The previous workspace is no longer available. Start it again.',
    '实例已释放，请重新登录。':'The instance has been released. Please sign in again.',
    '工作空间未能响应。请重试连接；若持续失败，可返回入口重启工作空间。':'The workspace did not respond. Try reconnecting; if it still fails, return to the entry page and restart the workspace.',
    '长时间未操作，实例已释放。已保存文件和设置仍保留。':'The instance was released due to inactivity. Saved files and settings are kept.',
    '服务暂时不可用，请稍后重试。':'The service is temporarily unavailable. Please try again later.',
    '入口域名无效。':'The entry domain is invalid.', '请求来源无效，请从本站重新登录。':'The request origin is invalid. Please sign in again from this site.',
    '请求格式无效。':'The request format is invalid.', '请求过大。':'The request is too large.', '跨站连接被拒绝。':'The cross-site connection was denied.',
    '实例已释放。':'The instance has been released.', '请从登录入口访问。':'Please use the sign-in entry page.',
    '注册成功，请使用新账号登录。':'Registration complete. Please sign in with your new account.',
    '密码已重置，请使用新密码登录。':'Your password has been reset. Please sign in with your new password.',
    '页面不存在。':'This page does not exist.', '工作空间暂时不可用。':'The workspace is temporarily unavailable.',
    '工作空间尚未就绪，请点击重新连接。':'The workspace is not ready. Click Reconnect.',
    '工作空间尚未就绪，请点击重新连接。 ':'The workspace is not ready. Click Reconnect.',
    'Failed to fetch':'Unable to connect. Check your network and try again.',
    'NetworkError when attempting to fetch resource.':'Unable to connect. Check your network and try again.'
  };
  Object.assign(translations,window.KSSOLVAdminTranslations || {});
  const storageKey = 'kssolv.portal.language';
  const valid = value => ['zh-CN','en'].includes(value);
  let language;
  try { language=localStorage.getItem(storageKey); } catch (_) { /* Storage may be disabled. */ }
  const requestedLanguage=new URL(location.href).searchParams.get('lang');
  if(valid(requestedLanguage)) {
    language=requestedLanguage;
    const cleanURL=new URL(location.href);
    cleanURL.searchParams.delete('lang');
    history.replaceState(null,'',cleanURL.href);
    try { localStorage.setItem(storageKey,language); } catch (_) {}
  }
  if(!valid(language)) language=/^zh\b/i.test(navigator.language || '')?'zh-CN':'en';
  const bindings=new Map(), listeners=new Set();
  function t(source, values={}) {
    const template=language==='en' ? (translations[source] || source) : source;
    return template.replace(/\{(\w+)\}/g,(match,key)=>Object.hasOwn(values,key)?String(values[key]):match);
  }
  function bind(element, source, attribute=null, values={}) {
    if(!element) return;
    let entries=bindings.get(element);
    if(!entries) bindings.set(element, entries=new Map());
    entries.set(attribute,{source,values});
    if(attribute) element.setAttribute(attribute,t(source,values));
    else element.textContent=t(source,values);
  }
  function setLanguage(value, persist=true) {
    if(!valid(value)) return;
    language=value;
    if(persist) try { localStorage.setItem(storageKey,value); } catch (_) { /* Keep the selection for this page. */ }
    document.documentElement.lang=value;
    for(const [element,entries] of bindings) for(const [attribute,{source,values}] of entries) {
      if(attribute) element.setAttribute(attribute,t(source,values)); else element.textContent=t(source,values);
    }
    const selector=document.getElementById('portal-language');
    if(selector) selector.value=value;
    for(const listener of listeners) listener(value);
  }
  for(const element of document.querySelectorAll('[data-i18n]')) bind(element,element.textContent);
  for(const attribute of ['aria-label','placeholder','title'])
    for(const element of document.querySelectorAll('[data-i18n-'+attribute+']')) bind(element,element.getAttribute(attribute),attribute);
  const selector=document.getElementById('portal-language');
  if(selector) selector.addEventListener('change',()=>setLanguage(selector.value));
  window.addEventListener('storage',event=>{if(event.key===storageKey && valid(event.newValue)) setLanguage(event.newValue,false);});
  window.KSSOLVI18n={t,setText:(element,source,values)=>bind(element,source,null,values),setLanguage,
    get language(){return language;},onChange:listener=>listeners.add(listener)};
  setLanguage(language,false);
})();
