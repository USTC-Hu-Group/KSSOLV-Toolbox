classdef SettingsDialog < controllib.ui.internal.dialog.AbstractDialog
    %SETTINGSDIALOG 设置对话框

    % 开发者：杨柳
    % 版权 2025 合肥瀚海量子科技有限公司

    properties (SetAccess = private)
        widgets
        dialogOptions
    end

    properties (SetAccess = private, GetAccess = ?matlab.unittest.TestCase)
        dialogLayout
        tabGroup
    end

    properties (Access = private)
        width = 680
        height = 550

        availableLanguageOptions = {'简体中文', 'English'}
        availableLanguageOptionsData = {'zh_CN', 'en_US'}

        availableLLMType = {'Ollama', 'OpenAICompatible'}
        availableLLMModels = {'deepseek-r1:7b', 'qwen2.5:7b'}
    end

    methods
        function this = SettingsDialog()
            %SETTINGSDIALOG 设置对话框构造函数
            import kssolv.ui.util.Localizer.*

            % 对话框标题
            this.Title = message('KSSOLV:dialogs:SettingsDialogName');
            this.CloseMode = 'hide';

            % 重载 close 方法
            fig = this.getWidget();
            fig.CloseRequestFcn = @(src, event) close(this);
        end

        function close(this)
            %CLOSE 重载 close 方法
            close@controllib.ui.internal.dialog.AbstractDialog(this);
            data = struct('KSSOLVOptions', this.dialogOptions);
            event = matlab.ui.internal.databrowser.GenericEventData(data);
            this.notify('CloseEvent', event);
        end
    end

    methods (Access = protected)
        function buildUI(this)
            %BUILDUI 构建对话框的控件和布局

            % 设置对话框的尺寸
            fig = this.getWidget;
            fig.Position(3:4) = [this.width this.height];

            % 对话框 layout
            this.dialogLayout = uigridlayout(fig, "Scrollable", "off");
            this.dialogLayout.RowHeight = {'fit', '1x', 'fit'};
            this.dialogLayout.ColumnWidth = {'1x'};

            % Tab 组
            this.tabGroup = uitabgroup(this.dialogLayout);
            this.tabGroup.Layout.Row = [1 2];
            this.tabGroup.Layout.Column = 1;

            % 构建 Tabs
            buildGeneralTab(this);

            % 控制控件默认条件下的显示和启用
            % enableWidgets(this);

            % 底部的 Button 组
            createButtonPanel(this);
        end

        function buildGeneralTab(this)
            %BUILDGENERALTAB 构建通用选项 tab 页
            import kssolv.ui.util.Localizer.*

            generalTab = uitab(this.tabGroup, ...
                'Title', message('KSSOLV:dialogs:SettingsDialogGeneralTabName'), ...
                "Scrollable", "off");

            % Tab layout
            generalTabLayout = uigridlayout(generalTab, [2, 2], "Scrollable", "on");
            generalTabLayout.RowHeight = {'fit', '1x'};
            generalTabLayout.ColumnWidth = {'fit', '1x'};
            generalTabLayout.RowSpacing = 0;

            %% 添加语言选项面板
            languageSettingPanel = uipanel(generalTabLayout, "Title", ...
                message('KSSOLV:dialogs:SettingsDialogGeneralTabLanguagePanelName'), ...
                "FontWeight", "bold", "BorderType", "none", "Scrollable", "off");
            languageSettingPanel.Layout.Row = 1;
            languageSettingPanel.Layout.Column = [1 2];

            % 添加语言选择控件 layout
            languageDropdownLayout = uigridlayout(languageSettingPanel, ...
                [2 2], "Scrollable", 'off');
            languageDropdownLayout.RowHeight = {'fit', 'fit'};
            languageDropdownLayout.ColumnWidth = {'fit', 'fit'};

            % 语言选项 label & dropdown
            languageLabel = uilabel(languageDropdownLayout, "Text", ...
                message('KSSOLV:dialogs:SettingsDialogGeneralTabLanguageLabel'));
            languageLabel.Layout.Row = 1;
            languageLabel.Layout.Column = 1;

            languageDropdown = uidropdown(languageDropdownLayout, ...
                "Items", this.availableLanguageOptions, ...
                'ItemsData', this.availableLanguageOptionsData, "Interruptible", "off");
            languageDropdown.Value = kssolv.ui.util.Localizer.getInstance().currentLocale;
            languageDropdown.Layout.Row = 1;
            languageDropdown.Layout.Column = 2;

            % 与语言选项更改相关的描述文字
            languageDropdownNote = uilabel(languageDropdownLayout, ...
                "Text", message('KSSOLV:dialogs:SettingsDialogGeneralTabLanguageNote'), ...
                "FontAngle", "italic", "WordWrap", "on");
            languageDropdownNote.Layout.Row = 2;
            languageDropdownNote.Layout.Column = 2;

            %% 添加大语言模型面板
            LLMSettingPanel = uipanel(generalTabLayout, "Title", ...
                message('KSSOLV:dialogs:SettingsDialogGeneralTabLLMPanelName'), ...
                "FontWeight", "bold", "BorderType", "none", "Scrollable", "off");
            LLMSettingPanel.Layout.Row = 2;
            LLMSettingPanel.Layout.Column = [1 2];

            % 添加大语言模型 layout
            LLMLayout = uigridlayout(LLMSettingPanel, ...
                [3 1], "Scrollable", 'off');
            LLMLayout.RowHeight = {'fit', 'fit', 'fit'};
            LLMLayout.ColumnWidth = {'fit'};

            % 添加大语言模型类型选择 layout
            LLMTypeLayout = uigridlayout(LLMLayout, ...
                [1 2], "Scrollable", 'off');
            LLMTypeLayout.RowHeight = {'fit'};
            LLMTypeLayout.ColumnWidth = {'fit', 'fit'};

            % 大语言模型类型选项 label & dropdown
            LLMTypeLabel = uilabel(LLMTypeLayout, "Text", ...
                message('KSSOLV:dialogs:SettingsDialogGeneralTabLLMType'));
            LLMTypeLabel.Layout.Row = 1;
            LLMTypeLabel.Layout.Column = 1;

            LLMTypeDropdown = uidropdown(LLMTypeLayout, ...
                "Items", this.availableLLMType, "Interruptible", "off");
            LLMTypeDropdown.Value = this.availableLLMType{1};
            LLMTypeDropdown.Layout.Row = 1;
            LLMTypeDropdown.Layout.Column = 2;

            % 添加 Ollama 大模型 layout
            OllamaLayout = uigridlayout(LLMLayout, ...
                [3 4], "Scrollable", 'off');
            OllamaLayout.RowHeight = {'fit', 'fit', 'fit'};
            OllamaLayout.ColumnWidth = {'fit', 200, 'fit'};

            % Ollama 服务地址 label & uieditfield & icon
            OllamaServerURLLabel = uilabel(OllamaLayout, "Text", "Ollama Server URL");
            OllamaServerURLLabel.Layout.Row = 1;
            OllamaServerURLLabel.Layout.Column = 1;

            OllamaServerURLText = uieditfield(OllamaLayout, ...
                "Placeholder", "http://127.0.0.1:11434", "Value", "http://127.0.0.1:11434");
            OllamaServerURLText.Layout.Row = 1;
            OllamaServerURLText.Layout.Column = 2;

            OllamaServerURLConnectState = uiimage(OllamaLayout, "ImageSource", ...
                kssolv.ui.util.GetIcon('greenCheck.svg'), "Tooltip", "Ollama Connect State");
            OllamaServerURLConnectState.Layout.Row = 1;
            OllamaServerURLConnectState.Layout.Column = 3;

            % 大语言模型名称 label & dropdown & button
            LLMModelListLabel = uilabel(OllamaLayout, "Text", ...
                message('KSSOLV:dialogs:SettingsDialogGeneralTabLLMModelName'));
            LLMModelListLabel.Layout.Row = 2;
            LLMModelListLabel.Layout.Column = 1;

            LLMModelListDropdown = uidropdown(OllamaLayout,...
                "Items", this.availableLLMModels, "Interruptible", "off");
            LLMModelListDropdown.Value = this.availableLLMModels{1};
            LLMModelListDropdown.Layout.Row = 2;
            LLMModelListDropdown.Layout.Column = 2;

            LLMModelListFetchButton = uibutton(OllamaLayout, "Text", "", ...
                "Icon", kssolv.ui.util.GetIcon('refresh.svg'), "Tooltip", "Update Model List");
            LLMModelListFetchButton.Layout.Row = 2;
            LLMModelListFetchButton.Layout.Column = 3;

            % 添加到 Widgets
            this.widgets.GeneralTab = generalTab;
        end

        function createButtonPanel(this)
            %% 创建包含 HELP、OK 和 CANCEL 按钮的面板
            import kssolv.ui.util.Localizer.*

            % 按钮组 layout
            buttonGroupLayout = uigridlayout(this.dialogLayout, [1 4], "Scrollable", 'off');
            buttonGroupLayout.Layout.Row = 3;
            buttonGroupLayout.Layout.Column = 1;
            buttonGroupLayout.RowHeight = {'fit'};
            buttonGroupLayout.ColumnWidth = {'fit', '1x', 'fit', 'fit'};
            buttonGroupLayout.Padding = 0;

            % Help 按钮
            helpButton = uibutton(buttonGroupLayout, "Text", ...
                message('KSSOLV:dialogs:SettingsDialogHelpButtonText'));
            helpButton.ButtonPushedFcn = @(src, event) this.helpButtonClicked();
            helpButton.Layout.Row = 1;
            helpButton.Layout.Column = 1;

            % OK 按钮
            okButton = uibutton(buttonGroupLayout, "Text", ...
                message('KSSOLV:dialogs:SettingsDialogOKButtonText'));
            okButton.ButtonPushedFcn = @(src, event) this.okButtonClicked();
            okButton.Layout.Row = 1;
            okButton.Layout.Column = 3;

            % Cancel 按钮
            cancelButton = uibutton(buttonGroupLayout, "Text", ...
                message('KSSOLV:dialogs:SettingsDialogCancelButtonText'));
            cancelButton.ButtonPushedFcn = @(src, event) this.cancelButtonClicked();
            cancelButton.Layout.Row = 1;
            cancelButton.Layout.Column = 4;
        end
    end

    methods (Access = private)
        function helpButtonClicked(this)
            close(this);
        end

        function okButtonClicked(this)
            close(this);
        end

        function cancelButtonClicked(this)
            close(this);
        end
    end

    methods (Hidden, Static)
        function dialog = qeShow()
            % 用于在单元测试中测试 SettingsDialog
            % 示例命令：
            % kssolv.ui.components.dialog.SettingsDialog.qeShow

            dialog = kssolv.ui.components.dialog.SettingsDialog();
            dialog.show();
        end
    end
end

