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
buildPathCleanup = isolateKssolvBuildPath(toolboxFolder);
[dialogFrameworkFiles, dialogFrameworkCleanup] = stageDialogFrameworkFiles(toolboxFolder);
[addOnRuntimeFiles, addOnRuntimeCleanup] = ...
    stageRequiredLLMAddonRuntimeFiles(toolboxFolder);
additionalFiles = [dialogFrameworkFiles(:).', ...
    string(fullfile(toolboxFolder, ".env.example")), ...
    string(fullfile(toolboxFolder, "ks.ks")), ...
    getApplicationRuntimeFiles(toolboxFolder), ...
    string(fullfile(toolboxFolder, "+kssolv", "+analysis", "+seekpath", "+data")), ...
    getMatgenlabRuntimeData(), ...
    getKssolvRuntimeFiles(toolboxFolder), ...
    addOnRuntimeFiles];

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
validateStandalonePayload(buildOptions.OutputDir, toolboxFolder);

% 仅在安装包需要 Runtime 时下载；none 模式不应触发数 GB 下载。
if runtimeDelivery ~= "none"
    compiler.runtime.download;
end

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
delete(addOnRuntimeCleanup)
delete(dialogFrameworkCleanup)
delete(buildPathCleanup)
end

function [runtimeFiles, cleanup] = ...
        stageRequiredLLMAddonRuntimeFiles(toolboxFolder)
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
[runtimeFiles, cleanup] = stageAddOnRuntimeFiles( ...
    addOnPath, toolboxFolder);
end

function [runtimeFiles, cleanup] = stageDialogFrameworkFiles(toolboxFolder)
% 编译器无法推断仅作为父类使用的 controllib 包类，也会过滤直接加入的 MATLAB 自带源码。
% 因此先按原包层级暂存未修改的原生对话框框架，再将其加入运行时资源。
sourceDirectory = fullfile(matlabroot, "toolbox", "shared", ...
    "controllib", "graphics", "+controllib", "+ui", "+internal", ...
    "+dialog");
if ~isfolder(sourceDirectory)
    error('KSSOLV:Deployment:DialogFrameworkNotFound', ...
        'Unable to locate the MATLAB dialog framework: %s', ...
        sourceDirectory);
end

stagingRoot = fullfile(toolboxFolder, "+controllib");
if isfolder(stagingRoot)
    error('KSSOLV:Deployment:DialogFrameworkStageConflict', ...
        'The dialog framework staging directory already exists: %s', ...
        stagingRoot);
end
destinationDirectory = fullfile(stagingRoot, "+ui", ...
    "+internal", "+dialog");
[created, detail] = mkdir(fileparts(destinationDirectory));
if ~created
    error('KSSOLV:Deployment:DialogFrameworkStageFailed', ...
        'Unable to create the dialog framework staging directory: %s', ...
        detail);
end
[copied, detail] = copyfile(sourceDirectory, destinationDirectory);
if ~copied
    rmdir(stagingRoot, 's');
    error('KSSOLV:Deployment:DialogFrameworkStageFailed', ...
        'Unable to stage the dialog framework: %s', detail);
end

runtimeFiles = string(stagingRoot);
cleanup = onCleanup(@() removeStagingDirectory(stagingRoot));
end

function removeStagingDirectory(stagingRoot)
% 删除编译期间创建的对话框框架暂存目录。
if isfolder(stagingRoot)
    rmdir(stagingRoot, 's');
end
end

function runtimeFiles = getKssolvRuntimeFiles(toolboxFolder)
% KSSOLV-3o 的非测试运行时载荷，包括示例与全部赝势数据。
runtimeRoot = string(fullfile(toolboxFolder, ...
    "+kssolv", "+core", "kssolv-3o"));
if ~isfolder(runtimeRoot)
    error('KSSOLV:Deployment:KssolvRuntimeNotFound', ...
        'KSSOLV-3o runtime directory was not found: %s', runtimeRoot);
end
entries = dir(fullfile(runtimeRoot, "**", "*"));
entries = entries(~[entries.isdir]);
runtimeFiles = string(fullfile({entries.folder}, {entries.name}));
relativeFiles = extractAfter(runtimeFiles, runtimeRoot + filesep);
isTest = hasDeploymentPathSegment(relativeFiles, ...
    ["+test", "+tests", "test", "tests"]) | ...
    hasDeploymentTestFileName(relativeFiles);
isDevelopmentEntryPoint = ismember(relativeFiles, ...
    ["buildfile.m", "startup.m"]);
isVersionControlMetadata = ismember(string({entries.name}), ...
    [".git", ".gitignore", ".gitattributes"]);
