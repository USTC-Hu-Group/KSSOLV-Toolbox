classdef StandaloneBuild
    %STANDALONEBUILD Build standalone applications with the JVM disabled.
    methods (Static)
        function files = documentationFiles(toolboxFolder)
            % Ship user-facing guides and finished PDFs, never authoring trees.
            docs = fullfile(toolboxFolder, 'docs');
            entries = [dir(fullfile(docs, '*.md')); ...
                dir(fullfile(docs, 'usage', '*.md')); ...
                dir(fullfile(docs, 'images', '*')); ...
                dir(fullfile(docs, 'manuals', '*'))];
            entries = entries(~[entries.isdir]);
            files = string(fullfile({entries.folder}, {entries.name}));
            names = string({entries.name});
            excluded = ismember(names, ["manual-plan.zh-CN.md", ...
                "kssolv-mcp-skills-development-plan.zh-CN.md", ...
                "development-layout.md", ".DS_Store"]);
            files = files(~excluded);
            required = fullfile(docs, 'manuals', ...
                ["KSSOLV_Toolbox_User_Manual_zh-CN.pdf", ...
                "KSSOLV_Toolbox_User_Manual_en.pdf"]);
            if any(~isfile(required))
                error('KSSOLV:Deployment:MissingManuals', ...
                    'Both Simplified Chinese and English PDF manuals are required.');
            end
            files = unique([files, required], 'stable');
        end

        function [files, runtimeDefinition] = build(options)
            if ~isfolder(options.OutputDir), mkdir(options.OutputDir); end
            compilerArguments = kssolv.util.StandaloneBuild.command(options);
            icon = '';
            if ispc || ismac
                % Keep the temporary icon alive through compilation and copying.
                [iconCleanup, icon] = compiler.internal.build.processIcon( ...
                    options.ExecutableIcon, options.OutputDir, options.ExecutableName);
                compilerArguments = [compilerArguments, {'-r', icon}];
            end
            mcc(compilerArguments{:}, options.AppFile);
            if ismac
                copyfile(icon, fullfile(options.OutputDir, ...
                    string(options.ExecutableName) + ".app", ...
                    'Contents', 'Resources', 'membrane.icns'), 'f');
            elseif ispc
                compiler.internal.image.copy(options.ExecutableSplashScreen, ...
                    fullfile(options.OutputDir, 'splash.png'), ...
                    'PropertyName', 'ExecutableSplashScreen', 'OutputImageSize', [400 400]);
            end
            if ispc || ismac, delete(iconCleanup); end
            files = kssolv.util.StandaloneBuild.outputFiles(options);
            runtimeDefinition = fullfile(options.OutputDir, 'buildresult.json');
        end

        function runtimeFiles = applicationRuntimeFiles(toolboxFolder)
            % 动态 UI 与服务代码按文件加入，避免递归带入普通测试目录
            runtimeRoots = fullfile(toolboxFolder, "+kssolv", ...
                ["+ui", "+settings", "+services"]);
            runtimeFiles = strings(1, 0);
            for runtimeRoot = runtimeRoots
                entries = dir(fullfile(runtimeRoot, "**", "*"));
                entries = entries(~[entries.isdir]);
                files = string(fullfile({entries.folder}, {entries.name}));
                relativeFiles = extractAfter(files, runtimeRoot + filesep);
                normalized = "/" + replace(relativeFiles, "\", "/") + "/";
                isTest = false(size(relativeFiles));
                for segment = ["+test", "+tests", "test", "tests"]
                    isTest = isTest | contains(normalized, "/" + segment + "/");
                end
                testNames = kssolv.util.isTestFileName(relativeFiles);
                testNames = testNames & ~endsWith(replace(files, '\', '/'), ...
                    '/+remote/+diagnostics/RemoteLoginTest.m');
                isTest = isTest | testNames;
                isDevelopmentFile = kssolv.util.Packaging.isDevelopmentFile(files) | ...
                    endsWith(files, [ ...
                    filesep + ".DS_Store", filesep + ".gitignore", ...
                    ".asv", ".m~", ".swp"]);
                runtimeFiles = [runtimeFiles, ...
                    files(~isTest & ~isDevelopmentFile)]; %#ok<AGROW>
            end
            browserFiles = fullfile(toolboxFolder, '+kssolv', '+ui', ...
                'resources', 'browser', kssolv.ui.browser.resourceNames());
            missingFiles = browserFiles(~isfile(browserFiles));
            if ~isempty(missingFiles)
                error('KSSOLV:Deployment:MissingBrowserResources', ...
                    'Required browser resources were not found:\n%s', ...
                    char(join(missingFiles, newline)));
            end
            runtimeFiles = [runtimeFiles, browserFiles];
            % Legacy MAT files can refer to the former public HTTP class.
            runtimeFiles(end+1) = fullfile(toolboxFolder, "+kssolv", ...
                "+util", "HTTPJSONRequest.m");
            runtimeFiles = [runtimeFiles, ...
                kssolv.util.Packaging.licenseFiles(toolboxFolder).'];
            runtimeFiles = unique(runtimeFiles, "stable");
        end

        function values = command(options, platform)
            arguments
                options
                platform (1,1) string {mustBeMember(platform, ...
                    ["win64", "maca64", "maci64", "glnxa64"])} = string(computer('arch'))
            end
            target = "main";
            if platform == "win64", target = "WinMain"; end
            values = {'-W', char(target + ":" + string(options.ExecutableName) + ...
                ",version=" + string(options.ExecutableVersion)), '-T', 'link:exe', ...
                '-d', char(options.OutputDir), '-R', '-nojvm', ...
                '-o', char(options.ExecutableName)};
            if options.Verbose, values{end+1} = '-v'; end
            if ~options.EmbedArchive, values{end+1} = '-C'; end
            if ~options.AutoDetectDataFiles, values{end+1} = '-X'; end
            if options.TreatInputsAsNumeric, values{end+1} = '-n'; end
            if options.ObfuscateArchive
                error('KSSOLV:Deployment:UnsupportedObfuscation', ...
                    'Standalone builds must keep ObfuscateArchive disabled.');
            end
            for file = reshape(string(options.AdditionalFiles), 1, [])
                values = [values, {'-a', char(file)}]; %#ok<AGROW>
            end
        end

        function files = outputFiles(options, platform)
            arguments
                options
                platform (1,1) string {mustBeMember(platform, ...
                    ["win64", "maca64", "maci64", "glnxa64"])} = string(computer('arch'))
            end
            name = string(options.ExecutableName);
            if platform == "win64"
                entries = [name + ".exe", "splash.png"];
            else
                if startsWith(platform, "mac"), executable = name + ".app";
                else, executable = name; end
                entries = [executable, "run_" + name + ".sh"];
            end
            entries(end+1) = "readme.txt";
            if ~options.EmbedArchive, entries(end+1) = name + ".ctf"; end
            files = fullfile(string(options.OutputDir), entries);
        end
    end
end
