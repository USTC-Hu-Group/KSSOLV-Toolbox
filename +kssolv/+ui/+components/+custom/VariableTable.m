classdef VariableTable < matlab.ui.componentcontainer.ComponentContainer & ...
        matlab.ui.control.internal.model.mixin.EnableableComponent

    %VARIABLETABLE 自定义的复杂表格及位于侧边的一些按钮。

    %   开发者：杨柳
    %   版权 2024 合肥瀚海量子科技有限公司

    properties
        LayoutBackgroundColor = '#f0f0f0'
        CurrentSelectedRow = ''
        TableData table
        HeaderFontSize uint16 = 11
    end

    properties (Access = private, Transient, NonCopyable)
        GridLayout matlab.ui.container.GridLayout
        Table matlab.ui.control.Table
        ButtonGroupLayout matlab.ui.container.GridLayout
        AddButton kssolv.ui.components.custom.CustomButton
        DeleteButton kssolv.ui.components.custom.CustomButton
        CopyButton kssolv.ui.components.custom.CustomButton
        ClearButton kssolv.ui.components.custom.CustomButton

        totalAdd = 0
    end

    methods (Access = protected)
        function setup(this)
            % 初始化组件
            this.GridLayout = uigridlayout(this, [1, 2]);
            this.GridLayout.BackgroundColor = this.LayoutBackgroundColor;
            this.GridLayout.Padding = [0, 0, 0, 0];
            this.GridLayout.ColumnSpacing = 5;
            this.GridLayout.RowSpacing = 0;
            this.GridLayout.ColumnWidth = {'1x', 30};
            this.GridLayout.RowHeight = {'1x'};

            % TableData
            tableIsEmpty = false;
            if isempty(this.TableData)
                tableIsEmpty = true;
                this.TableData = table({}, {}, {}, 'VariableNames', {'Enable', 'Name', 'Value'});
            end

            % Table
            this.Table = uitable(this.GridLayout, "Data", this.TableData, ...
                'ColumnEditable', true, 'SelectionType', 'row', 'Multiselect', 'off');
            this.Table.ColumnWidth = {55, 'auto', '1x'};
            this.Table.BackgroundColor = 'white';
            this.Table.FontSize = 11;
            this.Table.SelectionChangedFcn = @(src, event) this.onSelectionChanged(src, event);
            this.Table.CellEditCallback = @(src, event) this.onCellEdited(src, event);

            if tableIsEmpty
                this.addRow();
            end

            % ButtonGroupLayout
            this.ButtonGroupLayout = uigridlayout(this.GridLayout);
            this.ButtonGroupLayout.BackgroundColor = this.LayoutBackgroundColor;
            this.ButtonGroupLayout.Padding = [0, 0, 0, 0];
            this.ButtonGroupLayout.ColumnSpacing = 0;
            this.ButtonGroupLayout.RowSpacing = 3;
            this.ButtonGroupLayout.ColumnWidth = {'1x'};
            this.ButtonGroupLayout.RowHeight = {25, 25, 25, 25};

            % AddButton, DeleteButton, CopyButton, ClearButton
            import kssolv.ui.components.custom.CustomButton
            import kssolv.ui.util.Localizer.*

            this.AddButton = CustomButton(this.ButtonGroupLayout);
            matlab.ui.control.internal.specifyIconID(this.AddButton, 'add', 18);
            this.AddButton.Tooltip = message('KSSOLV:toolbox:VariableTableAddButtonTooltip');
            this.AddButton.ClickedFcn = @this.addRow;

            this.DeleteButton = CustomButton(this.ButtonGroupLayout);
            matlab.ui.control.internal.specifyIconID(this.DeleteButton, 'delete', 18);
            this.DeleteButton.Tooltip = message('KSSOLV:toolbox:VariableTableDeleteButtonTooltip');
            this.DeleteButton.Enable = false;
            this.DeleteButton.ClickedFcn = @this.deleteRow;

            this.CopyButton = CustomButton(this.ButtonGroupLayout);
            matlab.ui.control.internal.specifyIconID(this.CopyButton, 'copy', 18);
            this.CopyButton.Tooltip = message('KSSOLV:toolbox:VariableTableCopyButtonTooltip');
            this.CopyButton.Enable = false;
            this.CopyButton.ClickedFcn = @this.duplicateRow;

            this.ClearButton = CustomButton(this.ButtonGroupLayout);
            matlab.ui.control.internal.specifyIconID(this.ClearButton, 'clear_table', 18);
            this.ClearButton.Tooltip = message('KSSOLV:toolbox:VariableTableClearButtonTooltip');
            this.ClearButton.Enable = false;
            this.ClearButton.ClickedFcn = @this.clearTable;
        end

        function update(~)
            % 当属性变化时更新组件
        end
    end

    methods
        function set.LayoutBackgroundColor(this, newValue)
            this.get("GridLayout").BackgroundColor = newValue;
            this.get("ButtonGroupLayout").BackgroundColor = newValue;
            this.get("AddButton").LayoutBackgroundColor = newValue;
            this.get("DeleteButton").LayoutBackgroundColor = newValue;
            this.get("CopyButton").LayoutBackgroundColor = newValue;
            this.get("ClearButton").LayoutBackgroundColor = newValue;
        end

        function set.HeaderFontSize(this, fontsize)
            % 设置 uitable 列标题的 fontSize 样式

            % Reference: https://ww2.mathworks.cn/matlabcentral/answers/545846-how-to-change-uitable-row-column-header-font-size#answer_1258699
            [webWindow, tag] = this.getTableInternalInfo();
            if isempty(webWindow)
                return
            end
            % webWindow.openDevTools();

            jsCommand = sprintf(['var headerElements = document.querySelector(''div[data-tag="%s"]'').getElementsByClassName("mw-default-header-cell");\n' ...
                'for (let ii = 0; ii < headerElements.length; ii++) {\n' ...
                'headerElements[ii].style.fontSize = "%dpx";\n' ...
                '}\nheaderElements = undefined;'], tag, fontsize);

            % 在 2 秒时间内反复尝试执行 js 脚本，直至成功
            tic;
            t = toc;
            while t < 2
                try
                    webWindow.executeJS(jsCommand);
                    break
                catch
                    pause(.1);
                    t = toc;
                end
            end
        end
    end

    methods (Access = private)
        function onSelectionChanged(this, ~, event)
            % 获取选中的单元格（行，列）
            selectedCells = event.Selection;

            if ~isempty(selectedCells)
                % 将选中的行号存储在 CurrentSelectedRow 变量中
                this.CurrentSelectedRow = selectedCells(1,1);
                this.DeleteButton.Enable = true;
                this.CopyButton.Enable = true;
            else
                this.CurrentSelectedRow = [];
                this.DeleteButton.Enable = false;
                this.CopyButton.Enable = false;
            end
        end

        function onCellEdited(this, src, event)
            % 获取编辑后的数据并保存到 TableData
            editedRow = event.Indices(1);
            editedCol = event.Indices(2);
            newData = event.NewData;

            % 更新 TableData 中的对应单元格
            this.TableData{editedRow, editedCol} = {newData};

            % 更新 uitable
            src.Data = this.TableData;

            % 启用 ClearButton
            this.ClearButton.Enable = true;
        end

        function addRow(this)
            % 新增一行数据
            this.totalAdd = this.totalAdd + 1;
            newRow = {false, sprintf('Variable%d', this.totalAdd), ''};
            this.TableData = [this.TableData; newRow];

            % 更新 RowNames
            rowNames = arrayfun(@(x) num2str(x), 1:size(this.TableData, 1), 'UniformOutput', false);
            this.TableData.Properties.RowNames = rowNames;

            % 更新 uitable
            this.Table.Data = this.TableData;

            % 启用 ClearButton
            if ~isempty(this.ClearButton)
                this.ClearButton.Enable = true;
            end
        end

        function deleteRow(this)
            % 删除当前选中行的数据
            if ~isempty(this.CurrentSelectedRow)
                % 删除 TableData 中选中的行
                this.TableData(this.CurrentSelectedRow, :) = [];

                % 更新 RowNames
                rowNames = arrayfun(@(x) num2str(x), 1:size(this.TableData, 1), 'UniformOutput', false);
                this.TableData.Properties.RowNames = rowNames;

                % 更新 uitable
                this.Table.Data = this.TableData;

                % 重置按钮状态
                this.Table.Selection = [];
                this.CurrentSelectedRow = [];
                this.DeleteButton.Enable = false;
                this.CopyButton.Enable = false;
                if size(this.Table.Data, 1) > 0
                    this.ClearButton.Enable = true;
                else
                    this.ClearButton.Enable = false;
                end
            end
        end

        function duplicateRow(this)
            % 复制当前选中行的数据
            if ~isempty(this.CurrentSelectedRow)
                % 获取当前选中行的数据
                selectedRowData = this.TableData(this.CurrentSelectedRow, :);

                % 新增一行，数据为选中行的数据
                newRow = {selectedRowData.Enable{1}, ...
                    sprintf('%s_copy', selectedRowData.Name{1}), ...
                    selectedRowData.Value{1}};
                this.TableData = [this.TableData; newRow];

                % 更新 RowNames
                rowNames = arrayfun(@(x) num2str(x), 1:size(this.TableData, 1), 'UniformOutput', false);
                this.TableData.Properties.RowNames = rowNames;

                % 更新 uitable
                this.Table.Data = this.TableData;

                % 启用 ClearButton
                this.ClearButton.Enable = true;
            end
        end

        function clearTable(this)
            if size(this.Table.Data, 1) > 0
                this.totalAdd = 0;
                this.TableData = table({}, {}, {}, 'VariableNames', {'Enable', 'Name', 'Value'});
                this.addRow();
                this.Table.Data = this.TableData;
            end

            % 禁用ClearButton
            this.ClearButton.Enable = false;
        end

        function [webWindow, tag] = getTableInternalInfo(this)
            arguments (Output)
                webWindow matlab.internal.webwindow
                tag char
            end

            % Reference: https://ww2.mathworks.cn/matlabcentral/fileexchange/131274-cctools
            warning('off', 'MATLAB:structOnObject');

            figureHandle = ancestor(this.Table, 'figure');
            webWindow = [];

            % 在 10 秒时间内反复尝试获取 webWindow，直至成功
            tic;
            t = toc;
            while t < 10
                try
                    webWindow = struct(struct(struct(figureHandle).Controller).PlatformHost).CEF;
                    break
                catch
                    pause(.1);
                    t = toc;
                end
            end

            releaseVersion = version('-release');
            releaseYear    = str2double(releaseVersion(1:4));
            if releaseYear <= 2022
                tag = struct(this.Table).Controller.ProxyView.PeerNode.Id;
            else
                tag = struct(this.Table).Controller.ViewModel.Id;
            end
        end
    end

    methods (Hidden)
        function markPropertiesDirty(this, propertyNames)
            arguments
                this
                propertyNames cell
            end

            if size(propertyNames, 1) == 1
                switch propertyNames{1, 1}
                    case 'Enable'
                        if this.Enable
                            this.Table.Enable = 'on';
                            this.AddButton.Enable = true;
                        else
                            this.Table.Enable = 'off';
                            this.AddButton.Enable = false;
                            this.DeleteButton.Enable = false;
                            this.CopyButton.Enable = false;
                        end
                end
            end
        end
    end

    methods (Hidden, Static)
        function table1 = qeShow()
            % 用于单元测试中的 VariableTable 示例，可使用以下命令：
            % kssolv.ui.components.custom.VariableTable.qeShow();

            % 判断是否存在名为 "Unit Test" 的窗口
            existingFig = findall(0, 'Type', 'figure', 'Name', 'Unit Test');
            if ~isempty(existingFig)
                % 如果存在则关闭窗口
                close(existingFig);
            end

            % 创建画布和面板
            fig = uifigure("Name", "Unit Test");
            layout = uigridlayout(fig);
            layout.BackgroundColor = 'white';
            layout.ColumnWidth = {'1x'};
            layout.RowHeight = {'1x'};

            % 将 CustomButton 添加到画布
            table1 = kssolv.ui.components.custom.VariableTable(layout);
            table1.LayoutBackgroundColor = 'white';
            table1.HeaderFontSize = 9;
        end
    end
end