runtimeFiles = runtimeFiles(~isTest & ~isDevelopmentEntryPoint & ...
    ~isVersionControlMetadata & ...
    ~endsWith(runtimeFiles, filesep + ".DS_Store"));
runtimeFiles = reshape(runtimeFiles, 1, []);
end

function runtimeFiles = getMatgenlabRuntimeData()
% 递归包含生产代码动态加载的数据，同时排除所有测试目录和文档。
toolboxFolder = fileparts(mfilename('fullpath'));
matgenlabHome = string(fullfile(toolboxFolder, ...
    "+kssolv", "+analysis", "+matgenlab"));
entries = dir(fullfile(matgenlabHome, "**", "*"));
entries = entries(~[entries.isdir]);
allFiles = string(fullfile({entries.folder}, {entries.name}));
relativeFiles = extractAfter(allFiles, matgenlabHome + filesep);
isTest = hasDeploymentPathSegment(relativeFiles, ...
    ["+test", "+tests", "test", "tests"]) | ...
    hasDeploymentTestFileName(relativeFiles);
allowedExtensions = [ ...
    ".bz2", ".csv", ".dat", ".gz", ".h5", ".hdf5", ...
    ".json", ".lib", ".mat", ".template", ".txt", ...
    ".xml", ".yaml", ".yml"];
isRuntimeData = false(size(allFiles));
for extension = allowedExtensions
    isRuntimeData = isRuntimeData | ...
        endsWith(lower(allFiles), extension);
end
isRuntimeData = isRuntimeData | ...
    endsWith(allFiles, filesep + "OxideTersoffPotentials");
runtimeFiles = allFiles(isRuntimeData & ~isTest);

requiredFiles = [ ...
    fullfile(matgenlabHome, "+core", "+data", ...
    "periodic_table.json"), ...
    fullfile(matgenlabHome, "+analysis", "+data", ...
    "atomic_scattering_params.json"), ...
    fullfile(matgenlabHome, "+analysis", "+chemenv", ...
    "+coordination_environments", ...
    "+coordination_geometries_files", "allcg.txt"), ...
    fullfile(matgenlabHome, "+analysis", "+solar", "am1.5G.dat"), ...
    fullfile(matgenlabHome, "+command_line", "+gulp_caller", ...
    "+data", "OxideTersoffPotentials"), ...
    fullfile(matgenlabHome, "+io", "+vasp", "incar_parameters.json"), ...
    fullfile(matgenlabHome, "+io", "+vasp", ...
    "potcar-summary-stats.json.bz2"), ...
    fullfile(matgenlabHome, "+io", "+jdftx", ...
    "BaseJdftxSet.yaml"), ...
    fullfile(matgenlabHome, "+io", "+lobster", ...
    "lobster_basis", "BASIS_PBE_54_standard.yaml"), ...
    fullfile(matgenlabHome, "+io", "+lobster", "+future", ...
    "lobster_basis", "BASIS_PBE_54_standard.yaml"), ...
    fullfile(matgenlabHome, "+symmetry", "+maggroups", ...
    "magnetic_space_groups.mat"), ...
    fullfile(matgenlabHome, "+util", "structures", "Si.json"), ...
    fullfile(matgenlabHome, "+vis", "ElementColorSchemes.json")];
missingFiles = requiredFiles(~isfile(requiredFiles));
if ~isempty(missingFiles)
    error('KSSOLV:Deployment:MatgenlabRuntimeDataNotFound', ...
        'Required Matgenlab runtime resources were not found:\n%s', ...
        char(join(missingFiles, newline)));
end
runtimeFiles = unique([runtimeFiles(:); requiredFiles(:)], "stable").';
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
runtimeFiles = reshape(runtimeFiles, 1, []);

if isempty(runtimeFiles)
    error('KSSOLV:Deployment:LLMAddonFilesNotFound', ...
        'No deployable LLM Add-On files were found in: %s', addOnPath);
end
end

function runtimeFiles = getApplicationRuntimeFiles(toolboxFolder)
% 动态 UI 与服务代码按文件加入，避免递归带入普通测试目录。
runtimeRoots = fullfile(toolboxFolder, "+kssolv", ...
    ["+ui", "+settings", "+services"]);
