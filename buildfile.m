function plan = buildfile
%BUILDFILE 根据任务函数构建编译计划并执行编译

% 开发者：杨柳
% 版权 2025 合肥瀚海量子科技有限公司

import matlab.buildtool.tasks.CodeIssuesTask

plan = buildplan(localfunctions);
plan("check") = CodeIssuesTask(WarningThreshold = Inf, ...
    Results = ".buildtool/code-issues/results.sarif");
plan("check").Dependencies = "init";

plan("pcode").Inputs = "+kssolv/**/*.m";
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

options = matlab.addons.toolbox.ToolboxOptions(toolboxFolder, KSSOLV_Toolbox.Identifier);
options.AuthorName = KSSOLV_Toolbox.Author;
options.AuthorEmail = KSSOLV_Toolbox.AuthorEmail;
options.AuthorCompany = KSSOLV_Toolbox.AuthorCompany;
options.Description = KSSOLV_Toolbox.Description;
options.Summary = KSSOLV_Toolbox.Summary;

options.OutputFile = fullfile(toolboxFolder, 'Release', outputFileName);
options.ToolboxName = KSSOLV_Toolbox.Name;
options.ToolboxVersion = KSSOLV_Toolbox.Version;
options.ToolboxImageFile = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, 'icons', 'LOGO.png');
options.AppGalleryFiles = "kssolv.m";
options.SupportedPlatforms.Win64 = true;
options.SupportedPlatforms.Maci64 = true;
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

filteredConditions = ~contains(options.ToolboxFiles, 'buildfile.m') & ...
    ~contains(options.ToolboxFiles, 'buildInstaller.m') & ...
    ~contains(options.ToolboxFiles, '+test/') & ...
    ~contains(options.ToolboxFiles, 'derived') & ...
    ~contains(options.ToolboxFiles, 'Release') & ...
    ~endsWith(options.ToolboxFiles, '.mltbx') & ...
    ~endsWith(options.ToolboxFiles, '.DS_Store') & ...
    ~endsWith(options.ToolboxFiles, '.keep') & ...
    ~endsWith(options.ToolboxFiles, '.env') & ...
    ~endsWith(options.ToolboxFiles, '.gitignore') & ...
    ~endsWith(options.ToolboxFiles, '.gitattributes') & ...
    ~(contains(options.ToolboxFiles, '+kssolv/') & endsWith(options.ToolboxFiles, '.m'));
options.ToolboxFiles = options.ToolboxFiles(filteredConditions);
% options.ToolboxFiles(end+1) = fullfile(toolboxFolder, "ks.ks");

matlab.addons.toolbox.packageToolbox(options);
end

function cleanPcodeTask(context)
% 删除生成的 .p 文件
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