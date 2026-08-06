classdef DeploymentCompatibilityTest < matlab.unittest.TestCase
    %DEPLOYMENTCOMPATIBILITYTEST Contracts exercised by the standalone app.

    methods (TestClassSetup)
        function configureKssolvPaths(~)
            addpath(fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "+kssolv", "+core", "kssolv-3o"));
            KSSOLV.startup();
        end
    end

    methods (Test)
        function helpMenuPlacesLogImmediatelyAfterUpdate(testCase)
            kssolv.ui.util.DataStorage.setData( ...
                "Project", kssolv.services.filemanager.Project());
            homeTab = kssolv.ui.components.tab.HomeTab();
            popup = homeTab.Widgets.ResourceSection.ResourceHelpButton.Popup;

            testCase.verifyEqual(popup.getChildByIndex(4), ...
                homeTab.Widgets.ResourceSection.CheckUpdateListItem);
            testCase.verifyEqual(popup.getChildByIndex(5), ...
                homeTab.Widgets.ResourceSection.OpenLogsListItem);
            testCase.verifyEqual( ...
                string(homeTab.Widgets.ResourceSection.OpenLogsListItem.Text), ...
                string(kssolv.ui.util.Localizer.message( ...
                "KSSOLV:toolbox:OpenLogsListItemLabel")));
        end

        function settingsUsesMaskedEditFieldWithVisibilityToggle(testCase)
            dialog = kssolv.ui.components.dialog.SettingsDialog();
            cleanup = onCleanup(@() delete(dialog));
            metadata = metaclass(dialog);

            testCase.verifyTrue(any(strcmp( ...
                {metadata.SuperclassList.Name}, ...
                'controllib.ui.internal.dialog.AbstractDialog')));
            testCase.verifyClass(dialog.widgets.OpenAIAPIKeyText, ...
                'matlab.ui.control.EditField');
            testCase.verifyClass( ...
                dialog.widgets.OpenAIAPIKeyVisibilityButton, ...
                'matlab.ui.control.Button');

            editField = dialog.widgets.OpenAIAPIKeyText;
            editField.Value = 'sk-test-key';
            valueChangedCallback = editField.ValueChangedFcn;
            valueChangedCallback(editField, []);
            testCase.verifyEqual(editField.Value, 'sk-******');

            visibilityButton = ...
                dialog.widgets.OpenAIAPIKeyVisibilityButton;
            buttonPushedCallback = visibilityButton.ButtonPushedFcn;
            buttonPushedCallback(visibilityButton, []);
            testCase.verifyEqual(editField.Value, 'sk-test-key');
            buttonPushedCallback(visibilityButton, []);
            testCase.verifyEqual(editField.Value, 'sk-******');
            clear cleanup
        end

        function settingsUsesEncryptedCredentialStore(testCase)
            source = fileread(which('kssolv.settings.Settings'));
            testCase.verifyTrue(contains(source, ...
                'kssolv.settings.EncryptedStore'));
        end

    end
end
