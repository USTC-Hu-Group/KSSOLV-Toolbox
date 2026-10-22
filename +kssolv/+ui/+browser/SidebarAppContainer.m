classdef SidebarAppContainer < matlab.ui.container.internal.AppContainer
    %SIDEBARAPPCONTAINER Use the shared Desktop sidebar in Toolbox windows.
    % These AppContainer client features are internal MathWorks APIs.
    methods
        function this = SidebarAppContainer(options)
            this@matlab.ui.container.internal.AppContainer(options);
        end

        function page = getClientPage(this)
            % Also used by Online's nonce-qualified browser URL handoff.
            page = this.getPage();
        end
    end

    methods (Access = protected)
        function page = getPage(this)
            page = string(getPage@matlab.ui.container.internal.AppContainer(this));
            separator = "?";
            if contains(page, '?'), separator = "&"; end
            page = page + separator + "desktopFeatures=" + ...
                "sidebar,panelsGallery,toolHeaderStyle," + ...
                "dragAndDropDocuments,dragAndDropTools";
        end
    end
end
