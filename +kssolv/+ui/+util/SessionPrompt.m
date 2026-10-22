classdef SessionPrompt < handle
    %SESSIONPROMPT Desktop prompts or blocking input in an Online modal.
    %   Online input waits for the page modal to finish.

    properties (SetAccess = private)
        Completed (1,1) logical = false
    end

    properties (Access = private)
        Modal = []
        DestructionListener = []
        Fields cell = {}
        List = []
        Accepted (1,1) logical = false
        Result cell = {}
        SelectedIndices = []
    end

    methods (Static)
        function answer = confirm(parent, message, title, varargin)
            if ~isKSSOLVOnline()
                answer = uiconfirm(parent, message, title, varargin{:});
                return
            end
            dialog = kssolv.ui.components.dialog.ConfirmDialog( ...
                message, title, varargin{:});
            cleanup = onCleanup(@()delete(dialog));
            answer = dialog.show();
            clear cleanup
        end

        function answer = input(prompt, title, lines, defaults)
            if nargin < 2, title = 'Input'; end
            if nargin < 3, lines = 1; end
            prompts = cellstr(string(prompt));
            if nargin < 4, defaults = repmat({''}, size(prompts)); end
            if ~isKSSOLVOnline()
                answer = inputdlg(prompt, title, lines, defaults);
                return
            end
            defaults = cellstr(string(defaults));
            count = numel(prompts);
            if numel(defaults) ~= count
                error('KSSOLV:Online:PromptDefaults', ...
                    'Each prompt must have one default value.');
            end
            validateattributes(lines, {'numeric'}, ...
                {'real', 'finite', 'positive', 'integer'});
            if isscalar(lines)
                rows = repmat(lines, count, 1);
            elseif size(lines, 1) == count
                rows = lines(:, 1);
            elseif isvector(lines) && numel(lines) == count
                rows = lines(:);
            else
                error('KSSOLV:Online:PromptLines', ...
                    'Line counts must match the input prompts.');
            end

            state = kssolv.ui.util.SessionPrompt();
            cleanup = onCleanup(@()delete(state));
            figure = state.createModal(title);
            layout = uigridlayout(figure, [2 * count + 1, 1], ...
                'Scrollable', 'on', 'ColumnWidth', {'1x'}, ...
                'Padding', 16, 'RowSpacing', 8);
            heights = repmat({'fit'}, 1, 2 * count + 1);
            state.Fields = cell(count, 1);
            for index = 1:count
                label = uilabel(layout, 'Text', prompts{index}, ...
                    'WordWrap', 'on');
                label.Layout.Row = 2 * index - 1;
                if rows(index) > 1
                    field = uitextarea(layout, 'Value', defaults{index});
                else
                    field = uieditfield(layout, 'text', ...
                        'Value', defaults{index});
                end
                field.Tag = sprintf('SessionPromptInput%d', index);
                field.Layout.Row = 2 * index;
                heights{2 * index} = max(28, 22 * min(rows(index), 12));
                state.Fields{index} = field;
            end
            layout.RowHeight = heights;
            state.createButtons(layout, 2 * count + 1, 'OK', 'Cancel');
            figure.Position(3:4) = [560, min(700, ...
                100 + sum(26 + max(28, 22 * min(rows, 12))))];
            state.Modal.show();
            if ~kssolv.ui.browser.BrowserReconnectMonitor.waitFor(state, 'Completed', true)
                answer = {};
                return
            end
            answer = state.Result;
            clear cleanup
        end

        function [selection, accepted] = selection(varargin)
            if ~isKSSOLVOnline()
                [selection, accepted] = listdlg(varargin{:});
                return
            end
            parser = inputParser();
            parser.addParameter('PromptString', '');
            parser.addParameter('ListString', {});
            parser.addParameter('SelectionMode', 'multiple');
            parser.addParameter('InitialValue', 1);
            parser.addParameter('Name', 'Select');
            parser.addParameter('ListSize', [160, 300]);
            parser.addParameter('OKString', 'OK');
            parser.addParameter('CancelString', 'Cancel');
            parser.parse(varargin{:});
            options = parser.Results;
            items = cellstr(string(options.ListString));
            selection = [];
            accepted = false;
            if isempty(items), return; end
            mode = validatestring(options.SelectionMode, ...
                {'single', 'multiple'});
            initial = options.InitialValue;
            validateattributes(initial, {'numeric'}, ...
                {'vector', 'integer', 'positive', '<=', numel(items)});
            if strcmp(mode, 'single') && numel(initial) > 1
                error('KSSOLV:Online:PromptSelection', ...
                    'Single selection requires one initial value.');
            end

            state = kssolv.ui.util.SessionPrompt();
            cleanup = onCleanup(@()delete(state));
            figure = state.createModal(options.Name);
            layout = uigridlayout(figure, [3, 1], ...
                'RowHeight', {'fit', '1x', 'fit'}, ...
                'ColumnWidth', {'1x'}, 'Padding', 16);
            uilabel(layout, 'Text', char(join( ...
                string(options.PromptString), newline)), 'WordWrap', 'on');
            state.List = uilistbox(layout, 'Items', items, ...
                'ItemsData', 1:numel(items), ...
                'Multiselect', strcmp(mode, 'multiple'), ...
                'Value', initial, 'Tag', 'SessionPromptSelection');
            state.createButtons(layout, 3, ...
                options.OKString, options.CancelString);
            figure.Position(3:4) = [max(380, options.ListSize(1) + 32), ...
                max(220, options.ListSize(2) + 100)];
            state.Modal.show();
            if ~kssolv.ui.browser.BrowserReconnectMonitor.waitFor(state, 'Completed', true)
                return
            end
            selection = state.SelectedIndices;
            accepted = state.Accepted;
            clear cleanup
        end
    end

    methods
        function delete(this)
            if ~isempty(this.DestructionListener)
                delete(this.DestructionListener);
                this.DestructionListener = [];
            end
            if ~isempty(this.Modal) && isvalid(this.Modal)
                kssolv.ui.browser.OnlineModal.dispose(this.Modal);
            end
            this.Modal = [];
        end
    end

    methods (Access = private)
        function figure = createModal(this, title)
            this.Modal = kssolv.ui.browser.OnlineModal.create(title, true, false);
            figure = this.Modal.Figure;
            figure.CloseRequestFcn = @(~, ~)this.cancel();
            this.DestructionListener = addlistener(figure, ...
                'ObjectBeingDestroyed', @(~, ~)this.cancel());
        end

        function createButtons(this, parent, row, okText, cancelText)
            buttons = uigridlayout(parent, [1, 3], ...
                'ColumnWidth', {'1x', 'fit', 'fit'}, 'Padding', 0);
            buttons.Layout.Row = row;
            cancelButton = uibutton(buttons, 'Text', cancelText, ...
                'ButtonPushedFcn', @(~, ~)this.cancel(), ...
                'Tag', 'SessionPromptCancel');
            cancelButton.Layout.Column = 2;
            okButton = uibutton(buttons, 'Text', okText, ...
                'ButtonPushedFcn', @(~, ~)this.accept(), ...
                'Tag', 'SessionPromptOK');
            okButton.Layout.Column = 3;
        end

        function accept(this)
            if this.Completed, return; end
            if ~isempty(this.List)
                this.SelectedIndices = reshape(this.List.Value, 1, []);
            else
                this.Result = cell(numel(this.Fields), 1);
                for index = 1:numel(this.Fields)
                    value = string(this.Fields{index}.Value);
                    this.Result{index} = char(join(value, newline));
                end
            end
            this.Accepted = true;
            this.Completed = true;
        end

        function cancel(this)
            if this.Completed, return; end
            this.Result = {};
            this.SelectedIndices = [];
            this.Accepted = false;
            this.Completed = true;
        end
    end
end
