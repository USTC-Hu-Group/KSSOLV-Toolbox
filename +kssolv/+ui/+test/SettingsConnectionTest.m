classdef SettingsConnectionTest < matlab.unittest.TestCase
    % Exercise real HTTP futures and UI callbacks, including cold -nojvm pools.
    properties
        Dialog
        API
    end

    methods (TestMethodSetup)
        function createDialog(testCase)
            testCase.API = string(getenv('KSSOLV_TEST_MODEL_API'));
            testCase.assumeNotEmpty(char(testCase.API), ...
                'Start scripts/docker/fixtures/model_api.py and set KSSOLV_TEST_MODEL_API.');
            testCase.Dialog = kssolv.ui.components.dialog.SettingsDialog();
            key = testCase.Dialog.widgets.OpenAIAPIKeyText;
            key.Value = 'sk-fixture-only';
            key.ValueChangedFcn(key, []);
        end
    end

    methods (TestMethodTeardown)
        function destroyDialog(testCase)
            if ~isempty(testCase.Dialog) && isvalid(testCase.Dialog)
                delete(testCase.Dialog);
            end
        end
    end

    methods (Test)
        function coldPoolCompletesAndPopulatesModels(testCase)
            testCase.startRequest('success');
            testCase.waitForCompletion();
            dropdown = testCase.Dialog.widgets.OpenAIModelDropdown;
            testCase.verifyEqual(dropdown.Items, {'mock-cpu', 'mock-stream'});
            testCase.verifyEqual(dropdown.Value, 'mock-cpu');
            testCase.verifySubstring(testCase.status(), '(2)');
        end

        function refreshedListPreservesOnlyASelectionStillOfferedByTheService(testCase)
            testCase.startRequest('success');
            testCase.waitForCompletion();
            dropdown = testCase.Dialog.widgets.OpenAIModelDropdown;
            dropdown.Value = 'mock-stream';
            testCase.startRequest('success');
            testCase.waitForCompletion();
            testCase.verifyEqual(dropdown.Items, {'mock-cpu', 'mock-stream'});
            testCase.verifyEqual(dropdown.Value, 'mock-stream');
        end

        function failuresAreBoundedAndDoNotExposeCredentials(testCase)
            modes = ["unauthorized", "limited", "invalid", "empty"];
            keys = ["SettingsDialogAuthenticationFailed", ...
                "SettingsDialogRateLimited", ...
                "SettingsDialogInvalidServiceResponse", ...
                "SettingsDialogNoModelsFound"];
            for index = 1:numel(modes)
                testCase.startRequest(modes(index));
                testCase.waitForCompletion();
                expected = kssolv.ui.util.Localizer.message( ...
                    char("KSSOLV:dialogs:" + keys(index)));
                testCase.verifyEqual(testCase.status(), string(expected));
                testCase.verifyFalse(contains(testCase.status(), 'sk-fixture-only'));
            end
        end

        function cancellationAndRetryIgnoreOldCompletion(testCase)
            testCase.startRequest('slow');
            pause(0.2);
            button = testCase.Dialog.widgets.OpenAITestButton;
            button.ButtonPushedFcn(button, []);
            stopped = string(kssolv.ui.util.Localizer.message( ...
                'KSSOLV:dialogs:SettingsDialogConnectionStopped'));
            testCase.verifyEqual(testCase.status(), stopped);
            testCase.startRequest('success');
            testCase.waitForCompletion();
            testCase.verifySubstring(testCase.status(), '(2)');
        end

        function timeoutReturnsToRetryableState(testCase)
            testCase.startRequest('slow');
            testCase.waitForCompletion();
            expected = kssolv.ui.util.Localizer.message( ...
                'KSSOLV:dialogs:SettingsDialogConnectionTimedOut');
            testCase.verifyEqual(testCase.status(), string(expected));
            testCase.startRequest('success');
            testCase.waitForCompletion();
            testCase.verifySubstring(testCase.status(), '(2)');
        end

        function deletionCancelsRunningRequest(testCase)
            testCase.startRequest('slow');
            pause(0.2);
            started = tic;
            delete(testCase.Dialog);
            testCase.verifyFalse(isvalid(testCase.Dialog));
            testCase.verifyLessThan(toc(started), 5);
        end
    end

    methods (Access = private)
        function startRequest(testCase, mode)
            field = testCase.Dialog.widgets.OpenAIBaseURLText;
            field.Value = char(testCase.API + "/" + mode);
            field.ValueChangedFcn(field, []);
            button = testCase.Dialog.widgets.OpenAITestButton;
            button.ButtonPushedFcn(button, []);
        end

        function waitForCompletion(testCase)
            started = tic;
            stopText = string(kssolv.ui.util.Localizer.message( ...
                'KSSOLV:dialogs:SettingsDialogStopTest'));
            while string(testCase.Dialog.widgets.OpenAITestButton.Text) == stopText
                testCase.assertLessThan(toc(started), 23, 'Connection test never completed.');
                pause(0.05);
            end
            testCase.verifyEqual(string(testCase.Dialog.widgets.OpenAIRefreshButton.Enable), "on");
        end

        function text = status(testCase)
            text = string(testCase.Dialog.widgets.OpenAIStatusLabel.Text);
        end
    end
end
