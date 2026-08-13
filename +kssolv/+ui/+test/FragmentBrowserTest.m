classdef FragmentBrowserTest < matlab.unittest.TestCase
    %FRAGMENTBROWSERTEST Corrupt user libraries fail visibly and recoverably.

    methods (Test)
        function corruptedStoreDoesNotEscapeUiCallback(testCase)
            path=string(tempname)+" corrupt fragments.json";
            cleanup=onCleanup(@()delete(path));
            file=fopen(path,"w"); fwrite(file,"not json"); fclose(file);
            browser=kssolv.ui.features.modeling.FragmentBrowser( ...
                [],Visible=false,StorePath=path);
            browserCleanup=onCleanup(@()delete(browser));

            testCase.verifyEmpty(browser.Entries);
            testCase.verifyNotEmpty(browser.Widgets.Status.Text);
            testCase.verifyEqual(string(browser.Widgets.Attach.Enable),"off");
            clear browserCleanup cleanup
        end

        function tableHeadingsAndSourcesAreLocalized(testCase)
            cleanup=onCleanup(@()kssolv.ui.util.Localizer.setLocale("zh_CN"));
            storePath=string(tempname)+"-fragments.json";
            kssolv.ui.util.Localizer.setLocale("en_US");
            english=kssolv.ui.features.modeling.FragmentBrowser( ...
                [],Visible=false,StorePath=storePath);
            englishCleanup=onCleanup(@()delete(english));
            testCase.verifyEqual(string(english.Widgets.Table.ColumnName(1)), ...
                "Name");
            testCase.verifyTrue(all(english.Widgets.Table.Data.Source== ...
                "Built-in"));

            kssolv.ui.util.Localizer.setLocale("zh_CN");
            chinese=kssolv.ui.features.modeling.FragmentBrowser( ...
                [],Visible=false,StorePath=storePath);
            chineseCleanup=onCleanup(@()delete(chinese));
            testCase.verifyEqual(string(chinese.Widgets.Table.ColumnName(1)), ...
                "名称");
            testCase.verifyTrue(all(chinese.Widgets.Table.Data.Source=="内置"));
            clear chineseCleanup englishCleanup cleanup
        end

        function selectedFragmentRendersPreviewAndConnectionHead(testCase)
            storePath=string(tempname)+"-fragments.json";
            browser=kssolv.ui.features.modeling.FragmentBrowser( ...
                [],Visible=false,StorePath=storePath);
            cleanup=onCleanup(@()delete(browser));

            testCase.verifyGreaterThan(numel(browser.Widgets.Preview.Children),0);
            testCase.verifyEqual(string(browser.Widgets.Attach.Enable),"on");
            testCase.verifyEqual( ...
                string(browser.Widgets.Preview.Projection),"perspective");
            clear cleanup
        end

        function attachmentFailurePreservesSearchResults(testCase)
            storePath=string(tempname)+"-fragments.json";
            browser=kssolv.ui.features.modeling.FragmentBrowser( ...
                @(varargin)error("KSSOLV:Test:AttachFailure", ...
                "Deliberate attachment failure."), ...
                Visible=false,StorePath=storePath);
            cleanup=onCleanup(@()delete(browser));
            entryCount=numel(browser.Entries);
            tableHeight=height(browser.Widgets.Table.Data);

            callback=browser.Widgets.Attach.ButtonPushedFcn;
            callback(browser.Widgets.Attach,struct());

            testCase.verifyEqual(numel(browser.Entries),entryCount);
            testCase.verifyEqual(height(browser.Widgets.Table.Data),tableHeight);
            testCase.verifySubstring( ...
                string(browser.Widgets.Status.Text),"Deliberate");
            testCase.verifyEqual(string(browser.Widgets.Attach.Enable),"on");
            clear cleanup
        end
    end
end
