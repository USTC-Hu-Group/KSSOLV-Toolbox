classdef Sidebar < kssolv.ui.browser.Sidebar
    %SIDEBAR Compatibility alias for the former util namespace.
    methods
        function this = Sidebar(varargin)
            this@kssolv.ui.browser.Sidebar(varargin{:});
        end
    end
end