runtimeFiles = strings(1, 0);
for runtimeRoot = runtimeRoots
    entries = dir(fullfile(runtimeRoot, "**", "*"));
    entries = entries(~[entries.isdir]);
    files = string(fullfile({entries.folder}, {entries.name}));
    relativeFiles = extractAfter(files, runtimeRoot + filesep);
    isTest = hasDeploymentPathSegment(relativeFiles, ...
        ["+test", "+tests", "test", "tests"]) | ...
        hasDeploymentTestFileName(relativeFiles);
    isDevelopmentFile = endsWith(files, [ ...
        filesep + ".DS_Store", filesep + ".gitignore", ...
        ".asv", ".m~", ".swp"]);
    runtimeFiles = [runtimeFiles, ...
        files(~isTest & ~isDevelopmentFile)]; %#ok<AGROW>
end
runtimeFiles = unique(runtimeFiles, "stable");
end

function matches = hasDeploymentPathSegment(paths, segments)
normalizedPaths = "/" + strip(replace(string(paths), "\", "/"), ...
    'both', '/') + "/";
matches = false(size(normalizedPaths));
for segment = string(segments)
    matches = matches | contains(normalizedPaths, "/" + segment + "/");
end
end

function matches = hasDeploymentTestFileName(paths)
[~, baseNames] = fileparts(string(paths));
baseNames = lower(baseNames);
matches = startsWith(baseNames, "test_") | ...
    endsWith(baseNames, ["_test", "test", "tests"]);
end

function [runtimeFiles, cleanup] = stageAddOnRuntimeFiles( ...
        addOnPath, toolboxFolder)
% 复制 Add-On 运行文件并去掉只服务于测试的友元依赖。
sourceFiles = getAddOnRuntimeFiles(addOnPath);
stagingParent = fullfile(toolboxFolder, ".buildtool", "standalone");
[created, detail] = mkdir(stagingParent);
if ~created && ~isfolder(stagingParent)
    error('KSSOLV:Deployment:LLMAddonStageFailed', ...
        'Unable to create Add-On staging directory: %s', detail);
end
stagingRoot = string(tempname(stagingParent));
[created, detail] = mkdir(stagingRoot);
if ~created
    error('KSSOLV:Deployment:LLMAddonStageFailed', ...
        'Unable to create Add-On staging directory: %s', detail);
end
originalPath = path;
cleanup = onCleanup(@() restoreStagedAddOn( ...
    originalPath, stagingRoot));

for sourceFile = sourceFiles
    relativeFile = extractAfter(sourceFile, addOnPath + filesep);
    destinationFile = fullfile(stagingRoot, relativeFile);
    destinationFolder = fileparts(destinationFile);
    if ~isfolder(destinationFolder)
        [created, detail] = mkdir(destinationFolder);
        if ~created
            removeStagingDirectory(stagingRoot);
            error('KSSOLV:Deployment:LLMAddonStageFailed', ...
                'Unable to create Add-On staging directory: %s', detail);
        end
    end
    [copied, detail] = copyfile(sourceFile, destinationFile);
    if ~copied
        removeStagingDirectory(stagingRoot);
        error('KSSOLV:Deployment:LLMAddonStageFailed', ...
            'Unable to stage Add-On file %s: %s', sourceFile, detail);
    end
end

replaceStagedText( ...
    fullfile(stagingRoot, "ollamaChat.m"), ...
    "Access=?tollamaChat", "Access=private");
replaceStagedText( ...
    fullfile(stagingRoot, "+llms", "+stream", "responseStreamer.m"), ...
    "Access=?tresponseStreamer", "Access=private");

pathEntries = string(split(originalPath, pathsep));
normalizedAddOnPath = normalizeDeploymentPath(addOnPath);
insideOriginalAddOn = startsWith( ...
    normalizeDeploymentPath(pathEntries) + "/", ...
    normalizedAddOnPath + "/");
path(char(join(pathEntries(~insideOriginalAddOn), pathsep)));
addpath(stagingRoot, '-begin');
rehash path

entries = dir(fullfile(stagingRoot, "**", "*"));
entries = entries(~[entries.isdir]);
runtimeFiles = string(fullfile({entries.folder}, {entries.name}));
runtimeFiles = reshape(runtimeFiles, 1, []);
end

function replaceStagedText(file, oldText, newText)
content = string(fileread(file));
updated = replace(content, oldText, newText);
if updated == content
    error('KSSOLV:Deployment:LLMAddonTestDependencyNotFound', ...
        'Expected test-only Add-On dependency was not found in: %s', file);
end
try
    permissions = filePermissions(file);
    setPermissions(permissions, "Writable", true);
catch ME
    error('KSSOLV:Deployment:LLMAddonStageFailed', ...
        'Unable to make staged Add-On file writable: %s (%s)', ...
        file, ME.message);
end
fileId = fopen(file, 'w', 'n', 'UTF-8');
if fileId < 0
    error('KSSOLV:Deployment:LLMAddonStageFailed', ...
        'Unable to update staged Add-On file: %s', file);
end
fileCleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, char(updated), 'char');
clear fileCleanup
end

