classdef VolumeDisplay < handle
    %VOLUMEDISPLAY MATLAB uihtml host for the KSSOLV Volume Viewer.

    properties
        DocumentGroupTag (1,1) string = "Volume"
        tag (1,1) string = ""
    end

    properties (Access = private)
        FilePath (1,1) string
        HTMLComponent
        Datasets (1,:) cell = {}
        RequestSerial (1,1) double = 0
        ActiveRequestId (1,1) string = ""
        LastClientLoadedRequestId (1,1) string = ""
        LastClientError (1,1) string = ""
        TransferStages (1,:) cell = {}
        TransferStageIndex (1,1) double = 0
        TransferPayloadIndex (1,1) double = 0
        TransferChunks = []
        TransferChunkIndex (1,1) double = 0
        AwaitingChunkAck (1,1) logical = false
        StageCompleteSent (1,1) logical = false
    end

    methods
        function this = VolumeDisplay(filePath, tag)
            arguments
                filePath {mustBeTextScalar}
                tag string = ""
            end
            this.FilePath = string(filePath);
            this.tag = tag;
        end

        function Display(this)
            appContainer = kssolv.ui.util.DataStorage.getData( ...
                "AppContainer");
            group = appContainer.getDocumentGroup(this.DocumentGroupTag);
            if isempty(group)
                group = matlab.ui.internal.FigureDocumentGroup();
                group.Tag = this.DocumentGroupTag;
                group.Title = this.DocumentGroupTag;
                group.DefaultRegion = "left";
                appContainer.add(group);
            end
            document = appContainer.getDocument( ...
                this.DocumentGroupTag, this.tag);
            if ~isempty(document)
                document.Selected = true;
                return
            end
            options.Title = "Volume Viewer";
            options.DocumentGroupTag = this.DocumentGroupTag;
            if this.tag ~= ""
                options.Tag = this.tag;
                project = kssolv.ui.util.DataStorage.getData("Project");
                if isobject(project) && ...
                        ismethod(project, "findChildrenItem")
                    item = project.findChildrenItem(this.tag);
                    if ~isempty(item), options.Title = item.label; end
                end
            end
            document = matlab.ui.internal.FigureDocument(options);
            document.Figure.DeleteFcn = @(~, ~) this.cancelActiveRequest();
            layout = uigridlayout(document.Figure, [1, 1]);
            layout.Padding = 0;
            htmlFile = fullfile(fileparts(mfilename("fullpath")), ...
                "VolumeViewer", "index.html");
            this.HTMLComponent = uihtml(layout, HTMLSource = htmlFile);
            this.HTMLComponent.HTMLEventReceivedFcn = ...
                @this.eventReceiver;
            appContainer.add(document);
            waitfor(document.Figure, "FigureViewReady", true);
            if isdeployed, document.Docked = true; end
        end
    end

    methods (Access = private)
        function eventReceiver(this, ~, event)
            switch string(event.HTMLEventName)
                case "volume:ready"
                    this.loadAndSend();
                case "volume:cancel"
                    data = event.HTMLEventData;
                    if isstruct(data) && isfield(data, "requestId") && ...
                            string(data.requestId) == this.ActiveRequestId
                        this.ActiveRequestId = "";
                    end
                    this.clearTransferState();
                case "volume:manifest-ack"
                    this.handleManifestAck(event.HTMLEventData);
                case "volume:chunk-ack"
                    this.handleChunkAck(event.HTMLEventData);
                case "volume:loaded"
                    this.handleLoaded(event.HTMLEventData);
                case "volume:client-error"
                    data = event.HTMLEventData;
                    if isstruct(data) && isfield(data, "message")
                        this.LastClientError = string(data.message);
                    else
                        this.LastClientError = string(data);
                    end
                    warning("KSSOLV:VolumeViewer:ClientError", ...
                        "Volume viewer JavaScript error: %s", ...
                        this.LastClientError);
                    this.clearTransferState();
                case "volume:error"
                    warning("KSSOLV:VolumeViewer:WebGL", ...
                        "Volume viewer reported: %s", ...
                        string(event.HTMLEventData));
            end
        end

        function loadAndSend(this)
            this.RequestSerial = this.RequestSerial + 1;
            requestId = string(this.RequestSerial) + "-" + ...
                string(matlab.lang.internal.uuid);
            this.ActiveRequestId = requestId;
            this.LastClientLoadedRequestId = "";
            this.LastClientError = "";
            try
                [this.Datasets, ~] = ...
                    kssolv.ui.volume.VolumeFileReader.read( ...
                    this.FilePath);
                dataset = this.Datasets{1};
                overlay = this.atomicOverlay(dataset, requestId);
                stages = cell(1, 0);
                if prod(dataset.dimensions) > 96^3
                    preview = ...
                        kssolv.ui.volume.VolumeLodBuilder. ...
                        previewDataset(dataset);
                    % Preview and final payload share one logical request so
                    % the frontend preserves the user's camera on refinement.
                    stages{end + 1} = this.buildStage( ...
                        preview, requestId, overlay, ...
                        requestId + ":preview");
                end
                stages{end + 1} = this.buildStage( ...
                    dataset, requestId, overlay, requestId + ":full");
                this.TransferStages = stages;
                this.TransferStageIndex = 1;
                this.startCurrentStage();
            catch exception
                if this.canSend(requestId)
                    this.HTMLComponent.sendEventToHTMLSource( ...
                        "volume:error", struct( ...
                        "requestId", requestId, ...
                        "message", string(exception.message)));
                end
                warning("KSSOLV:VolumeViewer:LoadFailed", ...
                    "Unable to display '%s': %s", ...
                    this.FilePath, exception.message);
            end
        end

        function stage = buildStage(~, dataset, requestId, overlay, ...
                transportNamespace)
            [scene, payloads] = ...
                kssolv.ui.volume.VolumeSceneBuilder.build( ...
                dataset, requestId = requestId, ...
                transportNamespace = transportNamespace, ...
                atomicOverlay = overlay);
            stage = struct("scene", scene, "payloads", payloads);
        end

        function startCurrentStage(this)
            if this.TransferStageIndex < 1 || ...
                    this.TransferStageIndex > numel(this.TransferStages)
                return
            end
            stage = this.TransferStages{this.TransferStageIndex};
            scene = stage.scene;
            if ~this.canSend(scene.requestId), return; end
            this.TransferPayloadIndex = 1;
            this.TransferChunks = [];
            this.TransferChunkIndex = 0;
            this.AwaitingChunkAck = false;
            this.StageCompleteSent = false;
            this.HTMLComponent.sendEventToHTMLSource( ...
                "volume:begin", struct( ...
                    "requestId", scene.requestId, ...
                    "transferCount", numel(stage.payloads), ...
                    "totalBytes", sum(arrayfun( ...
                    @(channel) channel.transport.byteLength, ...
                    scene.channels))));
            this.HTMLComponent.sendEventToHTMLSource( ...
                "volume:manifest", jsonencode( ...
                kssolv.ui.volume.VolumeSceneSerializer. ...
                transportScene(scene)));
        end

        function handleManifestAck(this, data)
            if ~isstruct(data) || ~isfield(data, "requestId") || ...
                    ~isfield(data, "transferId") || ...
                    this.TransferStageIndex < 1 || ...
                    this.TransferStageIndex > numel(this.TransferStages)
                return
            end
            stage = this.TransferStages{this.TransferStageIndex};
            expected = string( ...
                stage.scene.channels(1).transport.transferId);
            if string(data.requestId) ~= this.ActiveRequestId || ...
                    string(data.transferId) ~= expected
                return
            end
            this.sendNextChunk();
        end

        function handleChunkAck(this, data)
            if ~this.AwaitingChunkAck || ~isstruct(data) || ...
                    ~isfield(data, "requestId") || ...
                    ~isfield(data, "transferId") || ...
                    ~isfield(data, "chunkIndex") || ...
                    isempty(this.TransferChunks)
                return
            end
            expected = this.TransferChunks(this.TransferChunkIndex);
            if string(data.requestId) ~= string(expected.requestId) || ...
                    string(data.transferId) ~= ...
                    string(expected.transferId) || ...
                    double(data.chunkIndex) ~= double(expected.chunkIndex)
                return
            end
            this.AwaitingChunkAck = false;
            this.TransferChunkIndex = this.TransferChunkIndex + 1;
            this.sendNextChunk();
        end

        function sendNextChunk(this)
            if this.AwaitingChunkAck || this.StageCompleteSent || ...
                    this.TransferStageIndex < 1 || ...
                    this.TransferStageIndex > numel(this.TransferStages)
                return
            end
            stage = this.TransferStages{this.TransferStageIndex};
            if ~this.canSend(stage.scene.requestId), return; end
            while this.TransferPayloadIndex <= numel(stage.payloads)
                if isempty(this.TransferChunks)
                    payload = stage.payloads(this.TransferPayloadIndex);
                    this.TransferChunks = ...
                        kssolv.ui.volume.VolumeChunkEncoder.encode( ...
                        stage.scene.requestId, payload);
                    this.TransferChunkIndex = 1;
                end
                if this.TransferChunkIndex <= numel(this.TransferChunks)
                    chunk = ...
                        this.TransferChunks(this.TransferChunkIndex);
                    this.AwaitingChunkAck = true;
                    this.HTMLComponent.sendEventToHTMLSource( ...
                        "volume:chunk", jsonencode(chunk));
                    return
                end
                this.TransferPayloadIndex = ...
                    this.TransferPayloadIndex + 1;
                this.TransferChunks = [];
                this.TransferChunkIndex = 0;
            end
            this.StageCompleteSent = true;
            this.HTMLComponent.sendEventToHTMLSource( ...
                "volume:complete", struct( ...
                "requestId", stage.scene.requestId, ...
                "transferCount", numel(stage.payloads)));
        end

        function handleLoaded(this, data)
            if ~isstruct(data) || ~isfield(data, "requestId") || ...
                    ~isfield(data, "transferId") || ...
                    this.TransferStageIndex < 1 || ...
                    this.TransferStageIndex > numel(this.TransferStages)
                return
            end
            stage = this.TransferStages{this.TransferStageIndex};
            expected = string( ...
                stage.scene.channels(1).transport.transferId);
            if string(data.requestId) ~= this.ActiveRequestId || ...
                    string(data.transferId) ~= expected
                return
            end
            if this.TransferStageIndex < numel(this.TransferStages)
                this.TransferStageIndex = this.TransferStageIndex + 1;
                this.startCurrentStage();
                return
            end
            this.LastClientLoadedRequestId = string(data.requestId);
            this.LastClientError = "";
            this.clearTransferState();
        end

        function value = canSend(this, cancelToken)
            value = this.ActiveRequestId == cancelToken && ...
                ~isempty(this.HTMLComponent) && ...
                isvalid(this.HTMLComponent);
        end

        function cancelActiveRequest(this)
            this.ActiveRequestId = "";
            this.Datasets = {};
            this.clearTransferState();
        end

        function clearTransferState(this)
            this.TransferStages = {};
            this.TransferStageIndex = 0;
            this.TransferPayloadIndex = 0;
            this.TransferChunks = [];
            this.TransferChunkIndex = 0;
            this.AwaitingChunkAck = false;
            this.StageCompleteSent = false;
        end

        function overlay = atomicOverlay(~, dataset, requestId)
            overlay = [];
            structure = dataset.structure;
            if isempty(structure), return; end
            try
                if isa(structure, ...
                        "kssolv.analysis.matgenlab.core.Structure")
                    includeNeighbors = structure.num_sites <= 2048;
                    overlay = ...
                        kssolv.ui.crystal.CrystalSceneBuilder.build( ...
                        structure, requestId = requestId, ...
                        includeConnectivity = includeNeighbors, ...
                        includePolyhedra = includeNeighbors, ...
                        includeBoundaryAtoms = true, ...
                        includeBondedOutside = true);
                elseif isa(structure, ...
                        "kssolv.analysis.matgenlab.core.Molecule")
                    overlay = ...
                        kssolv.ui.crystal.MoleculeSceneBuilder.build( ...
                        structure, requestId = requestId, ...
                        includeConnectivity = false);
                end
                if ~isempty(overlay)
                    overlay = ...
                        kssolv.ui.crystal.CrystalSceneSerializer. ...
                        transportScene(overlay);
                end
            catch exception
                warning("KSSOLV:VolumeViewer:AtomicOverlay", ...
                    "Volume loaded without atomic overlay: %s", ...
                    exception.message);
                overlay = [];
            end
        end
    end

    methods (Hidden)
        function value = testState(this)
            dimensions = zeros(0, 3);
            channelCounts = zeros(1, 0);
            if ~isempty(this.Datasets)
                dimensions = cell2mat(cellfun( ...
                    @(dataset) reshape(dataset.dimensions, 1, 3), ...
                    this.Datasets, UniformOutput = false).');
                channelCounts = cellfun( ...
                    @(dataset) dataset.numChannels, this.Datasets);
            end
            value = struct( ...
                "hasHTMLComponent", ~isempty(this.HTMLComponent), ...
                "datasetCount", numel(this.Datasets), ...
                "dimensions", dimensions, ...
                "channelCounts", channelCounts, ...
                "activeRequestId", this.ActiveRequestId, ...
                "clientLoadedRequestId", ...
                    this.LastClientLoadedRequestId, ...
                "clientError", this.LastClientError, ...
                "transferStageIndex", this.TransferStageIndex, ...
                "transferPayloadIndex", this.TransferPayloadIndex, ...
                "transferChunkIndex", this.TransferChunkIndex, ...
                "awaitingChunkAck", this.AwaitingChunkAck, ...
                "stageCompleteSent", this.StageCompleteSent);
        end

        function app = qeShow(this)
            options.Tag = "kssolv-volume-" + ...
                string(matlab.lang.internal.uuid);
            options.Title = "KSSOLV Volume Viewer Test";
            options.ToolstripEnabled = true;
            app = matlab.ui.container.internal.AppContainer(options);
            kssolv.ui.util.DataStorage.setData("AppContainer", app);
            app.Visible = true;
            this.Display();
        end
    end
end
