classdef CrystalViewerPrewarm < handle
    %CRYSTALVIEWERPREWARM Warm browser, shaders and preview code while idle.
    properties (SetAccess = private)
        IsReady (1,1) logical = false
        LastError (1,1) string = ""
    end
    properties (Access = private)
        Host
        HTML = []
        StartupTimer = []
        SelectionTimer = []
        HostListener = []
        IsClosing (1,1) logical = false
        StartedAt = []
    end
    methods
        function this = CrystalViewerPrewarm(host)
            this.Host = host;
            this.HostListener = addlistener(host, 'ObjectBeingDestroyed', ...
                @(~,~)this.shutdown());
            this.StartupTimer = timer('Name', 'KSSOLV Crystal Viewer prewarm', ...
                'ExecutionMode', 'fixedSpacing', 'Period', 0.5, ...
                'StartDelay', 0.5, 'BusyMode', 'drop', ...
                'TimerFcn', @(~,~)this.startWhenVisible());
            start(this.StartupTimer);
        end

        function prepareSelection(this, item)
            if this.IsClosing, return, end
            this.cancelTimer('SelectionTimer');
            if ~isa(item, 'kssolv.services.filemanager.Structure') || ...
                    ~isobject(item.data) || ~isprop(item.data, 'MatgenlabObject') || ...
                    isempty(item.data.MatgenlabObject)
                return
            end
            this.SelectionTimer = timer('Name', 'KSSOLV Crystal preview prewarm', ...
                'ExecutionMode', 'singleShot', 'StartDelay', 0.15, ...
                'TimerFcn', @(~,~)this.buildSelection(item));
            start(this.SelectionTimer);
        end

        function shutdown(this)
            if this.IsClosing, return, end
            this.IsClosing = true;
            this.cancelTimer('StartupTimer');
            this.cancelTimer('SelectionTimer');
            this.releaseHTML();
        end

        function delete(this)
            this.shutdown();
            if ~isempty(this.HostListener) && isvalid(this.HostListener)
                delete(this.HostListener);
            end
        end
    end
    methods (Access = private)
        function startWhenVisible(this)
            if this.IsClosing || ~isvalid(this.Host), return, end
            if ~this.Host.FigureViewReady || string(this.Host.Visible) ~= "on"
                return
            end
            % Do not compete with a document the user has already opened.
            registry = kssolv.ui.util.DataStorage.getData('ModelingSessionRegistry');
            if ~isempty(registry) && isvalid(registry) && registry.count() > 0
                this.cancelTimer('StartupTimer');
                this.releaseHTML();
                return
            end
            if ~isempty(this.HTML)
                if toc(this.StartedAt) > 30
                    this.LastError = "Viewer prewarm timed out.";
                    this.cancelTimer('StartupTimer');
                    this.releaseHTML();
                end
                return
            end
            try
                this.StartedAt = tic;
                model = kssolv.analysis.matgenlab.core.Structure(eye(3) * 5.43, ...
                    repmat({'Si'}, 1, 8), [0 0 0; .25 .25 .25; 0 .5 .5; ...
                    .25 .75 .75; .5 0 .5; .75 .25 .75; .5 .5 0; .75 .75 .25]);
                options = struct('algorithm', "CrystalNN", 'cell', "input", 'repeat', [1 1 1]);
                kssolv.ui.scene.atomic.AtomicPreviewCache.build(model, options, "prewarm");
                scene = kssolv.ui.scene.atomic.CrystalSceneCache.build(model, options, "prewarm");
                % Clipped outside the existing visible figure: CEF loads and
                % draws without creating a window, tab, or modeling session.
                this.HTML = uihtml(this.Host, 'Position', [-96 -96 64 64], ...
                    'Tag', 'KSSOLVCrystalPrewarm');
                this.HTML.HTMLEventReceivedFcn = @(~,event)this.receive(event);
                this.HTML.Data = jsonencode(struct('kssolvInitialScene', ...
                    kssolv.ui.scene.atomic.CrystalSceneSerializer.transportScene(scene)));
                entry = fullfile(KSSOLV_Toolbox.RootDirectory, '+kssolv', '+ui', ...
                    '+components', '+figuredocument', '@MoleculeDisplay', 'CrystalViewer', 'index.html');
                source = kssolv.ui.util.CrystalViewerRuntime.prepare(string(entry));
                this.HTML.HTMLSource = kssolv.ui.browser.htmlSource(source);
            catch exception
                this.LastError = string(exception.message);
                this.cancelTimer('StartupTimer');
                this.releaseHTML();
            end
        end

        function receive(this, event)
            if this.IsClosing, return, end
            if string(event.HTMLEventName) == "viewer:sceneRendered"
                this.IsReady = true;
                this.cancelTimer('StartupTimer');
                this.releaseHTML();
            elseif string(event.HTMLEventName) == "viewer:error"
                this.LastError = string(jsonencode(event.HTMLEventData));
                this.cancelTimer('StartupTimer');
                this.releaseHTML();
            end
        end

        function buildSelection(this, item)
            this.cancelTimer('SelectionTimer');
            if this.IsClosing || ~isvalid(item), return, end
            % A short atoms-only build is bounded; never run connectivity
            % speculatively while the user is selecting project entries.
            try
                model = item.data.MatgenlabObject;
                options = struct('algorithm', "CrystalNN", 'cell', "input", 'repeat', [1 1 1]);
                if isa(model, 'kssolv.analysis.matgenlab.core.IMolecule')
                    options.algorithm = "Auto";
                end
                if model.num_sites <= 1000
                    kssolv.ui.scene.atomic.AtomicPreviewCache.build(model, options, "prewarm");
                end
            catch
                % Speculative work must not interrupt selection or opening.
            end
        end

        function releaseHTML(this)
            html = this.HTML;
            this.HTML = [];
            if ~isempty(html) && isvalid(html)
                html.HTMLEventReceivedFcn = [];
                delete(html);
            end
        end

        function cancelTimer(this, name)
            pending = this.(name);
            this.(name) = [];
            if ~isempty(pending) && isvalid(pending)
                stop(pending);
                delete(pending);
            end
        end
    end
end
