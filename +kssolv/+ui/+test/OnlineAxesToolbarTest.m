classdef OnlineAxesToolbarTest < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function restoreEnvironment(testCase)
            previous = getenv('KSSOLV_ONLINE');
            testCase.addTeardown(@()setenv('KSSOLV_ONLINE', previous));
        end
    end

    methods (Test)
        function installsNativeDefaultToolsAndExportMenu(testCase)
            setenv('KSSOLV_ONLINE', 'true');
            ax = makeAxes(testCase);
            toolbar = kssolv.ui.browser.OnlineAxesToolbar.install(ax);
            testCase.verifyEqual(ax.Toolbar, toolbar);
            testCase.verifyClass(toolbar, 'matlab.ui.controls.AxesToolbar');
            for tag = ["export", "saveas", "copyimage", "copyvector", ...
                    "brush", "datacursor", "pan", "zoom", "restoreview"]
                testCase.verifyNumElements(findall(toolbar, 'Tag', tag), 1);
            end
            testCase.verifyClass(findall(toolbar, 'Tag', 'export'), ...
                'matlab.ui.controls.ToolbarDropdown');
            verifyExportCallbacks(testCase, toolbar);
        end

        function changesOnlyTheThreeExportCallbacks(testCase)
            setenv('KSSOLV_ONLINE', 'true');
            ax = makeAxes(testCase);
            toolbar = axtoolbar(ax, 'default');
            children = findall(toolbar);
            callbacks = cell(size(children));
            icons = cell(size(children));
            for index = 1:numel(children)
                callbacks{index} = callback(children(index));
                if isprop(children(index), 'Icon')
                    icons{index} = children(index).Icon;
                end
            end
            testCase.verifyEqual( ...
                kssolv.ui.browser.OnlineAxesToolbar.install(ax), toolbar);
            testCase.verifyEqual(findall(toolbar), children);
            for index = 1:numel(children)
                child = children(index);
                if ismember(string(child.Tag), ["saveas", "copyimage", "copyvector"])
                    testCase.verifyNotEqual(callback(child), callbacks{index});
                else
                    testCase.verifyEqual(callback(child), callbacks{index});
                end
                if isprop(child, 'Icon')
                    testCase.verifyEqual(child.Icon, icons{index});
                end
            end
            verifyExportCallbacks(testCase, toolbar);
        end

        function doesNotChangeDesktopToolbar(testCase)
            setenv('KSSOLV_ONLINE', 'false');
            ax = makeAxes(testCase);
            toolbar = axtoolbar(ax, 'default');
            saveButton = findall(toolbar, 'Tag', 'saveas');
            original = saveButton.ButtonPushedFcn;
            testCase.verifyEmpty(kssolv.ui.browser.OnlineAxesToolbar.install(ax));
            testCase.verifyEqual(ax.Toolbar, toolbar);
            testCase.verifyEqual(saveButton.ButtonPushedFcn, original);
            testCase.verifyFalse(isappdata(ax, 'KSSOLVOnlineAxesToolbar'));
        end

        function repeatedInstallKeepsToolbarAndCallbacks(testCase)
            setenv('KSSOLV_ONLINE', 'true');
            ax = makeAxes(testCase);
            toolbar = kssolv.ui.browser.OnlineAxesToolbar.install(ax);
            children = findall(toolbar);
            saveButton = findall(toolbar, 'Tag', 'saveas');
            installed = saveButton.ButtonPushedFcn;
            for index = 1:3
                testCase.verifyEqual( ...
                    kssolv.ui.browser.OnlineAxesToolbar.install(ax), toolbar);
            end
            testCase.verifyEqual(findall(toolbar), children);
            testCase.verifyEqual(saveButton.ButtonPushedFcn, installed);
        end

        function installsAgainAfterToolbarReplacement(testCase)
            setenv('KSSOLV_ONLINE', 'true');
            ax = makeAxes(testCase);
            first = kssolv.ui.browser.OnlineAxesToolbar.install(ax);
            replacement = axtoolbar(ax, 'default');
            testCase.verifyNotEqual(replacement, first);
            testCase.verifyEqual( ...
                kssolv.ui.browser.OnlineAxesToolbar.install(ax), replacement);
            verifyExportCallbacks(testCase, replacement);
        end

        function ignoresDeletedAxes(testCase)
            setenv('KSSOLV_ONLINE', 'true');
            ax = makeAxes(testCase);
            delete(ax);
            testCase.verifyEmpty(kssolv.ui.browser.OnlineAxesToolbar.install(ax));
        end
    end
end

function ax = makeAxes(testCase)
figureHandle = figure('Visible', 'off');
testCase.addTeardown(@()deleteValid(figureHandle));
ax = axes(figureHandle);
plot(ax, 1:3, [2, 1, 3]);
end

function deleteValid(object)
if isvalid(object), delete(object); end
end

function value = callback(object)
value = [];
if isprop(object, 'ButtonPushedFcn')
    value = object.ButtonPushedFcn;
elseif isprop(object, 'ValueChangedFcn')
    value = object.ValueChangedFcn;
end
end

function verifyExportCallbacks(testCase, toolbar)
tags = {'saveas', 'copyimage', 'copyvector'};
actions = {'save', 'image', 'vector'};
for index = 1:numel(tags)
    button = findall(toolbar, 'Tag', tags{index});
    testCase.assertNumElements(button, 1);
    details = functions(button.ButtonPushedFcn);
    testCase.verifySubstring(details.function, ...
        'kssolv.ui.browser.OnlinePlotExport.open');
    workspace = details.workspace{1};
    testCase.verifyEqual(workspace.action, actions{index});
end
end
