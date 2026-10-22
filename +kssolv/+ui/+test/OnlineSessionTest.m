classdef OnlineSessionTest < matlab.unittest.TestCase
    methods (Test)
        function recoveryUsesTheOnlineDataVolumeAndKeepsDesktopLocation(testCase)
            previous = getenv('KSSOLV_ONLINE');
            dataDirectory = getenv('KSSOLV_USER_DATA_DIR');
            cleanup = onCleanup(@()restoreRecoveryEnvironment(previous, dataDirectory));
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            setenv('KSSOLV_USER_DATA_DIR', folder);
            setenv('KSSOLV_ONLINE', 'true');
            testCase.verifyEqual( ...
                kssolv.modeling.provenance.RecoveryJournal.defaultDirectory(), ...
                fullfile(string(folder), "modeling-recovery"));
            setenv('KSSOLV_ONLINE', 'false');
            testCase.verifyEqual( ...
                kssolv.modeling.provenance.RecoveryJournal.defaultDirectory(), ...
                fullfile(prefdir, "KSSOLV", "modeling-recovery"));
        end

        function savedModelingLibrariesUseStableOnlineDataDirectories(testCase)
            previous = getenv('KSSOLV_ONLINE');
            dataDirectory = getenv('KSSOLV_USER_DATA_DIR');
            cleanup = onCleanup(@()restoreRecoveryEnvironment(previous, dataDirectory));
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            setenv('KSSOLV_USER_DATA_DIR', folder);
            directories = { ...
                @kssolv.modeling.provenance.RecipeLibrary.defaultDirectory, ...
                @kssolv.modeling.provenance.ProjectTemplateLibrary.defaultDirectory, ...
                @kssolv.modeling.provenance.ParameterPresetLibrary.defaultDirectory, ...
                @kssolv.modeling.ModelingJobStore.defaultDirectory};
            names = ["modeling-recipes", "modeling-project-templates", ...
                "modeling-presets", "modeling-jobs"];
            for online = [true, false]
                setenv('KSSOLV_ONLINE', string(online));
                if online, base = string(folder);
                else, base = fullfile(prefdir, "KSSOLV"); end
                for index = 1:numel(directories)
                    testCase.verifyEqual(string(directories{index}()), ...
                        fullfile(base, names(index)));
                end
            end
        end

        function saveStagesOutputBeforeRequestingABrowserDestination(testCase)
            % No AppContainer/browser is available: staging must still work.
            [file, folder, index] = kssolv.ui.browser.OnlineFileTransfer.choose( ...
                'save', {'*.ks', 'Project'}, 'Save project', '硅项目');
            cleanup = onCleanup(@()rmdir(folder, 's'));
            testCase.verifyEqual(file, '硅项目.ks');
            testCase.verifyTrue(isfolder(folder));
            testCase.verifyEqual(index, 1);
            testCase.verifyFalse(isfile(fullfile(folder, file)));
        end

        function modeIsExplicitAndIndependentOfBrowserHosting(testCase)
            previous = getenv('KSSOLV_ONLINE');
            browser = getenv('KSSOLV_HOST_IN_BROWSER');
            cleanup = onCleanup(@() restore(previous, browser));
            setenv('KSSOLV_ONLINE', '');
            setenv('KSSOLV_HOST_IN_BROWSER', 'true');
            testCase.verifyFalse(isKSSOLVOnline());
            for value = ["1", "true", "YES", " on "]
                setenv('KSSOLV_ONLINE', value);
                testCase.verifyTrue(isKSSOLVOnline());
            end
            for value = ["0", "false", "unknown"]
                setenv('KSSOLV_ONLINE', value);
                testCase.verifyFalse(isKSSOLVOnline());
            end
        end

        function rejectsClientPathsAndControlCharacters(testCase)
            for value = ["../secret", "..\secret", "/tmp/file", ...
                    "C:\file", "..", ".", "", string(newline)]
                testCase.verifyError(@() ...
                    kssolv.ui.browser.OnlineFileTransfer.validateName(value), ...
                    'KSSOLV:Online:Filename');
            end
            testCase.verifyEqual( ...
                kssolv.ui.browser.OnlineFileTransfer.validateName("硅.cif"), "硅.cif");
        end

        function encodesUnicodeAndURLDelimitersInDownloadNames(testCase)
            testCase.verifyEqual( ...
                kssolv.ui.browser.OnlineFileTransfer.encodeFilename("硅 #1%?.cif"), ...
                '%E7%A1%85%20%231%25%3F.cif');
            testCase.verifyEqual( ...
                kssolv.ui.browser.OnlineFileTransfer.encodeFilename("Si_2-1~1.cif"), ...
                'Si_2-1~1.cif');
        end

        function oversizedDownloadsAreRejectedBeforePublication(testCase)
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            path = fullfile(folder, 'over-limit.bin');
            file = fopen(path, 'w');
            cleanup = onCleanup(@()fclose(file));
            block = zeros(1, 1024 * 1024, 'uint8');
            for index = 1:128
                testCase.assertEqual(fwrite(file, block, 'uint8'), numel(block));
            end
            testCase.assertEqual(fwrite(file, uint8(0), 'uint8'), 1);
            clear cleanup
            testCase.verifyError(@() ...
                kssolv.ui.browser.OnlineFileTransfer.download(path), ...
                'KSSOLV:Online:DownloadSize');
        end

        function desktopHTMLSourceKeepsTheOriginalPath(testCase)
            previous = getenv('KSSOLV_ONLINE');
            cleanup = onCleanup(@()setenv('KSSOLV_ONLINE', previous));
            setenv('KSSOLV_ONLINE', 'false');
            path = fullfile(tempdir, 'unread-desktop-ui.html');
            testCase.verifyEqual(kssolv.ui.browser.htmlSource(path), path);
        end

        function onlineHTMLPreservesContentAndRegistersRelativeResources(testCase)
            previous = getenv('KSSOLV_ONLINE');
            cleanup = onCleanup(@()setenv('KSSOLV_ONLINE', previous));
            setenv('KSSOLV_ONLINE', 'true');
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            path = fullfile(folder, 'component.html');
            original = ['<!doctype html><html><head><title>Fixture</title>', ...
                '<script type="module" src="resource.js"></script>', ...
                '</head><body><p>Original content</p></body></html>'];
            writeFile(path, original);
            writeFile(fullfile(folder, 'resource.js'), ...
                'window.kssolvFixtureResource = true;');
            source = kssolv.ui.browser.htmlSource(path);
            testCase.verifyTrue(startsWith(source, '<!doctype html>'));
            testCase.verifySubstring(source, ...
                '<script type="module" src="resource.js"></script>');
            testCase.verifySubstring(source, '<p>Original content</p>');
            testCase.verifyNumElements(regexp(source, '<base '), 1);
            testCase.verifyNumElements(regexp(source, ...
                'kssolvOnlineSetup = ''waiting'''), 1);
            base = regexp(source, '<base href="([^"]+)">', 'tokens', 'once');
            resource = matlab.ui.internal.URLUtils.getURLToUserFile( ...
                fullfile(folder, 'resource.js'), false);
            testCase.verifyEqual([base{1}, 'resource.js'], resource);
            url = connector.getUrl([resource, '?snc=', connector.newNonce()]);
            content = webread(url, weboptions('CertificateFilename', '', ...
                'ContentType', 'text', 'Timeout', 15));
            testCase.verifyEqual(content, ...
                'window.kssolvFixtureResource = true;');
        end

        function onlyOptedInOnlineFiguresUseClientSizing(testCase)
            previous = getenv('KSSOLV_ONLINE');
            cleanup = onCleanup(@()setenv('KSSOLV_ONLINE', previous));
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            path = fullfile(folder, 'single-view.html');
            writeFile(path, '<html><head></head><body>View</body></html>');
            setenv('KSSOLV_ONLINE', 'true');
            ordinary = kssolv.ui.browser.htmlSource(path);
            singleView = kssolv.ui.browser.htmlSource(path, FillFigure=true);
            testCase.verifyFalse(contains(ordinary, 'kssolv-fill-view-style'));
            testCase.verifySubstring(singleView, 'kssolv-fill-view-style');
            testCase.verifySubstring(singleView, 'window.frameElement');
            setenv('KSSOLV_ONLINE', 'false');
            testCase.verifyEqual( ...
                kssolv.ui.browser.htmlSource(path, FillFigure=true), path);
        end

        function classicHTMLNeedsNoModuleBootstrap(testCase)
            previous = getenv('KSSOLV_ONLINE');
            cleanup = onCleanup(@()setenv('KSSOLV_ONLINE', previous));
            setenv('KSSOLV_ONLINE', 'true');
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            path = fullfile(folder, 'classic.html');
            writeFile(path, ['<html><head><script>function setup(h){}', ...
                '</script></head><body></body></html>']);
            source = kssolv.ui.browser.htmlSource(path);
            testCase.verifySubstring(source, 'function setup(h){}');
            testCase.verifyFalse(contains(source, 'kssolvOnlineSetup'));
            testCase.verifyNumElements(regexp(source, '<base '), 1);
        end

        function onlineHTMLRequiresAHeadElement(testCase)
            previous = getenv('KSSOLV_ONLINE');
            cleanup = onCleanup(@()setenv('KSSOLV_ONLINE', previous));
            setenv('KSSOLV_ONLINE', 'true');
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            path = fullfile(folder, 'nohead.html');
            writeFile(path, '<p>No head</p>');
            testCase.verifyError(@()kssolv.ui.browser.htmlSource(path), ...
                'KSSOLV:Online:HTMLHead');
        end
    end
end

function restoreRecoveryEnvironment(online, directory)
setenv('KSSOLV_ONLINE', online);
setenv('KSSOLV_USER_DATA_DIR', directory);
end

function writeFile(path, content)
file = fopen(path, 'w');
cleanup = onCleanup(@()fclose(file));
fwrite(file, content, 'char');
end

function restore(online, browser)
setenv('KSSOLV_ONLINE', online);
setenv('KSSOLV_HOST_IN_BROWSER', browser);
end
