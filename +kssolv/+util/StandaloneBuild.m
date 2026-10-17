classdef StandaloneBuild
    %STANDALONEBUILD Build standalone applications with the JVM disabled.
    methods (Static)
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
                    'Contents', 'Resources', 'membrane.icns'));
            elseif ispc
                compiler.internal.image.copy(options.ExecutableSplashScreen, ...
                    fullfile(options.OutputDir, 'splash.png'), ...
                    'PropertyName', 'ExecutableSplashScreen', 'OutputImageSize', [400 400]);
            end
            if ispc || ismac, delete(iconCleanup); end
            files = kssolv.util.StandaloneBuild.outputFiles(options);
            runtimeDefinition = fullfile(options.OutputDir, 'buildresult.json');
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
