function buildInstaller(runtimeDelivery)
%BUILDINSTALLER 编译 KSSOLV Toolbox 为独立应用程序，并生成安装包

% 开发者：杨柳
% 版权 2025-2026 合肥瀚海量子科技有限公司

arguments
    runtimeDelivery {mustBeMember(runtimeDelivery, ["web", "installer", "none"])} = "web"
end

% 编译仅支持使用公开 OpenAI-compatible API 的 4.9.0 及以上版本。
if ~kssolv.services.llm.isLLMWithMATLABAddonAvailable
    error('KSSOLV:Deployment:UnsupportedLLMAddon', ...
        'Before compiling, install and enable %s version %s or later.', ...
        kssolv.services.llm.Addon.Name, ...
        kssolv.services.llm.Addon.MinimumVersion);
end

% 设定代码依赖自动推断无法正确判断的、必须要包含的文件夹
toolboxFolder = fileparts(mfilename('fullpath'));
kssolv3Home = fullfile(toolboxFolder, "+kssolv", "+core", "kssolv-3o");
additionalFiles = [fullfile(toolboxFolder, "ks.ks"), ...
    fullfile(toolboxFolder, "+kssolv", "+settings"), ...
    fullfile(toolboxFolder, "+kssolv", "+ui"), ...
    fullfile(toolboxFolder, "+kssolv", "+services"), ...
    fullfile(kssolv3Home, "+example"), ...
    fullfile(kssolv3Home, "ppdata"), ...
    fullfile(toolboxFolder, "+kssolv", "+analysis", "+seekpath", "+data")];

% 包含第三方 Add-Ons
installedAddOns = matlab.internal.addons.registry.getInstalledAddOnsMetadata;
addOnIndex = strcmp(string({installedAddOns.name}), ...
    kssolv.services.llm.Addon.Name);
if isfield(installedAddOns, 'version')
    supportedVersion = arrayfun(@(addon) ...
        kssolv.services.llm.Addon.isVersionSupported( ...
        string(addon.version)), installedAddOns);
    supportedVersion = reshape(supportedVersion, size(addOnIndex));
    addOnIndex = addOnIndex & supportedVersion;
end
if ~any(addOnIndex)
    error('KSSOLV:Deployment:LLMAddonFilesNotFound', ...
        'Unable to locate the supported LLM Add-On files for packaging.');
end
addOn = installedAddOns(find(addOnIndex, 1, 'last'));
addOnPath = string(addOn.registrationRoot);
addOnRuntimeFiles = getAddOnRuntimeFiles(addOnPath);
additionalFiles = [additionalFiles addOnRuntimeFiles];

% 设置编译属性
buildOptions = compiler.build.StandaloneApplicationOptions(fullfile(toolboxFolder, "kssolvStart.m"));
buildOptions.AdditionalFiles = additionalFiles;
buildOptions.AutoDetectDataFiles = true;
buildOptions.OutputDir = fullfile(toolboxFolder, 'Release', 'StandaloneDesktopApp', 'build');
buildOptions.ObfuscateArchive = false;
buildOptions.Verbose = true;
buildOptions.EmbedArchive = true;
buildOptions.ExecutableIcon = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, "icons", "companyLOGO.png");
buildOptions.ExecutableName = "KSSOLV_Toolbox";
buildOptions.ExecutableVersion = KSSOLV_Toolbox.Version;
buildOptions.TreatInputsAsNumeric = false;

% 编译独立应用程序
if ispc
    buildOptions.ExecutableSplashScreen = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, "icons", "companyLOGO.png");
    buildResult = compiler.build.standaloneWindowsApplication(buildOptions);
else
    buildResult = compiler.build.standaloneApplication(buildOptions);
end

% 下载 MATLAB Runtime
compiler.runtime.download;

% 设置打包属性
packageOptions = compiler.package.InstallerOptions(buildResult);
packageOptions.ApplicationName = KSSOLV_Toolbox.Name;
packageOptions.AuthorName = KSSOLV_Toolbox.Author;
packageOptions.AuthorEmail = KSSOLV_Toolbox.AuthorEmail;
packageOptions.AuthorCompany = KSSOLV_Toolbox.AuthorCompany;
packageOptions.Description = KSSOLV_Toolbox.Description;
packageOptions.Summary = KSSOLV_Toolbox.Summary;

packageOptions.Verbose = true;
packageOptions.Version = KSSOLV_Toolbox.Version;
packageOptions.RuntimeDelivery = runtimeDelivery;
packageOptions.OutputDir = fullfile(toolboxFolder, 'Release', 'StandaloneDesktopApp');
packageOptions.InstallerIcon = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, "icons", "companyLOGO.png");
packageOptions.InstallerSplash = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, "icons", "companyLOGO.png");
packageOptions.InstallerName = sprintf('KSSOLV_Toolbox_V%s', KSSOLV_Toolbox.Version);

% 删除旧的安装包
filesToDelete = dir(fullfile(packageOptions.OutputDir, [packageOptions.InstallerName, '.*']));
for k = 1:length(filesToDelete)
    fullFilePath = fullfile(filesToDelete(k).folder, filesToDelete(k).name);
    try
        if filesToDelete(k).isdir
            rmdir(fullFilePath, 's');
        else
            delete(fullFilePath);
        end
    catch ME
    end
end

% 生成独立应用程序安装包
compiler.package.installer(buildResult, "Options", packageOptions);
end

function runtimeFiles = getAddOnRuntimeFiles(addOnPath)
% 收集 Add-On 运行文件，排除测试、示例、文档和仓库开发内容。
entries = dir(fullfile(addOnPath, "**", "*"));
entries = entries(~[entries.isdir]);
allFiles = string(fullfile({entries.folder}, {entries.name}));

excludedDirectories = fullfile(addOnPath, [ ...
    "tests", ...
    "examples", ...
    "doc", ...
    ".git", ...
    ".github", ...
    ".githooks"]);
excludedFiles = fullfile(addOnPath, [ ...
    ".gitattributes", ...
    ".gitignore", ...
    "CONTRIBUTING.md", ...
    "DEVELOPMENT.md", ...
    "SECURITY.md"]);

isExcluded = ismember(allFiles, excludedFiles);
for directory = excludedDirectories
    isExcluded = isExcluded | ...
        startsWith(allFiles, directory + string(filesep));
end
runtimeFiles = allFiles(~isExcluded);

if isempty(runtimeFiles)
    error('KSSOLV:Deployment:LLMAddonFilesNotFound', ...
        'No deployable LLM Add-On files were found in: %s', addOnPath);
end
end
