classdef OnlineFileTransfer < kssolv.ui.browser.OnlineFileTransfer
    %ONLINEFILETRANSFER Compatibility alias for the former util namespace.
    methods
        function this = OnlineFileTransfer(varargin)
            this@kssolv.ui.browser.OnlineFileTransfer(varargin{:});
        end
    end
end
