classdef LoginDialog < kssolv.ui.components.dialog.SessionDialog
    % LoginDialog 创建一个模态对话框，引导用户在外部浏览器中登录。
    %
    %   用法:
    %       successURL = 'https://gleamoe.com/some/success/page';
    %       dialog = LoginDialog(app.UIFigure, successURL);
    %       addlistener(dialog, 'LoginSuccess', @(src, event) disp('User confirmed login!'));
    %       dialog.show();
    %

    properties (Access = public)
        InitialURL (1, 1) string = "https://id.gleamoe.com/login/built-in?orgChoiceMode=None"
        SuccessURL (1, 1) string
    end

    properties (Access = private)
        LoginLink = []
    end

    events (NotifyAccess = public)
        LoginSuccess
        DialogClosed
    end

    methods
        function this = LoginDialog(successURL)
            arguments
                successURL   (1,1) string
            end
            this.SuccessURL = successURL;
        end

        % 重写 show 方法，在显示对话框的同时打开浏览器
        function show(this)
            fig = this.getWidget();
            fig.CloseRequestFcn = @(~, ~) this.onDialogCloseRequest();
            % 调用父类的show方法来显示UI
            show@kssolv.ui.components.dialog.SessionDialog(this);

            if isKSSOLVOnline()
                this.LoginLink.URL = this.InitialURL;
                return
            end

            % 使用系统的默认浏览器打开登录页面
            try
                disp(['[LoginDialog] Opening external browser to: ', this.InitialURL]);
                web(this.InitialURL, '-browser');
            catch ME
                uialert(this.getWidget(), ['无法打开浏览器: ' ME.message], '错误');
                delete(this);
            end
        end
    end

    methods (Access = protected)
        function buildUI(this)

            fig = this.getWidget();
            fig.Name = '需要登录';
            fig.Position(3:4) = [450 200];

            % 设置窗口关闭时的回调
            fig.CloseRequestFcn = @(~,~) this.onDialogCloseRequest();

            if isKSSOLVOnline()
                gl = uigridlayout(fig, [3, 1], ...
                    'RowHeight', {'1x', 'fit', 'fit'});
                uilabel(gl, 'Text', ...
                    '请通过下方链接登录，完成后返回并点击“我已登录，继续”。', ...
                    'WordWrap', 'on', 'HorizontalAlignment', 'center');
                this.LoginLink = uihyperlink(gl, ...
                    'Text', '打开登录页面', 'URL', this.InitialURL);
                this.LoginLink.Layout.Row = 2;
                buttonRow = 3;
            else
                gl = uigridlayout(fig, [2, 1], ...
                    'RowHeight', {'1x', 'fit'});
                uilabel(gl, 'Text', ...
                    ['<html><p style="font-size:13px;">登录页面已在您的默认浏览器中打开。</p>' ...
                    '<p style="font-size:13px;">请在浏览器中完成登录后，返回此窗口并点击下方的"继续"按钮。</p></html>'], ...
                    'VerticalAlignment', 'center', 'HorizontalAlignment', 'center', 'Interpreter', 'html');
                buttonRow = 2;
            end

            % 按钮面板
            buttonPanel = uipanel(gl);
            buttonPanel.Layout.Row = buttonRow;
            buttonPanel.BorderType = 'none';

            % [关键] 在 Panel 内部也创建一个网格布局来管理按钮
            buttonGrid = uigridlayout(buttonPanel, [1, 3]);
            buttonGrid.ColumnWidth = {'1x', 120, 100};
            buttonGrid.Padding = [0 0 0 0];

            % "继续"按钮 (位于按钮网格的第2列)
            continueButton = uibutton(buttonGrid, 'Text', '我已登录，继续', ...
                'ButtonPushedFcn', @(~,~) this.onContinue());
            continueButton.Layout.Column = 2;

            % "取消"按钮 (位于按钮网格的第3列)
            cancelButton = uibutton(buttonGrid, 'Text', '取消', ...
                'ButtonPushedFcn', @(~,~) this.onDialogCloseRequest());
            cancelButton.Layout.Column = 3;
        end
    end

    methods (Access = private)
        function onContinue(this)
            notify(this, 'LoginSuccess');
            delete(this);
        end

        function onDialogCloseRequest(this)
            notify(this, 'DialogClosed');
            delete(this);
        end
    end

    methods (Hidden, Static)
        function qeShow()
            % 用于在单元测试中测试当前对话框，可通过下面的命令使用：
            % kssolv.ui.components.dialog.LoginDialog.qeShow();

            % 创建 AppContainer
            appOptions.Tag = sprintf('kssolv(%s)',char(matlab.lang.internal.uuid));
            appOptions.Title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:UnitTestTitle');
            appOptions.ToolstripEnabled = true;
            app = matlab.ui.container.internal.AppContainer(appOptions);

            % 展示界面
            app.Visible = true;

            successURL = 'https://gleamoe.com/some/success/page';
            dialog = kssolv.ui.components.dialog.LoginDialog(successURL);
            addlistener(dialog, 'LoginSuccess', @(~,~) uialert(app, '登录流程继续！', '成功'));
            dialog.show();
        end
    end
end
