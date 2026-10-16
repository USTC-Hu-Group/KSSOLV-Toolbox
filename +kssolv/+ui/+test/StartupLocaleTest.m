classdef StartupLocaleTest < matlab.unittest.TestCase
    methods (Test)
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
