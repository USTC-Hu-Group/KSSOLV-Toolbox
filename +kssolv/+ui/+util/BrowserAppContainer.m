classdef BrowserAppContainer < kssolv.ui.browser.BrowserAppContainer
    %BROWSERAPPCONTAINER Compatibility alias for the former util namespace.
    methods
        function this = BrowserAppContainer(varargin)
            this@kssolv.ui.browser.BrowserAppContainer(varargin{:});
        end
    end
end
