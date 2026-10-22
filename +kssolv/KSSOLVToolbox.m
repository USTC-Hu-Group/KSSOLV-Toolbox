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
        Sidebar kssolv.ui.browser.Sidebar
    end

    properties (Access = private)
        projectBrowser % 用于判断 AppContainer 是否渲染结束
        filesBrowser
        runBrowser % 运行浏览器
        modelingTab % 结构文档打开时显示的上下文建模标签页
        appStateListener % AppContainer 状态监听器
        IsShuttingDown (1,1) logical = false
        IsDeleting (1,1) logical = false
        BrowserStartupPending (1,1) logical = false
        CrystalPrewarm = []
    end

    methods
        function this = KSSOLVToolbox()
            %KSSOLVTOOLBOX 构造此类的实例

            import kssolv.ui.util.Localizer.*

            % Configure Runtime docking before any embedded figures exist.
            kssolv.ui.util.configureFigureDocumentDocking();

            % 根据统一设置服务返回的配置设置本地化。
            settings = kssolv.settings.Settings.load();
            setLocale(settings.Locale);

            % 创建 App Container
            appOptions.Title = 'KSSOLV Toolbox';
            appOptions.Tag = sprintf('kssolv(%s)', char(matlab.lang.internal.uuid));
            appOptions.ToolstripEnabled = true;
            appOptions.EnableTheming = false;
            if strlength(getenv('KSSOLV_BROWSER_SESSION_FILE')) > 0
                this.AppContainer = kssolv.ui.browser.BrowserAppContainer(appOptions);
            else
                this.AppContainer = kssolv.ui.browser.SidebarAppContainer(appOptions);
            end
            this.Name = this.AppContainer.Tag;
            % 保存 AppContainer 至 DataStorage
            kssolv.ui.util.DataStorage.setData('AppContainer', this.AppContainer);
            % 设定 App Container 的标题
            kssolv.KSSOLVToolbox.setAppContainerTitle();
            % 添加工作区文字
            msg = message('KSSOLV:toolbox:WelcomeMessage');
            this.AppContainer.DocumentPlaceHolderText = msg;
            % 监听 App Container 的状态改变，例如关闭 App 时会触发 StateChanged 事件
            this.appStateListener = addlistener(this.AppContainer, ...
                'StateChanged', @(src,data) callbackAppStateChanged(this));
            % 添加多个 Data Browser 组件
            this.projectBrowser = kssolv.ui.components.databrowser.ProjectBrowser();
            this.projectBrowser.addToAppContainer(this.AppContainer);
            if isKSSOLVOnline()
                this.filesBrowser = kssolv.ui.components.databrowser.FilesBrowser();
                this.filesBrowser.addToAppContainer(this.AppContainer);
            end
            infoBrowser = kssolv.ui.components.databrowser.InfoBrowser();
            infoBrowser.addToAppContainer(this.AppContainer);
            configBrowser = kssolv.ui.components.databrowser.ConfigBrowser();
            configBrowser.addToAppContainer(this.AppContainer);
            this.runBrowser = kssolv.ui.components.databrowser.RunBrowser();
            this.runBrowser.addToAppContainer(this.AppContainer);
            commandWindow = kssolv.ui.components.databrowser.CommandWindow();
            commandWindow.addToAppContainer(this.AppContainer);
            panelTags = ["ProjectBrowser", "InfoBrowser", "ConfigBrowser", ...
                "RunBrowser", "CommandWindow"];
            if isKSSOLVOnline(), panelTags(end+1) = "OnlineFilesBrowser"; end
            for panelTag = panelTags
                % Accordion mode ignored Opened for these FigurePanels;
                % the native sidebar correctly uses it as panel membership.
                panel = this.AppContainer.getPanel(panelTag);
                panel.Opened = true;
                panel.Closable = panelTag ~= "ProjectBrowser";
            end
            this.Sidebar = kssolv.ui.browser.Sidebar(this.AppContainer, ...
                this.projectBrowser.Figure, panelTags);
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
            this.CrystalPrewarm = kssolv.ui.util.CrystalViewerPrewarm(this.projectBrowser.Figure);
            kssolv.ui.util.DataStorage.setData('CrystalViewerPrewarm', this.CrystalPrewarm);
        end

        function delete(this)
            %DELETE 析构函数
            if this.IsDeleting
                return
            end
            this.IsDeleting = true;
            if ~isempty(this.CrystalPrewarm) && isvalid(this.CrystalPrewarm)
                stored = kssolv.ui.util.DataStorage.getData('CrystalViewerPrewarm');
                if isequal(stored, this.CrystalPrewarm)
                    kssolv.ui.util.DataStorage.removeData('CrystalViewerPrewarm');
                end
                delete(this.CrystalPrewarm);
            end
            if ~isempty(this.appStateListener) && ...
                    isvalid(this.appStateListener)
                delete(this.appStateListener);
            end
            this.appStateListener = [];
            if ~isempty(this.Sidebar) && isvalid(this.Sidebar)
                delete(this.Sidebar);
            end
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
            % The modeling tab owns listeners on the session registry, while
            % the registry owns listeners on every open structure document.
            % Tear them down before the AppContainer even when the container
            % has already reached TERMINATED.  Otherwise a later Toolbox
            % instance can reuse a stale registry from DataStorage and fail
            % while attaching listeners to its reloaded class definition.
            if ~isempty(this.modelingTab) && isvalid(this.modelingTab)
                delete(this.modelingTab);
            end
            registry = kssolv.ui.util.DataStorage.getData( ...
                "ModelingSessionRegistry");
            if ~isempty(registry) && isvalid(registry)
                delete(registry);
            else
                kssolv.ui.util.DataStorage.removeData( ...
                    "ModelingSessionRegistry");
            end
            if ~isempty(this.runBrowser) && isvalid(this.runBrowser)
                delete(this.runBrowser);
            end
            if ~isempty(this.filesBrowser) && isvalid(this.filesBrowser)
                delete(this.filesBrowser);
            end
            % During a user-initiated close the AppContainer owns its native
            % teardown. Deleting it again from its TERMINATED callback is a
            % re-entrant ViewModel destruction and can segfault MATLAB.
            if ~this.IsShuttingDown && ~isempty(this.AppContainer) && ...
                    isvalid(this.AppContainer)
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
            if kssolv.ui.util.StartupSplash.tryShow(this)
                return
            end
            this.AppContainer.WindowBounds = [100 100 1200 800];
            this.AppContainer.HostInBrowser = this.HostInBrowser;
            this.AppContainer.Busy = true;

            sessionFile = string(getenv('KSSOLV_BROWSER_SESSION_FILE'));
            if this.HostInBrowser && strlength(sessionFile) > 0
                % A remote client cannot render until the proxy has its URL.
                % In a container, failure to open a local browser is expected.
                this.AppContainer.prepareBrowserView();
                url = this.getNewUrl();
                kssolv.ui.browser.BrowserSession.publish(sessionFile, url);
                this.BrowserStartupPending = true;
                return
            end

            try
                this.AppContainer.Visible = true;
                waitfor(this.projectBrowser.Figure, 'FigureViewReady', true);
            catch exception
                % 若 HostInBrowser 为 true，但此时无法打开默认浏览器则会报错
                if ~this.HostInBrowser
                    rethrow(exception);
                end
                disp(this.getNewUrl());
            end

            this.AppContainer.Busy = false;
        end

        function published = processBrowserSessionRequests(this)
            published = false;
            sessionFile = string(getenv('KSSOLV_BROWSER_SESSION_FILE'));
            if this.HostInBrowser && strlength(sessionFile) > 0
                published = kssolv.ui.browser.BrowserSession.respond(sessionFile, @() this.getNewUrl());
            end
        end

        function updateBrowserStartupState(this)
            if ~this.BrowserStartupPending, return, end
            home = kssolv.ui.util.DataStorage.getData('HomeTab');
            filesReady = isempty(this.filesBrowser) || this.filesBrowser.Figure.FigureViewReady;
            if this.AppContainer.State == matlab.ui.container.internal.appcontainer.AppState.RUNNING && ...
                    this.projectBrowser.Figure.FigureViewReady && this.projectBrowser.IsClientReady && ...
                    filesReady && home.IsBrowserReady
                this.BrowserStartupPending = false;
                this.AppContainer.Busy = false;
            end
        end

        function waitUntilReady(this)
            % 等待原生容器、Figure 和嵌入的 Project Browser 全部就绪。
            started = tic;
            while true
                if ~isvalid(this.AppContainer) || ...
                        this.AppContainer.State == ...
                        matlab.ui.container.internal.appcontainer.AppState.TERMINATED
                    error('KSSOLV:Startup:WindowClosed', ...
                        'The application window closed before it was ready.');
                end
                if this.AppContainer.State == ...
                        matlab.ui.container.internal.appcontainer.AppState.RUNNING && ...
                        this.projectBrowser.Figure.FigureViewReady && ...
                        this.projectBrowser.IsClientReady
                    return
                end
                if toc(started) >= 900
                    error('KSSOLV:Startup:RenderTimeout', ...
                        'The application interface did not become ready within 900 seconds.');
                end
                pause(0.05);
            end
        end

        function close(this)
            % 关闭 App
            delete(this);
        end

        function prepareForShutdown(this)
            %PREPAREFORSHUTDOWN Silence callbacks before native UI teardown.
            if this.IsShuttingDown
                return
            end
            this.IsShuttingDown = true;
            if ~isempty(this.CrystalPrewarm) && isvalid(this.CrystalPrewarm)
                this.CrystalPrewarm.shutdown();
            end
            if ~isempty(this.modelingTab) && isvalid(this.modelingTab)
                this.modelingTab.prepareForShutdown();
            end
            registry = kssolv.ui.util.DataStorage.getData( ...
                "ModelingSessionRegistry");
            if ~isempty(registry) && isvalid(registry)
                registry.prepareForShutdown();
            end
        end
    end

    methods (Static)
        function createListener()
            % 添加 Project 句柄对象的监听器
            project = kssolv.ui.util.DataStorage.getData('Project');
            previous = kssolv.ui.util.DataStorage.getData('ProjectDirtyListener');
            if ~isempty(previous) && isvalid(previous), delete(previous); end
            listener = addlistener(project, 'isDirty', 'PostSet', ...
                @kssolv.KSSOLVToolbox.callbackProjectDirtyChanged);
            kssolv.ui.util.DataStorage.setData('ProjectDirtyListener', listener);
        end

        function title = setAppContainerTitle(isDirty)
            % 按照特定格式设定 App Container 标题
            arguments
                isDirty logical = false
            end
            import kssolv.ui.util.Localizer.message
            import kssolv.ui.util.DataStorage.*

            projectFilename = getData('ProjectFilename');
            if isKSSOLVOnline()
                appTitle = "KSSOLV Toolbox Online";
            else
                appTitle = message('KSSOLV:toolbox:AppTitle');
            end
            if projectFilename == ""
                title = appTitle;
            else
                if isKSSOLVOnline()
                    [~, name, ext] = fileparts(projectFilename);
                    projectFilename = string(name) + ext;
                end
                title = strcat(appTitle, " - ", projectFilename);
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
            % Native proportional heights seed the stacked sidebar layout.
            % The splitter owns subsequent adjustments made by the user.
            panelTags = ["ProjectBrowser", "InfoBrowser", "ConfigBrowser", "RunBrowser"];
            portions = [0.75, 0.25, 0.75, 0.25];
            for index = 1:numel(panelTags)
                panel = this.AppContainer.getPanel(panelTags(index));
                panel.PreferredHeight = portions(index);
                panel.Resizable = true;
                panel.Collapsed = panelTags(index) == "InfoBrowser";
            end
            this.AppContainer.RightCollapsed = true;
            this.AppContainer.BottomCollapsed = true;
        end

        function url = getNewUrl(this)
            % 获取和 AppContainer 对应的浏览器访问网址
            warningState = warning('off', 'MATLAB:structOnObject');
            warningCleanup = onCleanup(@() warning(warningState));
            appContainer = struct(this.AppContainer);

            connector.ensureServiceOn;
            connector.newNonce;

            page = this.AppContainer.getClientPage();

            % 由于 channel 可能已被打开, 使用 connector.applyNonce 重设 url
            url = connector.getUrl(sprintf('%s&channel=%s&toolstripChannel=%s&id=%s&uuid=%s&UseMF0ForTS=true&waitForJavascriptDebugger=false&websocket=on', ...
                page, appContainer.ModelChannel, appContainer.ToolstripChannel, appContainer.Tag, appContainer.uuid));
            url = connector.applyNonce(url);
        end

        function status = canClose(this, ~)
            arguments (Output)
                status logical
            end
            import kssolv.ui.util.Localizer.*

            status = false;
            registry = kssolv.ui.util.DataStorage.getData( ...
                "ModelingSessionRegistry");
            if ~isempty(registry) && isvalid(registry)
                try
                    % The embedded structure viewer owns its browser
                    % fullscreen state.  Ask it to leave fullscreen before
                    % showing a close confirmation or tearing down the host.
                    registry.exitFullscreen();
                    registry.waitForFullscreenExit();
                catch exception
                    % A stale viewer must not prevent Toolbox shutdown.
                    warning('KSSOLV:Toolbox:FullscreenExitOnClose', ...
                        'Unable to exit a structure viewer from fullscreen: %s', ...
                        exception.message);
                end
            end
            try
                [project, projectFilename] = ...
                    this.projectBrowser.getCurrentProject();
            catch exception
                % CanCloseFcn must never trap the user in a window that can
                % no longer reach its project.  Log the recovery failure and
                % permit shutdown; there is no valid object left to save.
                warning('KSSOLV:Toolbox:ProjectUnavailableOnClose', ...
                    'Unable to recover the current project while closing: %s', ...
                    exception.message);
                this.prepareForShutdown();
                status = true;
                return
            end

            hasStructureDrafts = ~isempty(registry) && ...
                isvalid(registry) && registry.hasUnsavedChanges();

            if ~project.isDirty && ~hasStructureDrafts
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

                if isdeployed || isKSSOLVOnline()
                    % 独立应用和 Online 使用会话内的确认窗口。
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
                        if kssolv.ui.browser.OnlineWorkspace.available()
                            if ~kssolv.ui.util.DataStorage.getData('FilesBrowser').saveProject(false)
                                return
                            end
                        else
                        if projectFilename == ""
                            % 如果尚未指定要保存的文件，则选择保存为 .ks 文件的路径
                            [file,location] = kssolv.ui.util.FileDialog.save({'*.ks', 'KSSOLV Files (*.ks)'}, ...
                                message('KSSOLV:dialogs:SaveKSFileTitle'), 'untitled.ks');
                            if isequal(file, 0) || isequal(location, 0)
                                % 用户点击了"取消"按钮
                                return
                            else
                                projectFilename = fullfile(location, file);
                            end
                        end
                        % 应用退出时，“保存”会先把所有结构文档草稿提交到
                        % Project，再将完整 Project 写入 .ks 文件。
                        if hasStructureDrafts
                            registry.saveAllChangesToProject();
                        end
                        project.saveToKsFile(projectFilename);
                        if ~kssolv.ui.util.FileDialog.download(projectFilename, true)
                            project.isDirty = true;
                            return
                        end
                        end
                    case NoLabel
                        % Project 文件不保存，结构文档草稿也一并放弃。
                        if hasStructureDrafts
                            registry.discardAllChanges(false);
                        end
                    case CancelLabel
                        return
                end
            end
            this.prepareForShutdown();
            status = true;
        end

        %% 回调函数
        function callbackAppStateChanged(this)
            % 当 AppContainer 状态改变时，执行相关的操作
            import matlab.ui.container.internal.appcontainer.*
            switch this.AppContainer.State
                case AppState.TERMINATED
                    % 清除本地化管理器的类的实例
                    kssolv.ui.util.Localizer.clearInstance();
                    % The native container is already terminating. Mark the
                    % wrapper accordingly so its destructor cannot delete the
                    % event source again from inside this callback.
                    this.IsShuttingDown = true;
                    % 清除 App Container 相关的实例
                    delete(this);
            end
        end
    end
end
