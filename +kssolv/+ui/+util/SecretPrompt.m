classdef SecretPrompt
    %SECRETPROMPT Masked credential entry using native MATLAB UI components.
    methods (Static)
        function value = prompt(message, title, cancelledId)
            arguments
                message (1,1) string
                title (1,1) string = "KSSOLV Remote Computing"
                cancelledId (1,1) string = "KSSOLV:Remote:InteractiveCredentialCancelled"
            end
            if ~feature('ShowFigureWindows')
                value = string(matlabshared.internal.readPassword( ...
                    char(message + " "),Method="Builtin"));
                return
            end
            accepted = false;
            dialog = uifigure('Name',char(title),'Position',[100 100 420 170], ...
                'WindowStyle','modal','CloseRequestFcn',@cancel);
            cleanup = onCleanup(@()delete(dialog));
            grid = uigridlayout(dialog,[3 2], ...
                'RowHeight',{'fit','1x','fit'},'ColumnWidth',{'1x','1x'});
            label = uilabel(grid,'Text',char(message),'WordWrap','on');
            label.Layout.Row=1; label.Layout.Column=[1 2];
            field = uihtml(grid,'HTMLSource',fullfile(KSSOLV_Toolbox.RootDirectory, ...
                '+kssolv','+ui','+features','+remote','passwordField.html'), ...
                'Data',struct('Value','', 'Enabled',true, 'Placeholder',''));
            field.Layout.Row=2; field.Layout.Column=[1 2];
            uibutton(grid,'Text','Cancel','ButtonPushedFcn',@cancel);
            uibutton(grid,'Text','OK','ButtonPushedFcn',@confirm);
            uiwait(dialog);
            if ~accepted
                clear cleanup
                error(cancelledId,'Remote credential entry was cancelled.');
            end
            value = string(field.Data.Value);
            field.Data = struct('Value','', 'Enabled',false, 'Placeholder','');
            clear cleanup

            function confirm(~,~)
                accepted=true; uiresume(dialog);
            end
            function cancel(~,~)
                uiresume(dialog);
            end
        end
    end
end
