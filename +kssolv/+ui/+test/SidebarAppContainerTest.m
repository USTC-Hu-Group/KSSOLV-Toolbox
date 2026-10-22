classdef SidebarAppContainerTest < matlab.unittest.TestCase
    methods (Test)
        function nativeAndBrowserViewsUseTheSameSidebarPage(testCase)
            native = kssolv.ui.browser.SidebarAppContainer(struct( ...
                'Tag', 'kssolv-sidebar-page-test', 'ToolstripEnabled', false));
            nativeCleanup = onCleanup(@()delete(native));
            browser = kssolv.ui.browser.BrowserAppContainer(struct( ...
                'Tag', 'kssolv-sidebar-browser-page-test', 'ToolstripEnabled', false));
            browserCleanup = onCleanup(@()delete(browser));
            page = native.getClientPage();
            testCase.verifyEqual(browser.getClientPage(), page);
            testCase.verifySubstring(page, '?desktopFeatures=sidebar,panelsGallery,');
            % panelToolbars creates client actions in MATLAB's read-only
            % Toolstrip service and prevents FigurePanels from being added.
            testCase.verifyFalse(contains(page, 'panelToolbars'));
            testCase.verifyEqual(count(page, '?'), 1);
            clear nativeCleanup browserCleanup
        end
    end
end
