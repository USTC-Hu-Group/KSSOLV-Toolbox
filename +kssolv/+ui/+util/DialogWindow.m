classdef DialogWindow
    %DIALOGWINDOW Present fully built windows without a visible relocation.

    methods (Static)
        function figureHandle = create(varargin)
            % Build Online windows directly in their eventual browser figure.
            if ~isKSSOLVOnline()
                figureHandle = uifigure(varargin{:});
                return
            end
            modal = kssolv.ui.browser.OnlineModal.create('', true, false);
            figureHandle = modal.Figure;
            figureHandle.Visible = 'off';
            for index = 1:2:numel(varargin)
                name = string(varargin{index});
                if any(strcmpi(name, ["Visible", "WindowStyle"]))
                    continue
                end
                set(figureHandle, char(name), varargin{index + 1});
            end
            setappdata(figureHandle, 'KSSOLVDialogModal', modal);
            modal.CanCloseFcn = @(~) ...
                kssolv.ui.util.DialogWindow.requestClose(figureHandle);
            listener = addlistener(figureHandle, 'ObjectBeingDestroyed', ...
                @(~, ~)kssolv.ui.browser.OnlineModal.dispose(modal));
            setappdata(figureHandle, 'KSSOLVDialogListener', listener);
        end

        function showCentered(figureHandle)
            arguments
                figureHandle (1,1) matlab.ui.Figure
            end
            if string(figureHandle.Visible) ~= "off"
                error("KSSOLV:UI:DialogAlreadyVisible", ...
                    "A dialog must remain hidden until it is centered.");
            end
            if isappdata(figureHandle, 'KSSOLVDialogModal')
                kssolv.ui.util.DialogWindow.bringToFront(figureHandle);
                return
            end
            movegui(figureHandle, "center");
            figureHandle.Visible = "on";
        end

        function bringToFront(figureHandle)
            if isappdata(figureHandle, 'KSSOLVDialogModal')
                modal = getappdata(figureHandle, 'KSSOLVDialogModal');
                modal.Title = figureHandle.Name;
                modal.show();
            else
                figureHandle.Visible = 'on';
                figure(figureHandle);
            end
        end

        function close(figureHandle)
            % close(), unlike delete(), invokes the owner's cleanup callback.
            close(figureHandle);
        end

        function wait(figureHandle)
            if ~isappdata(figureHandle, 'KSSOLVDialogModal')
                uiwait(figureHandle);
                return
            end
            setappdata(figureHandle, 'KSSOLVDialogWaiting', true);
            while isvalid(figureHandle) && ...
                    getappdata(figureHandle, 'KSSOLVDialogWaiting')
                if kssolv.ui.browser.BrowserReconnectMonitor.pollCurrent(), return, end
                pause(.05);
            end
        end

        function resume(figureHandle)
            if isappdata(figureHandle, 'KSSOLVDialogModal')
                setappdata(figureHandle, 'KSSOLVDialogWaiting', false);
            else
                uiresume(figureHandle);
            end
        end
    end

    methods (Static, Access = private)
        function accepted = requestClose(figureHandle)
            if isvalid(figureHandle), close(figureHandle); end
            accepted = ~isvalid(figureHandle);
        end
    end
end
