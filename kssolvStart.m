function kssolvStart(ksFile, hostInBrowser)
%KSSOLVSTART 启动 KSSOLV 图形用户界面
%
% 该函数会展示图形用户界面并阻塞主进程，直到界面关闭。
% 用于编译独立应用程序时作为程序的主入口，以保持界面的持续显示。

% 开发者：杨柳
% 版权 2024-2026 合肥瀚海量子科技有限公司

arguments
    ksFile string = ""
    hostInBrowser (1, 1) logical = kssolv.settings.Environment.hostInBrowser()
end

if isdeployed
    % 在正常启动或预热创建界面之前，为独立程序会话统一设置原生浅色主题。
    runtimeSettings = settings;
    runtimeSettings.matlab.appearance.MATLABTheme.TemporaryValue = 'Light';
end

if ksFile == "--prewarm"
    if isdeployed
        setenv('KSSOLV_STARTUP_SIGNAL', '');
        setenv('KSSOLV_STARTUP_NONCE', '');
    end
    kssolvPrewarm();
    return
end

try
    app = kssolv(ksFile, hostInBrowser);
catch exception
    if isdeployed
        try
            kssolv.ui.util.StartupSplash.fail(exception);
        catch signalException
            disp(signalException.message);
        end
        if ~isfolder(KSSOLV_Toolbox.LogsDirectory)
            mkdir(KSSOLV_Toolbox.LogsDirectory);
        end
    end
    if strlength(getenv('KSSOLV_BROWSER_SESSION_FILE')) > 0
        % The container supervisor must see startup failure as a process failure.
        rethrow(exception);
    end
    disp(exception.message);
    writelines(exception.message, fullfile(KSSOLV_Toolbox.LogsDirectory, "kssolvStart.log"), "WriteMode", "append");
    return
end

browserEntryPublished = false;
reconnectState = [];
restoreDocuments = false;
sessionFile = string(getenv('KSSOLV_BROWSER_SESSION_FILE'));
reconnectMonitor = [];
if isKSSOLVOnline() && strlength(sessionFile) > 0
    reconnectMonitor = kssolv.ui.browser.BrowserReconnectMonitor(sessionFile);
end
monitorCleanup = onCleanup(@()deleteMonitor(reconnectMonitor));
while true
    pause(0.5);
    if ~isvalid(app)
        if ~isempty(reconnectState)
            try
                app = kssolv.ui.browser.OnlineReconnectState.create(reconnectState);
                restoreDocuments = true;
            catch exception
                warning('KSSOLV:Online:ReconnectFailed', ...
                    'Interface reconstruction failed (%s); retrying.', exception.identifier);
                continue
            end
        else
        if nargout == 0
            clear app
        end

        if isdeployed
            quit("force");
        else
            return
        end
        end
    end
    reconnectPending = false;
    if ~isempty(reconnectMonitor)
        reconnectMonitor.poll();
        reconnectPending = reconnectMonitor.Pending;
    end
    if reconnectPending && browserEntryPublished
        try
            nextState = kssolv.ui.browser.OnlineReconnectState.capture(app);
            if restoreDocuments
                % Another client can leave while restoration is waiting for
                % its first document. Retain tabs not yet recreated as well.
                nextState.Documents = unique([reconnectState.Documents(:); ...
                    nextState.Documents(:)], 'stable').';
                nextState.Selected = reconnectState.Selected;
            end
            reconnectState = nextState;
            reconnectMonitor.disarm();
            browserEntryPublished = false;
            delete(app);
            app = kssolv.ui.browser.OnlineReconnectState.create(reconnectState);
            restoreDocuments = true;
        catch exception
            warning('KSSOLV:Online:ReconnectFailed', ...
                'Interface reconstruction failed (%s); retrying.', exception.identifier);
            continue
        end
    end
    if app.processBrowserSessionRequests()
        browserEntryPublished = true;
        if ~isempty(reconnectMonitor), reconnectMonitor.arm(); end
    end
    if restoreDocuments && ...
            kssolv.ui.browser.OnlineReconnectState.restoreWhenReady(app, reconnectState)
        restoreDocuments = false;
        reconnectState = [];
    end
    if ~restoreDocuments
        app.updateBrowserStartupState();
    end
end
end

function deleteMonitor(monitor)
if ~isempty(monitor) && isvalid(monitor), delete(monitor); end
end
