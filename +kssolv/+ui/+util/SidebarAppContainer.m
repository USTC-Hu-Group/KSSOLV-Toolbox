classdef SidebarAppContainer < kssolv.ui.browser.SidebarAppContainer
    %SIDEBARAPPCONTAINER Compatibility alias for the former util namespace.
    methods
        function this = SidebarAppContainer(varargin)
            this@kssolv.ui.browser.SidebarAppContainer(varargin{:});
        end
    end
end
