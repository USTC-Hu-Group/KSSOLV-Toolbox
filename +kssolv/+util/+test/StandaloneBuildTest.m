classdef StandaloneBuildTest < matlab.unittest.TestCase
    methods (Test)
        function disablesJvmOnEveryTarget(testCase)
            options = buildOptions();
            for platform = ["win64", "maca64", "maci64", "glnxa64"]
                values = string(kssolv.util.StandaloneBuild.command(options, platform));
                runtimeFlags = find(values == "-R");
                testCase.verifyEqual(values(runtimeFlags+1), "-nojvm");
                target = values(find(values == "-W")+1);
                if platform == "win64"
                    testCase.verifyEqual(target, "WinMain:sample,version=1.2.3");
                else
                    testCase.verifyEqual(target, "main:sample,version=1.2.3");
                end
                testCase.verifyEqual(values(find(values == "-a")+1), ...
                    ["data with spaces", "second.json"]);
                testCase.verifyFalse(any(values == "-n"));
            end
        end

        function includesPlatformRuntimeFiles(testCase)
            options = buildOptions();
            testCase.verifyEqual(kssolv.util.StandaloneBuild.outputFiles(options, "win64"), ...
                fullfile(string(options.OutputDir), ["sample.exe", "splash.png", "readme.txt"]));
            testCase.verifyEqual(kssolv.util.StandaloneBuild.outputFiles(options, "maca64"), ...
                fullfile(string(options.OutputDir), ["sample.app", "run_sample.sh", "readme.txt"]));
            options.EmbedArchive = false;
            testCase.verifyEqual(kssolv.util.StandaloneBuild.outputFiles(options, "glnxa64"), ...
                fullfile(string(options.OutputDir), ["sample", "run_sample.sh", "readme.txt", "sample.ctf"]));
            values = string(kssolv.util.StandaloneBuild.command(options, "glnxa64"));
            testCase.verifyTrue(any(values == "-C"));
        end

        function buildDispatchPreservesRuntimePolicy(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            mockFolder = fullfile(folder, 'compiler'); mkdir(mockFolder);
            % Exercise resource processing and dispatch without compiling a payload.
            writelines([
                "function mcc(varargin)"
                "values = string(varargin);"
                "out = values(find(values == ""-d"", 1)+1);"
                "name = values(find(values == ""-o"", 1)+1);"
                "save(fullfile(out, 'compiler-arguments.mat'), 'values');"
                "if ismac"
                "    mkdir(fullfile(out, name + "".app"", 'Contents', 'Resources'));"
                "elseif ispc"
                "    writelines('', fullfile(out, name + "".exe""));"
                "else"
                "    writelines('', fullfile(out, name));"
                "end"
                "if isunix, writelines('', fullfile(out, ""run_"" + name + "".sh"")); end"
                "writelines('', fullfile(out, 'readme.txt'));"
                "writelines('{}', fullfile(out, 'buildresult.json'));"
                "end"
                ], fullfile(mockFolder, 'mcc.m'));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(mockFolder));
            root = KSSOLV_Toolbox.RootDirectory;
            options = compiler.build.StandaloneApplicationOptions(fullfile(root, 'kssolvStart.m'));
            options.OutputDir = fullfile(folder, 'build with spaces');
            options.ExecutableName = 'sample';
            options.TreatInputsAsNumeric = false;
            options.ExecutableIcon = fullfile(root, '+kssolv', '+ui', 'resources', 'icons', 'companyLOGO.png');
            [files, manifest] = kssolv.util.StandaloneBuild.build(options);
            captured = load(fullfile(options.OutputDir, 'compiler-arguments.mat'));
            values = captured.values;
            testCase.verifyEqual(values(find(values == "-R")+1), "-nojvm");
            testCase.verifyEqual(values(end), string(options.AppFile));
            testCase.verifyTrue(all(isfile(files) | isfolder(files)));
            testCase.verifyTrue(isfile(manifest));
            if ismac
                testCase.verifyTrue(isfile(fullfile(options.OutputDir, ...
                    'sample.app', 'Contents', 'Resources', 'membrane.icns')));
            end
        end
    end
end

function options = buildOptions()
options = struct('ExecutableName', 'sample', 'ExecutableVersion', '1.2.3', ...
    'OutputDir', fullfile(tempdir, 'sample build'), ...
    'Verbose', true, 'EmbedArchive', true, 'AutoDetectDataFiles', true, ...
    'TreatInputsAsNumeric', false, 'ObfuscateArchive', false, ...
    'AdditionalFiles', {{'data with spaces', 'second.json'}});
end
