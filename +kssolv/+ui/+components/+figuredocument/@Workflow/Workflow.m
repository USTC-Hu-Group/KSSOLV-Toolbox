classdef Workflow < handle
    %WORKFLOW 工作流组件

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties
        DocumentGroupTag
        graphJSON string
        tag string
    end

    properties (Access = private)
        HTMLComponent
    end

    methods
        function this = Workflow(graphJSON, tag)
            %WORKFLOW 构造此类的实例
            arguments
                graphJSON string = ""
                tag string = ""
            end
            this.graphJSON = graphJSON;
            this.tag = tag;
            this.DocumentGroupTag = 'Workflow';

            appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
            group = appContainer.getDocumentGroup(this.DocumentGroupTag);
            if isempty(group)
                % 若 appContainer 没有 Tag 为 'Workflow' 的 DocumentGroup，
                % 则创建 DocumentGroup 并添加到 appContainer 中
                group = matlab.ui.internal.FigureDocumentGroup();
                group.Tag = this.DocumentGroupTag;
                group.Title = this.DocumentGroupTag;
                group.DefaultRegion = 'left';
                appContainer.add(group);
            end
        end
    end

    methods
        function Display(this)
            %DISPLAY 在 Document Group 中展示工作流画布
            appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
            document = appContainer.getDocument(this.DocumentGroupTag, this.tag);
            if ~isempty(document)
                % 如果具有相同 tag 的 document 存在，则选中它
                document.Selected = true;
                return
            end

            figOptions.Title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:DocumentWorkflowTitle');
            figOptions.DocumentGroupTag = this.DocumentGroupTag;
            if this.tag ~= ""
                figOptions.Tag = this.tag;

                project = kssolv.ui.util.DataStorage.getData('Project');
                figOptions.Title = project.findChildrenItem(this.tag).label;
            end
            document = matlab.ui.internal.FigureDocument(figOptions);

            % 添加 html 组件
            fig = document.Figure;
            g = uigridlayout(fig);
            g.BackgroundColor = 'white';
            g.Padding = 0;
            g.RowHeight = {'1x'};
            g.ColumnWidth = {'1x'};
            htmlFile = fullfile(fileparts(mfilename('fullpath')), 'workflow', 'index.html');
            this.HTMLComponent = uihtml(g, "HTMLSource", htmlFile);

            % 将画布数据保存在 html 组件中
            this.HTMLComponent.Data = this.graphJSON;

            % 接收从 HTML 组件触发的事件
            this.HTMLComponent.HTMLEventReceivedFcn = @this.eventReceiver;

            % 添加到 App Container
            appContainer.add(document);

            % 等待渲染完成
            waitfor(document.Figure, 'FigureViewReady', true);
            if isdeployed
                % document 会异常地取消停靠（undocked），在渲染完成后需要重新停靠它
                document.Docked = true;
            end

            % 请求同步一次 graphJSON，目的是在此刻初始化画布中所有节点对应的 taskUI 控件
            this.HTMLComponent.sendEventToHTMLSource('workflowExportToJSON', '[]');
        end
    end

    methods (Access = private)
        function eventReceiver(this, src, event)
            switch event.HTMLEventName
                case 'OpenSettingsWindow'
                    this.callbackOpenSettingsWindow(src, event);
                case 'GraphExportToJSON'
                    this.callbackGraphExportToJSON(src, event);
                case 'RefreshWorkflowCanvas'
                    this.callbackRefreshWorkflowCanvas(src, event);
            end
        end

        function callbackOpenSettingsWindow(this, ~, event)
            AppContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
            ConfigBrowser = kssolv.ui.util.DataStorage.getData('ConfigBrowser');
            Project = kssolv.ui.util.DataStorage.getData('Project');
            workflowItem = Project.findChildrenItem(this.tag);
            ConfigBrowserPanel = AppContainer.getPanel('ConfigBrowser');
            nodeID = event.HTMLEventData;

            if AppContainer.RightCollapsed
                % 若右侧面板已被折叠，则打开右侧面板
                ConfigBrowser.nodeID = nodeID;
                ConfigBrowser.graph = workflowItem.graph;
                ConfigBrowser.updateUI();
                pause(0.5);

                AppContainer.RightCollapsed = false;
                ConfigBrowserPanel.Collapsed = false;
                pause(0.6);
                this.HTMLComponent.sendEventToHTMLSource('workflowZoomToFit');
            else
                % 若右侧面板已被打开，则不处理折叠
                ConfigBrowser.nodeID = event.HTMLEventData;
                ConfigBrowser.graph = workflowItem.graph;
                ConfigBrowser.updateUI();
            end
        end

        function callbackGraphExportToJSON(this, ~, event)
            this.graphJSON = event.HTMLEventData;

            project = kssolv.ui.util.DataStorage.getData('Project');
            item = project.findChildrenItem(this.tag);
            if ~isempty(item)
                item.graphJSON = this.graphJSON;
                item.updatedAt = datetime;
                project.isDirty = true;
                % 更新 Info Browser 的界面
                kssolv.ui.util.DataStorage.getData('ProjectBrowser').resetSelectedItem();
            end
        end

        function callbackRefreshWorkflowCanvas(this, ~, ~)
            this.HTMLComponent.Data = this.graphJSON;
        end
    end

    methods (Static)
        function content = getDagJSON()
            % 读取 HTML 组件中的 dag.json
            dagFilePath = fullfile(fileparts(mfilename('fullpath')), 'workflow', 'assets', 'data', 'dag.json');
            content = fileread(dagFilePath, "Encoding", "UTF-8");
        end

        function document = getCurrentWorkflowDocument()
            % 获取当前最新打开的工作流 document
            appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
            documentGroup = appContainer.getDocumentGroup('Workflow');

            if isempty(documentGroup) || isempty(documentGroup.LastSelected.tag)
                % 说明该 documentGroup 下没有 document 被选中
                document = matlab.ui.internal.FigureDocument.empty;
                return
            end

            tag = documentGroup.LastSelected.tag;
            document = appContainer.getDocument('Workflow', tag);
        end

        function sendEventToWorkflowUI(eventName, eventData)
            % 向当前最新打开的工作流 document 发送事件
            arguments
                eventName string {mustBeNonempty}
                eventData = struct.empty
            end

            document = kssolv.ui.components.figuredocument.Workflow.getCurrentWorkflowDocument();
            if isempty(document)
                return
            end

            h = document.Figure.Children.Children;
            h.sendEventToHTMLSource(eventName, ...
                jsonencode(eventData, "PrettyPrint", true));
        end

        function loadWfFile(wfFilePath)
            workflowItem = kssolv.services.filemanager.Workflow.loadWfFile(wfFilePath);
            project = kssolv.ui.util.DataStorage.getData('Project');
            workflowRoot = project.findChildrenItem('Workflow');
            workflowRoot.addWorkflowItem(workflowItem);

            projectBrowser = kssolv.ui.util.DataStorage.getData('ProjectBrowser');
            projectBrowser.updateTreetable('ADD', workflowRoot.name, workflowRoot.children{end}.encodeToJSON(1));
            projectBrowser.updateTreetable('PATCH', workflowRoot.name, workflowRoot.encodeToJSON(1));
        end
    end

    methods (Hidden)
        function app = qeShow(this)
            % 用于在单元测试中测试 Workflow，可通过下面的命令使用：
            % w = kssolv.ui.components.figuredocument.Workflow();
            % w.qeShow()

            % 创建 App Container
            appOptions.Tag = sprintf('kssolv(%s)',char(matlab.lang.internal.uuid));
            appOptions.Title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:UnitTestTitle');
            appOptions.ToolstripEnabled = true;
            app = matlab.ui.container.internal.AppContainer(appOptions);

            % 保存 app 至 DataStorage
            import kssolv.ui.util.DataStorage.*
            setData('AppContainer', app);

            % 添加 Document Group
            group = matlab.ui.internal.FigureDocumentGroup();
            group.Tag = 'DocumentGroupTest';
            group.Title = 'DocumentGroupTest';
            group.DefaultRegion = 'left';
            app.add(group);

            % 展示界面
            app.Visible = true;

            % 展示 Workflow 画布
            this.DocumentGroupTag = 'DocumentGroupTest';
            this.Display();
        end
    end
end
