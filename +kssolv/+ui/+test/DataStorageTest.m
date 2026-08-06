classdef DataStorageTest < matlab.unittest.TestCase
    %DATASTORAGETEST Regression tests for UI state persistence.

    methods (Test)
        function storageIsAnchoredOutsidePersistentMemory(testCase)
            key = 'DataStorageTestValue';
            cleanup = onCleanup(@() ...
                kssolv.ui.util.DataStorage.removeData(key));

            kssolv.ui.util.DataStorage.setData(key, 42);

            storedInstance = getappdata( ...
                groot, 'KSSOLVToolbox_DataStorage');
            testCase.verifyClass(storedInstance, ...
                'kssolv.ui.util.DataStorage');
            testCase.verifyEqual( ...
                kssolv.ui.util.DataStorage.getData(key), 42);

            clear cleanup
        end

        function projectBrowserRepairsMissingProjectCache(testCase)
            projectCleanup = onCleanup(@() ...
                kssolv.ui.util.DataStorage.removeData('Project'));
            filenameCleanup = onCleanup(@() ...
                kssolv.ui.util.DataStorage.removeData('ProjectFilename'));
            browserCacheCleanup = onCleanup(@() ...
                kssolv.ui.util.DataStorage.removeData('ProjectBrowser'));

            project = kssolv.services.filemanager.Project();
            kssolv.ui.util.DataStorage.setData('Project', project);
            kssolv.ui.util.DataStorage.setData( ...
                'ProjectFilename', 'recovery.ks');
            browser = ...
                kssolv.ui.components.databrowser.ProjectBrowser();
            browserCleanup = onCleanup(@() delete(browser));

            kssolv.ui.util.DataStorage.removeData('Project');
            kssolv.ui.util.DataStorage.removeData('ProjectFilename');
            [restoredProject, restoredFilename] = ...
                browser.getCurrentProject();

            testCase.verifyTrue(isequal(restoredProject, project));
            testCase.verifyEqual(restoredFilename, "recovery.ks");
            testCase.verifyTrue(isequal( ...
                kssolv.ui.util.DataStorage.getData('Project'), project));

            clear browserCleanup browserCacheCleanup filenameCleanup ...
                projectCleanup
        end
    end
end
