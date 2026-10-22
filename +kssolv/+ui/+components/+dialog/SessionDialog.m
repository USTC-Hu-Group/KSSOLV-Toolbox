classdef SessionDialog < controllib.ui.internal.dialog.AbstractDialog
    %SESSIONDIALOG Keep auxiliary Online UI in the connected AppContainer.
    %   Desktop dialogs retain AbstractDialog behavior. Online dialogs use a
    %   reusable modal and return from show without blocking callbacks.

    properties (Access = private)
        SessionModal = []
    end

    methods (Static)
        function dialog = open(factory, dialog, title, varargin)
            % Show the Online loading shell before expensive construction.
            % The same shell owns the finished controls; desktop is unchanged.
            if ~isKSSOLVOnline()
                if isempty(dialog) || ~isvalid(dialog), dialog = factory(); end
                dialog.show(varargin{:});
                return
            end
            fresh = isempty(dialog) || ~isvalid(dialog);
            if fresh
                modal = kssolv.ui.browser.OnlineModal.create(title, true, false);
                modal.Busy = true;
                modal.show();
            else
                modal = dialog.SessionModal;
                if isempty(modal) || ~isvalid(modal)
                    dialog.show(varargin{:});
                    return
                end
                modal.Busy = true;
                modal.show();
            end
            try
                drawnow;
                if fresh
                    dialog = factory();
                    dialog.attachToSession(dialog.getWidget(), modal);
                end
                dialog.show(varargin{:});
                drawnow;
                modal.Busy = false;
            catch exception
                if fresh, kssolv.ui.browser.OnlineModal.dispose(modal);
                else, modal.Busy = false; end
                rethrow(exception)
            end
        end
    end

    methods
        function show(this, varargin)
            if ~isKSSOLVOnline() && ~this.hasSessionModal()
                show@controllib.ui.internal.dialog.AbstractDialog( ...
                    this, varargin{:});
                return
            end

            firstTime = ~this.IsWidgetValid;
            source = this.getWidget();
            if firstTime || ~strcmp(this.CloseMode, 'hide')
                this.updateUI();
            end
            if ~this.hasSessionModal()
                this.attachToSession(source);
            end

            this.SessionModal.Title = string(this.UIFigure.Name);
            this.SessionModal.show();
        end

        function hide(this)
            if this.hasSessionModal()
                this.SessionModal.Visible = false;
            else
                hide@controllib.ui.internal.dialog.AbstractDialog(this);
            end
        end

        function close(this)
            if ~this.hasSessionModal()
                close@controllib.ui.internal.dialog.AbstractDialog(this);
            elseif strcmp(this.CloseMode, 'destroy')
                this.deleteSessionModal();
            else
                this.hide();
            end
        end

        function delete(this)
            this.deleteSessionModal();
        end
    end

    methods (Access = private)
        function result = hasSessionModal(this)
            result = ~isempty(this.SessionModal) && ...
                isvalid(this.SessionModal) && this.IsWidgetValid;
        end

        function attachToSession(this, source, modal)
            title = string(source.Name);
            if title == "", title = string(this.Title); end
            if nargin < 3
                modal = kssolv.ui.browser.OnlineModal.create(title, true, false);
            end
            modal.Title = title;
            target = modal.Figure;
            children = source.Children;
            try
                target.CloseRequestFcn = source.CloseRequestFcn;
                target.Tag = source.Tag;
                target.Color = source.Color;
                target.Position(3:4) = source.Position(3:4);
                for index = 1:numel(children)
                    children(index).Parent = target;
                end
            catch exception
                for index = 1:numel(children)
                    if isvalid(children(index))
                        children(index).Parent = source;
                    end
                end
                kssolv.ui.browser.OnlineModal.dispose(modal);
                rethrow(exception)
            end
            this.SessionModal = modal;
            this.UIFigure = target;
            source.CloseRequestFcn = [];
            delete(source);
        end

        function deleteSessionModal(this)
            modal = this.SessionModal;
            this.SessionModal = [];
            if ~isempty(modal) && isvalid(modal)
                if this.IsWidgetValid
                    this.UIFigure.CloseRequestFcn = [];
                end
                kssolv.ui.browser.OnlineModal.dispose(modal);
                this.UIFigure = [];
            end
        end
    end
end
