classdef OnlineNavigationTest < matlab.unittest.TestCase
    methods (Test)
        function toolstripLinksTargetTheClient(testCase)
            links = kssolv.ui.browser.onlineLinks();
            testCase.verifyEqual(numel(unique(string({links.tag}))), numel(links));
            testCase.verifyTrue(all(startsWith(string({links.url}), ...
                ["https://", "http://", "mailto:"])));
            site = links(strcmp({links.tag}, 'ResourceSection_OfficialSite'));
            testCase.verifyEqual(site.url, 'https://pwdft.com/prod/48.html');
            docs = links(strcmp({links.tag}, 'ResourceSection_ResourceDocumentation'));
            help = links(strcmp({links.tag}, 'QABHelpButton'));
            testCase.verifyEqual(help.url, docs.url);
            support = links(strcmp({links.tag}, 'ResourceSection_ResourceSupport'));
            testCase.verifySubstring(support.url, '?subject=Request%20for%20Assistance');
        end

        function viewerPreservesUnicodeAndLiteralMarkup(testCase)
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            path = fullfile(folder, 'session.log');
            original = "硅 structure <script>alert('literal')</script>" + newline + "complete";
            writeUTF8(path, original);
            [text, truncated] = kssolv.ui.browser.OnlineFileViewer.readTail(path);
            testCase.verifyEqual(text, original);
            testCase.verifyFalse(truncated);
        end

        function largeLogsHaveABoundedUtf8Tail(testCase)
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            path = fullfile(folder, 'large.log');
            original = string(repmat('硅', 1, 200000)) + newline + "latest output";
            writeUTF8(path, original);
            [text, truncated] = kssolv.ui.browser.OnlineFileViewer.readTail(path);
            testCase.verifyTrue(truncated);
            testCase.verifyTrue(endsWith(text, "latest output"));
            testCase.verifyLessThanOrEqual(numel(unicode2native(char(text), 'UTF-8')), 512 * 1024);
            testCase.verifyFalse(contains(text, char(65533)));
        end

        function onlineFoldersNeverLaunchAServerProgram(testCase)
            previous = getenv('KSSOLV_ONLINE');
            cleanup = onCleanup(@()setenv('KSSOLV_ONLINE', previous));
            setenv('KSSOLV_ONLINE', 'true');
            testCase.verifyError(@()kssolv.ui.util.openWithSystemDefault(tempdir), ...
                'KSSOLV:UI:OnlineFile:Folder');
        end
    end
end

function writeUTF8(path, text)
file = fopen(path, 'wb');
cleanup = onCleanup(@()fclose(file));
fwrite(file, unicode2native(char(text), 'UTF-8'), 'uint8');
end
