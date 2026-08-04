classdef DataPlot
    %DATAPLOT 展示数据绘图结果

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties
        DocumentGroupTag
        tag string
        figureFilePath string
        figure
    end

    methods
        function this = DataPlot(figureFilePathOrFigure, tag)
            %DATAPLOT 构造函数
            arguments
                figureFilePathOrFigure
                tag string = ""
            end

            this.tag = tag;
            if isa(figureFilePathOrFigure, 'matlab.ui.Figure') || isa(figureFilePathOrFigure, 'matlab.graphics.chartcontainer.ChartContainer')
                % 如果输入是 figure 类型或 ChartContainer 类型
                if isvalid(figureFilePathOrFigure) && ~isempty(figureFilePathOrFigure)
                    this.figure = figureFilePathOrFigure;
                    this.figureFilePath = "";
                else
                    this.figure = [];
                    this.figureFilePath = "";
                end
            elseif isstring(figureFilePathOrFigure) || ischar(figureFilePathOrFigure)
                % 如果输入是字符串路径，检查文件扩展名
                [~, ~, ext] = fileparts(figureFilePathOrFigure);
                if strcmpi(ext, '.fig')
                    % 如果是 .fig 文件，使用 openfig 读取并保存到 this.figure
                    this.figure = openfig(figureFilePathOrFigure, 'invisible');
                    this.figureFilePath = figureFilePathOrFigure;
                else
                    % 如果是其他图片格式（如 .png, .jpg），仅保存路径
                    this.figure = [];
                    this.figureFilePath = figureFilePathOrFigure;
                end
            else
                error('KSSOLV:figuredocument:DataPlot', ...
                    kssolv.ui.util.Localizer.message('KSSOLV:toolbox:DataPlotInputParameterError'));
            end

            this.DocumentGroupTag = 'Plot';
            appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
            group = appContainer.getDocumentGroup(this.DocumentGroupTag);
            if isempty(group)
                % 若 appContainer 没有 Tag 为 'Plot' 的 DocumentGroup，
                % 则创建 DocumentGroup 并添加到 appContainer 中
                group = matlab.ui.internal.FigureDocumentGroup();
                group.Tag = this.DocumentGroupTag;
                group.Title = this.DocumentGroupTag;
                group.DefaultRegion = 'left';
                appContainer.add(group);
            end
        end

        function Display(this, title, resolveProjectTitle)
            %DISPLAY 在 Document Group 中展示图像
            arguments
                this
                title (1, :) char = 'Plot'
                resolveProjectTitle (1,1) logical = true
            end

            appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
            document = appContainer.getDocument(this.DocumentGroupTag, this.tag);
            if ~isempty(document)
                % 如果具有相同 tag 的 document 存在，则选中它
                document.Selected = true;
                return
            end

            figOptions.Title = title;
            figOptions.DocumentGroupTag = this.DocumentGroupTag;
            if this.tag ~= ""
                figOptions.Tag = this.tag;

                if resolveProjectTitle
                    project = kssolv.ui.util.DataStorage.getData('Project');
                    item = project.findChildrenItem(this.tag);
                    if ~isempty(item)
                        figOptions.Title = item.label;
                    end
                end
            end
            document = matlab.ui.internal.FigureDocument(figOptions);

            % 创建 uigrid
            fig = document.Figure;
            g = uigridlayout(fig);
            g.BackgroundColor = 'white';
            g.RowHeight = {'1x'};
            g.ColumnWidth = {'1x'};

            if ~isempty(this.figure)
                if isa(this.figure, 'matlab.ui.Figure')
                    ax = findobj(this.figure, 'Type', 'Axes');
                    set(ax, 'Parent', g);
                else
                    ax = this.figure.getAxesObject();
                    ax.Parent = g;
                    this.figure.Parent = [];
                end
            else
                image = uiimage(g);
                image.ImageSource = this.figureFilePath;
            end

            % 添加到 App Container
            appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
            appContainer.add(document);

            % 等待渲染完成
            waitfor(document.Figure, 'FigureViewReady', true);
            if isdeployed
                % document 会异常地取消停靠（undocked），在渲染完成后需要重新停靠它
                document.Docked = true;
            end
        end
    end

    methods (Static, Hidden)
        function app = qeShow()
            % 用于在单元测试中测试 DataPlot，可通过下面的命令使用：
            % d = kssolv.ui.components.figuredocument.DataPlot.qeShow();

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

            % 展示 DataPlot
            figureFilePath = fullfile(fileparts(mfilename('fullpath')), ...
                'test', 'gtk.fig');
            plot = kssolv.ui.components.figuredocument.DataPlot(figureFilePath);
            plot.DocumentGroupTag = 'DocumentGroupTest';
            plot.Display('gtk.fig');
        end
    end
end
