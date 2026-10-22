classdef QuickAccessBar < handle
    %QUICKACCESSBAR 设置右上角快捷访问栏

    %   开发者：杨柳 林海饶
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties (Access = private)
        HelpButton
        RedoButton
        UndoButton
        SaveButton
        AccountButton = []
        OnlineUsername (1,1) string = ""
    end

    methods
        function this = QuickAccessBar()
            % 构造函数
            this.createQuickAccessBar();
            kssolv.ui.util.DataStorage.setData('QuickAccessBar', this);
        end

        function createQuickAccessBar(this)
            % 创建并配置 QuickAccessBar 相关组件

            % 创建帮助按钮，链接到 KSSOLV 帮助文档
            this.HelpButton = kssolv.ui.components.qab.QABHelpButton();
            this.HelpButton.ButtonPushedFcn = ...
                @(~,~)kssolv.ui.features.documentation.openManual();

            % 创建重做按钮
            this.RedoButton = kssolv.ui.components.qab.QABRedoButton();
            this.RedoButton.ButtonPushedFcn = @(src, data) callbackRedoButton(this);

            % 创建撤销按钮
            this.UndoButton = kssolv.ui.components.qab.QABUndoButton();
            this.UndoButton.ButtonPushedFcn = @(src, data) callbackUndoButton(this);

            % 创建保存按钮
            this.SaveButton = kssolv.ui.components.qab.QABSaveButton();
            this.SaveButton.ButtonPushedFcn = @(src, data) callbackSaveButton(this);
            if isKSSOLVOnline()
                this.AccountButton = matlab.ui.internal.toolstrip.impl.QABDropDownButton( ...
                    kssolv.ui.util.Localizer.message('KSSOLV:dialogs:OnlineAccountLogin'));
                this.AccountButton.Tag = 'QABAccountButton';
                this.AccountButton.ShowText = true;
                this.AccountButton.Enabled = false;
                this.AccountButton.DynamicPopupFcn = @(~,~)this.createAccountPopup();
                this.AccountButton.Popup = this.createAccountPopup();
            end
        end

        function addToAppContainer(this, appContainer)
            % AppContainer prepends QAB controls: add the account first so
            % its text appears to the right of the existing Help button.
            if ~isempty(this.AccountButton), appContainer.add(this.AccountButton); end
            appContainer.add(this.HelpButton);
            appContainer.add(this.RedoButton);
            appContainer.add(this.UndoButton);
            appContainer.add(this.SaveButton);
        end

        function setOnlineAccount(this, state)
            if isempty(this.AccountButton), return, end
            this.OnlineUsername = "";
            if isstruct(state) && isfield(state, 'username') && ...
                    ~isempty(regexp(char(string(state.username)), '^[a-z][a-z0-9-]{2,31}$', 'once'))
                this.OnlineUsername = string(state.username);
            end
            if strlength(this.OnlineUsername) > 0
                this.AccountButton.Text = char(this.OnlineUsername);
            else
                this.AccountButton.Text = kssolv.ui.util.Localizer.message( ...
                    'KSSOLV:dialogs:OnlineAccountLogin');
            end
            this.AccountButton.Enabled = true;
            kssolv.ui.util.DataStorage.setData('OnlineAccount', state);
        end

        function signOut(this)
            this.endWorkspace('logout');
        end

        function exitWorkspace(this)
            this.endWorkspace('exit');
        end

        function endWorkspace(this, action)
            import kssolv.ui.util.Localizer.message
            if strlength(this.OnlineUsername) == 0
                kssolv.ui.util.SessionPrompt.confirm([], ...
                    message('KSSOLV:dialogs:OnlineAccountUnavailable'), ...
                    message('KSSOLV:dialogs:OnlineAccountLogin'), ...
                    'Options', {message('KSSOLV:dialogs:OnlineAccountClose')});
                return
            end
            choice = message('KSSOLV:dialogs:OnlineAccountSignOut');
            note = message('KSSOLV:dialogs:OnlineAccountSignOutNote');
            if strcmp(action,'exit')
                choice = message('KSSOLV:dialogs:OnlineAccountExit');
                note = message('KSSOLV:dialogs:OnlineAccountExitNote');
            end
            answer = kssolv.ui.util.SessionPrompt.confirm([], ...
                note, choice, ...
                'Options', {choice, message('KSSOLV:dialogs:OnlineAccountCancel')}, ...
                'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
            if strcmp(answer, choice)
                this.AccountButton.Enabled = false;
                kssolv.ui.util.DataStorage.getData('HomeTab').requestOnlineAccountAction(action);
            end
        end
    end

    methods (Access = private)
        function popup = createAccountPopup(this)
            import matlab.ui.internal.toolstrip.*
            import kssolv.ui.util.Localizer.message
            popup = PopupList();
            settingsItem = ListItem(message('KSSOLV:dialogs:OnlineAccountMyAccount'));
            settingsItem.Tag = 'QABAccountSettings';
            settingsItem.ItemPushedFcn = @(~,~)kssolv.ui.util.DataStorage.getData('HomeTab').openSettings(true);
            popup.add(settingsItem);
            exitItem = ListItem(message('KSSOLV:dialogs:OnlineAccountExit'));
            exitItem.Tag = 'QABAccountExit';
            exitItem.Enabled = strlength(this.OnlineUsername) > 0;
            exitItem.ItemPushedFcn = @(~,~)this.exitWorkspace();
            popup.add(exitItem);
            if strlength(this.OnlineUsername) > 0
                label = message('KSSOLV:dialogs:OnlineAccountSignOut');
            else
                label = message('KSSOLV:dialogs:OnlineAccountLogin');
            end
            logoutItem = ListItem(label);
            logoutItem.Tag = 'QABAccountSignOut';
            logoutItem.ItemPushedFcn = @(~,~)this.signOut();
            popup.add(logoutItem);
        end

        function callbackRedoButton(this)
            this.historyAction('redo');
        end

        function callbackUndoButton(this)
            this.historyAction('undo');
        end

        function historyAction(~, action)
            app = kssolv.ui.util.DataStorage.getData('AppContainer');
            if ~isempty(app) && isvalid(app)
                selected = app.LastSelectedDocument;
                if isstruct(selected) && isfield(selected, 'documentGroupTag') && ...
                        strcmp(selected.documentGroupTag, 'Structure')
                    registry = kssolv.ui.features.modeling.SessionRegistry.getInstance();
                    display = registry.getCurrentDisplay();
                    if ~isempty(display) && isvalid(display)
                        if strcmp(action, 'undo'), display.undo();
                        else, display.redo(); end
                        return
                    end
                end
            end
            if strcmp(action, 'undo'), event = 'workflowUndo';
            else, event = 'workflowRedo'; end
            kssolv.ui.components.figuredocument.Workflow.sendEventToWorkflowUI(event);
        end

        function callbackSaveButton(~)
            home = kssolv.ui.util.DataStorage.getData('HomeTab');
            if ~isempty(home) && isvalid(home)
                home.saveCurrentProject();
            end
        end
    end

    methods (Static, Hidden)
        function app = qeShow()
            % 用于在单元测试中测试 QuickAccessBar，可通过下面的命令使用：
            % kssolv.ui.components.qab.QuickAccessBar.qeShow();

            % 创建 AppContainer
            appOptions.Tag = sprintf('kssolv(%s)',char(matlab.lang.internal.uuid));
            appOptions.Title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:UnitTestTitle');
            appOptions.ToolstripEnabled = true;
            app = matlab.ui.container.internal.AppContainer(appOptions);

            % 添加 QuickAccessBar
            quickAccessBar = kssolv.ui.components.qab.QuickAccessBar();
            quickAccessBar.addToAppContainer(app)

            % 设定 Status Context
            statusTestContext = matlab.ui.container.internal.appcontainer.ContextDefinition();
            statusTestContext.Tag = 'kssolvTestContext';
            statusTestContext.StatusComponentTags = {quickAccessBar.HelpButton.Tag};
            app.Contexts = [app.Contexts {statusTestContext}];

            % 设定 Active Context
            app.ActiveContexts = 'kssolvTestContext';

            % 展示界面
            app.Visible = true;
        end
    end
end
