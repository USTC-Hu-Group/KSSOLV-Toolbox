classdef BuildWorkflowFromTemplate < controllib.ui.internal.dialog.AbstractDialog
    %BUILDWORKFLOWFROMTEMPLATE 从预置和自定义的模板中导入工作流

    %   开发者：杨柳
    %   版权 2024 合肥瀚海量子科技有限公司

    properties
        workflowTemplatePanel
    end

    methods (Access = public)
        function this = BuildWorkflowFromTemplate()
            % 构造函数
            this.Name = 'BuildWorkflowFromTemplate';
            this.Title = '从模板建立工作流';
            buildUI(this);
        end
    end

    methods (Access = private)
        function onImportWorkflowButtonPushed(this, ~, ~)
            % 关闭对话框
            close(this);
            kssolv.ui.components.figuredocument.Workflow().Display();
        end
    end

    methods (Access = protected)
        function buildUI(this)
            g = uigridlayout('Parent', this.UIFigure);
            g.RowHeight = {350, 40, 'fit'};
            g.ColumnWidth = {'1x'};

            % 创建 WorkflowTemplatePanel
            this.workflowTemplatePanel = kssolv.ui.components.panel.WorkflowTemplatePanel(g);
            panel = this.workflowTemplatePanel.getWidget();
            panel.Layout.Row = 1;
            panel.Layout.Column = 1;

            % 创建 GridLayout
            gridLayout = uigridlayout(g);
            gridLayout.ColumnWidth = {'1x', 60};
            gridLayout.RowHeight = {30};

            % 创建 importWorkflowButton
            importWorkflowButton = uibutton(gridLayout, 'push');
            importWorkflowButton.ButtonPushedFcn = @this.onImportWorkflowButtonPushed;
            importWorkflowButton.Layout.Row = 1;
            importWorkflowButton.Layout.Column = 2;
            importWorkflowButton.Text = '插入';
        end

        function cleanupUI(this)
            % 清理 Panel
            if ~isempty(this.workflowTemplatePanel) && this.workflowTemplatePanel.IsWidgetValid
                delete(this.workflowTemplatePanel);
            end
        end
    end

    methods (Hidden)
        function this = qeShow(this, openInspect)
            arguments
                this
                openInspect logical = false
            end
            % 用于在单元测试中测试当前对话框，可通过下面的命令使用：
            % d = kssolv.ui.components.dialog.BuildWorkflowFromTemplate();
            % d.qeShow()

            % 创建 AppContainer
            appOptions.Tag = sprintf('kssolv(%s)',char(matlab.lang.internal.uuid));
            appOptions.Title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:UnitTestTitle');
            appOptions.ToolstripEnabled = true;
            app = matlab.ui.container.internal.AppContainer(appOptions);

            % 展示界面
            app.Visible = true;

            % 在 App Container 中展示对话框
            this.show(app);

            % 打开属性探查器
            if openInspect && ~isdeployed
                inspect(this);
            end
        end
    end
end

