classdef SessionPromptTest < matlab.unittest.TestCase
    %SESSIONPROMPTTEST Exercise real callbacks without opening a browser.
    properties (Access = private)
        App
        CallbackFailure = []
        CallbackRan (1,1) logical = false
        PromptFigures cell = {}
        SecretListener = []
        FinalSecretData = []
        TransferFolder = ""
    end

    methods (TestMethodSetup)
        function createIsolatedSession(testCase)
            previous = getenv('KSSOLV_ONLINE');
            previousApp = kssolv.ui.util.DataStorage.getData('AppContainer');
            testCase.addTeardown(@()setenv('KSSOLV_ONLINE', previous));
            testCase.addTeardown(@() ...
                kssolv.ui.util.DataStorage.setData('AppContainer', previousApp));
            setenv('KSSOLV_ONLINE', 'true');
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            writelines(["function status = web(varargin)"; ...
                "status = 1;"; "end"], fullfile(folder, 'web.m'));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
            testCase.App = kssolv.ui.browser.BrowserAppContainer(struct( ...
                'Tag', ['online-prompt-test-', char(matlab.lang.internal.uuid)]));
            testCase.addTeardown(@()deleteValid(testCase.App));
            testCase.App.prepareBrowserView();
            host = matlab.ui.internal.FigurePanel(struct( ...
                'Tag', 'ProjectBrowser', 'Title', 'Modal host fixture'));
            testCase.App.add(host);
            kssolv.ui.util.DataStorage.setData('AppContainer', testCase.App);
        end
    end

    methods (Test)
        function cancellingAFileBatchRejectsCompletedAndPartialFiles(testCase)
            testCase.schedule('OnlineFileTransfer', ...
                @(html)testCase.simulateFileBatch(html, true), false);
            [file, folder, index] = kssolv.ui.browser.OnlineFileTransfer.choose( ...
                'open', {'*.*', 'Fixtures'}, 'Cancelled batch', 'MultiSelect', 'on');
            testCase.verifyEqual(file, 0);
            testCase.verifyEqual(folder, 0);
            testCase.verifyEqual(index, 0);
            testCase.verifyFalse(isfolder(testCase.TransferFolder));
            testCase.verifyCompletedWithoutWarnings();
        end

        function completedFileBatchReturnsAllFiles(testCase)
            testCase.schedule('OnlineFileTransfer', ...
                @(html)testCase.simulateFileBatch(html, false), false);
            [files, folder, index] = kssolv.ui.browser.OnlineFileTransfer.choose( ...
                'open', {'*.*', 'Fixtures'}, 'Completed batch', 'MultiSelect', 'on');
            cleanup = onCleanup(@()rmdir(folder, 's'));
            testCase.verifyNumElements(files, 2);
            testCase.verifyEqual(index, 1);
            testCase.verifyEqual(fileread(fullfile(folder, files{1})), 'first');
            testCase.verifyEqual(fileread(fullfile(folder, files{2})), 'second');
            testCase.verifyCompletedWithoutWarnings();
        end

        function oneOptionErrorPromptCanClose(testCase)
            testCase.schedule('OnlineConfirmOption1', @(~)[]);
            lastwarn('', '');
            result = kssolv.ui.util.SessionPrompt.confirm([], ...
                'Invalid project fixture', 'Load failure', ...
                'Options', {'Close'}, 'Icon', 'error');
            testCase.verifyEqual(string(result), "Close");
            testCase.verifyCompletedWithoutWarnings();
        end

        function secretCancelKeepsErrorAndClearsField(testCase)
            testCase.schedule('OnlineSecretPromptCancel', ...
                @(button)testCase.prepareSecret(button));
            lastwarn('', '');
            testCase.verifyError(@()kssolv.ui.util.SecretPrompt.prompt( ...
                "Test credential", "Cancel fixture", 'KSSOLV:Test:Cancelled'), ...
                'KSSOLV:Test:Cancelled');
            testCase.verifyCompletedWithoutWarnings();
            testCase.verifyEqual(testCase.FinalSecretData.Value, '');
            testCase.verifyFalse(testCase.FinalSecretData.Enabled);
        end

        function secretConfirmReturnsValueAndClearsField(testCase)
            testCase.schedule('OnlineSecretPromptOK', ...
                @(button)testCase.prepareSecret(button));
            lastwarn('', '');
            value = kssolv.ui.util.SecretPrompt.prompt("Test credential");
            testCase.verifyEqual(value, "test-only-placeholder");
            testCase.verifyCompletedWithoutWarnings();
            testCase.verifyEqual(testCase.FinalSecretData.Value, '');
            testCase.verifyFalse(testCase.FinalSecretData.Enabled);
        end

        function inputCancelReturnsEmpty(testCase)
            testCase.schedule('SessionPromptCancel', @(~)[]);
            lastwarn('', '');
            result = kssolv.ui.util.SessionPrompt.input( ...
                {'Name'}, 'Input cancel', 1, {'original'});
            testCase.verifyEmpty(result);
            testCase.verifyCompletedWithoutWarnings();
        end

        function inputConfirmReturnsEditedValues(testCase)
            testCase.schedule('SessionPromptOK', @editInputs);
            lastwarn('', '');
            result = kssolv.ui.util.SessionPrompt.input( ...
                {'Name', 'Description'}, 'Input confirm', [1; 2], ...
                {'original', 'description'});
            testCase.verifyEqual(result, {'changed'; ['line one', newline, 'line two']});
            testCase.verifyCompletedWithoutWarnings();
        end

        function inputFigureCloseReleasesWait(testCase)
            testCase.schedule('SessionPromptInput1', @closeFigure, false);
            lastwarn('', '');
            result = kssolv.ui.util.SessionPrompt.input('Name', 'Close input');
            testCase.verifyEmpty(result);
            testCase.verifyCompletedWithoutWarnings();
        end

        function selectionConfirmReturnsNumericIndices(testCase)
            testCase.schedule('SessionPromptOK', @selectLastItem);
            lastwarn('', '');
            [indices, accepted] = kssolv.ui.util.SessionPrompt.selection( ...
                'PromptString', 'Choose a profile', ...
                'ListString', {'alpha', 'beta'}, 'SelectionMode', 'single', ...
                'InitialValue', 1, 'Name', 'Select fixture');
            testCase.verifyEqual(indices, 2);
            testCase.verifyTrue(accepted);
            testCase.verifyCompletedWithoutWarnings();
        end

        function selectionCancelReturnsNoIndices(testCase)
            testCase.schedule('SessionPromptCancel', @(~)[]);
            lastwarn('', '');
            [indices, accepted] = kssolv.ui.util.SessionPrompt.selection( ...
                'ListString', {'alpha', 'beta'}, 'SelectionMode', 'multiple', ...
                'InitialValue', [1, 2]);
            testCase.verifyEmpty(indices);
            testCase.verifyFalse(accepted);
            testCase.verifyCompletedWithoutWarnings();
        end

        function disposeBeforeShowDestroysTheFigure(testCase)
            modal = kssolv.ui.browser.OnlineModal.create('Dispose fixture', true, false);
            figure = modal.Figure;
            testCase.verifyFalse(modal.Visible);
            kssolv.ui.browser.OnlineModal.dispose(modal);
            testCase.verifyEmpty(testCase.App.getDocuments('Online'));
            testCase.verifyFalse(isvalid(modal));
            testCase.verifyFalse(isvalid(figure));
            kssolv.ui.browser.OnlineModal.dispose(modal);
        end

        function disposeAfterShowDestroysTheFigure(testCase)
            modal = kssolv.ui.browser.OnlineModal.create('Shown fixture', true, false);
            figure = modal.Figure;
            uibutton(figure, 'Text', 'Fixture');
            modal.show();
            testCase.verifyTrue(modal.Visible);
            modal.Title = 'Updated title';
            testCase.verifyEqual(modal.Title, "Updated title");
            testCase.verifyEqual(string(figure.Name), "Updated title");
            kssolv.ui.browser.OnlineModal.dispose(modal);
            testCase.verifyEmpty(testCase.App.getDocuments('Online'));
            testCase.verifyFalse(isvalid(modal));
            testCase.verifyFalse(isvalid(figure));
        end

        function realTransferHTMLResourcesCreateValidComponents(testCase)
            paths = {kssolv.ui.browser.resourcePath('online-files.html'), ...
                fullfile(KSSOLV_Toolbox.RootDirectory, '+kssolv', ...
                '+ui', '+features', '+remote', 'passwordField.html')};
            modal = kssolv.ui.browser.OnlineModal.create('HTML resources', true, false);
            cleanup = onCleanup(@() ...
                kssolv.ui.browser.OnlineModal.dispose(modal));
            for index = 1:numel(paths)
                source = kssolv.ui.browser.htmlSource(paths{index});
                testCase.verifySubstring(source, '<base href=');
                testCase.verifySubstring(source, 'function setup(');
                control = uihtml(modal.Figure, 'HTMLSource', source);
                testCase.verifyTrue(isvalid(control));
                delete(control);
            end
            clear cleanup
            testCase.verifyEmpty(testCase.App.getDocuments('Online'));
        end

        function sessionDialogKeepsControlsOnReopenAndDisposesOnDelete(testCase)
            dialog = kssolv.ui.components.dialog.AboutDialog();
            cleanup = onCleanup(@()deleteValid(dialog));
            expectedSize = dialog.getWidget().Position(3:4);
            dialog.show();
            figure = dialog.getWidget();
            testCase.verifyEqual(figure.Position(3:4), expectedSize);
            testCase.verifyEmpty(testCase.App.getDocuments('Online'));
            invokeButton(dialog.widgets.CloseButton);
            testCase.verifyFalse(dialog.IsVisible);
            testCase.verifyTrue(isvalid(figure));
            dialog.show();
            testCase.verifyEqual(dialog.getWidget(), figure);
            testCase.verifyTrue(dialog.IsVisible);
            delete(dialog);
            testCase.verifyFalse(isvalid(figure));
            testCase.verifyEmpty(testCase.App.getDocuments('Online'));
            clear cleanup
        end

        function hostDeletionDisposesActiveModal(testCase)
            modal = kssolv.ui.browser.OnlineModal.create('Host fixture', true, false);
            figure = modal.Figure;
            modal.show();
            host = testCase.App.getPanel('ProjectBrowser');
            delete(host.Figure);
            testCase.verifyFalse(isvalid(modal));
            testCase.verifyFalse(isvalid(figure));
            testCase.verifyEmpty(kssolv.ui.browser.OnlineModal.getInstances());
        end

        function desktopSessionDialogRetainsNativeFigure(testCase)
            setenv('KSSOLV_ONLINE', 'false');
            dialog = kssolv.ui.components.dialog.AboutDialog();
            cleanup = onCleanup(@()deleteValid(dialog));
            figure = dialog.getWidget();
            testCase.verifyEqual(figure.WindowStyle, 'alwaysontop');
            dialog.show();
            testCase.verifyEqual(dialog.getWidget(), figure);
            testCase.verifyEmpty(kssolv.ui.browser.OnlineModal.getInstances());
            dialog.close();
            testCase.verifyFalse(dialog.IsVisible);
            testCase.verifyTrue(isvalid(figure));
            clear cleanup
            testCase.verifyFalse(isvalid(figure));
        end

        function confirmCloseUsesNumericCancelOption(testCase)
            testCase.schedule('OnlineConfirmDialogLayout', @closeFigure, false);
            lastwarn('', '');
            dialog = kssolv.ui.components.dialog.ConfirmDialog( ...
                'Question', 'Numeric cancel', ...
                'Options', {'Accept', 'Reject', 'Dismiss'}, 'CancelOption', 2);
            cleanup = onCleanup(@()deleteValid(dialog));
            result = dialog.show();
            testCase.verifyEqual(string(result), "Reject");
            testCase.verifyCompletedWithoutWarnings();
            clear cleanup
        end

        function confirmCloseUsesTextCancelOption(testCase)
            testCase.schedule('OnlineConfirmDialogLayout', @closeFigure, false);
            lastwarn('', '');
            dialog = kssolv.ui.components.dialog.ConfirmDialog( ...
                'Question', 'Text cancel', ...
                'Options', {'Accept', 'Reject', 'Dismiss'}, ...
                'CancelOption', 'Dismiss');
            cleanup = onCleanup(@()deleteValid(dialog));
            result = dialog.show();
            testCase.verifyEqual(string(result), "Dismiss");
            testCase.verifyCompletedWithoutWarnings();
            clear cleanup
        end

        function confirmDisposalReleasesWaitWithCancelOption(testCase)
            testCase.schedule('OnlineConfirmDialogLayout', ...
                @disposeOwningModal, false);
            lastwarn('', '');
            dialog = kssolv.ui.components.dialog.ConfirmDialog( ...
                'Question', 'Dispose confirmation', ...
                'Options', {'Accept', 'Reject', 'Dismiss'}, 'CancelOption', 2);
            cleanup = onCleanup(@()deleteValid(dialog));
            result = dialog.show();
            testCase.verifyEqual(string(result), "Reject");
            testCase.verifyCompletedWithoutWarnings();
            clear cleanup
        end

        function twoOptionConfirmReturnsTheFirstOption(testCase)
            testCase.schedule('OnlineConfirmOption1', @(~)[]);
            lastwarn('', '');
            result = kssolv.ui.util.SessionPrompt.confirm( ...
                testCase.App.getPanel('ProjectBrowser').Figure, ...
                'Delete fixture?', 'Two options', 'Options', ["Delete", "Cancel"], ...
                'DefaultOption', 2, 'CancelOption', 2);
            testCase.verifyEqual(string(result), "Delete");
            testCase.verifyCompletedWithoutWarnings();
        end

        function twoOptionCancelReturnsTheSecondOption(testCase)
            testCase.schedule('OnlineConfirmOption2', @(~)[]);
            lastwarn('', '');
            result = kssolv.ui.util.SessionPrompt.confirm( ...
                testCase.App.getPanel('ProjectBrowser').Figure, ...
                'Delete fixture?', 'Two options', 'Options', {'Delete', 'Cancel'}, ...
                'DefaultOption', 2, 'CancelOption', 2);
            testCase.verifyEqual(string(result), "Cancel");
            testCase.verifyCompletedWithoutWarnings();
        end

        function twoOptionCloseDefaultsToTheLastOption(testCase)
            testCase.schedule('OnlineConfirmDialogLayout', @closeFigure, false);
            lastwarn('', '');
            result = kssolv.ui.util.SessionPrompt.confirm( ...
                testCase.App.getPanel('ProjectBrowser').Figure, ...
                'Delete fixture?', 'Close two options', ...
                'Options', {'Delete', 'Cancel'});
            testCase.verifyEqual(string(result), "Cancel");
            testCase.verifyCompletedWithoutWarnings();
        end

        function threeOptionButtonsPreserveTheirSelections(testCase)
            options = {'Accept', 'Reject', 'Dismiss'};
            for index = 1:3
                testCase.schedule(sprintf('OnlineConfirmOption%d', index), @(~)[]);
                lastwarn('', '');
                result = kssolv.ui.util.SessionPrompt.confirm( ...
                    testCase.App.getPanel('ProjectBrowser').Figure, ...
                    'Choose a fixture option', 'Three options', 'Options', options);
                testCase.verifyEqual(string(result), string(options{index}));
                testCase.verifyCompletedWithoutWarnings();
            end
        end
    end

    methods (Access = private)
        function simulateFileBatch(testCase, html, cancelBatch)
            callback = html.HTMLEventReceivedFcn;
            name = ['qa-', char(matlab.lang.internal.uuid), '.cif'];
            callback(html, struct('HTMLEventName', 'upload', ...
                'HTMLEventData', struct('name', name, 'index', 0, ...
                'bytes', matlab.net.base64encode(uint8('first')), 'final', true)));
            found = dir(fullfile(tempdir, '*', name));
            assert(isscalar(found), 'Completed fixture was not written.');
            testCase.TransferFolder = string(found.folder);
            callback(html, struct('HTMLEventName', 'upload', ...
                'HTMLEventData', struct('name', 'second.bin', 'index', 0, ...
                'bytes', matlab.net.base64encode(uint8('second')), 'final', ~cancelBatch)));
            if cancelBatch, event = 'cancel'; else, event = 'complete'; end
            callback(html, struct('HTMLEventName', event, 'HTMLEventData', struct()));
        end

        function schedule(testCase, tag, prepare, push)
            if nargin < 4, push = true; end
            driver = timer('ExecutionMode', 'fixedSpacing', 'Period', .05, ...
                'TasksToExecute', 400, 'TimerFcn', @(source, ~) ...
                testCase.drive(source, tag, prepare, push));
            testCase.addTeardown(@()deleteTimer(driver));
            start(driver);
        end

        function drive(testCase, driver, tag, prepare, push)
            modals = kssolv.ui.browser.OnlineModal.getInstances();
            for index = 1:numel(modals)
                control = findall(modals{index}.Figure, 'Tag', tag);
                if isempty(control), continue; end
                figure = ancestor(control(1), 'figure');
                testCase.PromptFigures{end + 1} = figure;
                stop(driver);
                try
                    prepare(control(1));
                    if push, invokeButton(control(1)); end
                    testCase.CallbackRan = true;
                catch exception
                    testCase.CallbackFailure = exception;
                    deleteValid(figure);
                end
                return
            end
            if driver.TasksExecuted >= 399
                testCase.CallbackFailure = MException('KSSOLV:Test:PromptTimeout', ...
                    'The expected prompt control did not appear.');
                stop(driver);
                for index = 1:numel(modals)
                    kssolv.ui.browser.OnlineModal.dispose(modals{index});
                end
            end
        end

        function prepareSecret(testCase, button)
            field = findall(ancestor(button, 'figure'), ...
                'Tag', 'OnlineSecretPromptField');
            field.Data = struct('Value', 'test-only-placeholder', ...
                'Enabled', true, 'Placeholder', '');
            testCase.SecretListener = addlistener(field, ...
                'ObjectBeingDestroyed', @(~, ~)testCase.recordSecret(field));
            testCase.addTeardown(@()deleteValid(testCase.SecretListener));
        end

        function recordSecret(testCase, field)
            testCase.FinalSecretData = field.Data;
        end

        function verifyCompletedWithoutWarnings(testCase)
            drawnow;
            pause(.05);
            [message, identifier] = lastwarn;
            testCase.verifyEmpty(message, identifier);
            testCase.verifyEmpty(testCase.CallbackFailure);
            testCase.verifyTrue(testCase.CallbackRan);
            testCase.verifyEmpty(kssolv.ui.browser.OnlineModal.getInstances());
            testCase.verifyEmpty(testCase.App.getDocuments('Online'));
            for index = 1:numel(testCase.PromptFigures)
                testCase.verifyFalse(isvalid(testCase.PromptFigures{index}));
            end
        end
    end
end

function invokeButton(button)
feval(button.ButtonPushedFcn, button, []);
end

function editInputs(button)
figure = ancestor(button, 'figure');
name = findall(figure, 'Tag', 'SessionPromptInput1');
description = findall(figure, 'Tag', 'SessionPromptInput2');
name.Value = 'changed';
description.Value = {'line one'; 'line two'};
end

function selectLastItem(button)
list = findall(ancestor(button, 'figure'), 'Tag', 'SessionPromptSelection');
list.Value = 2;
end

function closeFigure(control)
figure = ancestor(control, 'figure');
feval(figure.CloseRequestFcn, figure, []);
end

function disposeOwningModal(control)
figure = ancestor(control, 'figure');
modals = kssolv.ui.browser.OnlineModal.getInstances();
for index = 1:numel(modals)
    if isequal(modals{index}.Figure, figure)
        kssolv.ui.browser.OnlineModal.dispose(modals{index});
        return
    end
end
end

function deleteTimer(driver)
if isvalid(driver), stop(driver); delete(driver); end
end

function deleteValid(value)
if ~isempty(value) && isvalid(value), delete(value); end
end
