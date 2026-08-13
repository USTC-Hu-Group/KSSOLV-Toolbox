function plan = buildfile
%BUILDFILE 根据任务函数构建编译计划并执行编译

% 开发者：杨柳
% 版权 2025-2026 合肥瀚海量子科技有限公司

import matlab.buildtool.tasks.CodeIssuesTask

plan = buildplan(localfunctions);
toolboxFolder = fileparts(mfilename('fullpath'));
stagingFolder = fullfile(toolboxFolder, ".buildtool", "staging");
validationFolder = fullfile(toolboxFolder, ".buildtool", "validation");

sourceFiles = plan.files("**/*.m");
coreFolder = string(filesep) + fullfile("+kssolv", "+core") + string(filesep);
releaseFolder = string(filesep) + "Release" + string(filesep);
sourceFiles = sourceFiles.select(@(path) ...
    ~contains(path, coreFolder) & ~contains(path, releaseFolder));
plan("check") = CodeIssuesTask(sourceFiles, WarningThreshold = 0, ...
    Results = ".buildtool/code-issues/results.sarif");
plan("check").Dependencies = "init";

packagedSources = plan.files("+kssolv/**/*.m");
packagedSources = packagedSources.select(@shouldPcodeSource);
plan("pcode").Inputs = packagedSources;
stagedPcodeFiles = stagingPaths(packagedSources.paths, ...
    toolboxFolder, stagingFolder);
stagedPcodeFiles = replaceFileExtension(stagedPcodeFiles, ".p");
plan("pcode").Outputs = plan.files(stagedPcodeFiles);
plan("pcode").Dependencies = "check";

packagingAssets = getPackagingAssetFiles(toolboxFolder);
stagedAssets = stagingPaths(packagingAssets, toolboxFolder, stagingFolder);
plan("stage").Inputs = plan.files(packagingAssets);
plan("stage").Outputs = plan.files(stagedAssets);
plan("stage").Dependencies = "check";

outputFileName = sprintf('KSSOLV_Toolbox_V%s.mltbx', ...
    KSSOLV_Toolbox.Version);
outputFile = fullfile(toolboxFolder, "Release", outputFileName);
plan("package").Inputs = plan.files([stagedPcodeFiles; stagedAssets]);
plan("package").Outputs = plan.files(outputFile);
plan("package").Dependencies = ["pcode", "stage"];

validationStamp = fullfile(validationFolder, outputFileName + ".ok");
plan("validate").Inputs = plan("package").Outputs;
plan("validate").Outputs = plan.files(validationStamp);
plan("validate").Dependencies = "package";

plan.DefaultTasks = "validate";

plan("stats").Inputs = "**/*.m";
plan("stats").Dependencies = "init";
end

function initTask(~)
% 初始化
try
    rmdir('build', 's');
catch
end
end

function pcodeTask(context)
% 增量生成 P-Code，并将输出持久化到 staging 目录。
toolboxFolder = fileparts(mfilename('fullpath'));
stagingFolder = fullfile(toolboxFolder, ".buildtool", "staging");
cacheFolder = fullfile(toolboxFolder, ".buildtool", "pcode-cache");
sourceCacheFolder = fullfile(cacheFolder, "sources");
versionFile = fullfile(cacheFolder, "version.txt");
cacheVersion = "R2022a-v1";

inputPaths = context.Task.Inputs.paths;
sourcePaths = string(inputPaths(:));
pcodePaths = replaceFileExtension(stagingPaths( ...
    sourcePaths, toolboxFolder, stagingFolder), ".p");
cachedSources = stagingPaths(sourcePaths, toolboxFolder, sourceCacheFolder);

forceRebuild = ~isfile(versionFile) || ...
    string(strtrim(readTextFile(versionFile))) ~= cacheVersion;
needsPcode = forceRebuild | ~isfile(pcodePaths);
for index = find(~needsPcode).'
    needsPcode(index) = ~filesHaveSameContents( ...
        sourcePaths(index), cachedSources(index));
end

temporarySources = replaceFileExtension(pcodePaths(needsPcode), ".m");
cleanup = onCleanup(@() deleteExistingFiles(temporarySources));
changedSources = sourcePaths(needsPcode);
changedCacheFiles = cachedSources(needsPcode);
for index = 1:numel(changedSources)
    ensureParentFolder(temporarySources(index));
    copyfile(changedSources(index), temporarySources(index), "f");
