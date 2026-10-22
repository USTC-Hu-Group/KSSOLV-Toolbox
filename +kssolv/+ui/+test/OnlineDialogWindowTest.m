classdef OnlineDialogWindowTest < matlab.unittest.TestCase
    methods (Test)
        function buildsHiddenThenShowsTheSameFigure(testCase)
            setupSession(testCase);
            figureHandle = kssolv.ui.util.DialogWindow.create( ...
                'Name', 'Online factory fixture', 'Visible', 'on', ...
                'WindowStyle', 'modal', 'Color', [0.9, 0.8, 0.7]);
            cleanup = onCleanup(@()deleteValid(figureHandle));
            testCase.verifyEqual(string(figureHandle.Visible), "off");
            testCase.verifyEqual(figureHandle.WindowStyle, 'normal');
            testCase.verifyEqual(figureHandle.Color, [0.9, 0.8, 0.7]);
            modal = getappdata(figureHandle, 'KSSOLVDialogModal');
            testCase.verifyClass(modal, 'kssolv.ui.browser.OnlineModal');
            testCase.verifyEqual(modal.Figure, figureHandle);
            testCase.verifyFalse(modal.Visible);
            kssolv.ui.util.DialogWindow.showCentered(figureHandle);
            testCase.verifyEqual(modal.Figure, figureHandle);
            testCase.verifyEqual(string(modal.Title), "Online factory fixture");
            testCase.verifyTrue(modal.Visible);
            testCase.verifyEqual(string(figureHandle.Visible), "on");
            kssolv.ui.util.DialogWindow.bringToFront(figureHandle);
            app = kssolv.ui.util.DataStorage.getData('AppContainer');
            testCase.verifyEmpty(app.getDocumentGroup('Online'));
            delete(figureHandle);
            testCase.verifyFalse(isvalid(modal));
        end

        function closeInvokesTheOwnerAndAllowsAVeto(testCase)
            setupSession(testCase);
            figureHandle = kssolv.ui.util.DialogWindow.create( ...
                'Name', 'Close fixture', 'Visible', 'off', ...
                'CloseRequestFcn', @(source, ~) ...
                setappdata(source, 'CloseWasRequested', true));
            cleanup = onCleanup(@()deleteValid(figureHandle));
            kssolv.ui.util.DialogWindow.showCentered(figureHandle);
            modal = getappdata(figureHandle, 'KSSOLVDialogModal');
            kssolv.ui.util.DialogWindow.close(figureHandle);
            testCase.verifyTrue(getappdata(figureHandle, 'CloseWasRequested'));
            testCase.verifyTrue(isvalid(figureHandle));
            testCase.verifyTrue(isvalid(modal));
            testCase.verifyFalse(modal.CanCloseFcn(modal));
            figureHandle.CloseRequestFcn = @(source, ~)delete(source);
            closeRequest = modal.CanCloseFcn;
            testCase.verifyTrue(closeRequest(modal));
            testCase.verifyFalse(isvalid(figureHandle));
            testCase.verifyFalse(isvalid(modal));
        end

        function waitResumesWithoutClosingTheModal(testCase)
            setupSession(testCase);
            figureHandle = kssolv.ui.util.DialogWindow.create( ...
                'Name', 'Wait fixture', 'Visible', 'off');
            cleanup = onCleanup(@()deleteValid(figureHandle));
            release = timer('StartDelay', .2, 'TimerFcn', @(~, ~) ...
                kssolv.ui.util.DialogWindow.resume(figureHandle));
            timerCleanup = onCleanup(@()delete(release));
            start(release);
            kssolv.ui.util.DialogWindow.wait(figureHandle);
            testCase.verifyTrue(isvalid(figureHandle));
            testCase.verifyFalse(getappdata(figureHandle, 'KSSOLVDialogWaiting'));
        end
    end
end

function setupSession(testCase)
previous = getenv('KSSOLV_ONLINE');
previousApp = kssolv.ui.util.DataStorage.getData('AppContainer');
testCase.addTeardown(@()setenv('KSSOLV_ONLINE', previous));
testCase.addTeardown(@() ...
    kssolv.ui.util.DataStorage.setData('AppContainer', previousApp));
setenv('KSSOLV_ONLINE', 'true');
app = matlab.ui.container.internal.AppContainer(struct( ...
    'Tag', ['kssolv-online-unit-', char(matlab.lang.internal.uuid)]));
testCase.addTeardown(@()deleteValid(app));
kssolv.ui.util.DataStorage.setData('AppContainer', app);
panel = matlab.ui.internal.FigurePanel(struct('Tag', 'ProjectBrowser'));
testCase.addTeardown(@()deleteValid(panel));
app.add(panel);
end

function deleteValid(object)
if isvalid(object), delete(object); end
end
