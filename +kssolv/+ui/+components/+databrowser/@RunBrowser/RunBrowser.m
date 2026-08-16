classdef RunBrowser < matlab.ui.internal.databrowser.AbstractDataBrowser
    %RUNBROWSER 自定义的 Data Browser 组件，存放运行相关控件

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties
        Widgets   % 小组件
    end

    properties (Access = private)
        hasOutputToDisplay (1, 1) logical = false % 输出区域是否已经输出了内容
    end

    methods
        function this = RunBrowser()
            %RUNBROWSER 构造此类的实例
            title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:RunBrowserTitle');
            % 调用超类构造函数
            this = this@matlab.ui.internal.databrowser.AbstractDataBrowser('RunBrowser', title);
            % 自定义 widget 和 layout
            buildUI(this);
            % 设定 FigurePanel 的 Tag
            this.Panel.Tag = 'RunBrowser';
            % 将该 Browser 放在界面右侧
            this.Panel.Region = "right";

            % 将 RunBrowser 保存到 DataStorage
            kssolv.ui.util.DataStorage.setData('RunBrowser', this);

            % 使用 Diary 服务获取输出文本
            diaryService = kssolv.services.logs.Diary.getInstance();
            addlistener(diaryService, 'NewOutput', @(src, event) handleNewOutputEvent(this, event.Content));
        end

        function delete(~)
            %DELETE 析构函数
            diaryService = kssolv.services.logs.Diary.getInstance();
            delete(diaryService);
        end

        function addNewLineToOutputTextArea(this)
            %ADDNEWLINETOOUTPUTTEXTAREA 在输出区域增加换行以便于阅读
            currentTime = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss', 'TimeZone', 'Asia/Shanghai');
            outputTextArea = this.Widgets.OutputTextPanel.OutputTextArea;
            outputTextArea.HorizontalAlignment = 'left';

            if this.hasOutputToDisplay
                outputTextArea.Value = [outputTextArea.Value; ' '; char(currentTime)];
            else
                outputTextArea.Value = char(currentTime);
                outputTextArea.FontColor = 'black';
                this.hasOutputToDisplay = true;
            end
        end

        function restoreButtons(this)
            %RESTOREBUTTONS 恢复运行按钮和停止按钮至默认状态
            homeTab = kssolv.ui.util.DataStorage.getData('HomeTab');
            homeTab.Widgets.RunningSection.RunningRunButton.Enabled = true;
            homeTab.Widgets.RunningSection.RunningStopButton.Enabled = false;

            this.Widgets.ButtonPanel.RunButton.Enable = true;
            this.Widgets.ButtonPanel.StopButton.Enable = false;
        end
    end

    methods (Access = protected)
        function buildUI(this)
            % 创建网格布局
            g = uigridlayout(this.Figure);
            g.BackgroundColor = "white";
            g.Padding = [0 0 0 0];
            g.RowHeight = {'fit', '1x'};
            g.ColumnWidth = {'1x'};

            % 创建 buttonPanelLayout
            buttonPanelLayout = uigridlayout(g);
            buttonPanelLayout.BackgroundColor = "white";
            buttonPanelLayout.ColumnWidth = {25, 'fit', 25, 'fit', 25, '1x', 25, 'fit'};
            buttonPanelLayout.RowHeight = {'1x'};
            buttonPanelLayout.Padding = 10;
            buttonPanelLayout.RowSpacing = 5;
            buttonPanelLayout.ColumnSpacing = 5;

            import kssolv.ui.util.Localizer.*
            import kssolv.ui.components.databrowser.RunBrowser.createButton
            import matlab.ui.internal.toolstrip.Icon

            % 运行按钮，Row = 1，Column = 1
            runButtonTooltip = message('KSSOLV:toolbox:RunBrowserRunButtonTooltip');
            runButtonIcon = 'playControl';
            runButton = createButton(buttonPanelLayout, 1, 1, ...
                runButtonTooltip, runButtonIcon);
            runButton.ButtonPushedFcn = @(src, event) callbackRunButton(this, src, event);
            % 运行标签，Row = 1，Column = 2
            runLabel = uilabel(buttonPanelLayout);
            runLabel.Text = message('KSSOLV:toolbox:RunBrowserRunLabel');
            runLabel.Layout.Row = 1;
            runLabel.Layout.Column = 2;

            % 停止按钮，Row = 1，Column = 3
            stopButtonTooltip = message('KSSOLV:toolbox:RunBrowserStopButtonTooltip');
            stopButtonIcon = 'stop';
            stopButton = createButton(buttonPanelLayout, 1, 3, ...
                stopButtonTooltip, stopButtonIcon);
            stopButton.Enable = false;
            stopButton.ButtonPushedFcn = @(src, event) callbackStopButton(this, src, event);
            % 停止标签，Row = 1，Column = 4
            stopLabel = uilabel(buttonPanelLayout);
            stopLabel.Text = message('KSSOLV:toolbox:RunBrowserStopLabel');
            stopLabel.Layout.Row = 1;
            stopLabel.Layout.Column = 4;

            % 清空按钮，Row = 1，Column = 7
            clearButtonTooltip = message('KSSOLV:toolbox:RunBrowserClearButtonTooltip');
            clearButtonIcon = 'clear';
            clearButton = createButton(buttonPanelLayout, 1, 7, ...
                clearButtonTooltip, clearButtonIcon);
            clearButton.ButtonPushedFcn = @(src, event) callbackClearButton(this, src, event);
            % 清空标签，Row = 1，Column = 8
            clearLabel = uilabel(buttonPanelLayout);
            clearLabel.Text = message('KSSOLV:toolbox:RunBrowserClearLabel');
            clearLabel.Layout.Row = 1;
            clearLabel.Layout.Column = 8;

            % 添加到 Widgets
            this.Widgets.ButtonPanel = struct('RunButton', runButton, ...
                'StopButton', stopButton, 'ClearButton', clearButton);

            % 创建 outputPanelLayout
            outputPanelLayout = uigridlayout(g);
            outputPanelLayout.BackgroundColor = "white";
            outputPanelLayout.ColumnWidth = {'1x'};
            outputPanelLayout.RowHeight = {'1x'};
            outputPanelLayout.Padding = [10 10 10 0];

            % 日志输出区域
            outputTextArea = uitextarea(outputPanelLayout, "Value", message('KSSOLV:toolbox:RunBrowserOutputTextAreaEmptyContent'), ...
                'BackgroundColor', 'white', "FontName", 'monospace', 'FontSize', 13, 'FontColor', '#808080', ...
                'WordWrap', 'on', 'Editable', 'off');
            outputTextArea.HorizontalAlignment = 'center';

            % 添加到 Widgets
            this.Widgets.OutputTextPanel = struct('OutputTextArea', outputTextArea);
        end
    end

    methods (Access = private)
        function callbackRunButton(this, ~, ~)
            workflowDocument = kssolv.ui.components.figuredocument.Workflow.getCurrentWorkflowDocument();
            if isempty(workflowDocument)
                this.restoreButtons();
                return
            end

            project = kssolv.ui.util.DataStorage.getData('Project');
            homeTab = kssolv.ui.util.DataStorage.getData('HomeTab');
            homeTab.Widgets.RunningSection.RunningRunButton.Enabled = false;
            homeTab.Widgets.RunningSection.RunningStopButton.Enabled = true;
            this.Widgets.ButtonPanel.RunButton.Enable = false;
            this.Widgets.ButtonPanel.StopButton.Enable = true;

            % 增加换行以便于阅读
            this.addNewLineToOutputTextArea();

            workflowRoot = project.findChildrenItem('Workflow');
            workflow = workflowRoot.findChildrenItem(workflowDocument.Tag);
            cleanup = onCleanup(@()this.restoreButtons());
            [mode, record] = kssolv.ui.features.remote. ...
                RemoteRunController.execute(workflow.graph, ...
                string(workflow.label), string(workflowDocument.Tag));
            if mode == "Remote"
                fprintf(char(string(kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:dialogs:RemoteSubmitted")) + newline), ...
                    record.LocalJobId);
            end
            clear cleanup
            this.restoreButtons();
        end

        function callbackStopButton(this, ~, ~)
            this.restoreButtons();
        end

        function callbackClearButton(this, ~, ~)
            kssolv.services.logs.Diary.clearHistory();
            outputTextArea = this.Widgets.OutputTextPanel.OutputTextArea;
            outputTextArea.Value = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:RunBrowserOutputTextAreaEmptyContent');
            outputTextArea.FontColor = '#808080';
            outputTextArea.HorizontalAlignment = 'center';
            this.hasOutputToDisplay = false;
        end

        function handleNewOutputEvent(this, content)
            outputTextArea = this.Widgets.OutputTextPanel.OutputTextArea;
            outputTextArea.HorizontalAlignment = 'left';

            % 若 content 中存在超链接标签，则过滤出超链接文本
            if ~isempty(regexp(content, '<a\s+[^>]*>([^<]*)</a>', 'once'))
                content = regexprep(content, '<a\s+[^>]*>([^<]*)</a>', '$1');
            end

            if this.hasOutputToDisplay
                outputTextArea.Value = [outputTextArea.Value; content];
            else
                outputTextArea.Value = content;
                outputTextArea.FontColor = 'black';
                this.hasOutputToDisplay = true;
            end

            % 自动滚动至底部
            scroll(outputTextArea, "bottom");
        end
    end

    methods (Access = private, Static)
        function button = createButton(buttonPanelLayout, row, column, tooltip, icon, buttonText)
            % 创建按钮
            arguments
                buttonPanelLayout
                row
                column
                tooltip
                icon
                buttonText = ""
            end
            button = uibutton(buttonPanelLayout, "Interruptible", "off");
            button.Layout.Row = row;
            button.Layout.Column = column;
            button.BackgroundColor = 'white';
            button.Tooltip = tooltip;

            if buttonText == ""
                button.Text = '';
                matlab.ui.control.internal.specifyIconID(button, icon, 16);
            else
                buttonPanelLayout.ColumnWidth{column} = 'fit';
                button.Text = buttonText;
            end
            button.IconAlignment = "center";
        end
    end

    methods (Hidden)
        function this = qeShow(this)
            % 用于在单元测试中测试 RunBrowser，可通过下面的命令使用：
            % kssolv.ui.components.databrowser.RunBrowser().qeShow();

            % 启动 Diary 服务
            kssolv.services.logs.Diary.getInstance();

            % 创建 AppContainer
            appOptions.Tag = sprintf('kssolv(%s)',char(matlab.lang.internal.uuid));
            appOptions.Title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:UnitTestTitle');
            appOptions.ToolstripEnabled = true;
            app = matlab.ui.container.internal.AppContainer(appOptions);

            % 将 RunBrowser 添加到 App Container
            this.addToAppContainer(app);
            % 展示界面
            app.Visible = true;

            % 等待渲染完成后，输出一些文本
            waitfor(this.Figure, 'FigureViewReady', true);
            disp(help("edit"));
        end
    end
end
