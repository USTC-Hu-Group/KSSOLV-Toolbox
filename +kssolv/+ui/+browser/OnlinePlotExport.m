classdef OnlinePlotExport
    %ONLINEPLOTEXPORT Native graphics export with a browser-owned destination.
    % Keep exportgraphics' renderer and the native axes toolbar. Only the
    % desktop file/clipboard boundary is adapted for an Online session.
    methods (Static)
        function open(ax, action)
            arguments
                ax (1,1) {mustBeA(ax, 'matlab.graphics.axis.AbstractAxes')}
                action (1,1) string {mustBeMember(action,["save","image","vector"])}
            end
            if ~isgraphics(ax), return, end
            if action ~= "save"
                folder = string(tempname); mkdir(folder);
                cleanup = onCleanup(@()rmdir(folder, 's'));
                try
                    extension = ".png";
                    if action == "vector", extension = ".svg"; end
                    path = fullfile(folder, "Plot" + extension);
                    kssolv.ui.browser.OnlinePlotExport.write(ax, path, 150);
                    kssolv.ui.browser.OnlineFileTransfer.download(path, false, action);
                catch exception
                    kssolv.ui.browser.OnlinePlotExport.showError(exception.message);
                end
                return
            end

            zh = startsWith(kssolv.ui.util.Localizer.getInstance().currentLocale, 'zh');
            labels = {'Export plot', 'File name:', 'Format:', 'Resolution (DPI):', 'Save', 'Cancel'};
            if zh, labels = {'导出图片', '文件名：', '格式：', '分辨率（DPI）：', '保存', '取消'}; end
            fig = kssolv.ui.util.DialogWindow.create('Name', labels{1}, ...
                'Visible', 'off', 'Position', [100 100 440 245]);
            grid = uigridlayout(fig, [5 2], 'ColumnWidth', {120,'1x'}, ...
                'RowHeight', {28,28,28,'1x',28}, 'Padding', 16);
            uilabel(grid, 'Text', labels{2});
            name = uieditfield(grid, 'Value', 'Plot.png', 'Tag', 'PlotExportFilename');
            uilabel(grid, 'Text', labels{3});
            format = uidropdown(grid, 'Items', {'PNG','JPEG','TIFF','PDF','SVG'}, ...
                'ItemsData', {'.png','.jpg','.tif','.pdf','.svg'}, 'Tag', 'PlotExportFormat');
            uilabel(grid, 'Text', labels{4});
            dpi = uieditfield(grid, 'numeric', 'Limits', [72 600], ...
                'RoundFractionalValues', 'on', 'Value', 150, 'Tag', 'PlotExportResolution');
            status = uilabel(grid, 'Text', '', 'WordWrap', 'on', 'FontColor', [0.72 0.08 0.12]);
            status.Layout.Column = [1 2];
            bar = uigridlayout(grid, [1 3], 'ColumnWidth', {'1x',80,80}, ...
                'Padding', 0); bar.Layout.Column = [1 2];
            cancel = uibutton(bar, 'Text', labels{6}, 'ButtonPushedFcn', @(~,~)delete(fig));
            cancel.Layout.Column = 2;
            save = uibutton(bar, 'Text', labels{5}, 'Tag', 'PlotExportSave', ...
                'ButtonPushedFcn', @savePlot); save.Layout.Column = 3;
            format.ValueChangedFcn = @(~,~)updateExtension();
            kssolv.ui.util.DialogWindow.showCentered(fig);

            function updateExtension()
                [~, base] = fileparts(name.Value);
                name.Value = char(string(base) + string(format.Value));
            end
            function savePlot(~,~)
                if strcmp(save.Enable, 'off'), return, end
                save.Enable = 'off'; cancel.Enable = 'off'; status.Text = '';
                folder = string(tempname); mkdir(folder);
                cleanup = onCleanup(@()rmdir(folder, 's'));
                try
                    filename = kssolv.ui.browser.OnlineFileTransfer.validateName(name.Value);
                    [~,base,extension] = fileparts(filename);
                    if any(strcmpi(extension, [".png",".jpg",".jpeg",".tif",".tiff",".pdf",".svg"]))
                        filename = string(base);
                    end
                    path = fullfile(folder, filename + string(format.Value));
                    kssolv.ui.browser.OnlinePlotExport.write(ax, path, dpi.Value);
                    % Close the settings before showing the transfer dialog.
                    delete(fig);
                    kssolv.ui.browser.OnlineFileTransfer.download(path);
                catch exception
                    if isgraphics(fig)
                        status.Text = exception.message;
                        save.Enable = 'on'; cancel.Enable = 'on';
                    else
                        kssolv.ui.browser.OnlinePlotExport.showError(exception.message);
                    end
                end
            end
        end

        function write(ax, path, resolution)
            arguments
                ax (1,1) {mustBeA(ax, 'matlab.graphics.axis.AbstractAxes')}
                path (1,1) string
                resolution (1,1) double {mustBeFinite,mustBeInteger,mustBeInRange(resolution,72,600)} = 150
            end
            [~,~,extension] = fileparts(path);
            if ~any(strcmpi(extension, [".png",".jpg",".jpeg",".tif",".tiff",".pdf",".svg"]))
                error('KSSOLV:Online:PlotFormat', 'Unsupported plot export format.');
            end
            content = 'auto';
            if any(strcmpi(extension, [".pdf",".svg"])), content = 'vector'; end
            exportgraphics(ax, path, 'Resolution', resolution, 'ContentType', content);
        end
    end
    methods (Static, Access = private)
        function showError(message)
            fig = kssolv.ui.util.DialogWindow.create('Name', 'Export plot', ...
                'Visible', 'off', 'Position', [100 100 440 190]);
            grid = uigridlayout(fig, [2 1], 'RowHeight', {'1x',28}, 'Padding', 16);
            uilabel(grid, 'Text', message, 'WordWrap', 'on');
            uibutton(grid, 'Text', 'Close', 'ButtonPushedFcn', @(~,~)delete(fig));
            kssolv.ui.util.DialogWindow.showCentered(fig);
        end
    end
end
