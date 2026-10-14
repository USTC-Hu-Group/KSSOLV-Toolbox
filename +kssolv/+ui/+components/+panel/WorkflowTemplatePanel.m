classdef WorkflowTemplatePanel < controllib.ui.internal.dialog.AbstractContainer
    %WORKFLOWTEMPLATEPANEL 展示预置和自定义的工作流模板
    % 由 kssolv.ui.components.dialog.BuildWorkflowFromTemplate 对话框使用

    %   开发者：杨柳
    %   版权 2024 合肥瀚海量子科技有限公司

    properties
        parent   % 保存父 GridLayout 对象
        industryDropDown
        workflowDropDown
        workflowDemoImage
        industryWorkflows
    end

    methods (Access = public)
        function this = WorkflowTemplatePanel(parent)
            %WORKFLOWTEMPLATEPANEL 构造函数
            this.Name = 'WorkflowTemplatePanel';
            this.parent = parent;

            % 构建 industryWorkflows 字典
            industries = ["新能源", "化学化工", "航空航天", "电子信息", "军事国防"];
            workflows(1) = {{"锂电池", "半导体"}};
            workflows(2) = {{"化学制药", "有机合成", "过程工程"}};
            workflows(3) = {{"航空发动机", "卫星技术", "空间探测"}};
            workflows(4) = {{"集成电路", "通信技术", "人工智能"}};
            workflows(5) = {{"国防科技", "军事装备", "信息化作战"}};
            this.industryWorkflows = dictionary(industries, workflows);

            this.buildContainer();
        end
    end

    methods (Access = private)
        function onIndustryDropDownValueChanged(this, ~, ~)
            workflows = this.industryWorkflows(this.industryDropDown.Value);
            import kssolv.ui.components.panel.WorkflowTemplatePanel.cell2array
            this.workflowDropDown.Items = cell2array(workflows);
            this.workflowDropDown.Value = this.workflowDropDown.Items(1);

            if this.industryDropDown.Value == "新能源"
                this.workflowDemoImage.ImageSource = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                    'resources/images/workflowDemo.png');
            end
        end
    end

    methods (Static, Sealed, Access = private)
        function array = cell2array(cells)
            c = cells{:};
            array = cellfun(@string, c, 'UniformOutput', false);
            array = vertcat(array{:});

            % 转换数组的维度
            array = array(:);
        end
    end

    methods (Access = protected)
        function g = createContainer(this)
            g = uigridlayout('Parent', this.parent);
            g.RowHeight = {'1x'};
            g.ColumnWidth = {'1x'};

            % 创建 Panel
            panel = uipanel(g);
            panel.Layout.Row = 1;
            panel.Layout.Column = 1;

            % 创建 GridLayout
            gridLayout = uigridlayout(panel);
            gridLayout.ColumnWidth = {'fit', '1x', 'fit', '1x'};
            gridLayout.RowHeight = {30, 30, '1x'};

            % 创建 IndustryTemplateLabel
            industryTemplateLabel = uilabel(gridLayout);
            industryTemplateLabel.HorizontalAlignment = 'center';
            industryTemplateLabel.FontSize = 16;
            industryTemplateLabel.FontWeight = 'bold';
            industryTemplateLabel.Layout.Row = 1;
            industryTemplateLabel.Layout.Column = [1 4];
            industryTemplateLabel.Text = '行业模板';

            % 创建 IndustryLabel
            industryLabel = uilabel(gridLayout);
            industryLabel.HorizontalAlignment = 'right';
            industryLabel.Layout.Row = 2;
            industryLabel.Layout.Column = 1;
            industryLabel.Text = '行业：';

            % 创建 IndustryDropDown
            this.industryDropDown = uidropdown(gridLayout);
            this.industryDropDown.Items = keys(this.industryWorkflows);
            this.industryDropDown.ValueChangedFcn = @this.onIndustryDropDownValueChanged;
            this.industryDropDown.Layout.Row = 2;
            this.industryDropDown.Layout.Column = 2;
            this.industryDropDown.Value = '化学化工';

            % 创建 WorkflowLabel
            workflowLabel = uilabel(gridLayout);
            workflowLabel.HorizontalAlignment = 'right';
            workflowLabel.Layout.Row = 2;
            workflowLabel.Layout.Column = 3;
            workflowLabel.Text = '工作流：';

            % 创建 WorkflowDropDown
            this.workflowDropDown = uidropdown(gridLayout);
            workflows = this.industryWorkflows(this.industryDropDown.Value);
            import kssolv.ui.components.panel.WorkflowTemplatePanel.cell2array
            this.workflowDropDown.Items = cell2array(workflows);
            this.workflowDropDown.Layout.Row = 2;
            this.workflowDropDown.Layout.Column = 4;
            this.workflowDropDown.Value = this.workflowDropDown.Items(1);

            % 创建固定尺寸的流程图预览图
            imagePanel = uipanel(gridLayout);
            imagePanel.Layout.Row = 3;
            imagePanel.Layout.Column = [1 4];

            gridLayout2 = uigridlayout(imagePanel);
            gridLayout2.ColumnWidth = {'1x'};
            gridLayout2.RowHeight = {'1x'};

            this.workflowDemoImage = uiimage(gridLayout2);
            this.workflowDemoImage.ScaleMethod = 'scaledown';
        end
    end
end

