classdef ModelingJobsBrowserTest < matlab.unittest.TestCase
    %MODELINGJOBSBROWSERTEST Persistent-job diagnostics in the product UI.

    methods (Test)
        function corruptedJournalRemainsVisibleWithError(testCase)
            directory=string(tempname); mkdir(directory);
            directoryCleanup=onCleanup(@()rmdir(directory,"s"));
            path=fullfile(directory,"damaged-job.json");
            file=fopen(path,"w"); fwrite(file,"not json"); fclose(file);
            browser=kssolv.ui.features.modeling.ModelingJobsBrowser( ...
                directory=directory,visible=false);
            browserCleanup=onCleanup(@()delete(browser));

            data=browser.Widgets.Table.Data;
            testCase.verifyEqual(string(data.Id),"damaged-job");
            testCase.verifyEqual(string(data.Status),string( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:JobStatusinvalid")));
            testCase.verifyFalse(data.Recoverable);
            testCase.verifyNotEmpty(data.Error);
            testCase.verifyEqual(string(browser.Widgets.Table.ColumnName(1)), ...
                string(kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:JobColumnId")));
            testCase.verifyEqual(string(browser.Widgets.Resume.Enable),"off");
            testCase.verifyEqual(string(browser.Widgets.Cancel.Enable),"off");
            clear browserCleanup directoryCleanup
        end

        function statusLabelsSwitchBetweenEnglishAndChinese(testCase)
            cleanup=onCleanup(@()kssolv.ui.util.Localizer.setLocale("zh_CN"));
            directory=string(tempname); mkdir(directory);
            directoryCleanup=onCleanup(@()rmdir(directory,"s"));
            kssolv.modeling.ModelingJobStore.createFileBatch( ...
                "input.xyz",struct("commandId","delete_atoms", ...
                "siteIndices",1,"parameters",struct()),directory, ...
                directory=directory);

            kssolv.ui.util.Localizer.setLocale("en_US");
            english=kssolv.ui.features.modeling.ModelingJobsBrowser( ...
                directory=directory,visible=false);
            englishCleanup=onCleanup(@()delete(english));
            testCase.verifyEqual(string(english.Widgets.Table.Data.Status), ...
                "Queued");
            testCase.verifyEqual(string(english.Widgets.Resume.Enable),"off");
            english.Widgets.Table.Selection=[1,1];
            english.Widgets.Table.CellSelectionCallback([],[]);
            testCase.verifyEqual(string(english.Widgets.Resume.Enable),"on");
            testCase.verifyEqual(string(english.Widgets.Cancel.Enable),"on");

            kssolv.ui.util.Localizer.setLocale("zh_CN");
            chinese=kssolv.ui.features.modeling.ModelingJobsBrowser( ...
                directory=directory,visible=false);
            chineseCleanup=onCleanup(@()delete(chinese));
            testCase.verifyEqual(string(chinese.Widgets.Table.Data.Status), ...
                "排队中");
            clear chineseCleanup englishCleanup directoryCleanup cleanup
        end
    end
end