end

if ~isempty(temporarySources)
    temporarySourceCells = cellstr(temporarySources);
    pcode(temporarySourceCells{:}, "-inplace", "-R2022a");
    for index = 1:numel(changedSources)
        ensureParentFolder(changedCacheFiles(index));
        copyfile(changedSources(index), changedCacheFiles(index), "f");
    end
end

ensureParentFolder(versionFile);
writelines(cacheVersion, versionFile);
deleteOrphanedFiles(fullfile(stagingFolder, "+kssolv"), ...
    "*.p", pcodePaths);
deleteOrphanedFiles(fullfile(sourceCacheFolder, "+kssolv"), ...
    "*.m", cachedSources);
clear cleanup
end

function stageTask(context)
% 将非 P-Code 发布资源增量复制到 staging 目录。
toolboxFolder = fileparts(mfilename('fullpath'));
stagingFolder = fullfile(toolboxFolder, ".buildtool", "staging");
manifestFile = fullfile(toolboxFolder, ".buildtool", ...
    "package-cache", "assets.txt");
inputPaths = context.Task.Inputs.paths;
sourcePaths = string(inputPaths(:));
outputPaths = stagingPaths(sourcePaths, toolboxFolder, stagingFolder);

for index = 1:numel(sourcePaths)
    if ~filesHaveSameContents(sourcePaths(index), outputPaths(index))
        ensureParentFolder(outputPaths(index));
        copyfile(sourcePaths(index), outputPaths(index), "f");
    end
end

if isfile(manifestFile)
    previousOutputs = string(readlines(manifestFile));
    removedOutputs = setdiff(previousOutputs, outputPaths);
    deleteExistingFiles(removedOutputs);
end
ensureParentFolder(manifestFile);
writelines(outputPaths, manifestFile);
end

function packageTask(context)
% 将 KSSOLV Toolbox 打包为 .mltbx 文件
toolboxFolder = fileparts(mfilename('fullpath'));
stagingFolder = fullfile(toolboxFolder, ".buildtool", "staging");
inputPaths = context.Task.Inputs.paths;
toolboxFiles = string(inputPaths(:));
outputPaths = context.Task.Outputs.paths;

options = matlab.addons.toolbox.ToolboxOptions( ...
    stagingFolder, KSSOLV_Toolbox.Identifier, ...
    ToolboxFiles = toolboxFiles, ...
    ToolboxMatlabPath = stagingFolder);
options.AuthorName = KSSOLV_Toolbox.Author;
options.AuthorEmail = KSSOLV_Toolbox.AuthorEmail;
options.AuthorCompany = KSSOLV_Toolbox.AuthorCompany;
options.Description = KSSOLV_Toolbox.Description;
options.Summary = KSSOLV_Toolbox.Summary;

options.OutputFile = outputPaths{1};
options.ToolboxName = KSSOLV_Toolbox.Name;
options.ToolboxVersion = KSSOLV_Toolbox.Version;
options.ToolboxImageFile = fullfile(stagingFolder, "+kssolv", ...
    "+ui", "resources", "icons", "companyLOGO.png");
options.AppGalleryFiles = fullfile(stagingFolder, "kssolv.m");
options.SupportedPlatforms.Win64 = true;
options.SupportedPlatforms.Mac = true;
options.SupportedPlatforms.Glnxa64 = true;
options.SupportedPlatforms.MatlabOnline = true;
options.MinimumMatlabRelease = KSSOLV_Toolbox.MinimumMATLABVersion;
options.MaximumMatlabRelease = "";
matlab.addons.toolbox.packageToolbox(options);
end

function validateTask(context)
% 仅在 Toolbox 归档变化后重新执行完整解压校验。
toolboxFolder = fileparts(mfilename('fullpath'));
inputPaths = context.Task.Inputs.paths;
outputPaths = context.Task.Outputs.paths;
validateToolboxArchive(inputPaths{1}, toolboxFolder);
stampFile = outputPaths{1};
ensureParentFolder(stampFile);
writelines("validated", stampFile);
end

function cleanTask(~)
% 删除可再生的增量构建缓存；保留 Release 中的发布包。
toolboxFolder = fileparts(mfilename('fullpath'));
buildFolders = [ ...
    fullfile(toolboxFolder, ".buildtool", "staging")
    fullfile(toolboxFolder, ".buildtool", "pcode-cache")
    fullfile(toolboxFolder, ".buildtool", "package-cache")
    fullfile(toolboxFolder, ".buildtool", "validation")
    ];
