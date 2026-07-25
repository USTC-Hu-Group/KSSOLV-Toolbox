classdef LicenseDialog < controllib.ui.internal.dialog.AbstractDialog
    %LICENSEDIALOG 显示工具箱根目录中的 LICENSE 文件。

    % 开发者：杨柳
    % 版权 2026 合肥瀚海量子科技有限公司

    properties (SetAccess = private)
        widgets = struct()
    end

    properties (Access = private)
        width = 760
        height = 560
    end

    methods
        function this = LicenseDialog()
            import kssolv.ui.util.Localizer.message

            this.Title = message('KSSOLV:dialogs:LicenseDialogTitle');
            this.CloseMode = 'hide';

            fig = this.getWidget();
            fig.CloseRequestFcn = @(~, ~) close(this);
        end

        function show(this, varargin)
            this.widgets.LicenseText.Value = this.readLicenseFile();
            show@controllib.ui.internal.dialog.AbstractDialog( ...
                this, varargin{:});
        end
    end

    methods (Access = protected)
        function buildUI(this)
            import kssolv.ui.util.Localizer.message

            fig = this.getWidget();
            fig.Position(3:4) = [this.width this.height];

            layout = uigridlayout(fig, [3 1], ...
                'Scrollable', 'off', ...
                'RowHeight', {'fit', '1x', 'fit'}, ...
                'ColumnWidth', {'1x'}, ...
                'RowSpacing', 10, ...
                'Padding', [14 14 14 12]);

            heading = uilabel(layout, ...
                'Text', message('KSSOLV:dialogs:LicenseDialogHeading'), ...
                'FontSize', 15, ...
                'FontWeight', 'bold');
            heading.Layout.Row = 1;

            licenseText = uitextarea(layout, ...
                'Value', this.readLicenseFile(), ...
                'Editable', 'off', ...
                'FontName', 'Monospaced');
            licenseText.Layout.Row = 2;

            buttonLayout = uigridlayout(layout, [1 2], ...
                'RowHeight', {'fit'}, ...
                'ColumnWidth', {'1x', 'fit'}, ...
                'Padding', 0);
            buttonLayout.Layout.Row = 3;
            closeButton = uibutton(buttonLayout, ...
                'Text', message('KSSOLV:dialogs:DialogCloseButton'), ...
                'ButtonPushedFcn', @(~, ~) close(this));
            closeButton.Layout.Column = 2;

            this.widgets.LicenseText = licenseText;
            this.widgets.CloseButton = closeButton;
        end
    end

    methods (Static, Access = private)
        function lines = readLicenseFile()
            import kssolv.ui.util.Localizer.message

            licenseFile = fullfile(KSSOLV_Toolbox.RootDirectory, 'LICENSE');
            try
                lines = cellstr(splitlines(string(fileread(licenseFile))));
            catch
                lines = {message( ...
                    'KSSOLV:dialogs:LicenseDialogReadFailed')};
            end
        end
    end
end
