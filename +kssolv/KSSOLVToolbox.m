classdef KSSOLVToolbox < handle
    %KSSOLVTOOLBOX 排列和布局相关 UI 组件，生成 KSSOLV Toolbox 的完整用户图形界面

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties (Access = public)
        Name string
        AppContainer matlab.ui.container.internal.AppContainer
        HostInBrowser (1, 1) logical = false
    end

    properties (Access = private)
        projectBrowser % 用于判断 AppContainer 是否渲染结束
        runBrowser % 运行浏览器
        modelingTab % 结构文档打开时显示的上下文建模标签页
    end

    methods
        function this = KSSOLVToolbox()
            %KSSOLVTOOLBOX 构造此类的实例

            import kssolv.ui.util.Localizer.*

            % 根据统一设置服务返回的配置设置本地化。
            settings = kssolv.settings.Settings.load();
            setLocale(settings.Locale);

            % 创建 App Container
            appOptions.Title = 'KSSOLV Toolbox';
            appOptions.Tag = sprintf('kssolv(%s)', char(matlab.lang.internal.uuid));
            appOptions.ToolstripEnabled = true;
            appOptions.EnableTheming = false;
            this.AppContainer = matlab.ui.container.internal.AppContainer(appOptions);
            this.Name = this.AppContainer.Tag;
            % 保存 AppContainer 至 DataStorage
            kssolv.ui.util.DataStorage.setData('AppContainer', this.AppContainer);
            % 设定 App Container 的标题
            kssolv.KSSOLVToolbox.setAppContainerTitle();
            % 添加工作区文字
            msg = message('KSSOLV:toolbox:WelcomeMessage');
            this.AppContainer.DocumentPlaceHolderText = msg;
            % 监听 App Container 的状态改变，例如关闭 App 时会触发 StateChanged 事件
            addlistener(this.AppContainer, 'StateChanged', @(src,data) callbackAppStateChanged(this));
            % 添加多个 Data Browser 组件
            this.projectBrowser = kssolv.ui.components.databrowser.ProjectBrowser();
            this.projectBrowser.addToAppContainer(this.AppContainer);
            infoBrowser = kssolv.ui.components.databrowser.InfoBrowser();
            infoBrowser.addToAppContainer(this.AppContainer);
            configBrowser = kssolv.ui.components.databrowser.ConfigBrowser();
            configBrowser.addToAppContainer(this.AppContainer);
            this.runBrowser = kssolv.ui.components.databrowser.RunBrowser();
            this.runBrowser.addToAppContainer(this.AppContainer);
            commandWindow = kssolv.ui.components.databrowser.CommandWindow();
            commandWindow.addToAppContainer(this.AppContainer);
            this.setPanelLayout();
            % 添加多个 Tab 组件
            homeTab = kssolv.ui.components.tab.HomeTab();
            workflowTab = kssolv.ui.components.tab.WorkflowTab();
            tabGroup = matlab.ui.internal.toolstrip.TabGroup();
            tabGroup.Tag = 'kssolvTabGroup';
            tabGroup.add(homeTab.Tab);
            tabGroup.add(workflowTab.Tab);
            this.AppContainer.add(tabGroup);
            this.modelingTab = ...
                kssolv.ui.components.tab.ModelingTab(tabGroup);
            % 添加位于底部的 FooterBar 组件
            footerBar = kssolv.ui.components.others.FooterBar();
            footerBar.addToAppContainer(this.AppContainer);
            % 添加位于右上角的 QuickAccessBar 组件
            quickAccessBar = kssolv.ui.components.qab.QuickAccessBar();
            quickAccessBar.addToAppContainer(this.AppContainer)

            % 注册关闭时的提示对话框
            this.AppContainer.CanCloseFcn = @(varargin) canClose(this, varargin{:});

            % 添加 Project 句柄对象的监听器
            kssolv.KSSOLVToolbox.createListener();
        end

        function delete(this)
            %DELETE 析构函数
            storedApp = ...
                kssolv.ui.util.DataStorage.getData("KSSOLVToolbox");
            if ~isempty(storedApp) && isequal(storedApp, this)
                kssolv.ui.util.DataStorage.removeData( ...
                    "KSSOLVToolbox");
            end
            storedContainer = ...
                kssolv.ui.util.DataStorage.getData("AppContainer");
            if ~isempty(storedContainer) && ...
                    isequal(storedContainer, this.AppContainer)
                kssolv.ui.util.DataStorage.removeData( ...
                    "AppContainer");
            end
            % 删除 App Container
            if ~isempty(this.AppContainer) && isvalid(this.AppContainer)
                if ~isempty(this.modelingTab) && isvalid(this.modelingTab)
                    delete(this.modelingTab);
                end
                delete(this.runBrowser);
                delete(this.AppContainer);
            end
        end

        %% App 操作相关
        function appcontainer = getAppContainer(this)
            % 获取 App Container 实例
            appcontainer = this.AppContainer;
        end

        function show(this)
            % 绘制并展示 App 界面
            this.AppContainer.WindowBounds = [100 100 1200 800];
            this.AppContainer.HostInBrowser = this.HostInBrowser;
            this.AppContainer.Busy = true;

            try
                this.AppContainer.Visible = true;
                waitfor(this.projectBrowser.Figure, 'FigureViewReady', true);
            catch exception
                % 若 HostInBrowser 为 true，但此时无法打开默认浏览器则会报错
                disp(this.getNewUrl());
            end

            this.AppContainer.Busy = false;
        end

        function close(this)
            % 关闭 App
            delete(this);
        end
    end

    methods (Static)
        function createListener()
            % 添加 Project 句柄对象的监听器
            project = kssolv.ui.util.DataStorage.getData('Project');
            addlistener(project, 'isDirty', 'PostSet', @kssolv.KSSOLVToolbox.callbackProjectDirtyChanged);
        end

        function title = setAppContainerTitle(isDirty)
            % 按照特定格式设定 App Container 标题
            arguments
                isDirty logical = false
            end
            import kssolv.ui.util.Localizer.message
            import kssolv.ui.util.DataStorage.*

            projectFilename = getData('ProjectFilename');
            if projectFilename == ""
                title = message('KSSOLV:toolbox:AppTitle');
            else
                title = strcat(message('KSSOLV:toolbox:AppTitle'), " - ", projectFilename);
            end
            if isDirty
                title = strcat(title, '*');
            end
            appContainer = getData('AppContainer');
            appContainer.Title = title;
        end
    end

    methods (Access = private, Static)
        function callbackProjectDirtyChanged(~, event)
            isDirty = event.AffectedObject.isDirty;
            kssolv.KSSOLVToolbox.setAppContainerTitle(isDirty);
        end
    end

    methods (Access = private)
        function setPanelLayout(this)
            % 调整 Data Browsers 的布局
            % 折叠了两个 Panel
            InfoBrowserPanel = this.AppContainer.getPanel('InfoBrowser');
            InfoBrowserPanel.Collapsed = true;
            RunBrowserPanel = this.AppContainer.getPanel('RunBrowser');
            RunBrowserPanel.Collapsed = true;
            % 折叠了右侧和底部的面板
            this.AppContainer.RightCollapsed = true;
            this.AppContainer.BottomCollapsed = true;
        end

        function url = getNewUrl(this)
            % 获取和 AppContainer 对应的浏览器访问网址
            warning('off', 'MATLAB:structOnObject');
            appContainer = struct(this.AppContainer);

            connector.ensureServiceOn;
            connector.newNonce;

            if isdeployed
                webPath = fullfile(matlabroot, 'mcr', 'toolbox', 'matlab', 'appcontainer', 'web');
                path = connector.addStaticContentOnPath('AppContainerWebPath', webPath);
                page = path + "/index.html";
            else
                page = "/toolbox/matlab/appcontainer/web/index.html";
            end

            % 由于 channel 可能已被打开, 使用 connector.applyNonce 重设 url
            url = connector.getUrl(sprintf('%s?channel=%s&toolstripChannel=%s&id=%s&uuid=%s&UseMF0ForTS=true&waitForJavascriptDebugger=false', ...
                page, appContainer.ModelChannel, appContainer.ToolstripChannel, appContainer.Tag, appContainer.uuid));
            url = connector.applyNonce(url);
        end

        function status = canClose(this, ~)
            arguments (Output)
                status logical
            end
            import kssolv.ui.util.Localizer.*

            status = false;
            project = kssolv.ui.util.DataStorage.getData('Project');
            projectFilename = kssolv.ui.util.DataStorage.getData('ProjectFilename');

            if ~project.isDirty
                % 如果 project 没有进行任何修改，则直接关闭已有的 project
                % 此处不需要进行额外的处理
            else
                % 如果 App 正忙，取消正忙的状态
                if this.AppContainer.Busy
                    this.AppContainer.Busy = false;
                end

                % 如果 project 有进行修改，则弹出对话框，包含"保存"、"不保存"和"取消"按钮
                YesLabel = message('KSSOLV:dialogs:AppCanCloseSave');
                NoLabel = message('KSSOLV:dialogs:AppCanCloseDoNotSave');
                CancelLabel = message('KSSOLV:dialogs:AppCanCloseCancel');

                if isdeployed
                    % 在独立应用程序里，模态对话框无法正常工作，因此需要使用非模态的对话框
                    confirmDialog = kssolv.ui.components.dialog.ConfirmDialog( ...
                        message('KSSOLV:dialogs:AppCanCloseMessage'), ...
                        message('KSSOLV:dialogs:AppCanCloseTitle'), ...
                        'Options', {YesLabel, NoLabel, CancelLabel}, ...
                        'DefaultOption', 1, 'CancelOption', 3);
                    selection = confirmDialog.show();
                else
                    % 普通情况下使用模态对话框
                    selection = uiconfirm(this.AppContainer, ...
                        message('KSSOLV:dialogs:AppCanCloseMessage'), ...
                        message('KSSOLV:dialogs:AppCanCloseTitle'), ...
                        'Options', {YesLabel, NoLabel, CancelLabel}, ...
                        'DefaultOption', 1, 'CancelOption', 3);
                end

                switch selection
                    case YesLabel
                        if projectFilename == ""
                            % 如果尚未指定要保存的文件，则选择保存为 .ks 文件的路径
                            [file,location] = uiputfile({'*.ks', 'KSSOLV Files (*.ks)'}, ...
                                message('KSSOLV:dialogs:SaveKSFileTitle'), 'untitled.ks');
                            if isequal(file, 0) || isequal(location, 0)
                                % 用户点击了"取消"按钮
                                return
                            else
                                % 用户选择了具体的文件路径，保存 project
                                project.saveToKsFile(fullfile(location, file));
                            end
                        else
                            % 如果已打开 .ks 文件，则保存后关闭当前 project
                            project.saveToKsFile(projectFilename);
                        end
                    case NoLabel
                        % 此处无需进行处理
                    case CancelLabel
                        return
                end
            end
            status = true;
        end

        %% 回调函数
        function callbackAppStateChanged(this)
            % 当 AppContainer 状态改变时，执行相关的操作
            import matlab.ui.container.internal.appcontainer.*
            switch this.AppContainer.State
                case AppState.RUNNING
                    % 在 App 打开后进行一些操作，如折叠右侧面板
                    this.AppContainer.RightCollapsed = true;
                case AppState.TERMINATED
                    % 清除本地化管理器的类的实例
                    kssolv.ui.util.Localizer.clearInstance();
                    % 清除 App Container 相关的实例
                    delete(this);
            end
        end
    end
end
