classdef ConfirmDialog < controllib.ui.internal.dialog.AbstractDialog
    %CONFIRMDIALOG 确认对话框

    % 开发者：杨柳
    % 版权 2025 合肥瀚海量子科技有限公司

    properties
        Message
        Options (1, :) {mustBeText, mustBeNonempty} = {'Yes', 'No', 'Cancel'}
        Icon (1, :) {mustBeTextScalar} = 'question'
        DefaultOption {mustBeA(DefaultOption, {'char', 'string', 'numeric'})} = 1
        CancelOption {mustBeA(CancelOption, {'char', 'string', 'numeric'})} = 3
        CloseFcn function_handle
        Interpreter (1, 1) string {mustBeMember(Interpreter, {'none', 'tex', 'latex', 'html'})} = 'none'
    end

    properties (SetAccess = private)
        widgets
        dialogOptions
    end

    properties (SetAccess = private, GetAccess = ?matlab.unittest.TestCase)
        dialogLayout
    end

    properties (Access = private)
        width = 443
        height = 230
    end

    methods
        function this = ConfirmDialog(message, title, nv)
            %CONFIRMDIALOG 确认对话框构造函数
            arguments
                message (1, :) {mustBeTextScalar, mustBeNonempty}
                title (1, :) {mustBeTextScalar, mustBeNonempty}
                nv.?kssolv.ui.components.dialog.ConfirmDialog
            end

            narginchk(2, Inf);
            this.Message = message;
            this.Title = title;

            fields = fieldnames(nv);
            for i = 1:numel(fields)
                this.(fields{i}) = nv.(fields{i});
            end

            % 重载 close 方法
            fig = this.getWidget();
            fig.CloseRequestFcn = @(src, event) close(this);
        end

        function close(this)
            %CLOSE 重载 close 方法
            close@controllib.ui.internal.dialog.AbstractDialog(this);
            data = struct('ConfirmOptions', this.dialogOptions);
            event = matlab.ui.internal.databrowser.GenericEventData(data);
            this.notify('CloseEvent', event);

            if strcmp(get(this.getWidget, 'BeingDeleted'), 'off')
                uiresume(this.getWidget);
            end
        end

        function selection = show(this)
            %SHOW 重载 show 方法，返回用户选择按钮的 label
            this.pack();
            waitfor(this.getWidget, 'FigureViewReady', true);
            show@controllib.ui.internal.dialog.MixedInDialog(this);

            uiwait(this.getWidget);
            selection = this.dialogOptions;
        end
    end

    methods (Access = protected)
        function buildUI(this)
            %BUILDUI 构建对话框的控件和布局

            % 设置对话框的尺寸
            fig = this.getWidget;
            fig.Position(3:4) = [this.width this.height];

            % 对话框 layout
            this.dialogLayout = uigridlayout(fig, "Scrollable", "off");
            this.dialogLayout.RowHeight = {'fit', '1x', 'fit'};
            this.dialogLayout.ColumnWidth = {'1x'};

            % 图标和文本提示信息区域
            createMessagePanel(this);

            % 底部的 Button 组
            createButtonPanel(this);
        end

        function createMessagePanel(this)
            % 创建包含 Icon 和 Message 的面板
            % 文本信息 layout
            messageLayout = uigridlayout(this.dialogLayout, "Scrollable", 'off');
            messageLayout.Layout.Row = 1;
            messageLayout.Layout.Column = 1;
            messageLayout.RowHeight = {8, 32, 'fit'};
            messageLayout.ColumnWidth = {32, '1x'};
            messageLayout.Padding = 5;

            % 图标 Icon
            icon = uiimage(messageLayout, "VerticalAlignment", "top");
            icon.Layout.Row = 2;
            icon.Layout.Column = 1;

            if strcmp(this.Icon, 'question')
                icon.ImageSource = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, 'icons', 'orangeQuestionMark.svg');
            else
                icon.ImageSource = this.Icon;
            end

            % 文本消息 Message
            messageLabel = uilabel(messageLayout, "Text", this.Message, ...
                "WordWrap", "on", "FontSize", 14, "VerticalAlignment", "top");
            messageLabel.Layout.Row = [1 3];
            messageLabel.Layout.Column = 2;
        end

        function createButtonPanel(this)
            % 创建包含 YES、NO 和 CANCEL 按钮的面板
            import kssolv.ui.util.Localizer.*

            % 按钮组 layout
            buttonGroupLayout = uigridlayout(this.dialogLayout, [1 4], "Scrollable", 'off');
            buttonGroupLayout.Layout.Row = 3;
            buttonGroupLayout.Layout.Column = 1;
            buttonGroupLayout.RowHeight = {'fit'};
            buttonGroupLayout.ColumnWidth = {'1x', 'fit', 'fit', 'fit'};
            buttonGroupLayout.Padding = 0;

            % Yes 按钮
            yesButton = uibutton(buttonGroupLayout, "Text", ...
                this.Options{1}, "FontSize", 13);
            yesButton.ButtonPushedFcn = @(src, event) this.yesButtonClicked();
            yesButton.Layout.Row = 1;
            yesButton.Layout.Column = 2;

            % No 按钮
            noButton = uibutton(buttonGroupLayout, "Text", ...
                this.Options{2}, "FontSize", 13);
            noButton.ButtonPushedFcn = @(src, event) this.noButtonClicked();
            noButton.Layout.Row = 1;
            noButton.Layout.Column = 3;

            % Cancel 按钮
            cancelButton = uibutton(buttonGroupLayout, "Text", ...
                this.Options{3}, "FontSize", 13);
            cancelButton.ButtonPushedFcn = @(src, event) this.cancelButtonClicked();
            cancelButton.Layout.Row = 1;
            cancelButton.Layout.Column = 4;
        end
    end

    methods (Access = private)
        function yesButtonClicked(this)
            this.dialogOptions = this.Options{1};
            close(this);
        end

        function noButtonClicked(this)
            this.dialogOptions = this.Options{2};
            close(this);
        end

        function cancelButtonClicked(this)
            this.dialogOptions = this.Options{3};
            close(this);
        end
    end

    methods (Hidden, Static)
        function dialog = qeShow()
            % 用于在单元测试中测试 ConfirmDialog
            % 示例命令：
            % kssolv.ui.components.dialog.ConfirmDialog.qeShow

            import kssolv.ui.util.Localizer.*

            YesLabel = message('KSSOLV:dialogs:AppCanCloseSave');
            NoLabel = message('KSSOLV:dialogs:AppCanCloseDoNotSave');
            CancelLabel = message('KSSOLV:dialogs:AppCanCloseCancel');

            dialog = kssolv.ui.components.dialog.ConfirmDialog( ...
                message('KSSOLV:dialogs:AppCanCloseMessage'), ...
                message('KSSOLV:dialogs:AppCanCloseTitle'), ...
                'Options', {YesLabel, NoLabel, CancelLabel}, ...
                'DefaultOption', 1, ...
                'CancelOption', 3);
            disp(dialog.show());
        end
    end
end