for folder = buildFolders.'
    if isfolder(folder)
        rmdir(folder, "s");
    end
end
end

function statsTask(context)
% 统计所有 .m 文件的数量和总代码行数（非空行和非注释行）
filePaths = context.Task.Inputs.paths;
filePaths = filePaths(~contains(filePaths, filesep + "+core" + filesep));
numFiles = numel(filePaths);
totalLines = 0;
codeLines = 0;

for i = 1:numFiles
    fileContent = fileread(filePaths{i});
    lines = strsplit(fileContent, '\n');
    totalLines = totalLines + numel(lines);
    for j = 1:numel(lines)
        line = strtrim(lines{j});
        if ~isempty(line) && ~startsWith(line, '%')
            codeLines = codeLines + 1;
        end
    end
end

fprintf('Total number of .m files: %d\n', numFiles);
fprintf('Total lines of code: %d\n', totalLines);
fprintf('Total non-empty, non-comment lines of code: %d\n', codeLines);
end

function selected = shouldPcodeSource(path)
% 不为任何测试目录生成 P-Code。
normalizedPath = replace(string(path), "\", "/");
isTest = hasPackagingPathSegment(normalizedPath, ...
    ["+test", "+tests", "test", "tests"]) | ...
    hasPackagingTestFileName(normalizedPath);
selected = ~isTest;
end

function relativePaths = packagingRelativePaths(paths, toolboxFolder)
normalizedPaths = replace(string(paths), "\", "/");
normalizedRoot = strip(replace(string(toolboxFolder), "\", "/"), ...
    'right', '/');
prefix = normalizedRoot + "/";
relativePaths = normalizedPaths;
insideRoot = startsWith(normalizedPaths, prefix);
relativePaths(insideRoot) = extractAfter( ...
    normalizedPaths(insideRoot), strlength(prefix));
end

function matches = hasPackagingPathSegment(paths, segments)
normalizedPaths = "/" + strip(replace(string(paths), "\", "/"), ...
    'both', '/') + "/";
matches = false(size(normalizedPaths));
for segment = string(segments)
    matches = matches | contains(normalizedPaths, "/" + segment + "/");
end
end

function matches = hasPackagingTestFileName(paths)
[~, baseNames] = fileparts(string(paths));
baseNames = lower(baseNames);
matches = startsWith(baseNames, "test_") | ...
    endsWith(baseNames, ["_test", "test", "tests"]);
end

function assetFiles = getPackagingAssetFiles(toolboxFolder)
% 解析发布资源一次，供 stage 任务声明精确的输入和输出。
rootEntries = dir(toolboxFolder);
rootEntries = rootEntries(~ismember(string({rootEntries.name}), [".", ".."]));
excludedDirectories = [ ...
    ".buildtool", ".claude", ".git", "Release", "derived", ...
    "dev", "examples", "frontend", "output", "resources", ...
    "scripts", "tmp", "fmt"];
includedDirectories = rootEntries([rootEntries.isdir] & ...
    ~ismember(string({rootEntries.name}), excludedDirectories));
rootFiles = rootEntries(~[rootEntries.isdir]);
toolboxFiles = string(fullfile({rootFiles.folder}, {rootFiles.name}));
for directoryIndex = 1:numel(includedDirectories)
    directory = includedDirectories(directoryIndex);
    entries = dir(fullfile(directory.folder, directory.name, "**", "*"));
    entries = entries(~[entries.isdir]);
    entryFiles = string(fullfile({entries.folder}, {entries.name}));
    toolboxFiles = [toolboxFiles(:); entryFiles(:)];
end
relativeFiles = packagingRelativePaths(toolboxFiles, toolboxFolder);
isTest = hasPackagingPathSegment(relativeFiles, ...
    ["+test", "+tests", "test", "tests"]) | ...
    hasPackagingTestFileName(relativeFiles);
excludedPath = hasPackagingPathSegment(relativeFiles, [ ...
    "node_modules", ".vite", "coverage", "__pycache__", "doc"]) | ...
    (startsWith(relativeFiles, "+kssolv/") & ...
    hasPackagingPathSegment(relativeFiles, "docs"));
excludedFile = ismember(relativeFiles, [ ...
    ".env", "fmt", "buildfile.m", "buildInstaller.m", ...
    "package.ignore"]) | ...
    endsWith(relativeFiles, [ ...
    ".mltbx", ".DS_Store", ".keep", ".gitignore", ".gitattributes", ...
    ".asv", ".m~", ".swp", ".pyc", ".pyo", ".prj", ".prj.bak"]);
excludedFile = excludedFile | ...
    (endsWith(relativeFiles, ".ks") & relativeFiles ~= "ks.ks") | ...
    contains("/" + relativeFiles, "/.git");
isProtectedCode = startsWith(relativeFiles, "+kssolv/") & ...
    endsWith(relativeFiles, [".m", ".p"]);
filteredConditions = ~excludedPath & ~excludedFile & ...
    ~isTest & ~isProtectedCode;
assetFiles = toolboxFiles(filteredConditions);

requiredToolboxFiles = [ ...
    fullfile(toolboxFolder, ".env.example")
    fullfile(toolboxFolder, "ks.ks")
    fullfile(toolboxFolder, "docs", "README.md")
    fullfile(toolboxFolder, "docs", "usage", "start.md")
    fullfile(toolboxFolder, "docs", "modeling-user-guide.zh-CN.md")
    fullfile(toolboxFolder, "docs", "modeling-api.md")
    fullfile(toolboxFolder, "docs", "volume-viewer-user-guide.zh-CN.md")
    fullfile(toolboxFolder, "docs", "images", "modeling-shortcuts.svg")
    ];
missingFiles = requiredToolboxFiles(~isfile(requiredToolboxFiles));
if ~isempty(missingFiles)
    error('KSSOLV:Build:RequiredToolboxFileMissing', ...
        'Required Toolbox files were not found:\n%s', ...
        char(join(missingFiles, newline)));
end
assetFiles = unique([ ...
    string(assetFiles(:)); ...
    requiredToolboxFiles; ...
    getToolboxKssolv3oFiles(toolboxFolder)], 'stable');
end

function outputPaths = stagingPaths(inputPaths, toolboxFolder, stagingFolder)
relativePaths = packagingRelativePaths(inputPaths, toolboxFolder);
outputPaths = fullfile(stagingFolder, relativePaths);
outputPaths = string(outputPaths(:));
end

function outputPaths = replaceFileExtension(inputPaths, extension)
[folders, names] = fileparts(string(inputPaths));
outputPaths = fullfile(folders, names + extension);
outputPaths = string(outputPaths(:));
end

function same = filesHaveSameContents(firstFile, secondFile)
if ~isfile(firstFile) || ~isfile(secondFile)
    same = false;
    return
end
firstInfo = dir(firstFile);
secondInfo = dir(secondFile);
if firstInfo.bytes ~= secondInfo.bytes
    same = false;
    return
end
firstId = fopen(firstFile, "rb");
if firstId < 0
    error('KSSOLV:Build:FileOpenFailed', ...
        'Unable to open file: %s', firstFile);
end
firstCleanup = onCleanup(@() fclose(firstId));
secondId = fopen(secondFile, "rb");
if secondId < 0
    error('KSSOLV:Build:FileOpenFailed', ...
        'Unable to open file: %s', secondFile);
end
secondCleanup = onCleanup(@() fclose(secondId));
firstBytes = fread(firstId, Inf, "*uint8");
secondBytes = fread(secondId, Inf, "*uint8");
same = isequal(firstBytes, secondBytes);
clear firstCleanup secondCleanup
end

function text = readTextFile(filePath)
fileId = fopen(filePath, "r");
if fileId < 0
    error('KSSOLV:Build:FileOpenFailed', ...
        'Unable to open file: %s', filePath);
end
cleanup = onCleanup(@() fclose(fileId));
text = fread(fileId, Inf, "*char").';
clear cleanup
end

function ensureParentFolder(filePath)
parentFolder = fileparts(string(filePath));
if ~isfolder(parentFolder)
    [created, detail] = mkdir(parentFolder);
    if ~created
        error('KSSOLV:Build:DirectoryCreationFailed', ...
            'Unable to create directory %s: %s', parentFolder, detail);
    end
end
end

function deleteExistingFiles(filePaths)
for filePath = string(filePaths(:)).'
    if isfile(filePath)
        delete(filePath);
    end
end
end

function deleteOrphanedFiles(rootFolder, pattern, expectedFiles)
if ~isfolder(rootFolder)
    return
end
entries = dir(fullfile(rootFolder, "**", pattern));
entries = entries(~[entries.isdir]);
existingFiles = string(fullfile({entries.folder}, {entries.name}));
orphanedFiles = setdiff(existingFiles, string(expectedFiles));
deleteExistingFiles(orphanedFiles);
end

function runtimeFiles = getToolboxKssolv3oFiles(toolboxFolder)
% 发布 KSSOLV-3o 的非测试运行时文件。
runtimeRoot = string(fullfile(toolboxFolder, ...
    "+kssolv", "+core", "kssolv-3o"));
entries = dir(fullfile(runtimeRoot, "**", "*"));
entries = entries(~[entries.isdir]);
runtimeFiles = string(fullfile({entries.folder}, {entries.name}));
relativeFiles = extractAfter(runtimeFiles, runtimeRoot + filesep);
isTest = hasPackagingPathSegment(relativeFiles, ...
    ["+test", "+tests", "test", "tests"]) | ...
    hasPackagingTestFileName(relativeFiles);
isSource = endsWith(runtimeFiles, ".m");
isDevelopmentFile = endsWith(runtimeFiles, [ ...
    filesep + ".DS_Store", ".asv", ".m~", ".swp"]);
isVersionControlMetadata = ismember(string({entries.name}), ...
    [".git", ".gitignore", ".gitattributes"]);
runtimeFiles = runtimeFiles(~isTest & ~isSource & ~isDevelopmentFile & ...
    ~isVersionControlMetadata);
runtimeFiles = runtimeFiles(:);
end

function validateToolboxArchive(archivePath, toolboxFolder)
% 验证最终 Toolbox，而不是只验证构建前候选列表。
extractRoot = tempname;
[created, detail] = mkdir(extractRoot);
if ~created
    error('KSSOLV:Build:ToolboxValidationDirectoryFailed', ...
        'Unable to create Toolbox validation directory: %s', detail);
end
cleanup = onCleanup(@() rmdir(extractRoot, 's'));
unzip(archivePath, extractRoot);

entries = dir(fullfile(extractRoot, "**", "*"));
entries = entries(~[entries.isdir]);
files = string(fullfile({entries.folder}, {entries.name}));
normalizedFiles = replace(files, "\", "/");
% Toolbox archives percent-encode path characters such as "!".
normalizedFiles = replace(normalizedFiles, "%21", "!");
isTest = hasPackagingPathSegment(normalizedFiles, ...
    ["+test", "+tests", "test", "tests"]) | ...
    hasPackagingTestFileName(normalizedFiles);
unexpectedTests = normalizedFiles(isTest);
if ~isempty(unexpectedTests)
    error('KSSOLV:Build:UnexpectedToolboxTests', ...
        'Toolbox contains test files:\n%s', ...
        char(join(unexpectedTests, newline)));
end

requiredSuffixes = [ ...
    "/fsroot/.env.example"
    "/fsroot/ks.ks"
    "/fsroot/+kssolv/+core/kssolv-3o/ppdata/default/PBE-1.3"
    "/fsroot/+kssolv/+analysis/+matgenlab/+core/+data/periodic_table.json"
    "/fsroot/+kssolv/+analysis/+matgenlab/+analysis/+compatibility/data/MITCompatibility.yaml"
    ];
for suffix = requiredSuffixes
    if ~any(endsWith(normalizedFiles, suffix) | ...
            contains(normalizedFiles, suffix + "/"))
        error('KSSOLV:Build:RequiredToolboxPayloadMissing', ...
            'Required Toolbox payload is missing: %s', suffix);
    end
end

kssolvRuntimeFiles = getToolboxKssolv3oFiles(toolboxFolder);
relativeRuntimeFiles = packagingRelativePaths( ...
    kssolvRuntimeFiles, toolboxFolder);
for relativeFile = relativeRuntimeFiles(:).'
    suffix = "/fsroot/" + replace(relativeFile, "\", "/");
    if ~any(endsWith(normalizedFiles, suffix))
        error('KSSOLV:Build:KssolvRuntimeFileMissing', ...
            'Toolbox is missing KSSOLV-3o file: %s', relativeFile);
    end
end
clear cleanup
end