function restoreStagedAddOn(originalPath, stagingRoot)
path(originalPath);
rehash path
removeStagingDirectory(stagingRoot);
end

function cleanup = isolateKssolvBuildPath(toolboxFolder)
% 防止本机已安装的旧 KSSOLV Add-On 污染编译依赖闭包。
originalPath = path;
definitions = string(which('KSSOLV_Toolbox', '-all'));
normalizedToolboxRoot = normalizeDeploymentPath(toolboxFolder);
alternateRoots = strings(0, 1);
for definition = definitions(:).'
    if ~startsWith(normalizeDeploymentPath(definition) + "/", ...
            normalizedToolboxRoot + "/")
        alternateRoots(end + 1, 1) = string(fileparts(definition)); %#ok<AGROW>
    end
end

pathEntries = string(split(originalPath, pathsep));
keepEntry = true(size(pathEntries));
normalizedEntries = normalizeDeploymentPath(pathEntries);
for alternateRoot = unique(alternateRoots).'
    normalizedAlternateRoot = normalizeDeploymentPath(alternateRoot);
    keepEntry = keepEntry & ~startsWith( ...
        normalizedEntries + "/", normalizedAlternateRoot + "/");
end
path(char(join(pathEntries(keepEntry), pathsep)));
rehash path

resolved = string(which('KSSOLV_Toolbox'));
if ~startsWith(normalizeDeploymentPath(resolved) + "/", ...
        normalizedToolboxRoot + "/")
    path(originalPath);
    error('KSSOLV:Deployment:WorkingTreeNotSelected', ...
        'The build did not resolve KSSOLV_Toolbox from the working tree: %s', ...
        resolved);
end
cleanup = onCleanup(@() restoreDeploymentPath(originalPath));
end

function restoreDeploymentPath(originalPath)
path(originalPath);
rehash path
end

function normalized = normalizeDeploymentPath(paths)
normalized = strip(replace(string(paths), "\", "/"), 'right', '/');
end

function validateStandalonePayload(outputDirectory, toolboxFolder)
% 验证最终独立应用的文件集合与必需运行数据。
entries = dir(fullfile(outputDirectory, "**", "*"));
entries = entries(~[entries.isdir]);
files = string(fullfile({entries.folder}, {entries.name}));
normalizedFiles = normalizeDeploymentPath(files);
isTest = hasDeploymentPathSegment(normalizedFiles, ...
    ["+test", "+tests", "test", "tests"]) | ...
    hasDeploymentTestFileName(normalizedFiles);
unexpectedTests = normalizedFiles(isTest);
if ~isempty(unexpectedTests)
    error('KSSOLV:Deployment:UnexpectedTests', ...
        'Standalone payload contains test files:\n%s', ...
        char(join(unexpectedTests, newline)));
end

installedCopy = contains(normalizedFiles, ...
    "/MATLAB Add-Ons/KSSOLV_Toolbox@");
if any(installedCopy)
    error('KSSOLV:Deployment:InstalledToolboxContamination', ...
        'Standalone payload contains files from an installed KSSOLV Toolbox:\n%s', ...
        char(join(normalizedFiles(installedCopy), newline)));
end

requiredSuffixes = [ ...
    "/.env.example"
    "/ks.ks"
    "/+kssolv/+analysis/+matgenlab/+core/+data/periodic_table.json"
    "/+kssolv/+analysis/+matgenlab/+io/+jdftx/BaseJdftxSet.yaml"
    "/+kssolv/+analysis/+matgenlab/+io/+lobster/lobster_basis/BASIS_PBE_54_standard.yaml"
    "/+kssolv/+analysis/+matgenlab/+symmetry/+maggroups/magnetic_space_groups.mat"
    ];
for suffix = requiredSuffixes
    if ~any(endsWith(normalizedFiles, suffix))
        error('KSSOLV:Deployment:RequiredPayloadMissing', ...
            'Standalone payload is missing required data: %s', suffix);
    end
end

kssolvRuntimeFiles = getKssolvRuntimeFiles(toolboxFolder);
relativeRuntimeFiles = extractAfter(kssolvRuntimeFiles, ...
    string(toolboxFolder) + filesep);
for relativeFile = relativeRuntimeFiles
    suffix = "/" + normalizeDeploymentPath(relativeFile);
    if ~any(endsWith(normalizedFiles, suffix))
        error('KSSOLV:Deployment:KssolvRuntimeFileMissing', ...
            'Standalone payload is missing KSSOLV-3o file: %s', ...
            relativeFile);
    end
end
end
