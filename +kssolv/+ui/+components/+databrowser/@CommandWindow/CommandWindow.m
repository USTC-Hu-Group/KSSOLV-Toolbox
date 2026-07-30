classdef CommandWindow < matlab.ui.internal.databrowser.AbstractDataBrowser
    %COMMANDWINDOW 自定义的 Data Browser 组件，存放命令行窗口相关控件

    % 开发者：杨柳
    % 版权 2025 合肥瀚海量子科技有限公司

    properties
        Widgets % 小组件
        ChatBot % 对话机器人
        Workspace % 命令行变量工作空间
    end

    methods
        function this = CommandWindow()
            %COMMANDWINDOW 构造此类的实例
            title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:CommandWindowTitle');
            % 调用超类构造函数
            this = this@matlab.ui.internal.databrowser.AbstractDataBrowser('CommandWindow', title);
            % 自定义 widget 和 layout
            buildUI(this);
            % 设定 FigurePanel 的 Tag
            this.Panel.Tag = 'CommandWindow';
            % 设定合适的高度
            this.Panel.PreferredHeight = 280;
            % 将该 Browser 放在界面右侧
            this.Panel.Region = "bottom";
            % 保存实例，设置变更后可使已有聊天会话失效。
            kssolv.ui.util.DataStorage.setData('CommandWindow', this);

            % 初始化命令行变量工作空间
            if ~isMATLABReleaseOlderThan('R2025a', "release")
                this.Workspace = matlab.lang.Workspace;
            end
        end
    end

    methods (Static)
        generateCommandReferences()
    end

    methods (Access = protected)
        function buildUI(this)
            fig = this.Figure;
            g = uigridlayout(fig);
            g.BackgroundColor = "white";
            g.Padding = [0 0 0 0];
            g.RowHeight = {'1x'};
            g.ColumnWidth = {'1x'};

            htmlFile = fullfile(fileparts(mfilename('fullpath')), 'html', 'index.html');

            h = uihtml(g, "HTMLSource", htmlFile);
            this.Widgets.html = h;

            % 向 html 组件传递参考命令列表以供自动补全
            this.readCommandReferencesFile()

            % 接收从 HTML 组件触发的事件
            h.HTMLEventReceivedFcn = @this.eventReceiver;
        end
    end

    methods (Access = private)
        function readCommandReferencesFile(this)
            % 逐行读取 commandReferences.txt 文件中的 MATLAB 命令列表
            import kssolv.ui.util.Localizer.*

            currentFolder = fileparts(mfilename('fullpath'));
            commandReferencesFile = fullfile(currentFolder, 'html', 'commandReferences.txt');

            fileID = fopen(commandReferencesFile, 'r');
            if fileID == -1
                warning([message('KSSOLV:toolbox:CommandReferencesFileOpenError'), '%s'], commandReferencesFile);
            end

            % 初始化一个空的 cell 数组来存储每一行
            data = {};

            % 逐行读取文件并将每一行存储到 h.Data 中
            lineIndex = 1;
            while ~feof(fileID)
                line = fgetl(fileID);
                if ischar(line)
                    data{lineIndex} = line; %#ok<AGROW>
                    lineIndex = lineIndex + 1;
                end
            end

            fclose(fileID);
            this.Widgets.html.Data = data;
        end

        function addChat(this, content)
            %ADDCHAT 向 html 组件流式更新 tokens
            % content = replace(content, newline, " <br>");
            this.Widgets.html.sendEventToHTMLSource('TokensStreamed', content);
            drawnow
        end

        function eventReceiver(this, src, event)
            switch event.HTMLEventName
                case 'CommandSubmitted'
                    this.callbackCommandSubmitted(src, event);
                case 'UserPromptSubmitted'
                    this.callbackUserPromptSubmitted(src, event);
                case 'EventSent'
                    this.callbackEventSent(src, event);
                case 'ClientError'
                    warning("KSSOLV:CommandWindow:HTMLClientError", ...
                        "Command Window JavaScript error: %s", ...
                        string(event.HTMLEventData));
            end
        end

        function callbackCommandSubmitted(this, ~, event)
            % 执行命令行窗口提交的命令
            command = event.HTMLEventData;

            if isempty(command)
                % 如果命令为空则直接回复空白
                this.Widgets.html.sendEventToHTMLSource('ResultUpdated', '');
                return
            end

            % 在函数工作区内预置持久变量 ANS，可简化上一次计算结果的使用
            persistent ANS %#ok<NUSED>

            if isMATLABReleaseOlderThan('R2025a', "release")
                % 若当前版本低于 R2025a，使用 evalc + ANS
                try
                    output = evalc('base', command); %#ok<EVLC>
                catch ME
                    output = ME.message;
                end
            else
                % 若当前版本高于 R2025a，使用 evaluateAndCapture
                try
                    output = evaluateAndCapture(this.Workspace, command);
                catch ME
                    output = ME.message;
                end
            end

            this.Widgets.html.sendEventToHTMLSource('ResultUpdated', output);
        end

        function callbackUserPromptSubmitted(this, ~, event)
            % 执行命令行窗口提交的用户提示词
            import kssolv.ui.util.Localizer.*

            userPrompt = event.HTMLEventData;

            initializationFailure = [];
            try
                if isempty(this.ChatBot)
                    % 若未初始化对话机器人，则创建对话机器人
                    [this.ChatBot, initializationFailure] = ...
                        kssolv.services.llm.chatBot('', '', ...
                        @(tokens) this.addChat(tokens));
                end
            catch exception
                initializationFailure = exception;
            end

            if ~isempty(initializationFailure)
                this.addChat(this.initializationFailureMessage( ...
                    initializationFailure));
                return
            end

            if isempty(this.ChatBot) || ~isvalid(this.ChatBot)
                this.addChat(message('KSSOLV:toolbox:LLMServiceInitializationFailed'));
                return
            end
            try
                this.ChatBot.chat(userPrompt.prompt, userPrompt.useHistory);
            catch
                this.addChat(message('KSSOLV:toolbox:LLMRequestFailed'));
            end
        end

        function content = initializationFailureMessage(~, failure)
            import kssolv.ui.util.Localizer.message

            switch string(failure.identifier)
                case "KSSOLV:LLM:MissingOpenAIConfiguration"
                    key = 'KSSOLV:toolbox:LLMConfigurationMissing';
                case "KSSOLV:LLM:AddonUnavailable"
                    key = 'KSSOLV:toolbox:LLMAddonUnavailable';
                otherwise
                    key = 'KSSOLV:toolbox:LLMServiceInitializationFailed';
            end
            content = message(key);
        end

        function callbackEventSent(~, ~, event)
            % 执行命令行窗口直接发送的事件
            command = event.HTMLEventData;
            if strcmp(command, "demo")
                % 若命令行窗口发送了 "demo"，则直接关闭当前项目，并打开 ks.ks 文件
                appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
                
                % 关闭所有已打开的 document
                documents = appContainer.getDocuments();
                for i = 1:numel(documents)
                    documents{i}.close();
                end

                % 更新 UI 界面
                kssolv.ui.util.DataStorage.setData('Project', kssolv.services.filemanager.Project());
                kssolv.ui.util.DataStorage.setData('ProjectFilename', '');
                kssolv.ui.util.DataStorage.getData('ProjectBrowser').reBuildUI();
                kssolv.ui.util.DataStorage.getData('InfoBrowser').reBuildUI();
                kssolv.KSSOLVToolbox.setAppContainerTitle();
                kssolv.KSSOLVToolbox.createListener();
                appContainer.bringToFront();

                % 导入并打开 ks.ks 文件
                kssolv.ui.util.DataStorage.setData('LoadingKsFile', true);
                ksFile = fullfile(KSSOLV_Toolbox.RootDirectory, 'ks.ks');
                project = kssolv.services.filemanager.Project.loadKsFile(ksFile);
                kssolv.ui.util.DataStorage.setData('Project', project);
                kssolv.ui.util.DataStorage.setData('ProjectFilename', ksFile);
                kssolv.ui.util.DataStorage.setData('LoadingKsFile', false);

                % 更新 UI 界面
                kssolv.ui.util.DataStorage.getData('ProjectBrowser').reBuildUI();
                kssolv.ui.util.DataStorage.getData('InfoBrowser').reBuildUI();
                kssolv.KSSOLVToolbox.setAppContainerTitle();
                kssolv.KSSOLVToolbox.createListener();
                appContainer.bringToFront();
            end
        end
    end

    methods (Hidden)
        function app = qeShow(this)
            % 用于在单元测试中测试 CommandWindow
            % 示例命令：
            % cw = kssolv.ui.components.databrowser.CommandWindow();
            % cw.qeShow()

            % 创建 AppContainer
            appOptions.Tag = sprintf('kssolv(%s)', char(matlab.lang.internal.uuid));
            appOptions.Title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:UnitTestTitle');
            appOptions.ToolstripEnabled = true;
            app = matlab.ui.container.internal.AppContainer(appOptions);

            % 保存 AppContainer 至 DataStorage
            kssolv.ui.util.DataStorage.setData('AppContainer', app);

            % 将 CommandWindow 添加到 App Container
            this.addToAppContainer(app);
            % 展示界面
            app.Visible = true;
        end
    end
end
