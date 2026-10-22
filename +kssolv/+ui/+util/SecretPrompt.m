classdef SecretPrompt < handle
    %SECRETPROMPT Masked credential entry using native MATLAB UI components.
    properties (SetAccess = private)
        Completed (1,1) logical = false
    end

    properties (Access = private)
        OnlineModal = []
        OnlineField = []
        OnlineDestructionListener = []
        OnlineAccepted (1,1) logical = false
    end

    methods (Static)
        function value = prompt(message, title, cancelledId)
            arguments
                message (1,1) string
                title (1,1) string = "KSSOLV Remote Computing"
                cancelledId (1,1) string = "KSSOLV:Remote:InteractiveCredentialCancelled"
            end
            if isKSSOLVOnline()
                value = kssolv.ui.util.SecretPrompt.promptOnline( ...
                    message, title, cancelledId);
                return
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
            field = uihtml(grid,'HTMLSource',kssolv.ui.browser.htmlSource( ...
                fullfile(KSSOLV_Toolbox.RootDirectory, ...
                '+kssolv','+ui','+features','+remote','passwordField.html')), ...
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

    methods
        function delete(this)
            listener = this.OnlineDestructionListener;
            this.OnlineDestructionListener = [];
            if ~isempty(listener) && isvalid(listener), delete(listener); end
            this.clearOnlineField();
            modal = this.OnlineModal;
            this.OnlineModal = [];
            kssolv.ui.browser.OnlineModal.dispose(modal);
            this.OnlineField = [];
        end
    end

    methods (Static, Access = private)
        function value = promptOnline(message, title, cancelledId)
            % The page modal keeps credential entry in the connected browser.
            state = kssolv.ui.util.SecretPrompt();
            cleanup = onCleanup(@()delete(state));
            state.buildOnline(message, title);
            completed = kssolv.ui.browser.BrowserReconnectMonitor.waitFor(state, 'Completed', true);
            if ~completed || ~state.OnlineAccepted
                clear cleanup
                error(cancelledId, 'Remote credential entry was cancelled.');
            end
            value = string(state.OnlineField.Data.Value);
            clear cleanup
        end
    end

    methods (Access = private)
        function buildOnline(this, message, title)
            this.OnlineModal = kssolv.ui.browser.OnlineModal.create(title, true, false);
            figure = this.OnlineModal.Figure;
            figure.Position(3:4) = [420, 170];
            figure.CloseRequestFcn = @(~, ~)this.cancelOnline();
            grid = uigridlayout(figure, [3, 2], ...
                'RowHeight', {'fit', 30, 'fit'}, ...
                'ColumnWidth', {'1x', '1x'}, 'Padding', 16);
            label = uilabel(grid, 'Text', char(message), 'WordWrap', 'on');
            label.Layout.Row = 1;
            label.Layout.Column = [1, 2];
            this.OnlineField = uihtml(grid, 'HTMLSource', ...
                kssolv.ui.browser.htmlSource(fullfile( ...
                KSSOLV_Toolbox.RootDirectory, '+kssolv', '+ui', ...
                '+features', '+remote', 'passwordField.html')), ...
                'Data', struct('Value', '', 'Enabled', true, ...
                'Placeholder', ''), 'Tag', 'OnlineSecretPromptField');
            this.OnlineField.Layout.Row = 2;
            this.OnlineField.Layout.Column = [1, 2];
            cancelButton = uibutton(grid, 'Text', 'Cancel', ...
                'ButtonPushedFcn', @(~, ~)this.cancelOnline(), ...
                'Tag', 'OnlineSecretPromptCancel');
            cancelButton.Layout.Row = 3;
            cancelButton.Layout.Column = 1;
            okButton = uibutton(grid, 'Text', 'OK', ...
                'ButtonPushedFcn', @(~, ~)this.confirmOnline(), ...
                'Tag', 'OnlineSecretPromptOK');
            okButton.Layout.Row = 3;
            okButton.Layout.Column = 2;
            this.OnlineDestructionListener = addlistener(figure, ...
                'ObjectBeingDestroyed', @(~, ~)this.cancelOnline());
            this.OnlineModal.show();
        end

        function confirmOnline(this)
            if this.Completed, return; end
            this.OnlineAccepted = true;
            this.Completed = true;
        end

        function cancelOnline(this)
            if this.Completed, return; end
            this.OnlineAccepted = false;
            this.clearOnlineField();
            this.Completed = true;
        end

        function clearOnlineField(this)
            if ~isempty(this.OnlineField) && isvalid(this.OnlineField) && ...
                    strcmp(this.OnlineField.BeingDeleted, 'off')
                this.OnlineField.Data = struct('Value', '', ...
                    'Enabled', false, 'Placeholder', '');
            end
        end
    end
end
