function kssolvPrewarm()
%KSSOLVPREWARM 初始化完整桌面界面，渲染就绪后关闭应用。

% 开发者：杨柳
% 版权 2026 合肥瀚海量子科技有限公司

existingApp = kssolv.ui.util.DataStorage.getData("KSSOLVToolbox");
if isa(existingApp, "kssolv.KSSOLVToolbox") && isvalid(existingApp)
    error('KSSOLV:Startup:ExistingSession', ...
        'Prewarm requires a new application session.');
end

startupTimer = tic;
fprintf('KSSOLV_STARTUP_ENTRY prefdir=%s\n', prefdir(1));

app = kssolv("", false);
cleanup = onCleanup(@() delete(app));
app.waitUntilReady();

fprintf('KSSOLV_UI_READY entry_elapsed=%.3f\n', toc(startupTimer));
clear cleanup

drawnow;
fprintf('KSSOLV_UI_PREWARM_OK\n');
end
