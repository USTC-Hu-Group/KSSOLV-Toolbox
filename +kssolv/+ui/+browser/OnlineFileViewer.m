classdef OnlineFileViewer
    %ONLINEFILEVIEWER View session text files without launching a server app.
    methods (Static)
        function modal = open(path, title)
            if nargin < 2
                [~, name, ext] = fileparts(path);
                title = string(name) + string(ext);
            end
            modal = kssolv.ui.browser.OnlineModal.create(title, true, false);
            try
            figure = modal.Figure;
            figure.Position(3:4) = [780 510];
            figure.CloseRequestFcn = @(~,~)kssolv.ui.browser.OnlineModal.dispose(modal);
            layout = uigridlayout(figure, [3 1], ...
                'RowHeight', {'fit','1x','fit'}, 'Padding', [12 12 12 12]);
            status = uilabel(layout, 'WordWrap', 'on');
            area = uitextarea(layout, 'Editable', 'off', 'FontName', 'Monospaced');
            area.Layout.Row = 2;
            footer = uigridlayout(layout, [1 4], 'Padding', 0, ...
                'RowHeight', {'fit'}, 'ColumnWidth', {'fit','fit','1x','fit'});
            footer.Layout.Row = 3;
            uibutton(footer, 'Text', 'Refresh', 'ButtonPushedFcn', ...
                @(~,~)kssolv.ui.browser.OnlineFileViewer.refresh(path, status, area));
            uibutton(footer, 'Text', 'Download', 'ButtonPushedFcn', ...
                @(~,~)kssolv.ui.util.FileDialog.download(path));
            closeButton = uibutton(footer, 'Text', 'Close', 'ButtonPushedFcn', ...
                @(~,~)kssolv.ui.browser.OnlineModal.dispose(modal));
            closeButton.Layout.Column = 4;
            kssolv.ui.browser.OnlineFileViewer.refresh(path, status, area);
            modal.show();
            catch exception
                kssolv.ui.browser.OnlineModal.dispose(modal);
                rethrow(exception)
            end
        end

        function [text, truncated] = readTail(path)
            % Bound UI rendering; Download always provides the complete file.
            file = fopen(path, 'rb');
            if file < 0
                error('KSSOLV:UI:OnlineFile:Read', 'Unable to read the session file.');
            end
            cleanup = onCleanup(@()fclose(file));
            fseek(file, 0, 'eof');
            length = ftell(file);
            limit = 512 * 1024;
            offset = max(0, length - limit);
            fseek(file, offset, 'bof');
            bytes = fread(file, limit, '*uint8')';
            if offset > 0
                % A tail offset can split a UTF-8 character. Skip continuation
                % bytes so multilingual logs do not start with invalid text.
                while ~isempty(bytes) && bytes(1) >= 128 && bytes(1) < 192
                    bytes(1) = [];
                end
            end
            text = string(native2unicode(bytes, 'UTF-8'));
            truncated = offset > 0;
        end
    end
    methods (Static, Access = private)
        function refresh(path, status, area)
            [text, truncated] = kssolv.ui.browser.OnlineFileViewer.readTail(path);
            area.Value = splitlines(text);
            if truncated
                status.Text = 'Showing the last 512 KiB. Download includes the complete file.';
            else
                [~, name, ext] = fileparts(path);
                status.Text = string(name) + string(ext);
            end
        end
    end
end
