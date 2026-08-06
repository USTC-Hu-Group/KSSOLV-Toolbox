classdef InfoBrowser < matlab.ui.internal.databrowser.AbstractDataBrowser
    %INFOBROWSER 自定义的 Data Browser 组件，显示 Project Browser 里对应项的具体信息
    
    %   开发者：杨柳
    %   版权 2024 合肥瀚海量子科技有限公司
    
    properties
        Widgets
    end
    
    methods
        function this = InfoBrowser()
            %INFOBROWSER 构造此类的实例
            title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:InfoBrowserTitle');
            % 调用超类构造函数
            this = this@matlab.ui.internal.databrowser.AbstractDataBrowser('InfoBrowser', title);          
            % 自定义 widget 和 layout
            buildUI(this);
            % 设定 FigurePanel 的 Tag
            this.Panel.Tag = 'InfoBrowser';
            % 设定初始高度
            this.Panel.PreferredHeight = 342;
            % 添加 ProjectBrowser 的监听器
            projectBrowser = kssolv.ui.util.DataStorage.getData('ProjectBrowser');
            addlistener(projectBrowser, 'currentSelectedItem', 'PostSet', ...
                    @this.handleCurrentSelectedItem);
            % 保存至 DataStorage
            kssolv.ui.util.DataStorage.setData('InfoBrowser', this);
        end

        function reBuildUI(this)
            % 重新渲染 Info Browser 的 UI 界面
            % 可用于清空 Info Browser 的信息显示
            this.buildUI();
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
            
            htmlFile = fullfile(fileparts(mfilename('fullpath')), 'html', 'index.html');
            h = uihtml(g, "HTMLSource", htmlFile);
            this.Widgets.html = h;

            % 接收从 HTML 组件触发的事件
            h.HTMLEventReceivedFcn = @this.eventReceiver;
        end
    end

    methods (Access = private)
        function eventReceiver(this, src, event)
            switch event.HTMLEventName
                case 'ValueChanged'
                    this.callbackValueChanged(src, event);
                case 'ClientError'
                    warning("KSSOLV:InfoBrowser:HTMLClientError", ...
                        "Information Browser JavaScript error: %s", ...
                        string(event.HTMLEventData));
            end
        end

        function callbackValueChanged(~, ~, event)
            newValueJSON = event.HTMLEventData;
            newValueStruct = jsondecode(newValueJSON);
        
            name = newValueStruct.name;
            key = newValueStruct.key;
            value = newValueStruct.value;
        
            % 更新 Project 中相应 item 的属性
            project = kssolv.ui.util.DataStorage.getData('Project');
            if ~isa(project, 'kssolv.services.filemanager.Project') || ...
                    ~isvalid(project)
                return
            end
            item = project.findChildrenItem(name);
            if isempty(item)
                return
            end
            item.setItemProperty(key, value);

            % 更新 Info Browser 界面
            projectBrowser = kssolv.ui.util.DataStorage.getData('ProjectBrowser');
            projectBrowser.resetSelectedItem();

            if key == "label"
                % 更新 Project Browser 界面
                projectBrowser.updateTreetable('PATCH', item.name, item.encodeToJSON(1));

                % 更新已打开的 document 标签页的标题
                appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
                document = appContainer.getDocument(item.category, item.name);
                if ~isempty(document)
                    document.Title = item.label;
                end
            end
        end

        function handleCurrentSelectedItem(this, ~, event)
            project = kssolv.ui.util.DataStorage.getData('Project');
            if ~isa(project, 'kssolv.services.filemanager.Project') || ...
                    ~isvalid(project)
                return
            end
            name = event.AffectedObject.currentSelectedItem;
            item = project.findChildrenItem(name);
            if ~isempty(item)
                this.Widgets.html.Data = item.encode();
            end
        end
    end

    methods (Hidden)
        function app = qeShow(this)
            % 用于在单元测试中测试 InfoBrowser，可通过下面的命令使用：
            % b = kssolv.ui.components.databrowser.InfoBrowser();
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
