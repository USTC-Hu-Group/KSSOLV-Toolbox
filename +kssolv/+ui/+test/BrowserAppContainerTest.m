classdef BrowserAppContainerTest < matlab.unittest.TestCase
    methods (Test)
        function publishesVisibilityWhenLocalBrowserIsUnavailable(testCase)
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            writelines(["function status = web(varargin)"; ...
                "status = 1;"; "end"], fullfile(folder, 'web.m'));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
            container = kssolv.ui.browser.BrowserAppContainer( ...
                struct('Tag', 'kssolv-browser-visibility-test'));
            cleanup = onCleanup(@() delete(container));
            container.prepareBrowserView();
            testCase.verifyTrue(container.HostInBrowser);
            testCase.verifyTrue(container.Visible);
        end

        function propagatesUnexpectedViewErrors(testCase)
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            writelines(["function status = web(varargin)"; ...
                "status = 1;"; ...
                "error('KSSOLV:Test:BrowserFailure', 'Unexpected browser failure.');"; ...
                "end"], fullfile(folder, 'web.m'));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
            container = kssolv.ui.browser.BrowserAppContainer( ...
                struct('Tag', 'kssolv-browser-error-test'));
            cleanup = onCleanup(@() delete(container));
            testCase.verifyError(@() container.prepareBrowserView(), ...
                'KSSOLV:Test:BrowserFailure');
        end
    end
end
