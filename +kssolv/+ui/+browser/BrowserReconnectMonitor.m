classdef BrowserReconnectMonitor < handle
    %BROWSERRECONNECTMONITOR Release old browser waits before rebuilding views.
    % The timer only cancels dialogs; the startup loop owns capture/recreation.
    properties (SetAccess = private)
        Pending (1,1) logical = false
        Armed (1,1) logical = false
    end

    properties (Access = private)
        SessionFile (1,1) string
        PollTimer = []
        Cancelling (1,1) logical = false
        Disposing (1,1) logical = false
    end

    methods
        function this = BrowserReconnectMonitor(sessionFile)
            arguments
                sessionFile (1,1) string
            end
            this.SessionFile = sessionFile;
            kssolv.ui.util.DataStorage.setData('BrowserReconnectMonitor', this);
            this.PollTimer = timer('Name', 'KSSOLV browser reconnect monitor', ...
                'ExecutionMode', 'fixedSpacing', 'Period', 0.1, ...
                'BusyMode', 'drop', 'TimerFcn', @(~,~)this.poll());
            start(this.PollTimer);
        end

        function arm(this)
            % Only a replacement request after the initial entry is a reconnect.
            this.Pending = false;
            this.Armed = true;
        end

        function disarm(this)
            this.Armed = false;
            this.Pending = false;
        end

        function poll(this)
            if this.Disposing || ~this.Armed || this.Cancelling, return, end
            if ~this.Pending
                if ~kssolv.ui.browser.BrowserSession.hasPendingRequest(this.SessionFile)
                    return
                end
                this.Pending = true;
            end
            % Repeat while unwinding nested callbacks: cancellation can make
            % a caller display an error prompt before returning to startup.
            this.Cancelling = true;
            cleanup = onCleanup(@()this.finishCancelling());
            modals = kssolv.ui.browser.OnlineModal.getInstances();
            for index = numel(modals):-1:1
                if isvalid(modals{index})
                    % Bypass close vetoes on the disconnected page. Figure
                    % destruction listeners return cancelled results, release
                    % credentials/transfers, and unwind their owning callbacks.
                    kssolv.ui.browser.OnlineModal.dispose(modals{index});
                end
            end
        end

        function delete(this)
            this.Disposing = true;
            if ~isempty(this.PollTimer) && isvalid(this.PollTimer)
                stop(this.PollTimer);
                delete(this.PollTimer);
            end
            this.PollTimer = [];
            stored = kssolv.ui.util.DataStorage.getData('BrowserReconnectMonitor');
            if isequal(stored, this)
                kssolv.ui.util.DataStorage.removeData('BrowserReconnectMonitor');
            end
        end
    end

    methods (Static)
        function pending = pollCurrent()
            pending = false;
            monitor = kssolv.ui.util.DataStorage.getData('BrowserReconnectMonitor');
            if ~isempty(monitor) && isvalid(monitor)
                monitor.poll();
                pending = monitor.Pending;
            end
        end

        function reached = waitFor(object, property, value)
            % A timer callback can itself open a blocking recovery prompt.
            % MATLAB does not run another timer inside that callback, so the
            % wait must also poll directly rather than rely on the timer alone.
            if ~isKSSOLVOnline()
                waitfor(object, property, value);
                reached = isvalid(object) && isequal(object.(property), value);
                return
            end
            while isvalid(object) && ~isequal(object.(property), value)
                if kssolv.ui.browser.BrowserReconnectMonitor.pollCurrent()
                    reached = false;
                    return
                end
                pause(0.05);
            end
            reached = isvalid(object) && isequal(object.(property), value);
        end
    end

    methods (Access = private)
        function finishCancelling(this)
            this.Cancelling = false;
        end
    end
end
