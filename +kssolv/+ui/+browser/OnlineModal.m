classdef OnlineModal < handle
    %ONLINEMODAL Host MATLAB controls in the connected page's modal layer.
    % Uses the modal and embedded-figure services shipped with MATLAB. No
    % FigureDocument, native window, JVM, or additional browser client is used.
    properties (SetAccess = private)
        Figure
    end
    properties
        CanCloseFcn = []
    end
    properties (Dependent)
        Title
        Visible
        Selected
        Busy
    end
    properties (Access = private)
        Id char = ''
        TitleValue (1,1) string = ""
        Bridge = []
        HostListener = []
        ShowTimer = []
        FigureListener = []
        PositionListener = []
        WantedVisible = false
        Disposing = false
        Packet = []
        Sequence = 0
        Closable = true
        BusyValue = false
    end
    methods (Static)
        function instances = getInstances()
            % Embedded figures are Internal and cannot be found via groot.
            instances = kssolv.ui.browser.OnlineModal.registry('get', []);
        end

        function modal = create(title, closable, autoShow)
            if nargin < 2, closable = true; end
            if nargin < 3, autoShow = true; end
            modal = kssolv.ui.browser.OnlineModal(title, closable);
            if autoShow
                modal.ShowTimer = timer('ExecutionMode','singleShot', ...
                    'StartDelay',0.01,'TimerFcn',@(~,~)modal.show());
                start(modal.ShowTimer);
            end
        end
        function dispose(modal)
            if ~isempty(modal) && isvalid(modal), delete(modal); end
        end
    end
    methods
        function show(this)
            if this.Disposing || ~isgraphics(this.Figure), return, end
            this.stopTimer();
            this.WantedVisible = true;
            this.Figure.Visible = 'on';
            if isempty(this.Bridge) || ~isvalid(this.Bridge)
                app = kssolv.ui.util.DataStorage.getData('AppContainer');
                if isempty(app) || ~isvalid(app)
                    error('KSSOLV:Online:NoSession','No active Online session.');
                end
                panel = app.getPanel('ProjectBrowser');
                if isempty(panel)
                    error('KSSOLV:Online:NoModalHost','The Online modal host is unavailable.');
                end
                this.Packet = matlab.ui.internal.FigureServices.getDivFigurePacket(this.Figure);
                this.Bridge = uihtml(panel.Figure, 'Position',[0 0 1 1], ...
                    'Data',this.command('show'));
                this.HostListener = addlistener(panel.Figure, ...
                    'ObjectBeingDestroyed', @(~,~)delete(this));
                this.Bridge.DataChangedFcn = @(src,~)this.receive(src.Data);
                this.Bridge.HTMLSource = fileread( ...
                    kssolv.ui.browser.resourcePath('online-modal.html'));
            else
                this.Bridge.Data = this.command('show');
            end
        end
        function value = get.Busy(this), value = this.BusyValue; end
        function set.Busy(this, value)
            this.BusyValue = logical(value);
            if ~isempty(this.Bridge) && isvalid(this.Bridge)
                this.Bridge.Data = this.command('busy');
            end
        end
        function value = get.Title(this), value = this.TitleValue; end
        function set.Title(this, title)
            this.TitleValue = string(title);
            if isgraphics(this.Figure), this.Figure.Name = char(this.TitleValue); end
            if ~isempty(this.Bridge) && isvalid(this.Bridge)
                this.Bridge.Data = this.command('update');
            end
        end
        function value = get.Visible(this), value = this.WantedVisible; end
        function set.Visible(this,value)
            if value
                this.show();
            else
                this.stopTimer();
                this.WantedVisible = false;
                if isgraphics(this.Figure), this.Figure.Visible = 'off'; end
                if ~isempty(this.Bridge) && isvalid(this.Bridge)
                    this.Bridge.Data = this.command('hide');
                end
            end
        end
        function value = get.Selected(this), value = this.WantedVisible; end
        function set.Selected(this,value)
            if value, this.show(); end
        end
        function delete(this)
            if this.Disposing, return, end
            this.Disposing = true;
            kssolv.ui.browser.OnlineModal.registry('remove', this);
            this.stopTimer();
            if ~isempty(this.HostListener) && isvalid(this.HostListener)
                delete(this.HostListener);
            end
            this.HostListener = [];
            if ~isempty(this.FigureListener), delete(this.FigureListener); end
            if ~isempty(this.PositionListener), delete(this.PositionListener); end
            if ~isempty(this.Bridge) && isvalid(this.Bridge)
                % The bridge's unload handler removes the modal and destroys
                % its embedded view, including when the parent app closes.
                delete(this.Bridge);
            end
            if isgraphics(this.Figure), delete(this.Figure); end
        end
    end
    methods (Static, Access = private)
        function instances = registry(action, instance)
            persistent active
            if isempty(active)
                active = containers.Map('KeyType','char','ValueType','any');
            end
            switch action
                case 'add'
                    active(instance.Id) = instance;
                case 'remove'
                    if ~isempty(instance.Id) && isKey(active, instance.Id)
                        remove(active, instance.Id);
                    end
            end
            instances = active.values;
            instances = instances(cellfun(@(item)isvalid(item), instances));
        end
    end
    methods (Access = private)
        function this = OnlineModal(title,closable)
            this.Id = char(matlab.lang.internal.uuid);
            this.Title = string(title);
            this.Closable = closable;
            this.Figure = matlab.ui.internal.divfigure('Visible','off', ...
                'Name',char(title),'Position',[0 0 600 400]);
            this.FigureListener = addlistener(this.Figure,'ObjectBeingDestroyed', ...
                @(~,~)delete(this));
            this.PositionListener = addlistener(this.Figure,'SizeChanged', ...
                @(~,~)this.resize());
            kssolv.ui.browser.OnlineModal.registry('add', this);
        end
        function resize(this)
            if ~this.Disposing && ~isempty(this.Bridge) && isvalid(this.Bridge)
                this.Bridge.Data = this.command('resize');
            end
        end
        function stopTimer(this)
            if ~isempty(this.ShowTimer) && isvalid(this.ShowTimer)
                stop(this.ShowTimer);
                delete(this.ShowTimer);
            end
            this.ShowTimer = [];
        end
        function data = command(this, action)
            this.Sequence = this.Sequence + 1;
            data = struct('action',action,'sequence',this.Sequence, ...
                'title',char(this.Title),'closable',this.Closable, ...
                'size',this.Figure.Position(3:4),'packet',this.Packet, ...
                'busy',this.BusyValue,'visible',this.WantedVisible);
        end
        function receive(this, data)
            if this.Disposing || ~isstruct(data), return, end
            if isfield(data,'error')
                warning('KSSOLV:Online:ModalClient','%s',data.error);
            elseif isfield(data,'event') && strcmp(data.event,'close')
                if ~isempty(this.CanCloseFcn)
                    accepted = this.CanCloseFcn(this);
                    if ~isempty(accepted) && accepted && isvalid(this), delete(this); end
                elseif isgraphics(this.Figure)
                    close(this.Figure);
                end
            end
        end
    end
end
