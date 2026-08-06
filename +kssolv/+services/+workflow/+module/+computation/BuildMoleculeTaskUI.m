classdef BuildMoleculeTaskUI < kssolv.services.workflow.module.AbstractTaskUI
    %BUILDMOLECULETASKUI 与 buildMoleculeTask 的选项相关的 UI 控件

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties (Dependent)
        options
    end

    properties (Transient)
        widgets
    end

    methods (Access = protected)
        function setupDefaultOptions(this)
            this.defaultOptions = struct(...
                'type', 'Crystal', ...                    % 默认结构类型
                'pseudopotentialPpType', 'default', ...   % 赝势类型
                'funct', 'PBE', ...                       % 泛函类型
                'ecut', 20, ...                           % 截断能
                'smear', 'fermi-dirac', ...               % 展宽方法
                'temperature', 0, ...                     % 温度（K）
                'nspin', 1, ...                           % 自旋分量数
                'autokpts', [1,1,1,0,0,0], ...            % 自动 k 点网格
                'extranbnd', 0, ...                       % 额外能带数
                'lspinorb', false, ...                    % 自旋轨道耦合开关
                'lsda', false, ...                        % LSDA 开关
                'noncolin', false, ...                    % 非共线开关
                'domag', false ...                        % 磁性计算开关
                );
        end

        function setup(this, options)
            arguments
                this
                options (1, 1) struct = this.defaultOptions
            end

            import kssolv.ui.util.Localizer.*

            % Options AccordionPanel
            this.widgets.accordionPanel1 = matlab.ui.container.internal.AccordionPanel();
            this.widgets.accordionPanel1.BackgroundColor = 'white';
            this.widgets.accordionPanel1.Title = message('KSSOLV:toolbox:ConfigBrowserOptionsPanelTitle');

            this.widgets.g1 = uigridlayout(this.widgets.accordionPanel1);
            this.widgets.g1.BackgroundColor = 'white';
            this.widgets.g1.ColumnWidth = {100, '1x'};
            this.widgets.g1.RowHeight = {20, 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};

            % type - Molecule/Crystal 选项
            buttonGroupLayout = uigridlayout(this.widgets.g1);
            buttonGroupLayout.BackgroundColor = 'white';
            buttonGroupLayout.Padding = 0;
            buttonGroupLayout.Layout.Row = 1;
            buttonGroupLayout.Layout.Column = [1 2];
            buttonGroupLayout.ColumnWidth = {'fit', '1x'};
            buttonGroupLayout.RowHeight = {20};

            buttonGroupTooltip = 'Choose build type';
            structureTypeLabel = uilabel(buttonGroupLayout);
            structureTypeLabel.HorizontalAlignment = 'left';
            structureTypeLabel.Text = "Type: ";
            structureTypeLabel.Tooltip = buttonGroupTooltip;
            structureTypeLabel.Layout.Row = 1;
            structureTypeLabel.Layout.Column = 1;

            this.widgets.buttonGroup = uibuttongroup(buttonGroupLayout);
            this.widgets.buttonGroup.Layout.Row = 1;
            this.widgets.buttonGroup.Layout.Column = 2;
            this.widgets.buttonGroup.Tooltip = buttonGroupTooltip;
            this.widgets.buttonGroup.BackgroundColor = 'white';
            this.widgets.buttonGroup.BorderType = 'none';
            this.widgets.buttonGroup.SelectionChangedFcn = @(src, event) this.toggleAutokpts(event.NewValue.Text);

            % 创建单选按钮并根据 options.type 设置默认选中
            radioMolecule = uiradiobutton(this.widgets.buttonGroup, "Text", "Molecule", 'Position', [12 3 80 15]);
            radioCrystal = uiradiobutton(this.widgets.buttonGroup, "Text", "Crystal", 'Position', [125 3 80 15]);
            if strcmpi(options.type, 'Molecule')
                this.widgets.buttonGroup.SelectedObject = radioMolecule;
            else
                this.widgets.buttonGroup.SelectedObject = radioCrystal;
            end

            % 选择结构标题
            structureTooltip = 'Choose imported structures';
            structureSelectTitleLabel = uilabel(this.widgets.g1);
            structureSelectTitleLabel.Layout.Row = 2;
            structureSelectTitleLabel.Layout.Column = [1 2];
            structureSelectTitleLabel.HorizontalAlignment = 'left';
            structureSelectTitleLabel.Text = "Choose imported structures: ";
            structureSelectTitleLabel.Tooltip = structureTooltip;

            % 选择结构的列表框
            this.widgets.structureListbox = uilistbox(this.widgets.g1, "Multiselect", "on");
            this.widgets.structureListbox.Layout.Row = 3;
            this.widgets.structureListbox.Layout.Column = [1 2];
            % Multiselect ListBox 使用空元胞表示尚未选择，避免随后更新
            % ItemsData 时遗留默认项造成 Value/ItemsData 不一致。
            this.widgets.structureListbox.Value = {};
            importedStructures = kssolv.services.filemanager.Structure.getAllImportedStructures();
            if ~isempty(importedStructures)
                this.widgets.structureListbox.Items = cellfun(@(cell) cell.node.label, importedStructures, 'UniformOutput', true);
                this.widgets.structureListbox.ItemsData = cellfun(@(cell) cell.node.name, importedStructures, 'UniformOutput', false);
                if isfield(options, 'structures')
                    if isstruct(options.structures)
                        selectedNames = strings(1, 0);
                        for i = 1:numel(options.structures)
                            if isfield(options.structures(i), 'node') && ...
                                    isstruct(options.structures(i).node) && ...
                                    isfield(options.structures(i).node, 'name')
                                selectedNames(end + 1) = string( ...
                                    options.structures(i).node.name); %#ok<AGROW>
                            end
                        end
                        availableNames = string( ...
                            this.widgets.structureListbox.ItemsData);
                        selectedItems = ...
                            this.widgets.structureListbox.ItemsData( ...
                            ismember(availableNames, selectedNames));
                        this.widgets.structureListbox.Value = selectedItems;
                    end
                else
                    % 新建任务保持原有行为：默认选择第一个可用结构。
                    this.widgets.structureListbox.Value = ...
                        this.widgets.structureListbox.ItemsData(1);
                end
            else
                this.widgets.structureListbox.Items = "Empty";
                this.widgets.structureListbox.ItemsData = {};
                this.widgets.structureListbox.Value = {};
                this.widgets.structureListbox.Enable = 'off';
            end
            this.widgets.structureListbox.ValueChangedFcn = @(src, event) this.markDirty();
            this.widgets.structureListbox.Tooltip = structureTooltip;

            % funct 下拉菜单
            functTooltip = 'Select the functional';
            functLabel = uilabel(this.widgets.g1);
            functLabel.Layout.Row = 4;
            functLabel.Layout.Column = 1;
            functLabel.HorizontalAlignment = 'right';
            functLabel.Text = "Functional:";
            functLabel.Tooltip = functTooltip;

            this.widgets.functDropdown = uidropdown(this.widgets.g1, 'Items', {'PBE', 'PZ', 'HSE06'});
            this.widgets.functDropdown.Layout.Row = 4;
            this.widgets.functDropdown.Layout.Column = 2;
            this.widgets.functDropdown.Value = options.funct;
            this.widgets.functDropdown.ValueChangedFcn = @(src, event) this.markDirty();
            this.widgets.functDropdown.Tooltip = functTooltip;

            % pseudopotential.PpType 编辑框
            ppTypeTooltip = 'Enter pseudopotential type';
            ppTypeLabel = uilabel(this.widgets.g1);
            ppTypeLabel.Layout.Row = 5;
            ppTypeLabel.Layout.Column = 1;
            ppTypeLabel.HorizontalAlignment = 'right';
            ppTypeLabel.Text = "Pseudopotential:";
            ppTypeLabel.Tooltip = ppTypeTooltip;

            this.widgets.ppTypeEditField = uieditfield(this.widgets.g1, 'text');
            this.widgets.ppTypeEditField.Layout.Row = 5;
            this.widgets.ppTypeEditField.Layout.Column = 2;
            this.widgets.ppTypeEditField.Value = options.pseudopotentialPpType;
            this.widgets.ppTypeEditField.ValueChangedFcn = @(src, event) this.markDirty();
            this.widgets.ppTypeEditField.Tooltip = ppTypeTooltip;

            % Ecut 数值输入框
            ecutTooltip = 'Set energy cutoff in Hartree';
            ecutLabel = uilabel(this.widgets.g1);
            ecutLabel.Layout.Row = 6;
            ecutLabel.Layout.Column = 1;
            ecutLabel.HorizontalAlignment = 'right';
            ecutLabel.Text = "Ecut (Hartree):";
            ecutLabel.Tooltip = ecutTooltip;

            this.widgets.ecutSpinner = uispinner(this.widgets.g1);
            this.widgets.ecutSpinner.Layout.Row = 6;
            this.widgets.ecutSpinner.Layout.Column = 2;
            this.widgets.ecutSpinner.Value = options.ecut;
            this.widgets.ecutSpinner.ValueChangedFcn = @(src, event) this.markDirty();
            this.widgets.ecutSpinner.Tooltip = ecutTooltip;

            % Smearing 方法下拉菜单
            smearTooltip = 'Select the smearing method';
            smearLabel = uilabel(this.widgets.g1);
            smearLabel.Layout.Row = 7;
            smearLabel.Layout.Column = 1;
            smearLabel.HorizontalAlignment = 'right';
            smearLabel.Text = "Smearing:";
            smearLabel.Tooltip = smearTooltip;

            this.widgets.smearDropdown = uidropdown(this.widgets.g1, 'Items', {'fermi-dirac', 'cold', 'gaussian', 'mp'});
            this.widgets.smearDropdown.Layout.Row = 7;
            this.widgets.smearDropdown.Layout.Column = 2;
            this.widgets.smearDropdown.Value = options.smear;
            this.widgets.smearDropdown.ValueChangedFcn = @(src, event) this.markDirty();
            this.widgets.smearDropdown.Tooltip = smearTooltip;

            % Temperature 输入框
            temperatureTooltip = 'Set the temperature in Kelvin';
            temperatureLabel = uilabel(this.widgets.g1);
            temperatureLabel.Layout.Row = 8;
            temperatureLabel.Layout.Column = 1;
            temperatureLabel.HorizontalAlignment = 'right';
            temperatureLabel.Text = "Temperature (K):";
            temperatureLabel.Tooltip = temperatureTooltip;

            this.widgets.temperatureSpinner = uispinner(this.widgets.g1);
            this.widgets.temperatureSpinner.Layout.Row = 8;
            this.widgets.temperatureSpinner.Layout.Column = 2;
            this.widgets.temperatureSpinner.Value = options.temperature;
            this.widgets.temperatureSpinner.ValueChangedFcn = @(src, event) this.markDirty();
            this.widgets.temperatureSpinner.Tooltip = temperatureTooltip;

            % nspin 下拉菜单
            nspinTooltip = 'Select the number of spin components';
            nspinLabel = uilabel(this.widgets.g1);
            nspinLabel.Layout.Row = 9;
            nspinLabel.Layout.Column = 1;
            nspinLabel.HorizontalAlignment = 'right';
            nspinLabel.Text = "Nspin:";
            nspinLabel.Tooltip = nspinTooltip;

            this.widgets.nspinDropdown = uidropdown(this.widgets.g1, 'Items', {'1', '2', '4'});
            this.widgets.nspinDropdown.Layout.Row = 9;
            this.widgets.nspinDropdown.Layout.Column = 2;
            this.widgets.nspinDropdown.Value = num2str(options.nspin);
            this.widgets.nspinDropdown.Tooltip = nspinTooltip;
            this.widgets.nspinDropdown.ValueChangedFcn = @(src, event) this.updateAdvancedOptions(src, event);

            % autokpts 编辑框
            autokptsTooltip = 'Set automatic k-point grid';
            this.widgets.autokptsLabel = uilabel(this.widgets.g1);
            this.widgets.autokptsLabel.Layout.Row = 10;
            this.widgets.autokptsLabel.Layout.Column = 1;
            this.widgets.autokptsLabel.HorizontalAlignment = 'right';
            this.widgets.autokptsLabel.Text = "Autokpts:";
            this.widgets.autokptsLabel.Tooltip = autokptsTooltip;

            this.widgets.autokptsEditField = uieditfield(this.widgets.g1, 'text');
            this.widgets.autokptsEditField.Layout.Row = 10;
            this.widgets.autokptsEditField.Layout.Column = 2;
            this.widgets.autokptsEditField.Value = mat2str(options.autokpts);
            this.widgets.autokptsEditField.ValueChangedFcn = @(src, event) this.markDirty();
            this.widgets.autokptsEditField.Tooltip = autokptsTooltip;

            % Advanced Options AccordionPanel
            this.widgets.accordionPanel2 = matlab.ui.container.internal.AccordionPanel();
            this.widgets.accordionPanel2.BackgroundColor = 'white';
            this.widgets.accordionPanel2.Title = message('KSSOLV:toolbox:ConfigBrowserAdvancedOptionsPanelTitle');
            this.widgets.accordionPanel2.collapse();

            this.widgets.g2 = uigridlayout(this.widgets.accordionPanel2);
            this.widgets.g2.BackgroundColor = 'white';
            this.widgets.g2.ColumnWidth = {120, '1x'};
            this.widgets.g2.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};

            % extranbnd 数值输入框
            extranbndTooltip = 'Set the number of extra bands';
            extranbndLabel = uilabel(this.widgets.g2);
            extranbndLabel.Layout.Row = 1;
            extranbndLabel.Layout.Column = 1;
            extranbndLabel.HorizontalAlignment = 'right';
            extranbndLabel.Text = 'Extra bands:';
            extranbndLabel.Tooltip = extranbndTooltip;

            this.widgets.extranbndSpinner = uispinner(this.widgets.g2);
            this.widgets.extranbndSpinner.Layout.Row = 1;
            this.widgets.extranbndSpinner.Layout.Column = 2;
            this.widgets.extranbndSpinner.Value = options.extranbnd;
            this.widgets.extranbndSpinner.ValueChangedFcn = @(src, event) this.markDirty();
            this.widgets.extranbndSpinner.Tooltip = extranbndTooltip;

            % lspinorb 逻辑开关
            lspinorbTooltip = 'Enable spin-orbit coupling';
            this.widgets.lspinorbLabel = uilabel(this.widgets.g2);
            this.widgets.lspinorbLabel.Layout.Row = 2;
            this.widgets.lspinorbLabel.Layout.Column = 1;
            this.widgets.lspinorbLabel.HorizontalAlignment = 'right';
            this.widgets.lspinorbLabel.Text = 'Spin-orbit:';
            this.widgets.lspinorbLabel.Tooltip = lspinorbTooltip;
            this.widgets.lspinorbLabel.Visible = false;

            this.widgets.lspinorbSwitch = uiswitch(this.widgets.g2, 'slider');
            this.widgets.lspinorbSwitch.Layout.Row = 2;
            this.widgets.lspinorbSwitch.Layout.Column = 2;
            this.widgets.lspinorbSwitch.Value = this.iif(options.lspinorb, 'On', 'Off');
            this.widgets.lspinorbSwitch.ValueChangedFcn = @(src, event) this.markDirty();
            this.widgets.lspinorbSwitch.Tooltip = lspinorbTooltip;
            this.widgets.lspinorbSwitch.Visible = false;
            this.widgets.g2.RowHeight{2} = 0;

            % lsda 逻辑开关
            lsdaTooltip = 'Enable LSDA approximation';
            this.widgets.lsdaLabel = uilabel(this.widgets.g2);
            this.widgets.lsdaLabel.Layout.Row = 3;
            this.widgets.lsdaLabel.Layout.Column = 1;
            this.widgets.lsdaLabel.HorizontalAlignment = 'right';
            this.widgets.lsdaLabel.Text = 'LSDA:';
            this.widgets.lsdaLabel.Tooltip = lsdaTooltip;
            this.widgets.lsdaLabel.Visible = false;

            this.widgets.lsdaSwitch = uiswitch(this.widgets.g2, 'slider');
            this.widgets.lsdaSwitch.Layout.Row = 3;
            this.widgets.lsdaSwitch.Layout.Column = 2;
            this.widgets.lsdaSwitch.Value = this.iif(options.lsda, 'On', 'Off');
            this.widgets.lsdaSwitch.ValueChangedFcn = @(src, event) this.markDirty();
            this.widgets.lsdaSwitch.Tooltip = lsdaTooltip;
            this.widgets.lsdaSwitch.Visible = false;
            this.widgets.g2.RowHeight{3} = 0;

            % noncolin 逻辑开关
            noncolinTooltip = 'Enable non-collinear magnetism';
            this.widgets.noncolinLabel = uilabel(this.widgets.g2);
            this.widgets.noncolinLabel.Layout.Row = 4;
            this.widgets.noncolinLabel.Layout.Column = 1;
            this.widgets.noncolinLabel.HorizontalAlignment = 'right';
            this.widgets.noncolinLabel.Text = 'Non-collinear:';
            this.widgets.noncolinLabel.Tooltip = noncolinTooltip;
            this.widgets.noncolinLabel.Visible = false;

            this.widgets.noncolinSwitch = uiswitch(this.widgets.g2, 'slider');
            this.widgets.noncolinSwitch.Layout.Row = 4;
            this.widgets.noncolinSwitch.Layout.Column = 2;
            this.widgets.noncolinSwitch.Value = this.iif(options.noncolin, 'On', 'Off');
            this.widgets.noncolinSwitch.ValueChangedFcn = @(src, event) this.markDirty();
            this.widgets.noncolinSwitch.Tooltip = noncolinTooltip;
            this.widgets.noncolinSwitch.Visible = false;
            this.widgets.g2.RowHeight{4} = 0;

            % domag 逻辑开关
            domagTooltip = 'Enable magnetic calculation';
            this.widgets.domagLabel = uilabel(this.widgets.g2);
            this.widgets.domagLabel.Layout.Row = 5;
            this.widgets.domagLabel.Layout.Column = 1;
            this.widgets.domagLabel.HorizontalAlignment = 'right';
            this.widgets.domagLabel.Text = 'Magnetic:';
            this.widgets.domagLabel.Tooltip = domagTooltip;
            this.widgets.domagLabel.Visible = false;

            this.widgets.domagSwitch = uiswitch(this.widgets.g2, 'slider');
            this.widgets.domagSwitch.Layout.Row = 5;
            this.widgets.domagSwitch.Layout.Column = 2;
            this.widgets.domagSwitch.Value = this.iif(options.domag, 'On', 'Off');
            this.widgets.domagSwitch.ValueChangedFcn = @(src, event) this.markDirty();
            this.widgets.domagSwitch.Tooltip = domagTooltip;
            this.widgets.domagSwitch.Visible = false;
            this.widgets.g2.RowHeight{5} = 0;

            % 初始化高级选项的可见性
            this.updateAdvancedOptions(this.widgets.nspinDropdown);
            this.toggleAutokpts(this.widgets.buttonGroup.SelectedObject.Text);
        end
    end

    methods
        function attachUIToAccordion(this, accordion)
            arguments
                this
                accordion matlab.ui.container.internal.Accordion
            end

            import kssolv.ui.util.Localizer.*

            if size(accordion.Children, 1) >= 4
                if strcmp(accordion.Children(3).Title, message('KSSOLV:toolbox:ConfigBrowserOptionsPanelTitle'))
                    % 移除旧的 Options AccordionPanel
                    accordion.Children(3).Parent = [];
                end

                if strcmp(accordion.Children(3).Title, message('KSSOLV:toolbox:ConfigBrowserAdvancedOptionsPanelTitle'))
                    % 移除旧的 Advanced Options AccordionPanel，注意在 Children 中的位置仍然是第三个
                    accordion.Children(3).Parent = [];
                end
            end

            % 将两个 accordionPanel 添加到 accordion
            if isempty(accordion.Children)
                this.widgets.accordionPanel1.Parent = accordion;
                this.widgets.accordionPanel2.Parent = accordion;
            elseif size(accordion.Children, 1) >= 3
                existingPanels = accordion.Children;

                for i = 1:numel(existingPanels)
                    existingPanels(i).Parent = [];
                end

                existingPanels(1).Parent = accordion;
                existingPanels(2).Parent = accordion;
                this.widgets.accordionPanel1.Parent = accordion;
                this.widgets.accordionPanel2.Parent = accordion;

                for i = 3:numel(existingPanels)
                    existingPanels(i).Parent = accordion;
                end
            end
        end

        function detachUIFromAccordion(this)
            this.widgets.accordionPanel1.Parent = [];
            this.widgets.accordionPanel2.Parent = [];
        end

        function output = get.options(this)
            % 创建结构体并提取所有 UI 控件的值
            this.privateOptions.type = this.widgets.buttonGroup.SelectedObject.Text;

            this.privateOptions.structures = [];
            project = kssolv.ui.util.DataStorage.getData('Project');
            for i = 1:length(this.widgets.structureListbox.Value)
                structureItem = project.findChildrenItem(this.widgets.structureListbox.Value{i});
                if ~isempty(structureItem)
                    temp = structureItem.data.KSSOLVSetupObject;
                    temp.node.label = structureItem.label;
                    temp.node.name = structureItem.name;
                    this.privateOptions.structures = [this.privateOptions.structures, temp];
                end
            end

            this.privateOptions.pseudopotentialPpType = this.widgets.ppTypeEditField.Value;

            % 选项
            this.privateOptions.funct = this.widgets.functDropdown.Value;
            this.privateOptions.ecut = this.widgets.ecutSpinner.Value;
            this.privateOptions.smear = this.widgets.smearDropdown.Value;
            this.privateOptions.temperature = this.widgets.temperatureSpinner.Value;
            this.privateOptions.nspin = str2double(this.widgets.nspinDropdown.Value);
            this.privateOptions.autokpts = str2num(this.widgets.autokptsEditField.Value); %#ok<ST2NM>

            % 高级选项
            this.privateOptions.extranbnd = this.widgets.extranbndSpinner.Value;
            this.privateOptions.lspinorb = matlab.lang.OnOffSwitchState(this.widgets.lspinorbSwitch.Value);
            this.privateOptions.lsda = matlab.lang.OnOffSwitchState(this.widgets.lsdaSwitch.Value);
            this.privateOptions.noncolin = matlab.lang.OnOffSwitchState(this.widgets.noncolinSwitch.Value);
            this.privateOptions.domag = matlab.lang.OnOffSwitchState(this.widgets.domagSwitch.Value);

            output = this.privateOptions;
        end
    end

    methods (Access = private)
        function output = iif(~, condition, trueValue, falseValue)
            % 辅助函数，用于简化条件判断
            if condition
                output = trueValue;
            else
                output = falseValue;
            end
        end

        function updateAdvancedOptions(this, src, ~)
            nspinValue = str2double(src.Value);

            % 更新 lspinorb 和 domag 可见性
            if nspinValue ~= 1
                this.widgets.lspinorbLabel.Visible = true;
                this.widgets.lspinorbSwitch.Visible = true;
                this.widgets.g2.RowHeight{2} = 'fit';
                this.widgets.domagLabel.Visible = true;
                this.widgets.domagSwitch.Visible = true;
                this.widgets.g2.RowHeight{5} = 'fit';
            else
                this.widgets.lspinorbLabel.Visible = false;
                this.widgets.lspinorbSwitch.Visible = false;
                this.widgets.g2.RowHeight{2} = 0;
                this.widgets.domagLabel.Visible = false;
                this.widgets.domagSwitch.Visible = false;
                this.widgets.g2.RowHeight{5} = 0;
            end

            % 更新 lsda 可见性 (仅 nspin 为 2 时显示)
            if nspinValue == 2
                this.widgets.lsdaLabel.Visible = true;
                this.widgets.lsdaSwitch.Visible = true;
                this.widgets.g2.RowHeight{3} = 'fit';
            else
                this.widgets.lsdaLabel.Visible = false;
                this.widgets.lsdaSwitch.Visible = false;
                this.widgets.g2.RowHeight{3} = 0;
            end

            % 更新 noncolin 可见性 (仅 nspin 为 4 时显示)
            if nspinValue == 4
                this.widgets.noncolinLabel.Visible = true;
                this.widgets.noncolinSwitch.Visible = true;
                this.widgets.g2.RowHeight{4} = 'fit';
            else
                this.widgets.noncolinLabel.Visible = false;
                this.widgets.noncolinSwitch.Visible = false;
                this.widgets.g2.RowHeight{4} = 0;
            end

            this.markDirty();
        end

        function toggleAutokpts(this, selectedOption)
            this.markDirty();
            if strcmp(selectedOption, 'Molecule')
                this.widgets.autokptsLabel.Visible = 'off';
                this.widgets.autokptsEditField.Visible = 'off';
                this.widgets.g1.RowHeight{10} = 0;
            else
                this.widgets.autokptsLabel.Visible = 'on';
                this.widgets.autokptsEditField.Visible = 'on';
                this.widgets.g1.RowHeight{10} = 'fit';
            end
        end
    end

    methods (Hidden, Static)
        function this = qeShow(debug)
            % 用于在单元测试中测试 BuildMoleculeTaskUI，可通过下面的命令使用：
            % kssolv.services.workflow.module.computation.BuildMoleculeTaskUI.qeShow();
            arguments
                debug logical = false
            end

            accordion = kssolv.services.workflow.module.AbstractTaskUI.qeShow(debug);
            this = kssolv.services.workflow.module.computation.BuildMoleculeTaskUI();
            this.attachUIToAccordion(accordion);
        end
    end
end
