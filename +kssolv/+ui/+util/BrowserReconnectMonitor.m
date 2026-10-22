classdef BrowserReconnectMonitor < kssolv.ui.browser.BrowserReconnectMonitor
    %BROWSERRECONNECTMONITOR Compatibility alias for the former util namespace.
    methods
        function this = BrowserReconnectMonitor(varargin)
            this@kssolv.ui.browser.BrowserReconnectMonitor(varargin{:});
        end
    end
end
