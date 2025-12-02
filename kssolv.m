function app = kssolv(ksFile, hostInBrowser)
%KSSOLV 运行 KSSOLV 的图形用户界面

% 开发者：杨柳
% 版权 2024-2025 合肥瀚海量子科技有限公司

arguments
    ksFile string = ""
    hostInBrowser (1, 1) logical = strcmpi(getenv("KSSOLV_HOST_IN_BROWSER"), 'true')
end

% 从 .env 文件中读取环境变量
envFilePath = fullfile(KSSOLV_Toolbox.RootDirectory, '.env');
if ~isdeployed && exist(envFilePath, "file")
    loadenv(envFilePath);
end

% 创建 project 并保存至 DataStorage
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
    addpath(fullfile(KSSOLV_Toolbox.RootDirectory, '+kssolv', '+services', '+llm', 'patch'));
    addpath(fullfile(KSSOLV_Toolbox.RootDirectory, '+kssolv', '+core', 'kssolv-3o'));
    addpath(fullfile(KSSOLV_Toolbox.RootDirectory, '+kssolv', '+core', 'processsuite', 'seekpath'));
    evalc('KSSOLV.startup()');
catch
end

% 初始化图形用户界面
app = kssolv.KSSOLVToolbox();
app.HostInBrowser = hostInBrowser;

% 展示图形用户界面
app.show();
end

