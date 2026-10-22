classdef Sidebar < handle
    %SIDEBAR Register native panels in the client-owned Open Panels gallery.
    % Inline uihtml runs in both the native window and HostInBrowser. It does
    % not require a native webwindow, a debugging port, or a MATLAB-side timer.
    properties (SetAccess = private)
        Ready (1,1) logical = false
        PanelCount (1,1) double = 0
        Error (1,1) string = ""
    end

    properties (Access = private)
        Bridge
    end

    methods
        function this = Sidebar(container, figure, panelTags)
            panels = struct('tag', {}, 'title', {});
            for index = 1:numel(panelTags)
                panel = container.getPanel(panelTags(index));
                panels(index) = struct('tag', char(panelTags(index)), ...
                    'title', char(panel.Title));
            end
            this.Bridge = uihtml(figure, 'Position', [0 0 1 1], ...
                'Tag', 'KSSOLVSidebarBridge', ...
                'Data', struct('panels', panels, 'online', isKSSOLVOnline(), ...
                    'memoryLabel', kssolv.ui.util.Localizer.message('KSSOLV:dialogs:OnlineResourceMemory'), ...
                    'hostLabel', kssolv.ui.util.Localizer.message('KSSOLV:dialogs:OnlineResourceHost'), ...
                    'galleryTitle', kssolv.ui.util.Localizer.message('KSSOLV:dialogs:OpenPanelsTitle'), ...
                    'closeLabel', kssolv.ui.util.Localizer.message('KSSOLV:dialogs:DialogCloseButton')), ...
                'HTMLEventReceivedFcn', @(~,event)this.receive(event), ...
                'HTMLSource', fileread(kssolv.ui.browser.resourcePath('sidebar.html')));
        end

        function delete(this)
            if ~isempty(this.Bridge) && isvalid(this.Bridge)
                delete(this.Bridge);
            end
        end
    end

    methods (Access = private)
        function receive(this, event)
            switch event.HTMLEventName
                case 'SidebarReady'
                    this.Ready = true;
                    this.PanelCount = event.HTMLEventData.panelCount;
                    this.Error = "";
                case 'SidebarError'
                    this.Ready = false;
                    this.Error = string(event.HTMLEventData.message);
                    warning('KSSOLV:UI:SidebarUnavailable', '%s', this.Error);
            end
        end
    end
end
