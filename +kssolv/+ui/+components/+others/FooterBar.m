classdef FooterBar < handle
    %FOOTERBAR 自定义的底部状态栏

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties
        statusBar % 组件的容器
        statusContext % 组件的状态上下文
        statusLabel % 文字标签组件
    end

    methods
        function this = FooterBar()
            % 构造函数
            this.createComponents();
            this.createStatusContext();

            % 保存至 DataStorage
            kssolv.ui.util.DataStorage.setData('FooterBar', this);
        end

        function createStatusContext(this)
            % 创建状态上下文
            this.statusContext = matlab.ui.container.internal.appcontainer.ContextDefinition();
            this.statusContext.Tag = 'FooterBarContext';
            this.statusContext.StatusComponentTags = {this.statusLabel.Tag};
        end

        function createComponents(this)
            % 创建并配置底部状态栏组件
            this.statusBar = matlab.ui.internal.statusbar.StatusBar();
            this.statusBar.Tag = 'StatusBar';

            this.statusLabel = matlab.ui.internal.statusbar.StatusLabel();
            this.statusLabel.Tag = 'StatusLabel';
            this.statusLabel.Region = 'right';
        end

        function addToAppContainer(this, appContainer)
            % 添加状态栏到 AppContainer，并处理上下文
            appContainer.add(this.statusBar);
            appContainer.add(this.statusLabel);
            appContainer.Contexts = [appContainer.Contexts {this.statusContext}];
            appContainer.ActiveContexts = this.statusContext.Tag;
        end

        function setLabelText(this, text)
            % 设置标签组件的文本
            arguments
                this
                text {mustBeTextScalar}
            end

            this.statusLabel.Text = text;
        end
    end

    methods (Static, Hidden)
        function app = qeShow()
            % 用于在单元测试中测试 FooterBar，可通过下面的命令使用：
            % kssolv.ui.components.others.FooterBar.qeShow();

            % 创建 AppContainer
            appOptions.Tag = sprintf('kssolv(%s)',char(matlab.lang.internal.uuid));
            appOptions.Title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:UnitTestTitle');
            appOptions.ToolstripEnabled = true;
            app = matlab.ui.container.internal.AppContainer(appOptions);

            % 添加 FooterBar
            footerBar = kssolv.ui.components.others.FooterBar();
            footerBar.addToAppContainer(app);

            % 设定 FooterBar Label
            footerBar.setLabelText('正忙');

            % 展示界面
            app.Visible = true;
        end
    end
end

