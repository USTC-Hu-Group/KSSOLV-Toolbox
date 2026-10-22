classdef DocumentationTest < matlab.unittest.TestCase
    methods (Test)
        function localeSelectsTheBundledPdf(testCase)
            for locale = ["zh_CN", "zh-CN", "zh_TW"]
                path = kssolv.ui.features.documentation.manualPath(locale);
                testCase.verifyTrue(endsWith(path, '_zh-CN.pdf'));
                testCase.verifyTrue(isfile(path));
            end
            for locale = ["en_US", "en-GB", "fr_FR", ""]
                path = kssolv.ui.features.documentation.manualPath(locale);
                testCase.verifyTrue(endsWith(path, '_en.pdf'));
                testCase.verifyTrue(isfile(path));
            end
        end

        function activeLocaleIsUsedForTheDefaultPath(testCase)
            localizer = kssolv.ui.util.Localizer.getInstance();
            previous = localizer.currentLocale;
            cleanup = onCleanup(@()kssolv.ui.util.Localizer.setLocale(previous));
            kssolv.ui.util.Localizer.setLocale('zh_CN');
            testCase.verifyTrue(endsWith( ...
                kssolv.ui.features.documentation.manualPath(), '_zh-CN.pdf'));
            kssolv.ui.util.Localizer.setLocale('en_US');
            testCase.verifyTrue(endsWith( ...
                kssolv.ui.features.documentation.manualPath(), '_en.pdf'));
        end

        function desktopDispatchUsesTheSystemDefaultApplication(testCase)
            testCase.assumeTrue(ismac || isunix);
            previous = getenv('KSSOLV_ONLINE');
            cleanup = onCleanup(@()setenv('KSSOLV_ONLINE', previous));
            setenv('KSSOLV_ONLINE', 'false');
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            writelines(["function [status, output] = system(command)"; ...
                "setappdata(0, 'KSSOLVManualOpenCommand', command);"; ...
                "status = 0; output = '';"; "end"], fullfile(folder, 'system.m'));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
            testCase.addTeardown(@()rmappdata(0, 'KSSOLVManualOpenCommand'));
            localizer = kssolv.ui.util.Localizer.getInstance();
            previousLocale = localizer.currentLocale;
            testCase.addTeardown(@()kssolv.ui.util.Localizer.setLocale(previousLocale));
            for locale = ["zh_CN", "en_US"]
                kssolv.ui.util.Localizer.setLocale(locale);
                kssolv.ui.features.documentation.openManual();
                command = string(getappdata(0, 'KSSOLVManualOpenCommand'));
                testCase.verifySubstring(command, ...
                    kssolv.ui.features.documentation.manualPath(locale));
                testCase.verifyTrue(startsWith(command, ["open ", "xdg-open "]));
            end
        end

        function onlineNeverLaunchesAServerPdfViewer(testCase)
            previous = getenv('KSSOLV_ONLINE');
            cleanup = onCleanup(@()setenv('KSSOLV_ONLINE', previous));
            setenv('KSSOLV_ONLINE', 'true');
            testCase.verifyWarningFree(@()kssolv.ui.features.documentation.openManual());
        end

        function standaloneManifestContainsOnlyFinishedUserDocumentation(testCase)
            files = kssolv.util.StandaloneBuild.documentationFiles(KSSOLV_Toolbox.RootDirectory);
            normalized = replace(files, '\', '/');
            for locale = ["en_US", "zh_CN"]
                testCase.verifyTrue(any(files == kssolv.ui.features.documentation.manualPath(locale)));
            end
            testCase.verifyFalse(any(contains(normalized, ...
                ["/manual-research/", "/manual-zh/", "/presentations/", "/review/"])));
            testCase.verifyFalse(any(endsWith(normalized, [".tex", ".py", ".aux", ".log"])));
            testCase.verifyTrue(all(isfile(files)));
        end
    end
end
