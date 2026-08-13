function app = kssolv(ksFile, hostInBrowser)
%KSSOLV 运行 KSSOLV 的图形用户界面

% 开发者：杨柳
% 版权 2024-2026 合肥瀚海量子科技有限公司

arguments
    ksFile string = ""
    hostInBrowser (1, 1) logical = kssolv.settings.Environment.hostInBrowser()
end

% 清除遗留的 AppContainer、uihtml 页面和监听器，
% 以消除 HTML Source JavaScript 警告。
existingApp = kssolv.ui.util.DataStorage.getData("KSSOLVToolbox");
if isa(existingApp, "kssolv.KSSOLVToolbox") && isvalid(existingApp)
    existingContainer = existingApp.getAppContainer();
    if ~isempty(existingContainer) && isvalid(existingContainer)
        if ksFile == ""
            existingContainer.Visible = true;
            existingContainer.bringToFront();
            app = existingApp;
            return
        end
        delete(existingApp);
    end
else
    % 清理在引入单例生命周期跟踪之前创建的 AppContainer，
    % 或者是因构造过程被中断而遗留的 AppContainer。
    existingContainer = ...
        kssolv.ui.util.DataStorage.getData("AppContainer");
    if ~isempty(existingContainer) && isvalid(existingContainer)
        delete(existingContainer);
    end
    kssolv.ui.util.DataStorage.removeData("AppContainer");
    kssolv.ui.util.DataStorage.removeData("KSSOLVToolbox");
end

% 从环境变量加载 API 密钥
settings = kssolv.settings.Settings.load();
kssolv.settings.Environment.apply(settings);

% 创建项目并保存至 DataStorage
import kssolv.services.filemanager.Project

if ksFile == ""
    project = Project();
else
    kssolv.ui.util.DataStorage.setData('LoadingKsFile', true);

    ksFile = fullfile(pwd, ksFile);
    project = Project.loadKsFile(ksFile);
end
kssolv.ui.util.DataStorage.setData('Project', project);
kssolv.ui.util.DataStorage.setData('ProjectFilename', ksFile);
kssolv.ui.util.DataStorage.setData('LoadingKsFile', false);

% 添加文件夹到 MATLAB 搜索路径
try
    addpath(fullfile(KSSOLV_Toolbox.RootDirectory, '+kssolv', '+core', 'kssolv-3o'));
    evalc('KSSOLV.startup()');
catch
end

% 初始化图形用户界面
app = kssolv.KSSOLVToolbox();
app.HostInBrowser = hostInBrowser;
kssolv.ui.util.DataStorage.setData("KSSOLVToolbox", app);

% 展示图形用户界面
try
    app.show();
catch exception
    delete(app);
    rethrow(exception);
end
end
