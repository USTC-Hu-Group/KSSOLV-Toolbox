classdef SettingsDialog < controllib.ui.internal.dialog.AbstractDialog
    %SETTINGSDIALOG 配置界面语言和大语言模型服务。

    % 开发者：杨柳
    % 版权 2025-2026 合肥瀚海量子科技有限公司

    properties (SetAccess = private)
        widgets = struct()
        dialogOptions = struct()
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
        availableLLMType = {'OpenAICompatible', 'Ollama'}
        materialsProjectAPIURL = ...
            'https://next-gen.materialsproject.org/api'

        savedSettings = struct()
        pendingDialogOptions = struct()
        openAIAPIKey (1, 1) string = ""
        openAIAPIKeyVisible (1, 1) logical = false
        materialsProjectAPIKey (1, 1) string = ""
        materialsProjectAPIKeyVisible (1, 1) logical = false
        isClosing (1, 1) logical = false
        connectionTestFuture = []
        connectionTestCompletionFuture = []
        connectionTestProvider (1, 1) string = ""
        connectionTestToken (1, 1) uint64 = uint64(0)
    end

    methods
        function this = SettingsDialog()
            %SETTINGSDIALOG 构造设置对话框。
            import kssolv.ui.util.Localizer.message

            this.Title = message('KSSOLV:dialogs:SettingsDialogName');
            this.CloseMode = 'hide';
            this.savedSettings = kssolv.settings.Settings.load();

            fig = this.getWidget();
            fig.CloseRequestFcn = @(~, ~) this.cancelButtonClicked();
            this.loadSettingsIntoWidgets();
        end

        function show(this, varargin)
            %SHOW 每次打开时重新载入已保存值，丢弃上次未确认的编辑。
            this.stopConnectionTest(false);
            this.savedSettings = kssolv.settings.Settings.load();
            this.loadSettingsIntoWidgets();
            this.isClosing = false;
            this.pendingDialogOptions = struct();
            show@controllib.ui.internal.dialog.AbstractDialog(this, varargin{:});
        end

        function close(this)
            %CLOSE 由外部关闭时采用与“取消”一致的语义。
            if this.isClosing
                return
            end

            this.stopConnectionTest(false);
            if isempty(fieldnames(this.pendingDialogOptions))
                this.loadSettingsIntoWidgets();
                options = this.savedSettings;
                if isfield(options, 'OpenAIAPIKey')
                    options = rmfield(options, 'OpenAIAPIKey');
                end
                if isfield(options, 'MaterialsProjectAPIKey')
                    options = rmfield(options, 'MaterialsProjectAPIKey');
                end
                options.Applied = false;
                options.Action = 'cancel';
            else
                options = this.pendingDialogOptions;
            end

            this.isClosing = true;
            this.dialogOptions = options;
            close@controllib.ui.internal.dialog.AbstractDialog(this);

            data = struct('KSSOLVOptions', this.dialogOptions);
            event = matlab.ui.internal.databrowser.GenericEventData(data);
            this.notify('CloseEvent', event);
            this.pendingDialogOptions = struct();
        end
    end

    methods (Access = protected)
        function buildUI(this)
            %BUILDUI 构建对话框的控件和布局。
            fig = this.getWidget();
            fig.Position(3:4) = [this.width this.height];

            this.dialogLayout = uigridlayout(fig, [3 1], ...
                'Scrollable', 'off', ...
                'RowHeight', {0, '1x', 'fit'}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', [10 10 10 10]);

            this.tabGroup = uitabgroup(this.dialogLayout);
            this.tabGroup.Layout.Row = [1 2];
            this.tabGroup.Layout.Column = 1;

            this.buildGeneralTab();
            this.buildMaterialsProjectTab();
            this.createButtonPanel();
        end

        function buildGeneralTab(this)
            %BUILDGENERALTAB 构建通用设置页。
            import kssolv.ui.util.Localizer.message

            generalTab = uitab(this.tabGroup, ...
                'Title', message('KSSOLV:dialogs:SettingsDialogGeneralTabName'), ...
                'Scrollable', 'off');
            mainLayout = uigridlayout(generalTab, [2 1], ...
                'Scrollable', 'on', ...
                'RowHeight', {'fit', '1x'}, ...
                'ColumnWidth', {'1x'}, ...
                'RowSpacing', 8, ...
                'Padding', [10 10 10 10]);

            this.buildLanguagePanel(mainLayout);
            this.buildLLMPanel(mainLayout);
            this.widgets.GeneralTab = generalTab;
        end

        function buildMaterialsProjectTab(this)
            %BUILDMATERIALSPROJECTTAB 构建 Materials Project 设置页。
            import kssolv.ui.util.Localizer.message

            tab = uitab(this.tabGroup, ...
                'Title', message( ...
                'KSSOLV:dialogs:SettingsDialogMaterialsProjectTabName'), ...
                'Scrollable', 'off');
            layout = uigridlayout(tab, [4 3], ...
                'RowHeight', {24, 'fit', 'fit', '1x'}, ...
                'ColumnWidth', {145, '1x', 110}, ...
                'RowSpacing', 10, ...
                'Padding', [18 18 18 18]);

            apiKeyLabel = uilabel(layout, 'Text', message( ...
                'KSSOLV:dialogs:SettingsDialogMaterialsProjectAPIKey'));
            apiKeyLabel.Layout.Row = 1;
            apiKeyLabel.Layout.Column = 1;

            apiKey = uieditfield(layout, 'text', ...
                'Placeholder', message( ...
                'KSSOLV:dialogs:SettingsDialogMaterialsProjectKeyPlaceholder'), ...
                'ValueChangedFcn', ...
                @(src, ~) this.materialsProjectAPIKeyEditChanged(src));
            apiKey.Layout.Row = 1;
            apiKey.Layout.Column = 2;

            visibilityButton = uibutton(layout, ...
                'Text', '', ...
                'Icon', kssolv.ui.util.GetIcon('eye.svg'), ...
                'Tooltip', message( ...
                'KSSOLV:dialogs:SettingsDialogShowAPIKey'), ...
                'Interruptible', 'off', ...
                'ButtonPushedFcn', ...
                @(~, ~) this.toggleMaterialsProjectAPIKeyVisibility());
            visibilityButton.Layout.Row = 1;
            visibilityButton.Layout.Column = 3;

            dashboardButton = uibutton(layout, 'Text', message( ...
                'KSSOLV:dialogs:SettingsDialogMaterialsProjectOpenAPIPage'), ...
                'Interruptible', 'off', ...
                'ButtonPushedFcn', ...
                @(~, ~) this.openMaterialsProjectAPIPage());
            dashboardButton.Layout.Row = 2;
            dashboardButton.Layout.Column = [2 3];

            note = uilabel(layout, 'Text', message( ...
                'KSSOLV:dialogs:SettingsDialogMaterialsProjectKeyNote'), ...
                'FontAngle', 'italic', ...
                'FontColor', [0.35 0.35 0.35], ...
                'VerticalAlignment', 'top', ...
                'WordWrap', 'on');
            note.Layout.Row = 3;
            note.Layout.Column = [2 3];

            this.widgets.MaterialsProjectTab = tab;
            this.widgets.MaterialsProjectAPIKeyText = apiKey;
            this.widgets.MaterialsProjectAPIKeyVisibilityButton = ...
                visibilityButton;
            this.widgets.MaterialsProjectAPIPageButton = dashboardButton;
        end

        function buildLanguagePanel(this, parent)
            import kssolv.ui.util.Localizer.message

            panel = uipanel(parent, ...
                'Title', message('KSSOLV:dialogs:SettingsDialogGeneralTabLanguagePanelName'), ...
                'FontWeight', 'bold', 'BorderType', 'none');
            panel.Layout.Row = 1;

            layout = uigridlayout(panel, [2 2], ...
                'RowHeight', {'fit', 'fit'}, ...
                'ColumnWidth', {'fit', '1x'}, ...
                'Padding', [8 6 8 8]);

            label = uilabel(layout, 'Text', ...
                message('KSSOLV:dialogs:SettingsDialogGeneralTabLanguageLabel'));
            label.Layout.Row = 1;
            label.Layout.Column = 1;

            dropdown = uidropdown(layout, ...
                'Items', this.availableLanguageOptions, ...
                'ItemsData', this.availableLanguageOptionsData, ...
                'Interruptible', 'off');
            dropdown.Layout.Row = 1;
            dropdown.Layout.Column = 2;

            note = uilabel(layout, ...
                'Text', message('KSSOLV:dialogs:SettingsDialogGeneralTabLanguageNote'), ...
                'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35], ...
                'WordWrap', 'on');
            note.Layout.Row = 2;
            note.Layout.Column = 2;

            this.widgets.LanguageDropdown = dropdown;
        end

        function buildLLMPanel(this, parent)
            import kssolv.ui.util.Localizer.message

            panel = uipanel(parent, ...
                'Title', message('KSSOLV:dialogs:SettingsDialogGeneralTabLLMPanelName'), ...
                'FontWeight', 'bold', 'BorderType', 'none');
            panel.Layout.Row = 2;

            layout = uigridlayout(panel, [2 1], ...
                'RowHeight', {'fit', '1x'}, ...
                'ColumnWidth', {'1x'}, ...
                'RowSpacing', 8, ...
                'Padding', [8 6 8 8]);

            typeLayout = uigridlayout(layout, [1 2], ...
                'RowHeight', {'fit'}, ...
                'ColumnWidth', {150, '1x'}, ...
                'Padding', 0);
            typeLayout.Layout.Row = 1;
            uilabel(typeLayout, 'Text', ...
                message('KSSOLV:dialogs:SettingsDialogGeneralTabLLMType'));
            typeDropdown = uidropdown(typeLayout, ...
                'Items', this.availableLLMType, ...
                'Interruptible', 'off', ...
                'ValueChangedFcn', @(~, ~) this.llmTypeChanged());
            typeDropdown.Layout.Column = 2;

            providerContainer = uipanel(layout, 'BorderType', 'none');
            providerContainer.Layout.Row = 2;
            providerLayout = uigridlayout(providerContainer, [1 1], ...
                'RowHeight', {'1x'}, 'ColumnWidth', {'1x'}, 'Padding', 0);

            ollamaPanel = this.buildOllamaPanel(providerLayout);
            openAIPanel = this.buildOpenAIPanel(providerLayout);

            this.widgets.LLMTypeDropdown = typeDropdown;
            this.widgets.OllamaPanel = ollamaPanel;
            this.widgets.OpenAIPanel = openAIPanel;
        end

        function panel = buildOllamaPanel(this, parent)
            import kssolv.ui.util.Localizer.message

            panel = uipanel(parent, 'BorderType', 'none');
            panel.Layout.Row = 1;
            panel.Layout.Column = 1;
            layout = uigridlayout(panel, [4 4], ...
                'RowHeight', {'fit', 'fit', 'fit', '1x'}, ...
                'ColumnWidth', {150, '1x', 30, 95}, ...
                'Padding', 0);

            serverLabel = uilabel(layout, 'Text', ...
                message('KSSOLV:dialogs:SettingsDialogOllamaServerURL'));
            serverLabel.Layout.Row = 1;
            serverLabel.Layout.Column = 1;
            serverURL = uieditfield(layout, 'text', ...
                'Placeholder', 'http://127.0.0.1:11434', ...
                'ValueChangedFcn', @(~, ~) this.resetConnectionState('Ollama'));
            serverURL.Layout.Row = 1;
            serverURL.Layout.Column = 2;
            testButton = uibutton(layout, 'Text', ...
                message('KSSOLV:dialogs:SettingsDialogTestConnection'), ...
                'Interruptible', 'off', ...
                'ButtonPushedFcn', @(~, ~) this.toggleConnectionTest('Ollama'));
            testButton.Layout.Row = 1;
            testButton.Layout.Column = [3 4];

            modelLabel = uilabel(layout, 'Text', ...
                message('KSSOLV:dialogs:SettingsDialogGeneralTabLLMModelName'));
            modelLabel.Layout.Row = 2;
            modelLabel.Layout.Column = 1;
            modelDropdown = uidropdown(layout, 'Editable', 'on', 'Interruptible', 'off');
            modelDropdown.Layout.Row = 2;
            modelDropdown.Layout.Column = 2;
            refreshButton = uibutton(layout, 'Text', '', ...
                'Icon', kssolv.ui.util.GetIcon('refresh.svg'), ...
                'Tooltip', message('KSSOLV:dialogs:SettingsDialogRefreshModels'), ...
                'Interruptible', 'off', ...
                'ButtonPushedFcn', @(~, ~) this.refreshModels('Ollama'));
            refreshButton.Layout.Row = 2;
            refreshButton.Layout.Column = 3;

            [statusIcon, statusLabel] = this.createStatusWidgets(layout);

            note = uilabel(layout, ...
                'Text', message('KSSOLV:dialogs:SettingsDialogOllamaNote'), ...
                'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35], ...
                'VerticalAlignment', 'top', 'WordWrap', 'on');
            note.Layout.Row = 4;
            note.Layout.Column = [2 4];

            this.widgets.OllamaServerURLText = serverURL;
            this.widgets.OllamaModelDropdown = modelDropdown;
            this.widgets.OllamaRefreshButton = refreshButton;
            this.widgets.OllamaTestButton = testButton;
            this.widgets.OllamaStatusIcon = statusIcon;
            this.widgets.OllamaStatusLabel = statusLabel;
        end

        function panel = buildOpenAIPanel(this, parent)
            import kssolv.ui.util.Localizer.message

            panel = uipanel(parent, 'BorderType', 'none');
            panel.Layout.Row = 1;
            panel.Layout.Column = 1;
            layout = uigridlayout(panel, [5 4], ...
                'RowHeight', {'fit', 24, 'fit', 'fit', '1x'}, ...
                'ColumnWidth', {150, '1x', 30, 95}, ...
                'Padding', 0);

            baseURLLabel = uilabel(layout, 'Text', ...
                message('KSSOLV:dialogs:SettingsDialogOpenAIBaseURL'));
            baseURLLabel.Layout.Row = 1;
            baseURLLabel.Layout.Column = 1;
            baseURL = uieditfield(layout, 'text', ...
                'Placeholder', 'https://api.openai.com/v1', ...
                'ValueChangedFcn', @(~, ~) this.resetConnectionState('OpenAI'));
            baseURL.Layout.Row = 1;
            baseURL.Layout.Column = 2;

            apiKeyLabel = uilabel(layout, 'Text', ...
                message('KSSOLV:dialogs:SettingsDialogOpenAIAPIKey'));
            apiKeyLabel.Layout.Row = 2;
            apiKeyLabel.Layout.Column = 1;
            apiKey = uieditfield(layout, 'text', ...
                'Placeholder', 'sk-...', ...
                'ValueChangedFcn', ...
                @(src, ~) this.apiKeyEditChanged(src));
            apiKey.Layout.Row = 2;
            apiKey.Layout.Column = 2;
            apiKeyVisibilityButton = uibutton(layout, ...
                'Text', '', ...
                'Icon', kssolv.ui.util.GetIcon('eye.svg'), ...
                'Tooltip', ...
                message('KSSOLV:dialogs:SettingsDialogShowAPIKey'), ...
                'Interruptible', 'off', ...
                'ButtonPushedFcn', ...
                @(~, ~) this.toggleAPIKeyVisibility());
            apiKeyVisibilityButton.Layout.Row = 2;
            apiKeyVisibilityButton.Layout.Column = 3;
            testButton = uibutton(layout, 'Text', ...
                message('KSSOLV:dialogs:SettingsDialogTestConnection'), ...
                'Interruptible', 'off', ...
                'ButtonPushedFcn', @(~, ~) this.toggleConnectionTest('OpenAI'));
            testButton.Layout.Row = 2;
            testButton.Layout.Column = 4;

            modelLabel = uilabel(layout, 'Text', ...
                message('KSSOLV:dialogs:SettingsDialogGeneralTabLLMModelName'));
            modelLabel.Layout.Row = 3;
            modelLabel.Layout.Column = 1;
            modelDropdown = uidropdown(layout, 'Editable', 'on', 'Interruptible', 'off');
            modelDropdown.Layout.Row = 3;
            modelDropdown.Layout.Column = 2;
            refreshButton = uibutton(layout, 'Text', '', ...
                'Icon', kssolv.ui.util.GetIcon('refresh.svg'), ...
                'Tooltip', message('KSSOLV:dialogs:SettingsDialogRefreshModels'), ...
                'Interruptible', 'off', ...
                'ButtonPushedFcn', @(~, ~) this.refreshModels('OpenAI'));
            refreshButton.Layout.Row = 3;
            refreshButton.Layout.Column = 3;

            [statusIcon, statusLabel] = this.createStatusWidgets(layout);
            statusIcon.Layout.Row = 4;
            statusLabel.Layout.Row = 4;

            note = uilabel(layout, ...
                'Text', message('KSSOLV:dialogs:SettingsDialogOpenAIKeyNote'), ...
                'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35], ...
                'VerticalAlignment', 'top', 'WordWrap', 'on');
            note.Layout.Row = 5;
            note.Layout.Column = [2 4];

            this.widgets.OpenAIBaseURLText = baseURL;
            this.widgets.OpenAIAPIKeyText = apiKey;
            this.widgets.OpenAIAPIKeyVisibilityButton = ...
                apiKeyVisibilityButton;
            this.widgets.OpenAIModelDropdown = modelDropdown;
            this.widgets.OpenAIRefreshButton = refreshButton;
            this.widgets.OpenAITestButton = testButton;
            this.widgets.OpenAIStatusIcon = statusIcon;
            this.widgets.OpenAIStatusLabel = statusLabel;
        end

        function [icon, label] = createStatusWidgets(~, parent)
            icon = uiimage(parent, 'Visible', 'off', ...
                'ScaleMethod', 'fit', 'Tooltip', '');
            icon.Layout.Row = 3;
            icon.Layout.Column = 3;
            label = uilabel(parent, 'Text', '', 'WordWrap', 'on');
            label.Layout.Row = 3;
            label.Layout.Column = 2;
        end

        function createButtonPanel(this)
            import kssolv.ui.util.Localizer.message

            layout = uigridlayout(this.dialogLayout, [1 4], ...
                'RowHeight', {'fit'}, ...
                'ColumnWidth', {'fit', '1x', 'fit', 'fit'}, ...
                'Padding', 0);
            layout.Layout.Row = 3;

            helpButton = uibutton(layout, 'Text', ...
                message('KSSOLV:dialogs:SettingsDialogHelpButtonText'), ...
                'ButtonPushedFcn', @(~, ~) this.helpButtonClicked());
            helpButton.Layout.Column = 1;
            okButton = uibutton(layout, 'Text', ...
                message('KSSOLV:dialogs:SettingsDialogOKButtonText'), ...
                'ButtonPushedFcn', @(~, ~) this.okButtonClicked());
            okButton.Layout.Column = 3;
            cancelButton = uibutton(layout, 'Text', ...
                message('KSSOLV:dialogs:SettingsDialogCancelButtonText'), ...
                'ButtonPushedFcn', @(~, ~) this.cancelButtonClicked());
            cancelButton.Layout.Column = 4;

            this.widgets.HelpButton = helpButton;
            this.widgets.OKButton = okButton;
            this.widgets.CancelButton = cancelButton;
        end
    end

    methods (Access = private)
        function loadSettingsIntoWidgets(this)
            if ~isfield(this.widgets, 'LanguageDropdown')
                return
            end

            settings = this.savedSettings;
            locale = char(settings.Locale);
            if ~ismember(locale, this.availableLanguageOptionsData)
                locale = kssolv.ui.util.Localizer.getInstance().currentLocale;
            end
            this.widgets.LanguageDropdown.Value = locale;

            llmType = char(settings.LLMType);
            if ~ismember(llmType, this.availableLLMType)
                llmType = this.availableLLMType{1};
            end
            this.widgets.LLMTypeDropdown.Value = llmType;
            this.widgets.OllamaServerURLText.Value = char(settings.OllamaServerURL);
            this.setDropdownModels(this.widgets.OllamaModelDropdown, ...
                settings.OllamaModels, settings.OllamaModel);
            this.widgets.OpenAIBaseURLText.Value = char(settings.OpenAIBaseURL);
            this.openAIAPIKey = settings.OpenAIAPIKey;
            this.openAIAPIKeyVisible = false;
            this.updateAPIKeyDisplay();
            this.materialsProjectAPIKey = ...
                settings.MaterialsProjectAPIKey;
            this.materialsProjectAPIKeyVisible = false;
            this.updateMaterialsProjectAPIKeyDisplay();
            this.setDropdownModels(this.widgets.OpenAIModelDropdown, ...
                settings.OpenAIModels, settings.OpenAIModel);

            this.resetConnectionState('Ollama');
            this.resetConnectionState('OpenAI');
            this.llmTypeChanged();
        end

        function settings = getSettingsFromWidgets(this)
            settings = this.savedSettings;
            settings.Locale = string(this.widgets.LanguageDropdown.Value);
            settings.LLMType = string(this.widgets.LLMTypeDropdown.Value);
            settings.OllamaServerURL = string(this.widgets.OllamaServerURLText.Value);
            settings.OllamaModel = string(this.widgets.OllamaModelDropdown.Value);
            settings.OllamaModels = this.widgets.OllamaModelDropdown.Items;
            settings.OpenAIBaseURL = string(this.widgets.OpenAIBaseURLText.Value);
            settings.OpenAIAPIKey = this.openAIAPIKey;
            settings.MaterialsProjectAPIKey = ...
                this.materialsProjectAPIKey;
            settings.OpenAIModel = string(this.widgets.OpenAIModelDropdown.Value);
            settings.OpenAIModels = this.widgets.OpenAIModelDropdown.Items;
        end

        function llmTypeChanged(this)
            isOllama = strcmp(this.widgets.LLMTypeDropdown.Value, 'Ollama');
            selectedProvider = "OpenAI";
            if isOllama
                selectedProvider = "Ollama";
            end
            if strlength(this.connectionTestProvider) > 0 && ...
                    this.connectionTestProvider ~= selectedProvider
                this.stopConnectionTest(false);
            end
            this.widgets.OllamaPanel.Visible = this.onOff(isOllama);
            this.widgets.OpenAIPanel.Visible = this.onOff(~isOllama);
        end

        function toggleConnectionTest(this, provider)
            if this.isConnectionTestRunning(provider)
                this.stopConnectionTest(true);
            else
                this.refreshModels(provider);
            end
        end

        function refreshModels(this, provider)
            import kssolv.ui.util.Localizer.message

            this.stopConnectionTest(false);
            try
                [url, apiKey] = this.getConnectionTestParameters(provider);
            catch exception
                detail = message( ...
                    'KSSOLV:dialogs:SettingsDialogConnectionUnexpectedError');
                if startsWith(exception.identifier, 'KSSOLV:SettingsDialog:')
                    detail = exception.message;
                end
                this.setConnectionState(provider, 'failure', detail);
                return
            end

            this.connectionTestToken = this.connectionTestToken + 1;
            token = this.connectionTestToken;
            this.connectionTestProvider = string(provider);
            this.setConnectionTestRunning(provider, true);
            this.setConnectionState(provider, 'checking', ...
                message('KSSOLV:dialogs:SettingsDialogConnectionChecking'));
            drawnow;

            future = [];
            try
                future = parfeval(backgroundPool, ...
                    @kssolv.ui.components.dialog.SettingsDialog.fetchModels, ...
                    1, provider, url, apiKey);
                this.connectionTestFuture = future;
                this.connectionTestCompletionFuture = afterEach(future, ...
                    @(completedFuture) this.connectionTestFinished( ...
                    completedFuture, token, provider, url), ...
                    0, PassFuture = true);
            catch exception
                this.cancelFuture(future);
                this.connectionTestFuture = [];
                this.connectionTestCompletionFuture = [];
                this.connectionTestProvider = "";
                this.setConnectionTestRunning(provider, false);
                this.setConnectionState(provider, 'failure', ...
                    this.localizedConnectionError(exception));
            end
        end

        function [url, apiKey] = getConnectionTestParameters(this, provider)
            import kssolv.ui.util.Localizer.message

            apiKey = "";
            if strcmp(provider, 'Ollama')
                url = this.validateURL(this.widgets.OllamaServerURLText.Value);
                return
            end

            url = this.validateOpenAIBaseURL( ...
                this.widgets.OpenAIBaseURLText.Value);
            apiKey = strip(this.openAIAPIKey);
            if strlength(apiKey) == 0
                error('KSSOLV:SettingsDialog:MissingAPIKey', ...
                    '%s', message('KSSOLV:dialogs:SettingsDialogAPIKeyRequired'));
            end
        end

        function connectionTestFinished(this, future, token, provider, url)
            if token ~= this.connectionTestToken || ...
                    this.connectionTestProvider ~= string(provider)
                return
            end

            try
                [state, detail] = ...
                    this.connectionTestResult(future, provider, url);
            catch
                state = 'failure';
                detail = kssolv.ui.util.Localizer.message( ...
                    'KSSOLV:dialogs:SettingsDialogConnectionUnexpectedError');
            end

            this.connectionTestFuture = [];
            this.connectionTestCompletionFuture = [];
            this.connectionTestProvider = "";
            this.setConnectionTestRunning(provider, false);
            this.setConnectionState(provider, state, detail);
        end

        function [state, detail] = connectionTestResult(this, future, provider, url)
            import kssolv.ui.util.Localizer.message

            state = 'failure';
            if ~isempty(future.Error)
                exception = future.Error;
                if iscell(exception)
                    exception = exception{1};
                end
                detail = this.localizedConnectionError(exception);
                return
            end

            try
                models = future.OutputArguments{1};
                if isempty(models)
                    error('KSSOLV:SettingsDialog:NoModels', ...
                        '%s', message('KSSOLV:dialogs:SettingsDialogNoModelsFound'));
                end
                if strcmp(provider, 'OpenAI')
                    cacheProvider = 'OpenAICompatible';
                    dropdown = this.widgets.OpenAIModelDropdown;
                else
                    cacheProvider = provider;
                    dropdown = this.widgets.OllamaModelDropdown;
                end
                try
                    kssolv.settings.Settings.cacheModels( ...
                        cacheProvider, url, models);
                catch
                    % 缓存失败不影响连接测试结果和本次模型列表。
                end
                this.setDropdownModels(dropdown, models, dropdown.Value);
                state = 'success';
                detail = sprintf('%s (%d)', message( ...
                    'KSSOLV:dialogs:SettingsDialogConnectionSucceeded'), numel(models));
            catch exception
                if strcmp(exception.identifier, 'KSSOLV:SettingsDialog:NoModels')
                    detail = exception.message;
                else
                    detail = message( ...
                        'KSSOLV:dialogs:SettingsDialogInvalidServiceResponse');
                end
            end
        end

        function detail = localizedConnectionError(~, exception)
            import kssolv.ui.util.Localizer.message

            identifiers = ...
                kssolv.ui.components.dialog.SettingsDialog.exceptionIdentifiers(exception);
            combinedIdentifiers = char(join(identifiers, ' '));
            statusToken = regexp(combinedIdentifiers, ...
                'HTTP(\d{3})StatusCodeError', 'tokens', 'once');
            if ~isempty(statusToken)
                statusCode = str2double(statusToken{1});
                switch statusCode
                    case {401, 403}
                        detail = message( ...
                            'KSSOLV:dialogs:SettingsDialogAuthenticationFailed');
                    case 404
                        detail = message( ...
                            'KSSOLV:dialogs:SettingsDialogEndpointNotFound');
                    case 429
                        detail = message( ...
                            'KSSOLV:dialogs:SettingsDialogRateLimited');
                    otherwise
                        detail = sprintf(message( ...
                            'KSSOLV:dialogs:SettingsDialogHTTPError'), statusCode);
                end
                return
            end

            normalizedIdentifiers = lower(identifiers);
            if any(contains(normalizedIdentifiers, ["timeout", "timedout"]))
                detail = message( ...
                    'KSSOLV:dialogs:SettingsDialogConnectionTimedOut');
            elseif any(contains(normalizedIdentifiers, ...
                    ["contenttypereader", "contenttypemismatch", ...
                    "invalidjson", "json"]))
                detail = message( ...
                    'KSSOLV:dialogs:SettingsDialogInvalidServiceResponse');
            elseif any(contains(normalizedIdentifiers, ...
                    ["certificate", "ssl", "tls"]))
                detail = message( ...
                    'KSSOLV:dialogs:SettingsDialogSecureConnectionFailed');
            elseif any(contains(normalizedIdentifiers, ...
                    ["connection", "resolvehost", "resolvehostname", ...
                    "network", "couldntresolve"]))
                detail = message( ...
                    'KSSOLV:dialogs:SettingsDialogConnectionFailed');
            else
                detail = message( ...
                    'KSSOLV:dialogs:SettingsDialogConnectionUnexpectedError');
            end
        end

        function stopConnectionTest(this, showStatus)
            import kssolv.ui.util.Localizer.message

            provider = this.connectionTestProvider;
            requestFuture = this.connectionTestFuture;
            completionFuture = this.connectionTestCompletionFuture;

            this.connectionTestToken = this.connectionTestToken + 1;
            this.connectionTestFuture = [];
            this.connectionTestCompletionFuture = [];
            this.connectionTestProvider = "";

            this.cancelFuture(completionFuture);
            this.cancelFuture(requestFuture);

            if strlength(provider) == 0
                return
            end
            this.setConnectionTestRunning(char(provider), false);
            if showStatus
                this.setConnectionState(char(provider), 'stopped', ...
                    message('KSSOLV:dialogs:SettingsDialogConnectionStopped'));
            else
                this.widgets.([char(provider) 'StatusIcon']).Visible = 'off';
                this.widgets.([char(provider) 'StatusLabel']).Text = '';
            end
        end

        function setConnectionTestRunning(this, provider, isRunning)
            import kssolv.ui.util.Localizer.message

            refreshButton = this.widgets.([provider 'RefreshButton']);
            testButton = this.widgets.([provider 'TestButton']);
            refreshButton.Enable = this.onOff(~isRunning);
            testButton.Enable = 'on';
            if isRunning
                testButton.Text = message('KSSOLV:dialogs:SettingsDialogStopTest');
            else
                testButton.Text = message('KSSOLV:dialogs:SettingsDialogTestConnection');
            end
        end

        function running = isConnectionTestRunning(this, provider)
            running = strlength(this.connectionTestProvider) > 0 && ...
                this.connectionTestProvider == string(provider) && ...
                ~isempty(this.connectionTestFuture);
        end

        function resetConnectionState(this, provider)
            if ~isfield(this.widgets, [provider 'StatusIcon'])
                return
            end
            if this.isConnectionTestRunning(provider)
                this.stopConnectionTest(false);
            end
            this.widgets.([provider 'StatusIcon']).Visible = 'off';
            this.widgets.([provider 'StatusLabel']).Text = '';
        end

        function apiKeyEditChanged(this, editField)
            editedValue = string(editField.Value);
            if ~this.openAIAPIKeyVisible && ...
                    editedValue == this.maskedAPIKey() && ...
                    strlength(this.openAIAPIKey) > 0
                return
            end
            this.openAIAPIKey = editedValue;
            this.openAIAPIKeyVisible = false;
            this.updateAPIKeyDisplay();
            this.resetConnectionState('OpenAI');
        end

        function toggleAPIKeyVisibility(this)
            this.openAIAPIKeyVisible = ~this.openAIAPIKeyVisible;
            this.updateAPIKeyDisplay();
        end

        function updateAPIKeyDisplay(this)
            import kssolv.ui.util.Localizer.message

            if this.openAIAPIKeyVisible
                displayedValue = this.openAIAPIKey;
                iconName = 'eyeOff.svg';
                tooltip = message( ...
                    'KSSOLV:dialogs:SettingsDialogHideAPIKey');
            else
                displayedValue = "";
                if strlength(this.openAIAPIKey) > 0
                    displayedValue = this.maskedAPIKey();
                end
                iconName = 'eye.svg';
                tooltip = message( ...
                    'KSSOLV:dialogs:SettingsDialogShowAPIKey');
            end

            this.widgets.OpenAIAPIKeyText.Value = char(displayedValue);
            this.widgets.OpenAIAPIKeyVisibilityButton.Icon = ...
                kssolv.ui.util.GetIcon(iconName);
            this.widgets.OpenAIAPIKeyVisibilityButton.Tooltip = tooltip;
        end

        function materialsProjectAPIKeyEditChanged(this, editField)
            editedValue = string(editField.Value);
            if ~this.materialsProjectAPIKeyVisible && ...
                    editedValue == this.maskedMaterialsProjectAPIKey() && ...
                    strlength(this.materialsProjectAPIKey) > 0
                return
            end
            this.materialsProjectAPIKey = editedValue;
            this.materialsProjectAPIKeyVisible = false;
            this.updateMaterialsProjectAPIKeyDisplay();
        end

        function toggleMaterialsProjectAPIKeyVisibility(this)
            this.materialsProjectAPIKeyVisible = ...
                ~this.materialsProjectAPIKeyVisible;
            this.updateMaterialsProjectAPIKeyDisplay();
        end

        function updateMaterialsProjectAPIKeyDisplay(this)
            import kssolv.ui.util.Localizer.message

            if this.materialsProjectAPIKeyVisible
                displayedValue = this.materialsProjectAPIKey;
                iconName = 'eyeOff.svg';
                tooltip = message( ...
                    'KSSOLV:dialogs:SettingsDialogHideAPIKey');
            else
                displayedValue = "";
                if strlength(this.materialsProjectAPIKey) > 0
                    displayedValue = this.maskedMaterialsProjectAPIKey();
                end
                iconName = 'eye.svg';
                tooltip = message( ...
                    'KSSOLV:dialogs:SettingsDialogShowAPIKey');
            end

            this.widgets.MaterialsProjectAPIKeyText.Value = ...
                char(displayedValue);
            this.widgets.MaterialsProjectAPIKeyVisibilityButton.Icon = ...
                kssolv.ui.util.GetIcon(iconName);
            this.widgets.MaterialsProjectAPIKeyVisibilityButton.Tooltip = ...
                tooltip;
        end

        function openMaterialsProjectAPIPage(this)
            import kssolv.ui.util.Localizer.message
            try
                web(this.materialsProjectAPIURL, '-browser');
            catch
                uialert(this.getWidget(), message( ...
                    'KSSOLV:dialogs:SettingsDialogMaterialsProjectOpenFailed'), ...
                    message( ...
                    ['KSSOLV:dialogs:' ...
                    'SettingsDialogMaterialsProjectOpenErrorTitle']));
            end
        end

        function setConnectionState(this, provider, state, detail)
            icon = this.widgets.([provider 'StatusIcon']);
            label = this.widgets.([provider 'StatusLabel']);
            switch state
                case 'success'
                    icon.ImageSource = kssolv.ui.util.GetIcon('greenCheck.svg');
                    label.FontColor = [0.10 0.45 0.15];
                otherwise
                    icon.ImageSource = kssolv.ui.util.GetIcon('warning.svg');
                    if strcmp(state, 'failure')
                        label.FontColor = [0.75 0.15 0.10];
                    else
                        label.FontColor = [0.35 0.35 0.35];
                    end
            end
            icon.Tooltip = detail;
            icon.Visible = 'on';
            label.Text = detail;
        end

        function okButtonClicked(this)
            import kssolv.ui.util.Localizer.message

            try
                settings = this.getSettingsFromWidgets();
                this.validateSettings(settings);
            catch exception
                detail = message('KSSOLV:dialogs:SettingsDialogInvalidSettings');
                if startsWith(exception.identifier, 'KSSOLV:SettingsDialog:')
                    detail = exception.message;
                end
                uialert(this.getWidget(), detail, ...
                    message('KSSOLV:dialogs:SettingsDialogValidationTitle'));
                return
            end

            try
                kssolv.settings.Settings.save(settings);
            catch
                uialert(this.getWidget(), ...
                    message('KSSOLV:dialogs:SettingsDialogSaveFailed'), ...
                    message('KSSOLV:dialogs:SettingsDialogSaveErrorTitle'));
                return
            end

            this.savedSettings = settings;
            % 已应用新的服务或模型后，下一次提问创建新的聊天对象，避免
            % 继续使用旧端点和旧模型。
            commandWindow = ...
                kssolv.ui.util.DataStorage.getData('CommandWindow');
            if ~isempty(commandWindow) && isvalid(commandWindow)
                commandWindow.ChatBot = [];
            end
            publicSettings = rmfield(settings, 'OpenAIAPIKey');
            publicSettings = rmfield( ...
                publicSettings, 'MaterialsProjectAPIKey');
            publicSettings.Applied = true;
            publicSettings.Action = 'ok';
            this.finishClose(publicSettings);
        end

        function cancelButtonClicked(this)
            if this.isClosing
                return
            end
            this.stopConnectionTest(false);
            this.loadSettingsIntoWidgets();
            options = this.savedSettings;
            if isfield(options, 'OpenAIAPIKey')
                options = rmfield(options, 'OpenAIAPIKey');
            end
            if isfield(options, 'MaterialsProjectAPIKey')
                options = rmfield(options, 'MaterialsProjectAPIKey');
            end
            options.Applied = false;
            options.Action = 'cancel';
            this.finishClose(options);
        end

        function finishClose(this, options)
            if this.isClosing
                return
            end
            this.pendingDialogOptions = options;
            close(this);
        end

        function helpButtonClicked(this)
            import kssolv.ui.util.Localizer.message
            try
                web([KSSOLV_Toolbox.CodeRepository '#readme'], '-browser');
            catch
                uialert(this.getWidget(), ...
                    message('KSSOLV:dialogs:SettingsDialogHelpFailed'), ...
                    message('KSSOLV:dialogs:SettingsDialogHelpErrorTitle'));
            end
        end

        function validateSettings(this, settings)
            import kssolv.ui.util.Localizer.message

            if ~ismember(char(settings.Locale), this.availableLanguageOptionsData)
                error('KSSOLV:SettingsDialog:InvalidLocale', '%s', ...
                    message('KSSOLV:dialogs:SettingsDialogInvalidLocale'));
            end
            if ~ismember(char(settings.LLMType), this.availableLLMType)
                error('KSSOLV:SettingsDialog:InvalidLLMType', '%s', ...
                    message('KSSOLV:dialogs:SettingsDialogInvalidLLMType'));
            end

            this.validateURL(settings.OllamaServerURL);
            this.validateOpenAIBaseURL(settings.OpenAIBaseURL);
            if strcmp(settings.LLMType, 'OpenAICompatible')
                if strlength(strip(settings.OpenAIAPIKey)) == 0
                    error('KSSOLV:SettingsDialog:MissingAPIKey', '%s', ...
                        message('KSSOLV:dialogs:SettingsDialogAPIKeyRequired'));
                end
            end
            validatedMaterialsProjectAPIKey = ...
                strip(settings.MaterialsProjectAPIKey);
            if strlength(validatedMaterialsProjectAPIKey) > 0 && ...
                    strlength(validatedMaterialsProjectAPIKey) ~= 32
                error('KSSOLV:SettingsDialog:InvalidMaterialsProjectAPIKey', ...
                    '%s', message( ...
                    ['KSSOLV:dialogs:' ...
                    'SettingsDialogMaterialsProjectInvalidAPIKey']));
            end
            if strlength(strip(settings.OllamaModel)) == 0 || ...
                    strlength(strip(settings.OpenAIModel)) == 0
                error('KSSOLV:SettingsDialog:MissingModel', '%s', ...
                    message('KSSOLV:dialogs:SettingsDialogModelRequired'));
            end
        end
    end

    methods (Static, Access = private)
        function value = maskedAPIKey()
            value = "sk-******";
        end

        function value = maskedMaterialsProjectAPIKey()
            value = "********************************";
        end

        function models = fetchModels(provider, url, apiKey)
            if strcmp(provider, 'Ollama')
                response = webread(url + "/api/tags", ...
                    weboptions('Timeout', 10, 'ContentType', 'json'));
                models = ...
                    kssolv.ui.components.dialog.SettingsDialog.extractOllamaModels(response);
                return
            end

            options = weboptions('Timeout', 10, 'ContentType', 'json', ...
                'HeaderFields', {'Authorization', ['Bearer ' char(apiKey)]});
            response = webread(url + "/models", options);
            models = ...
                kssolv.ui.components.dialog.SettingsDialog.extractOpenAIModels(response);
        end

        function cancelFuture(future)
            if isempty(future)
                return
            end
            try
                cancel(future);
            catch
                % Future 已结束或失效时无需额外处理。
            end
        end

        function identifiers = exceptionIdentifiers(exception)
            causeIdentifiers = cell(size(exception.cause));
            for index = 1:numel(exception.cause)
                causeIdentifiers{index} = ...
                    kssolv.ui.components.dialog.SettingsDialog ...
                    .exceptionIdentifiers(exception.cause{index});
            end
            identifiers = [string(exception.identifier); ...
                vertcat(causeIdentifiers{:})];
            identifiers(strlength(identifiers) == 0) = [];
        end

        function normalizedURL = validateURL(value)
            import kssolv.ui.util.Localizer.message

            normalizedURL = strip(string(value));
            normalizedURL = strip(normalizedURL, 'right', '/');
            expression = '^https?://[^\s/?#]+(?::\d+)?(?:/[^\s?#]*)?$';
            if ~isscalar(normalizedURL) || strlength(normalizedURL) == 0 || ...
                    isempty(regexp(normalizedURL, expression, 'once'))
                error('KSSOLV:SettingsDialog:InvalidURL', '%s', ...
                    message('KSSOLV:dialogs:SettingsDialogInvalidURL'));
            end
        end

        function normalizedURL = validateOpenAIBaseURL(value)
            import kssolv.ui.util.Localizer.message

            normalizedURL = ...
                kssolv.ui.components.dialog.SettingsDialog.validateURL(value);
            endpointPaths = ["/chat/completions", "/models"];
            if any(endsWith(lower(normalizedURL), endpointPaths))
                error('KSSOLV:SettingsDialog:OpenAIBaseURLIncludesEndpoint', ...
                    '%s', message( ...
                    'KSSOLV:dialogs:SettingsDialogOpenAIBaseURLIncludesEndpoint'));
            end
        end

        function models = extractOllamaModels(response)
            models = strings(0, 1);
            if ~isstruct(response) || ~isfield(response, 'models') || isempty(response.models)
                return
            end
            entries = response.models;
            if iscell(entries)
                entries = [entries{:}];
            end
            if isfield(entries, 'name')
                models = string({entries.name}).';
            elseif isfield(entries, 'model')
                models = string({entries.model}).';
            end
            models = unique(models(strlength(strip(models)) > 0), 'stable');
        end

        function models = extractOpenAIModels(response)
            models = strings(0, 1);
            if ~isstruct(response) || ~isfield(response, 'data') || isempty(response.data)
                return
            end
            entries = response.data;
            if iscell(entries)
                entries = [entries{:}];
            end
            if isfield(entries, 'id')
                models = string({entries.id}).';
            end
            models = sort(unique(models(strlength(strip(models)) > 0), 'stable'));
        end

        function setDropdownModels(dropdown, models, selectedModel)
            models = string(models(:));
            selectedModel = strip(string(selectedModel));
            models = unique([selectedModel; strip(models)], 'stable');
            models(strlength(models) == 0) = [];
            if isempty(models)
                models = "";
            end
            dropdown.Items = cellstr(models(:).');
            dropdown.Value = char(models(1));
            if strlength(selectedModel) > 0
                dropdown.Value = char(selectedModel);
            end
        end

        function value = onOff(condition)
            if condition
                value = 'on';
            else
                value = 'off';
            end
        end
    end

    methods (Hidden, Static)
        function dialog = qeShow()
            %QESHOW 用于人工和 UI 自动化测试。
            dialog = kssolv.ui.components.dialog.SettingsDialog();
            dialog.show();
        end
    end
end
