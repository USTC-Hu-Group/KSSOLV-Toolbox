function plan = buildfile
%BUILDFILE 根据任务函数构建编译计划并执行编译

% 开发者：杨柳
% 版权 2025-2026 合肥瀚海量子科技有限公司

import matlab.buildtool.tasks.CodeIssuesTask

plan = buildplan(localfunctions);

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
plan("pcode").Outputs = plan("pcode").Inputs.replace(".m",".p");
plan("pcode").Dependencies = "check";

plan("package").Dependencies = "pcode";

plan.DefaultTasks = "cleanPcode";
plan("cleanPcode").Inputs = plan("pcode").Outputs;
plan("cleanPcode").Dependencies = "package";

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
% 将所有 .m 结尾的工程文件加密混淆为 .p 文件
filePaths = context.Task.Inputs.paths;
pcode(filePaths{:}, "-inplace", "-R2022a");
end

function packageTask(~)
% 将 KSSOLV Toolbox 打包为 .mltbx 文件
toolboxFolder = fileparts(mfilename('fullpath'));
outputFileName = sprintf('KSSOLV_Toolbox_V%s.mltbx', KSSOLV_Toolbox.Version);

options = matlab.addons.toolbox.ToolboxOptions( ...
    toolboxFolder, KSSOLV_Toolbox.Identifier, ...
    ToolboxMatlabPath = toolboxFolder);
options.AuthorName = KSSOLV_Toolbox.Author;
options.AuthorEmail = KSSOLV_Toolbox.AuthorEmail;
options.AuthorCompany = KSSOLV_Toolbox.AuthorCompany;
options.Description = KSSOLV_Toolbox.Description;
options.Summary = KSSOLV_Toolbox.Summary;

options.OutputFile = fullfile(toolboxFolder, 'Release', outputFileName);
options.ToolboxName = KSSOLV_Toolbox.Name;
options.ToolboxVersion = KSSOLV_Toolbox.Version;
options.ToolboxImageFile = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, 'icons', 'companyLOGO.png');
options.AppGalleryFiles = "kssolv.m";
options.SupportedPlatforms.Win64 = true;
options.SupportedPlatforms.Mac = true;
options.SupportedPlatforms.Glnxa64 = true;
options.SupportedPlatforms.MatlabOnline = true;
options.MinimumMatlabRelease = KSSOLV_Toolbox.MinimumMATLABVersion;
options.MaximumMatlabRelease = "";
%{
options.RequiredAddons = struct( ...
    "Name", "Large Language Models (LLMs) with MATLAB", ...
    "Identifier", "ea932835-80d6-44d7-90e4-48fdefd221fa", ...
    "EarliestVersion", "4.4.0", ...
    "LatestVersion", "4.5.0", ...
    "DownloadURL", "https://www.mathworks.com/matlabcentral/mlc-downloads/downloads/ea932835-80d6-44d7-90e4-48fdefd221fa/ade2cad8-f069-4490-96a0-08a2605dacf6/packages/zip?src=addons_ml_desktop");
%}

toolboxFiles = string(options.ToolboxFiles(:));
relativeFiles = packagingRelativePaths(toolboxFiles, toolboxFolder);
isTest = hasPackagingPathSegment(relativeFiles, ...
    ["+test", "+tests", "test", "tests"]) | ...
    hasPackagingTestFileName(relativeFiles);
excludedRoot = startsWith(relativeFiles, [ ...
    ".buildtool/", ".claude/", "Release/", "derived/", ...
    "dev/", "frontend/", "output/", "scripts/", "tmp/"]);
excludedFile = ismember(relativeFiles, [ ...
    ".env", "fmt", "buildfile.m", "buildInstaller.m"]) | ...
    endsWith(relativeFiles, [ ...
    ".mltbx", ".DS_Store", ".keep", ".gitignore", ...
    ".gitattributes"]);
isProtectedSource = startsWith(relativeFiles, "+kssolv/") & ...
    endsWith(relativeFiles, ".m");
filteredConditions = ~excludedRoot & ~excludedFile & ...
    ~isTest & ~isProtectedSource;
options.ToolboxFiles = toolboxFiles(filteredConditions);

requiredToolboxFiles = [ ...
    fullfile(toolboxFolder, ".env.example")
    fullfile(toolboxFolder, "ks.ks")
    fullfile(toolboxFolder, "docs", "modeling-user-guide.zh-CN.md")
    fullfile(toolboxFolder, "docs", "modeling-api.md")
    fullfile(toolboxFolder, "docs", "images", "modeling-shortcuts.svg")
    ];
missingFiles = requiredToolboxFiles(~isfile(requiredToolboxFiles));
if ~isempty(missingFiles)
    error('KSSOLV:Build:RequiredToolboxFileMissing', ...
        'Required Toolbox files were not found:\n%s', ...
        char(join(missingFiles, newline)));
end
options.ToolboxFiles = unique([ ...
    string(options.ToolboxFiles(:)); ...
    requiredToolboxFiles; ...
    getToolboxKssolv3oFiles(toolboxFolder)], 'stable');

matlab.addons.toolbox.packageToolbox(options);
validateToolboxArchive(options.OutputFile, toolboxFolder);
end

function cleanPcodeTask(context)
% 删除生成的 .p 文件
% 先释放由 .p 文件定义的持久对象。否则在对应 .p 文件删除后再触发
% 析构，MATLAB 将无法解析类的 delete 方法。
registry = kssolv.ui.util.DataStorage.getData( ...
    "ModelingSessionRegistry");
if ~isempty(registry) && isvalid(registry)
    delete(registry);
end
clear registry

filePaths = context.Task.Inputs.paths;
for i = 1:length(filePaths)
    if isfile(filePaths{i})
        delete(filePaths{i});
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
