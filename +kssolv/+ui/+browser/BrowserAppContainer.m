classdef BrowserAppContainer < kssolv.ui.browser.SidebarAppContainer
    %BROWSERAPPCONTAINER Initialize a browser view without a local browser.
    methods
        function this = BrowserAppContainer(options)
            this@kssolv.ui.browser.SidebarAppContainer(options);
        end

        function prepareBrowserView(this)
            this.HostInBrowser = true;
            try
                this.Visible = true;
            catch exception
                if exception.identifier ~= "MATLAB:uiframework:appcontainer:failedToLoadBrowser"
                    rethrow(exception);
                end
                % AppContainer initializes its peer model before opening the
                % browser, but its Visible setter stops before publishing
                % visibility when the local launcher fails. Remote clients
                % still need that property to build the complete container.
                this.setProperty('Visible', true);
            end
        end
    end
end
