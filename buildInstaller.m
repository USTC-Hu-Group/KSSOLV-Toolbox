function buildInstaller(runtimeDelivery)
%BUILDINSTALLER 编译 KSSOLV Toolbox 为独立应用程序，并生成安装包

% 开发者：杨柳
% 版权 2025 合肥瀚海量子科技有限公司

arguments
    runtimeDelivery {mustBeMember(runtimeDelivery, ["web", "installer", "none"])} = "installer"
end

% 提示安装 LLMs with MATLAB 插件
if ~kssolv.services.llm.isLLMWithMATLABAddonAvailable
    warning('KSSOLV:Deployment:MissingRequiredAddOns', ...
        "Before compiling, you need to manually install the plugins that KSSOLV Toolbox depends on.");
end

% 设定代码依赖自动推断无法正确判断的、必须要包含的文件夹
toolboxFolder = fileparts(mfilename('fullpath'));
kssolv3Home = fullfile(toolboxFolder, "+kssolv", "+core", "kssolv-3o");
processsuiteHome = fullfile(toolboxFolder, "+kssolv", "+core", "processsuite");
additionalFiles = [fullfile(toolboxFolder, "ks.ks"), ...
    fullfile(toolboxFolder, "+kssolv", "+ui"), ...
    fullfile(toolboxFolder, "+kssolv", "+services"), ...
    fullfile(kssolv3Home, "+example"), ...
    fullfile(kssolv3Home, "ppdata"), ...
    fullfile(processsuiteHome, "seekpath", "+seekpath", "+data")];

% 包含第三方 Add-Ons
installedAddOns = matlab.internal.addons.registry.getInstalledAddOnsMetadata;
addOnIndex = strcmp(string({installedAddOns.name}), "Large Language Models (LLMs) with MATLAB");
if any(addOnIndex)
    addOnPath = string(installedAddOns(addOnIndex).registrationRoot);
    additionalFiles = [additionalFiles addOnPath];
end

% 设置编译属性
buildOptions = compiler.build.StandaloneApplicationOptions(fullfile(toolboxFolder, "kssolvStart.m"));
buildOptions.AdditionalFiles = additionalFiles;
buildOptions.AutoDetectDataFiles = true;
buildOptions.OutputDir = fullfile(toolboxFolder, 'Release', 'StandaloneDesktopApp', 'build');
buildOptions.ObfuscateArchive = false;
buildOptions.Verbose = true;
buildOptions.EmbedArchive = true;
buildOptions.ExecutableIcon = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, "icons", "LOGO.png");
buildOptions.ExecutableName = "KSSOLV_Toolbox";
buildOptions.ExecutableVersion = KSSOLV_Toolbox.Version;
buildOptions.TreatInputsAsNumeric = false;

% 编译独立应用程序
buildResult = compiler.build.standaloneApplication(buildOptions);

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
packageOptions.InstallerIcon = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, "icons", "LOGO.png");
packageOptions.InstallerSplash = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, "icons", "LOGO.png");
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
