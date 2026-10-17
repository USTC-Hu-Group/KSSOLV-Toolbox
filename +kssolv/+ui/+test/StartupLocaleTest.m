classdef StartupLocaleTest < matlab.unittest.TestCase
    methods (Test)
        function resolvesAndWritesDefaultPathFromEnvironment(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            for name = ["HOME", "USERPROFILE", "APPDATA", "XDG_CONFIG_HOME"]
                testCase.applyFixture(matlab.unittest.fixtures.EnvironmentVariableFixture( ...
                    name, folder));
            end
            if ispc
                base = string(folder);
            elseif ismac
                base = fullfile(string(folder), 'Library', 'Application Support');
            else
                base = string(folder);
            end
            file = fullfile(base, 'KSSOLV Toolbox', 'startup.json');
            testCase.verifyEqual(kssolv.settings.StartupLocale.filePath(), file);
            kssolv.settings.StartupLocale.write("zh_CN");
            testCase.verifyEqual(jsondecode(fileread(file)).locale, 'zh_CN');
            if ~ispc && ~ismac
                setenv('XDG_CONFIG_HOME', '');
                testCase.verifyEqual(kssolv.settings.StartupLocale.filePath(), ...
                    fullfile(string(folder), '.config', 'KSSOLV Toolbox', 'startup.json'));
            end
        end

        function writesResolvedNonSensitiveLocale(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            file = fullfile(folder, 'startup.json');
            kssolv.settings.StartupLocale.write("zh_CN", file);
            value = jsondecode(fileread(file));
            testCase.verifyEqual(value.locale, 'zh_CN');
            testCase.verifyEqual(value.version, 1);
            testCase.verifyEqual(sort(fieldnames(value)), {'locale'; 'version'});
            kssolv.settings.StartupLocale.write("en_US", file);
            value = jsondecode(fileread(file));
            testCase.verifyEqual(value.locale, 'en_US');
            kssolv.settings.StartupLocale.write("unsupported", file);
            value = jsondecode(fileread(file));
            testCase.verifyEqual(value.locale, 'en_US');
        end
    end
end
