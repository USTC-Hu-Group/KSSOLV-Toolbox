classdef ProjectBrowser < matlab.ui.internal.databrowser.AbstractDataBrowser
    %PROJECTBROWSER 自定义的 Data Browser 组件，存放 ks 项目文件的 TreeTable 视图

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties
        Widgets
    end

    properties (SetObservable)
        currentSelectedItem   % 当前选中的节点
    end

    properties (Access = private)
        CurrentProject
        CurrentProjectFilename (1, 1) string = ""
        CurrentAppContainer
    end

    methods
        function this = ProjectBrowser()
            %PROJECTBROWSER 构造此类的实例
            title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:ProjectBrowserTitle');
            % 调用超类构造函数
            this = this@matlab.ui.internal.databrowser.AbstractDataBrowser('ProjectBrowser', title);
            % 自定义 widget 和 layout
            buildUI(this);
            % 设定 FigurePanel 的 Tag
            this.Panel.Tag = 'ProjectBrowser';
            % 保存至 DataStorage
            kssolv.ui.util.DataStorage.setData('ProjectBrowser', this);
        end

        function updateTreetable(this, action, itemName, itemJSON)
            arguments
                this
                action {mustBeMember(action, {'ADD', 'PATCH', 'DELETE'})}
                itemName {mustBeNonempty}
                itemJSON string = ''
            end
            eventName = strcat(lower(action), 'Item');
            eventData = struct('itemName', itemName, 'itemJSON', itemJSON);
            this.Widgets.html.sendEventToHTMLSource(eventName, ...
                jsonencode(eventData, "PrettyPrint", true));

            if action == "PATCH"
                % 更新 html 组件中的 tableData 变量，以便在折叠时能够折叠新增的节点
                project = this.resolveCurrentProject();
                this.Widgets.html.sendEventToHTMLSource('updateTreeTableData', ...
                    project.encodeToJSON());
            end
        end

        function refreshUIAfterItemCreation(this, item)
            % 在新增 item 时更新部分 UI
            this.updateTreetable('ADD', item.name, item.children{end}.encodeToJSON(1));
            this.updateTreetable('PATCH', item.name, item.encodeToJSON(1));
        end

        function reBuildUI(this)
            % 重新渲染 Project Browser 的 UI 界面
            % 可用于加载了新的 .ks 文件后使用
            this.buildUI();
        end

        function resetSelectedItem(this)
            % 触发监听 currentSelectedItem 变化的监听器
            this.resolveCurrentProject();
            this.currentSelectedItem = this.currentSelectedItem;
        end

        function [project, projectFilename] = getCurrentProject(this)
            %GETCURRENTPROJECT Return the live project and repair its cache.
            [project, projectFilename] = this.resolveCurrentProject();
        end
    end

    methods (Access = protected)
        function buildUI(this)
            fig = this.Figure;
            g = uigridlayout(fig);
            g.BackgroundColor = "white";
            g.Padding = [0 0 0 0];
            g.RowHeight = {'1x'};
            g.ColumnWidth = {'1x'};

            htmlFile = fullfile(fileparts(mfilename('fullpath')), 'TreeTable', 'TreeTable.html');
            h = uihtml(g, "HTMLSource", htmlFile);
            this.Widgets.html = h;

            % 将当前加载的 project 文件编码为 JSON，发送给 HTML 组件
            project = this.resolveCurrentProject();
            h.Data = project.encodeToJSON();

            % 接收从 HTML 组件触发的事件
            h.HTMLEventReceivedFcn = @this.eventReceiver;
        end
    end

    methods (Access = private)
        function eventReceiver(this, src, event)
            switch event.HTMLEventName
                case 'RowClicked'
                    this.callbackRowClicked(src, event);
                case 'RowDoubleClicked'
                    this.callbackRowDoubleClicked(src, event);
                case 'RowRemoved'
                    this.callbackRowRemoved(src, event);
                case 'ClientError'
                    warning("KSSOLV:ProjectBrowser:HTMLClientError", ...
                        "Project Browser JavaScript error: %s", ...
                        string(event.HTMLEventData));
            end
        end

        function callbackRowClicked(this, ~, event)
            % 先恢复 Project，再触发 PostSet 监听器。否则 InfoBrowser 会
            % 在 DataStorage 被清空后尝试对 double([]) 调用对象方法。
            this.resolveCurrentProject();
            this.currentSelectedItem = event.HTMLEventData;
        end

        function callbackRowDoubleClicked(this, ~, event)
            project = this.resolveCurrentProject();
            this.currentSelectedItem = event.HTMLEventData;

            item = project.findChildrenItem(this.currentSelectedItem);
            if isempty(item)
                return
            end
            switch class(item)
                case 'kssolv.services.filemanager.Structure'
                    if startsWith(item.parent.name, 'Project')
                        % 打开导入结构文件对话框，导入和解析结构文件，并显示渲染的结构
                        importedFileCount = item.importStructureFromFile();
                        if importedFileCount > 0
                            startIndex = numel(item.children) - importedFileCount + 1;
                            for index = startIndex : numel(item.children)
                                % 更新 TreeTable
                                this.updateTreetable('ADD', item.name, item.children{index}.encodeToJSON(1));
                            end
                            this.updateTreetable('PATCH', item.name, item.encodeToJSON(1));
                        end
                    else
                        % 直接显示渲染的结构
                        item.showMoleculeDisplay();
                    end
                case 'kssolv.services.filemanager.Workflow'
                    if startsWith(item.parent.name, 'Project')
                        % 新增 workflow 项，并打开相应的 document
                        item.createWorkflowItem();
                        % 更新 TreeTable
                        this.refreshUIAfterItemCreation(item);
                    else
                        % 直接显示工作流画布
                        item.showWorkflowDisplay();
                    end
                case 'kssolv.services.filemanager.Volume'
                    if startsWith(item.parent.name, 'Project')
                        importedFileCount = item.importVolumeFromFile();
                        if importedFileCount > 0
                            startIndex = numel(item.children) - ...
                                importedFileCount + 1;
                            for index = startIndex:numel(item.children)
                                this.updateTreetable('ADD', item.name, ...
                                    item.children{index}.encodeToJSON(1));
                            end
                            this.updateTreetable('PATCH', item.name, ...
                                item.encodeToJSON(1));
                        end
                    else
                        item.showVolumeDisplay();
                    end
                otherwise
                    if strcmp(item.type, "Plot")
                        plotHandler = item.data;
                        plotHandler.replot();
                        dataPlot = kssolv.ui.components.figuredocument.DataPlot(plotHandler, item.name);
                        dataPlot.Display(item.label);
                    end
            end
        end

        function callbackRowRemoved(this, ~, event)
            removedItemName = event.HTMLEventData;
            project = this.resolveCurrentProject();
            appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
            removedItem = project.findChildrenItem(removedItemName);
            if isempty(removedItem)
                return
            end
            parentItem = removedItem.parent;

            % 关闭相应的 document
            document = appContainer.getDocument(removedItem.category, removedItem.name);
            if ~isempty(document)
                closed = document.close();
                if ~closed
                    % 用户取消关闭时，同步取消 Project 节点删除。
                    this.reBuildUI();
                    return
                end
            end
            % 在 project 中移除对应的子节点
            parentItem.removeChildrenItem(removedItemName);
            % 更新父节点的 Size 显示
            this.updateTreetable('PATCH', parentItem.name, parentItem.encodeToJSON(1));
        end

        function [project, projectFilename] = resolveCurrentProject(this)
            % ProjectBrowser 保留一份当前 Project 句柄。若执行 clear 等
            % 操作重置了 DataStorage 的 persistent 状态，仍可从可见的
            % Project Browser 恢复项目和文件名，供所有 UI 路径继续使用。
            this.restoreAppContainer();
            project = kssolv.ui.util.DataStorage.getData('Project');
            projectFilename = ...
                kssolv.ui.util.DataStorage.getData('ProjectFilename');
            if isa(project, 'kssolv.services.filemanager.Project') && ...
                    isvalid(project)
                isSameProject = isequal(project, this.CurrentProject);
                this.CurrentProject = project;

                if this.isValidProjectFilename(projectFilename)
                    this.CurrentProjectFilename = string(projectFilename);
                elseif isSameProject
                    projectFilename = this.CurrentProjectFilename;
                    kssolv.ui.util.DataStorage.setData( ...
                        'ProjectFilename', projectFilename);
                else
                    projectFilename = "";
                    this.CurrentProjectFilename = projectFilename;
                    kssolv.ui.util.DataStorage.setData( ...
                        'ProjectFilename', projectFilename);
                end
                return
            end

            project = this.CurrentProject;
            if ~isa(project, 'kssolv.services.filemanager.Project') || ...
                    ~isvalid(project)
                error('KSSOLV:ProjectBrowser:ProjectUnavailable', ...
                    'The current project is unavailable.');
            end
            kssolv.ui.util.DataStorage.setData('Project', project);
            projectFilename = this.CurrentProjectFilename;
            kssolv.ui.util.DataStorage.setData( ...
                'ProjectFilename', projectFilename);
        end

        function status = isValidProjectFilename(~, value)
            status = (isstring(value) && isscalar(value)) || ...
                (ischar(value) && (isrow(value) || isempty(value)));
        end

        function restoreAppContainer(this)
            appContainer = ...
                kssolv.ui.util.DataStorage.getData('AppContainer');
            if isobject(appContainer) && isvalid(appContainer)
                this.CurrentAppContainer = appContainer;
                return
            end

            appContainer = this.CurrentAppContainer;
            if isobject(appContainer) && isvalid(appContainer)
                kssolv.ui.util.DataStorage.setData( ...
                    'AppContainer', appContainer);
            end
        end
    end

    methods (Hidden)
        function app = qeShow(this)
            % 用于在单元测试中测试 ProjectBrowser，可通过下面的命令使用：
            % b = kssolv.ui.components.databrowser.ProjectBrowser();
            % b.qeShow()

            % 创建 AppContainer
            appOptions.Tag = sprintf('kssolv(%s)',char(matlab.lang.internal.uuid));
            appOptions.Title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:UnitTestTitle');
            appOptions.ToolstripEnabled = true;
            app = matlab.ui.container.internal.AppContainer(appOptions);

            % 将 Browser 添加到 App Container
            this.addToAppContainer(app);
            % 展示界面
            app.Visible = true;
        end
    end
end
