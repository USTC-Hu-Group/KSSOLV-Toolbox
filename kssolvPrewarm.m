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
if ispc
    % WinMain 不可靠地转发标准输出，使用启动器提供的独立结果文件。
    resultFile = string(getenv('KSSOLV_PREWARM_RESULT'));
    if strlength(resultFile) > 0
        result = struct('status', 'ready', ...
            'nonce', getenv('KSSOLV_PREWARM_NONCE'), ...
            'elapsedSeconds', toc(startupTimer));
        temporaryFile = resultFile + ".tmp";
        writelines(jsonencode(result), temporaryFile, Encoding="UTF-8");
        [moved, detail] = movefile(temporaryFile, resultFile, 'f');
        if ~moved
            error('KSSOLV:Startup:PrewarmResultFailed', '%s', detail);
        end
    end
end
end
