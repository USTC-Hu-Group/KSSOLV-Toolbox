classdef SelectionSetNameDialog
    %SELECTIONSETNAMEDIALOG Small validated modal for naming selections.

    methods (Static)
        function [name, cancelled] = prompt(defaultName)
            arguments
                defaultName string = ""
            end
            if defaultName==""
                defaultName=sprintf(kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:DefaultSelectionSetName"),1);
            end
            name = "";
            cancelled = true;
            figure = uifigure( ...
                "Name", kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:SaveSelectionSet"), ...
                "WindowStyle", "modal", ...
                "Resize", "off", ...
                "Position", [100, 100, 390, 144], ...
                "Visible", "off");
            cleanup = onCleanup(@()deleteIfValid(figure));
            layout = uigridlayout(figure, [3, 2], ...
                "RowHeight", {22, 28, 32}, ...
                "ColumnWidth", {"1x", 90}, ...
                "Padding", [16, 7, 16, 12], ...
                "RowSpacing", 8, "ColumnSpacing", 8);
            label = uilabel(layout, "Text", ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:SelectionSetName"));
            label.Layout.Row = 1;
            label.Layout.Column = [1, 2];
            field = uieditfield(layout, "text", ...
                "Value", char(defaultName));
            field.Layout.Row = 2;
            field.Layout.Column = [1, 2];
            cancelButton = uibutton(layout, "push", ...
                "Text", kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:Cancel"), ...
                "ButtonPushedFcn", @(~, ~)cancel());
            cancelButton.Layout.Row = 3;
            cancelButton.Layout.Column = 1;
            okButton = uibutton(layout, "push", ...
                "Text", kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:Apply"), ...
                "ButtonPushedFcn", @(~, ~)accept());
            okButton.Layout.Row = 3;
            okButton.Layout.Column = 2;
            figure.CloseRequestFcn = @(~, ~)cancel();
            kssolv.ui.util.DialogWindow.showCentered(figure);
            focus(field);
            uiwait(figure);
            clear cleanup

            function accept()
                candidate = strip(string(field.Value));
                if candidate == ""
                    field.BackgroundColor = [1, 0.86, 0.86];
                    return
                end
                name = candidate;
                cancelled = false;
                uiresume(figure);
                delete(figure);
            end

            function cancel()
                if isvalid(figure), uiresume(figure); delete(figure); end
            end

            function deleteIfValid(value)
                if ~isempty(value) && isvalid(value), delete(value); end
            end
        end
    end
end
