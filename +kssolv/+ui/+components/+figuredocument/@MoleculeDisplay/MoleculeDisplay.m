classdef MoleculeDisplay < handle
    %MOLECULEDISPLAY 三维渲染分子结构和晶体结构的组件

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties
        DocumentGroupTag
        structureFileContent string
        structureFileType string
        tag string
    end

    properties (SetAccess = private)
        LastSelection = struct.empty
        Document = matlab.ui.internal.FigureDocument.empty
    end

    properties (Access = private)
        HTMLComponent
        ParsedModel
        InitialModel
        SceneOptions = struct( ...
            "algorithm", "CrystalNN", ...
            "cell", "input", ...
            "repeat", [1, 1, 1])
        RequestSerial (1,1) double = 0
        CurrentRequestId string = ""
        IsBuilding (1,1) logical = false
        UndoStack cell = {}
        RedoStack cell = {}
        CurrentRevision (1,1) double = 0
        NextRevision (1,1) double = 0
        MaximumHistory (1,1) double = 50
        PendingImageExportRequestId string = ""
        PendingImageExportPath string = ""
        PendingImageExportTempPath string = ""
        PendingImageExportNextChunk (1,1) double = 0
        HTMLSourcePath string = ""
        ImageExportDestinationTimer = []
        BridgeEventSerial (1,1) double = 0
        PendingFullscreenExit (1,1) logical = false
        LastInteractionBenchmark = struct.empty
        OperationRecorder = []
        RecoveryJournal = []
        ModelingPreviewActive (1,1) logical = false
        IsClosing (1,1) logical = false
        DocumentCloseListener = []
        PendingSelectionSiteIndices double = []
        HasPendingSelection (1,1) logical = false
    end

    events
        HistoryChanged
        SelectionChanged
    end

    methods
        function this = MoleculeDisplay(structureInput, structureFileType, tag)
            %MOLECULEDISPLAY 构造此类的实例
            arguments
                structureInput = []
                structureFileType string = ""
                tag string = ""
            end
            if isa(structureInput, ...
                    "kssolv.analysis.matgenlab.core.IStructure") || ...
                    isa(structureInput, ...
                    "kssolv.analysis.matgenlab.core.IMolecule")
                this.ParsedModel = structureInput.copy();
                this.InitialModel = this.ParsedModel.copy();
                this.structureFileContent = "";
                this.structureFileType = structureFileType;
            elseif isempty(structureInput) || string(structureInput) == ""
                structureFilePath = fullfile(fileparts(mfilename('fullpath')), ...
                    'test', 'MoS2_mp-2815_conventional_standard.cif');
                this.structureFileContent = fileread(structureFilePath);
                this.structureFileType = "cif";
            else
                this.structureFileContent = string(structureInput);
                this.structureFileType = structureFileType;
            end
            if isa(this.ParsedModel, ...
                    "kssolv.analysis.matgenlab.core.IMolecule")
                this.SceneOptions.algorithm = "Auto";
            end
            this.tag = tag;
            if this.tag ~= ""
                this.RecoveryJournal = ...
                    kssolv.modeling.provenance.RecoveryJournal(this.tag);
            end
            this.DocumentGroupTag = 'Structure';

            appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
            group = appContainer.getDocumentGroup(this.DocumentGroupTag);
            if isempty(group)
                % 若 appContainer 没有 Tag 为 'Structure' 的 DocumentGroup，
                % 则创建 DocumentGroup 并添加到 appContainer 中
                group = matlab.ui.internal.FigureDocumentGroup();
                group.Tag = this.DocumentGroupTag;
                group.Title = this.DocumentGroupTag;
                group.DefaultRegion = 'left';
                appContainer.add(group);
            end
        end

        function Display(this)
            %DISPLAY 在 Document Group 中展示渲染的分子/晶体结构
            appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
            document = appContainer.getDocument(this.DocumentGroupTag, this.tag);
            if ~isempty(document)
                % 如果具有相同 tag 的 document 存在，则选中它
                document.Selected = true;
                return
            end

            figOptions.Title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:DocumentStructureTitle');
            figOptions.DocumentGroupTag = this.DocumentGroupTag;
            if this.tag ~= ""
                figOptions.Tag = this.tag;

                project = kssolv.ui.util.DataStorage.getData('Project');
                figOptions.Title = project.findChildrenItem(this.tag).label;
            end
            document = matlab.ui.internal.FigureDocument(figOptions);
            this.Document = document;
            document.CanCloseFcn = @(~)this.canCloseDocument();

            % 添加 html 组件
            fig = document.Figure;
            this.DocumentCloseListener=addlistener(fig, ...
                "ObjectBeingDestroyed",@(~,~)this.beginClose());
            g = uigridlayout(fig);
            g.Padding = 0;
            g.RowHeight = {'1x'};
            g.ColumnWidth = {'1x'};
            htmlFile = fullfile(fileparts(mfilename('fullpath')), ...
                'CrystalViewer', 'index.html');
            runtimeManifest = ...
                kssolv.ui.util.CrystalViewerRuntime.verify(string(htmlFile));
            % uihtml/CEF can retain a local HTML document under the same path
            % after Toolbox updates.  A unique source path guarantees that the
            % current embedded viewer (including render progress UI) is loaded.
            this.HTMLSourcePath = string(tempname) + ".html";
            [copied, copyMessage] = copyfile(htmlFile, this.HTMLSourcePath, 'f');
            if ~copied
                error("KSSOLV:CrystalViewer:HTMLSource", ...
                    "Unable to stage the crystal viewer: %s", copyMessage);
            end
            kssolv.ui.util.CrystalViewerRuntime.assertEntry( ...
                this.HTMLSourcePath, string(runtimeManifest.entrySha256));
            this.HTMLComponent = uihtml(g, "HTMLSource", this.HTMLSourcePath);
            this.HTMLComponent.HTMLEventReceivedFcn = @this.eventReceiver;
            if isempty(this.ParsedModel)
                this.ParsedModel = this.parseTextInput();
                this.InitialModel = this.ParsedModel.copy();
                if isa(this.ParsedModel, ...
                        "kssolv.analysis.matgenlab.core.IMolecule")
                    this.SceneOptions.algorithm = "Auto";
                end
            end

            % 添加到 App Container
            appContainer.add(document);
            kssolv.ui.features.modeling.SessionRegistry.getInstance().register( ...
                document, this);

            % 等待渲染完成
            waitfor(document.Figure, 'FigureViewReady', true);
            if isdeployed
                % document 会异常地取消停靠（undocked），在渲染完成后需要重新停靠它
                document.Docked = true;
            end
            this.promptForRecoveryDraft();
        end

        function model = getModel(this)
            %GETMODEL Return a defensive copy of the rendered model.
            if isempty(this.ParsedModel)
                model = [];
            else
                model = this.ParsedModel.copy();
            end
        end

        function value = isCrystal(this)
            value = isa(this.ParsedModel, ...
                "kssolv.analysis.matgenlab.core.IStructure");
        end

        function value = getRevision(this)
            %GETREVISION Return the document-local modeling revision.
            value = this.CurrentRevision;
        end

        function transaction = previewModelingCommand( ...
                this, commandId, parameters)
            %PREVIEWMODELINGCOMMAND Build a side-effect-free command preview.
            arguments
                this
                commandId {mustBeTextScalar}
                parameters (1,1) struct = struct()
            end
            transaction = ...
                kssolv.modeling.contracts.EditTransaction( ...
                this.getModel(), this.CurrentRevision, ...
                commandId, parameters);
        end

        function result = showModelingPreview(this, transaction)
            %SHOWMODELINGPREVIEW Render a transaction result without mutation.
            arguments
                this
                transaction kssolv.modeling.contracts.EditTransaction
            end
            if transaction.BaseRevision ~= this.CurrentRevision
                error("KSSOLV:Modeling:StaleTransaction", ...
                    "The preview was created from revision %d, but the " + ...
                    "document is at revision %d.", ...
                    transaction.BaseRevision, this.CurrentRevision);
            end
            result = transaction.preview();
            if ~isfield(result, "changed") || ~result.changed || ...
                    ~isfield(result, "model")
                error("KSSOLV:Modeling:PreviewUnavailable", ...
                    "This command does not produce a model preview.");
            end
            try
                this.renderModel(result.model, true);
                this.ModelingPreviewActive = true;
            catch exception
                this.ModelingPreviewActive = false;
                this.renderModel(this.ParsedModel, false);
                rethrow(exception)
            end
        end

        function clearModelingPreview(this)
            %CLEARMODELINGPREVIEW Restore the committed document scene.
            if ~this.ModelingPreviewActive
                return
            end
            this.ModelingPreviewActive = false;
            this.renderModel(this.ParsedModel, false);
        end

        function value = isModelingPreviewActive(this)
            value = this.ModelingPreviewActive;
        end

        function showModelingCandidatePreview(this, model, baseRevision)
            %SHOWMODELINGCANDIDATEPREVIEW Render an analysis candidate safely.
            arguments
                this
                model
                baseRevision (1,1) double {mustBeInteger,mustBeNonnegative}
            end
            this.assertCandidateRevision(baseRevision);
            this.validateModel(model);
            try
                this.renderModel(model, true);
                this.ModelingPreviewActive = true;
            catch exception
                this.ModelingPreviewActive = false;
                this.renderModel(this.ParsedModel, false);
                rethrow(exception)
            end
        end

        function commitModelingCandidate( ...
                this, model, baseRevision, description)
            %COMMITMODELINGCANDIDATE Commit one preview as one history entry.
            arguments
                this
                model
                baseRevision (1,1) double {mustBeInteger,mustBeNonnegative}
                description {mustBeTextScalar} = "Modeling candidate"
            end
            this.assertCandidateRevision(baseRevision);
            this.applyModel(model, description);
        end

        function value = hasRecoveryDraft(this)
            value = ~isempty(this.RecoveryJournal) && ...
                isvalid(this.RecoveryJournal) && this.RecoveryJournal.exists();
        end

        function snapshot = restoreRecoveryDraft(this)
            %RESTORERECOVERYDRAFT Restore a verified autosave as an unsaved draft.
            if ~this.hasRecoveryDraft()
                error("KSSOLV:Modeling:RecoveryMissing", ...
                    "No recovery snapshot exists for this document.");
            end
            snapshot = this.RecoveryJournal.recover();
            this.commitModel(snapshot.model);
            this.UndoStack = {};
            this.RedoStack = {};
            this.CurrentRevision = max(1, double(snapshot.revision));
            this.NextRevision = this.CurrentRevision;
            notify(this, "HistoryChanged");
            notify(this, "SelectionChanged");
        end

        function discardRecoveryDraft(this)
            %DISCARDRECOVERYDRAFT Remove the verified or corrupt snapshot file.
            if isempty(this.RecoveryJournal) || ...
                    ~isvalid(this.RecoveryJournal)
                return
            end
            this.RecoveryJournal.clear();
        end

        function result = commitModelingTransaction( ...
                this, transaction, description)
            %COMMITMODELINGTRANSACTION Atomically commit a current preview.
            arguments
                this
                transaction kssolv.modeling.contracts.EditTransaction
                description {mustBeTextScalar} = "Modeling operation"
            end
            parentModel = this.getModel();
            result = transaction.commit(this.CurrentRevision);
            this.ModelingPreviewActive = false;
            if isfield(result, "changed") && result.changed && ...
                    isfield(result, "model")
                this.applyModel(result.model, description);
                if ~isempty(this.OperationRecorder) && ...
                        isvalid(this.OperationRecorder)
                    this.OperationRecorder.record(parentModel, ...
                        transaction.CommandId,transaction.Parameters,result.model);
                end
            end
        end

        function startOperationRecording(this)
            %STARTOPERATIONRECORDING Begin a versioned GUI modeling recipe.
            this.OperationRecorder = ...
                kssolv.modeling.provenance.OperationRecorder();
        end

        function recipe = stopOperationRecording(this)
            %STOPOPERATIONRECORDING Stop recording and return the recipe.
            if isempty(this.OperationRecorder)
                error("KSSOLV:Modeling:RecorderInactive", ...
                    "No modeling operation recording is active.");
            end
            recipe = this.OperationRecorder.recipe();
            this.OperationRecorder = [];
        end

        function value = isOperationRecording(this)
            value = ~isempty(this.OperationRecorder) && ...
                isvalid(this.OperationRecorder);
        end

        function applyModel(this, model, description)
            %APPLYMODEL Atomically update the document-local modeling draft.
            arguments
                this
                model
                description {mustBeTextScalar} = "Modeling operation"
            end
            this.validateModel(model);
            this.ModelingPreviewActive = false;
            previous = this.ParsedModel.copy();
            previousRevision = this.CurrentRevision;
            this.commitModel(model);
            this.UndoStack{end + 1} = struct( ...
                "model", previous, ...
                "description", string(description), ...
                "revision", previousRevision);
            if numel(this.UndoStack) > this.MaximumHistory
                this.UndoStack(1) = [];
            end
            this.RedoStack = {};
            this.NextRevision = this.NextRevision + 1;
            this.CurrentRevision = this.NextRevision;
            this.checkpointRecovery();
            notify(this, "HistoryChanged");
            notify(this, "SelectionChanged");
        end

        function applyRecordedModel(this,model,description,commandId,parameters)
            %APPLYRECORDEDMODEL Commit a precomputed GUI command with provenance.
            arguments
                this
                model
                description {mustBeTextScalar}
                commandId {mustBeTextScalar}
                parameters (1,1) struct=struct()
            end
            parent=this.getModel();
            this.applyModel(model,description);
            if ~isempty(this.OperationRecorder) && ...
                    isvalid(this.OperationRecorder)
                this.OperationRecorder.record(parent,commandId,parameters,model);
            end
        end

        function value = canUndo(this)
            value = ~isempty(this.UndoStack);
        end

        function value = canRedo(this)
            value = ~isempty(this.RedoStack);
        end

        function exitFullscreen(this)
            %EXITFULLSCREEN Ask the embedded viewer to leave fullscreen.
            if isempty(this.HTMLComponent) || ~isvalid(this.HTMLComponent)
                return
            end
            this.PendingFullscreenExit = true;
            try
                this.HTMLComponent.sendEventToHTMLSource( ...
                    "viewer:command", struct("command", "exit-fullscreen"));
            catch exception
                this.PendingFullscreenExit = false;
                rethrow(exception)
            end
        end

        function value = isFullscreenExitPending(this)
            %ISFULLSCREENEXITPENDING True until the browser handles exit.
            value = this.PendingFullscreenExit;
        end

        function undo(this)
            if ~this.canUndo()
                return
            end
            entry = this.UndoStack{end};
            current = this.ParsedModel.copy();
            this.commitModel(entry.model);
            this.UndoStack(end) = [];
            this.RedoStack{end + 1} = struct( ...
                "model", current, ...
                "description", entry.description, ...
                "revision", this.CurrentRevision);
            this.CurrentRevision = entry.revision;
            this.checkpointRecovery();
            notify(this, "HistoryChanged");
            notify(this, "SelectionChanged");
        end

        function redo(this)
            if ~this.canRedo()
                return
            end
            entry = this.RedoStack{end};
            current = this.ParsedModel.copy();
            this.commitModel(entry.model);
            this.RedoStack(end) = [];
            this.UndoStack{end + 1} = struct( ...
                "model", current, ...
                "description", entry.description, ...
                "revision", this.CurrentRevision);
            this.CurrentRevision = entry.revision;
            this.checkpointRecovery();
            notify(this, "HistoryChanged");
            notify(this, "SelectionChanged");
        end

        function value = hasUnsavedChanges(this)
            %HASUNSAVEDCHANGES True when the draft differs from its baseline.
            value = this.CurrentRevision ~= 0;
        end

        function value = canReset(this)
            value = this.hasUnsavedChanges();
        end

        function reset(this)
            %RESET Restore the structure captured when this draft began.
            this.discardChanges(true);
        end

        function resetViewerCamera(this)
            %RESETVIEWERCAMERA Fit the current production scene in view.
            if isempty(this.HTMLComponent) || ~isvalid(this.HTMLComponent)
                return
            end
            this.sendBridgeDataEvent("viewer:command", ...
                struct("command", "reset"));
        end

        function showShortcutHelp(this, tier)
            %SHOWSHORTCUTHELP Open the production shortcut guide at a tier.
            arguments
                this
                tier (1,1) string {mustBeMember(tier, ...
                    ["common", "advanced"])} = "common"
            end
            if isempty(this.HTMLComponent) || ~isvalid(this.HTMLComponent)
                error("KSSOLV:Modeling:ViewerUnavailable", ...
                    "Display the structure before opening shortcut help.");
            end
            locale = this.viewerLocale();
            this.sendBridgeDataEvent("viewer:command", struct( ...
                "command", "open-shortcut-help", "tier", tier, ...
                "locale", locale));
        end

        function setContentZoom(this, percent)
            %SETCONTENTZOOM Set a supported production viewer zoom level.
            arguments
                this
                percent (1,1) double {mustBeMember(percent, ...
                    [75, 100, 125, 150, 175, 200])}
            end
            if isempty(this.HTMLComponent) || ~isvalid(this.HTMLComponent)
                error("KSSOLV:Modeling:ViewerUnavailable", ...
                    "Display the structure before setting viewer zoom.");
            end
            this.sendBridgeDataEvent("viewer:command", struct( ...
                "command", "set-content-zoom", "percent", percent));
        end

        function saveChangesToProject(this)
            %SAVECHANGESTOPROJECT Commit this document's draft to Project.
            if ~this.hasUnsavedChanges()
                return
            end
            this.persistModel();
            this.InitialModel = this.ParsedModel.copy();
            this.clearHistory();
            this.clearRecovery();
        end

        function discardChanges(this, render)
            %DISCARDCHANGES Restore the initial copy without touching Project.
            arguments
                this
                render (1,1) logical = true
            end
            if ~this.hasUnsavedChanges()
                return
            end
            initial = this.InitialModel.copy();
            if render
                this.commitModel(initial);
            else
                this.ParsedModel = initial;
                this.LastSelection = struct.empty;
            end
            this.clearHistory();
            this.clearRecovery();
            notify(this, "SelectionChanged");
        end

        function indices = getSelectedSiteIndices(this)
            %GETSELECTEDSITEINDICES Convert viewer zero-based selection to MATLAB.
            indices = [];
            data = this.LastSelection;
            if isempty(data) || ~isstruct(data)
                return
            end
            if isfield(data, "siteIndices")
                indices = double(data.siteIndices) + 1;
            elseif isfield(data, "siteIndex")
                indices = double(data.siteIndex) + 1;
            end
            indices = unique(reshape(indices, 1, []), "stable");
            if ~isempty(this.ParsedModel)
                indices = indices(indices >= 1 & ...
                    indices <= this.ParsedModel.num_sites);
            end
        end

        function setSelectedSiteIndices(this, indices)
            %SETSELECTEDSITEINDICES Select source sites by MATLAB indices.
            indices = unique(reshape(double(indices), 1, []), "stable");
            if any(~isfinite(indices)) || any(indices ~= fix(indices)) || ...
                    any(indices < 1) || ...
                    (~isempty(this.ParsedModel) && ...
                    any(indices > this.ParsedModel.num_sites))
                error("KSSOLV:Modeling:InvalidSiteIndices", ...
                    "Site indices must be valid positive integers.");
            end
            zeroBased = indices - 1;
            kind = "none";
            if ~isempty(indices), kind = "atom"; end
            % Programmatic selection is authoritative on the MATLAB side.
            % Updating it before the asynchronous web command prevents a
            % viewer-ready race from losing selection-set operations.
            this.LastSelection = struct( ...
                "siteIndices", zeroBased, "kind", kind);
            this.PendingSelectionSiteIndices = zeroBased;
            this.HasPendingSelection = true;
            notify(this, "SelectionChanged");
            if ~isempty(this.HTMLComponent) && isvalid(this.HTMLComponent)
                this.HTMLComponent.sendEventToHTMLSource( ...
                    "viewer:command", struct( ...
                    "command", "select-sites", ...
                    "siteIndices", zeroBased));
            end

        end

        function result = benchmarkViewerInteraction( ...
                this, sampleCount, timeout)
            %BENCHMARKVIEWERINTERACTION Measure production WebGL drag frames.
            arguments
                this
                sampleCount (1,1) double {mustBeInteger, mustBePositive} = 30
                timeout (1,1) double {mustBePositive} = 30
            end
            if isempty(this.HTMLComponent) || ~isvalid(this.HTMLComponent)
                error("KSSOLV:Modeling:ViewerUnavailable", ...
                    "Display the structure before running the viewer benchmark.");
            end
            started = tic;
            while toc(started) < timeout
                requestToken = string(matlab.lang.internal.uuid);
                this.LastInteractionBenchmark = struct.empty;
                this.sendBridgeDataEvent( ...
                    "viewer:command", struct( ...
                    "command", "benchmark-direct-manipulation", ...
                    "requestToken", requestToken, ...
                    "samples", sampleCount));
                retry = false;
                while toc(started) < timeout
                    drawnow
                    data = this.LastInteractionBenchmark;
                    if ~isempty(data) && isstruct(data) && ...
                            isfield(data, "requestToken") && ...
                            string(data.requestToken) == requestToken
                        if isfield(data, "status") && ...
                                string(data.status) == "success"
                            result = data;
                            return
                        end
                        messageText = "Viewer benchmark failed.";
                        if isfield(data, "message")
                            messageText = string(data.message);
                        end
                        retry = contains(messageText, ...
                            "rendered atomic scene is required", ...
                            IgnoreCase = true);
                        if ~retry
                            error("KSSOLV:Modeling:ViewerBenchmark", ...
                                "%s", messageText);
                        end
                        break
                    end
                    pause(0.01)
                end
                if retry
                    pause(0.1)
                    continue
                end
                if toc(started) >= timeout
                    break
                else
                    error("KSSOLV:Modeling:ViewerBenchmark", ...
                        "The viewer benchmark returned no result.");
                end
            end
            error("KSSOLV:Modeling:ViewerBenchmarkTimeout", ...
                "The viewer interaction benchmark timed out.");
        end

        function saveSelectionSet(this, name)
            %SAVESELECTIONSET Persist the current source-site selection.
            indices = this.getSelectedSiteIndices();
            if isempty(indices)
                error("KSSOLV:Modeling:SelectionSetEmpty", ...
                    "Select at least one atom before saving a selection set.");
            end
            [model, set] = ...
                kssolv.modeling.selection.SelectionSetStore.save( ...
                this.getModel(), name, indices);
            this.applyModel(model, "Save selection set: " + set.name);
        end

        function values = getSelectionSets(this)
            %GETSELECTIONSETS Return persistent selection-set summaries.
            values = kssolv.modeling.selection.SelectionSetStore.list( ...
                this.getModel());
        end

        function [indices, missingIds] = recallSelectionSet(this, name)
            %RECALLSELECTIONSET Select all still-present sites in a named set.
            [indices, missingIds] = ...
                kssolv.modeling.selection.SelectionSetStore.resolve( ...
                this.getModel(), name);
            zeroBased = indices - 1;
            if isempty(this.HTMLComponent) || ~isvalid(this.HTMLComponent)
                this.LastSelection = struct( ...
                    "siteIndices", zeroBased, "kind", "atom");
                notify(this, "SelectionChanged");
            else
                this.HTMLComponent.sendEventToHTMLSource( ...
                    "viewer:command", struct( ...
                    "command", "select-sites", ...
                    "siteIndices", zeroBased));
            end
        end

        function removeSelectionSet(this, name)
            %REMOVESELECTIONSET Delete persistent selection metadata.
            model = kssolv.modeling.selection.SelectionSetStore.remove( ...
                this.getModel(), name);
            this.applyModel(model, "Remove selection set: " + string(name));
        end

        function delete(this)
            %DELETE Remove the cache-busting viewer copy when the display closes.
            this.prepareForShutdown();
            this.cancelImageExportDestinationTimer();
            if this.HTMLSourcePath ~= "" && isfile(this.HTMLSourcePath)
                try
                    delete(this.HTMLSourcePath);
                catch
                    % Temporary files are also reclaimed by the operating system.
                end
            end
        end

        function prepareForShutdown(this)
            %PREPAREFORSHUTDOWN Stop browser and document callbacks early.
            this.beginClose();
            if ~isempty(this.HTMLComponent) && isvalid(this.HTMLComponent)
                try
                    this.HTMLComponent.HTMLEventReceivedFcn = [];
                catch
                end
            end
            if ~isempty(this.Document) && isvalid(this.Document)
                try
                    this.Document.CanCloseFcn = [];
                catch
                end
            end
            if ~isempty(this.DocumentCloseListener)
                try
                    delete(this.DocumentCloseListener);
                catch
                end
                this.DocumentCloseListener=[];
            end
            this.cancelImageExportDestinationTimer();
        end
    end

    methods (Access = private)
        function commitModel(this, model)
            %COMMITMODEL Render first, then update the document-local draft.
            this.validateModel(model);
            candidate = model.copy();
            previous = this.ParsedModel.copy();
            try
                % A modeled result is not committed until its complete scene
                % can be built.  This prevents a caught renderer exception
                % from corrupting the project item while reporting success.
                this.renderModel(candidate, true);
                this.ParsedModel = candidate;
                this.LastSelection = struct.empty;
            catch exception
                this.ParsedModel = previous;
                try
                    this.renderModel(previous, false);
                catch
                end
                rethrow(exception)
            end
        end

        function validateModel(~, model)
            if ~(isa(model, ...
                    "kssolv.analysis.matgenlab.core.IStructure") || ...
                    isa(model, ...
                    "kssolv.analysis.matgenlab.core.IMolecule"))
                error("KSSOLV:Modeling:InvalidModel", ...
                    "A modeled result must be a matgenlab structure or molecule.");
            end
            if model.num_sites < 0
                error("KSSOLV:Modeling:InvalidSiteCount", ...
                    "A modeled result cannot have a negative site count.");
            end
        end

        function assertCandidateRevision(this, baseRevision)
            if baseRevision ~= this.CurrentRevision
                error("KSSOLV:Modeling:StaleCandidate", ...
                    "The candidate was generated at revision %d, but the " + ...
                    "document is now at revision %d. Run the search again.", ...
                    baseRevision, this.CurrentRevision);
            end
        end

        function persistModel(this)
            if this.tag == ""
                error("KSSOLV:Modeling:ProjectItemUnavailable", ...
                    "This structure is not associated with a Project item.");
            end
            project = kssolv.ui.util.DataStorage.getData("Project");
            if isempty(project) || ~isvalid(project)
                error("KSSOLV:Modeling:ProjectUnavailable", ...
                    "The current Project is unavailable.");
            end
            item = project.findChildrenItem(this.tag);
            if isempty(item) || isempty(item.data)
                error("KSSOLV:Modeling:ProjectItemUnavailable", ...
                    "The structure's Project item is unavailable.");
            end
            if ~ismethod(item.data, "updateMatgenlabObject")
                error("KSSOLV:Modeling:ProjectItemReadOnly", ...
                    "The structure's Project item cannot be updated.");
            end
            item.data.updateMatgenlabObject(this.ParsedModel);
            item.updatedAt = datetime;
            project.isDirty = true;
        end

        function clearHistory(this)
            this.UndoStack = {};
            this.RedoStack = {};
            this.CurrentRevision = 0;
            this.NextRevision = 0;
            notify(this, "HistoryChanged");
        end

        function checkpointRecovery(this)
            if isempty(this.RecoveryJournal) || ...
                    ~isvalid(this.RecoveryJournal) || ...
                    ~this.hasUnsavedChanges()
                return
            end
            try
                this.RecoveryJournal.checkpoint(this.ParsedModel, ...
                    this.CurrentRevision,struct("tag",this.tag));
            catch exception
                warning("KSSOLV:Modeling:RecoveryCheckpoint", ...
                    "Unable to autosave the modeling draft: %s",exception.message);
            end
        end

        function clearRecovery(this)
            if isempty(this.RecoveryJournal) || ...
                    ~isvalid(this.RecoveryJournal)
                return
            end
            try
                this.RecoveryJournal.clear();
            catch exception
                warning("KSSOLV:Modeling:RecoveryClear", ...
                    "Unable to remove the recovery snapshot: %s",exception.message);
            end
        end

        function promptForRecoveryDraft(this)
            if ~this.hasRecoveryDraft()
                return
            end
            import kssolv.ui.util.Localizer.message
            appContainer = kssolv.ui.util.DataStorage.getData("AppContainer");
            try
                snapshot = this.RecoveryJournal.recover();
            catch exception
                if ~isempty(appContainer) && isvalid(appContainer)
                    uialert(appContainer, sprintf( ...
                        message("KSSOLV:dialogs:RecoveryCorruptMessage"), ...
                        exception.message, this.RecoveryJournal.Path), ...
                        message("KSSOLV:dialogs:RecoveryCorruptTitle"), ...
                        "Icon", "warning");
                end
                return
            end
            restoreLabel = message("KSSOLV:dialogs:RecoveryRestore");
            discardLabel = message("KSSOLV:dialogs:RecoveryDiscard");
            laterLabel = message("KSSOLV:dialogs:RecoveryLater");
            prompt = sprintf(message("KSSOLV:dialogs:RecoveryMessage"), ...
                string(snapshot.savedAt), double(snapshot.revision));
            if isdeployed
                dialog = kssolv.ui.components.dialog.ConfirmDialog( ...
                    prompt, message("KSSOLV:dialogs:RecoveryTitle"), ...
                    "Options", {restoreLabel, discardLabel, laterLabel}, ...
                    "DefaultOption", 1, "CancelOption", 3);
                selection = dialog.show();
            else
                selection = uiconfirm(appContainer, prompt, ...
                    message("KSSOLV:dialogs:RecoveryTitle"), ...
                    "Options", {restoreLabel, discardLabel, laterLabel}, ...
                    "DefaultOption", 1, "CancelOption", 3);
            end
            if selection == restoreLabel
                this.restoreRecoveryDraft();
            elseif selection == discardLabel
                this.discardRecoveryDraft();
            end
        end

        function status = canCloseDocument(this)
            status = true;
            if ~this.hasUnsavedChanges()
                return
            end

            import kssolv.ui.util.Localizer.message
            appContainer = kssolv.ui.util.DataStorage.getData("AppContainer");
            saveLabel = message("KSSOLV:dialogs:StructureCanCloseSave");
            discardLabel = ...
                message("KSSOLV:dialogs:StructureCanCloseDiscard");
            cancelLabel = message("KSSOLV:dialogs:StructureCanCloseCancel");
            if isdeployed
                dialog = kssolv.ui.components.dialog.ConfirmDialog( ...
                    message("KSSOLV:dialogs:StructureCanCloseMessage"), ...
                    message("KSSOLV:dialogs:StructureCanCloseTitle"), ...
                    "Options", {saveLabel, discardLabel, cancelLabel}, ...
                    "DefaultOption", 1, "CancelOption", 3);
                selection = dialog.show();
            else
                selection = uiconfirm(appContainer, ...
                    message("KSSOLV:dialogs:StructureCanCloseMessage"), ...
                    message("KSSOLV:dialogs:StructureCanCloseTitle"), ...
                    "Options", {saveLabel, discardLabel, cancelLabel}, ...
                    "DefaultOption", 1, "CancelOption", 3);
            end

            try
                switch selection
                    case saveLabel
                        this.saveChangesToProject();
                    case discardLabel
                        this.discardChanges(false);
                    otherwise
                        status = false;
                end
            catch exception
                status = false;
                if ~isempty(appContainer) && isvalid(appContainer)
                    uialert(appContainer, exception.message, ...
                        message("KSSOLV:modeling:ModelingError"), ...
                        "Icon", "error");
                else
                    warning("KSSOLV:Modeling:CloseFailed", ...
                        "%s", exception.message);
                end
            end
        end

        function eventReceiver(this, ~, event)
            if this.IsClosing
                return
            end
            switch string(event.HTMLEventName)
                case "viewer:ready"
                    this.sendViewerLocale();
                    this.rebuildScene();
                    this.sendPendingSelection();
                case "viewer:analysisRequested"
                    this.applyAnalysisRequest(event.HTMLEventData);
                case "viewer:selection"
                    data = event.HTMLEventData;
                    if ischar(data) || (isstring(data) && isscalar(data))
                        data = jsondecode(data);
                    end
                    if isstruct(data) && isfield(data, "kind") && ...
                            string(data.kind) == "benchmark"
                        this.LastInteractionBenchmark = data;
                    elseif this.HasPendingSelection && ...
                            (~isstruct(data) || ...
                            ~isfield(data, "siteIndices") || ...
                            ~isequal(unique(reshape( ...
                            double(data.siteIndices), 1, []), "stable"), ...
                            this.PendingSelectionSiteIndices))
                        % Scene initialization emits a transient empty
                        % selection. Preserve the authoritative MATLAB
                        % selection and retry once the viewer is live.
                        this.sendPendingSelection();
                    else
                        this.LastSelection = data;
                        this.HasPendingSelection = false;
                        notify(this, "SelectionChanged");
                    end
                case "viewer:modelingCommandRequested"
                    this.applyModelingRequest(event.HTMLEventData);
                case "viewer:historyCommand"
                    this.applyHistoryRequest(event.HTMLEventData);
                case "viewer:exportStructure"
                    this.exportStructure(event.HTMLEventData);
                case "viewer:chooseImageExport"
                    this.chooseImageExport(event.HTMLEventData);
                case "viewer:imageExportChunk"
                    this.writeImageExportChunk(event.HTMLEventData);
                case "viewer:cancelImageExport"
                    this.cancelImageExport(event.HTMLEventData);
                case "viewer:bringToFront"
                    this.bringToolboxToFront();
                case "viewer:fullscreenExitComplete"
                    this.PendingFullscreenExit = false;
                case "viewer:error"
                    this.reportViewerError(event.HTMLEventData);
            end
        end

        function bringToolboxToFront(this)
            % Restore focus to the Toolbox once the native save panel closes.
            try
                if ~isempty(this.Document) && isvalid(this.Document)
                    this.Document.Selected = true;
                end
                appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
                if ~isempty(appContainer) && isvalid(appContainer)
                    appContainer.bringToFront();
                end
                drawnow
            catch exception
                warning("KSSOLV:CrystalViewer:BringToFront", ...
                    "Unable to bring KSSOLV Toolbox to front: %s", ...
                    exception.message);
            end
        end

        function applyAnalysisRequest(this, data)
            try
                if ischar(data) || (isstring(data) && isscalar(data))
                    data = jsondecode(data);
                end
                if ~isstruct(data)
                    error("KSSOLV:CrystalViewer:InvalidRequest", ...
                        "The rebuild request payload must be a structure.");
                end
                if isfield(data, "algorithm")
                    this.SceneOptions.algorithm = string(data.algorithm);
                end
                if isfield(data, "cell")
                    this.SceneOptions.cell = string(data.cell);
                end
                if isfield(data, "repeat")
                    repeat = reshape(double(data.repeat), 1, []);
                    if numel(repeat) ~= 3 || any(~isfinite(repeat)) || ...
                            any(repeat < 1)
                        error("KSSOLV:CrystalViewer:InvalidRepeat", ...
                            "Repeat cell must contain three positive values.");
                    end
                    this.SceneOptions.repeat = repeat;
                end
                this.rebuildScene();
            catch exception
                this.sendSceneError("MATLAB_ANALYSIS_REQUEST", ...
                    string(exception.message), "");
            end
        end

        function applyModelingRequest(this, data)
            commandId = "";
            try
                if ischar(data) || (isstring(data) && isscalar(data))
                    data = jsondecode(data);
                end
                if ~isstruct(data) || ~isscalar(data) || ...
                        ~isfield(data, "requestId") || ...
                        ~isfield(data, "commandId") || ...
                        ~isfield(data, "siteIndices") || ...
                        ~isfield(data, "parameters")
                    error("KSSOLV:Modeling:ContextRequest", ...
                        "The atom modeling request is invalid.");
                end
                requestId = string(data.requestId);
                if ~isscalar(requestId) || requestId == "" || ...
                        requestId ~= this.CurrentRequestId
                    error("KSSOLV:Modeling:StaleContextRequest", ...
                        "The structure changed before the modeling command was applied.");
                end
                commandId = string(data.commandId);
                allowed = ["delete_atoms", "substitute_atoms", ...
                    "move_atoms", "rotate_atoms", "translate_atoms", ...
                    "sketch_atom", "sketch_ring", "add_bond", ...
                    "delete_bond", "set_bond_order", "set_distance", ...
                    "set_angle", "set_dihedral", "place_adsorbate"];
                if ~isscalar(commandId) || ~any(commandId == allowed)
                    error("KSSOLV:Modeling:ContextCommand", ...
                        "The requested atom modeling command is not available.");
                end

                zeroBased = unique(reshape(double(data.siteIndices), 1, []), ...
                    "stable");
                selectionOptional = any(commandId == ...
                    ["sketch_atom", "sketch_ring"]);
                if (~selectionOptional && isempty(zeroBased)) || ...
                        any(~isfinite(zeroBased)) || ...
                        any(zeroBased ~= fix(zeroBased)) || ...
                        any(zeroBased < 0) || ...
                        any(zeroBased >= this.ParsedModel.num_sites)
                    error("KSSOLV:Modeling:ContextIndices", ...
                        "Selected atom indices are invalid for the current structure.");
                end
                source = data.parameters;
                if ~isstruct(source) || ~isscalar(source)
                    error("KSSOLV:Modeling:ContextParameters", ...
                        "The atom modeling parameters are invalid.");
                end
                parameters = struct("indices", zeroBased + 1);
                switch commandId
                    case "delete_atoms"
                        % Site indices are the complete parameter set.
                    case "substitute_atoms"
                        if ~isfield(source, "species")
                            error("KSSOLV:Modeling:ContextSpecies", ...
                                "A replacement element or species is required.");
                        end
                        species = strtrim(string(source.species));
                        if ~isscalar(species) || species == ""
                            error("KSSOLV:Modeling:ContextSpecies", ...
                                "A replacement element or species is required.");
                        end
                        parameters.species = species;
                    case "move_atoms"
                        parameters.coordinates = contextVector( ...
                            source, "coordinates");
                        parameters.cartesian = contextLogical( ...
                            source, "cartesian");
                    case "rotate_atoms"
                        parameters.angleDegrees = contextScalar( ...
                            source, "angleDegrees");
                        parameters.axis = contextVector(source, "axis");
                        parameters.anchor = contextVector(source, "anchor");
                    case "translate_atoms"
                        parameters.vector = contextVector(source, "vector");
                        parameters.fractional = contextLogical( ...
                            source, "fractional");
                    case "sketch_atom"
                        parameters.species = contextText(source, "species");
                        parameters.coordinates = contextVector( ...
                            source, "coordinates");
                        parameters.connectTo = contextInteger( ...
                            source, "connectTo", 0, this.ParsedModel.num_sites);
                        parameters.bondOrder = contextBondOrder(source);
                        parameters.formalCharge = contextScalar( ...
                            source, "formalCharge");
                        parameters.hybridization = ...
                            contextText(source, "hybridization");
                        parameters.aromatic = contextLogical( ...
                            source, "aromatic");
                    case "sketch_ring"
                        parameters.ringSize = contextInteger( ...
                            source, "ringSize", 3, 8);
                        parameters.species = contextText(source, "species");
                        parameters.center = contextVector(source, "center");
                        parameters.normal = contextVector(source, "normal");
                        parameters.bondOrder = contextBondOrder(source);
                        parameters.aromatic = contextLogical( ...
                            source, "aromatic");
                        parameters.attachTo = contextInteger( ...
                            source, "attachTo", 0, this.ParsedModel.num_sites);
                    case {"add_bond", "set_bond_order"}
                        if this.isCrystal() || numel(zeroBased) ~= 2
                            error("KSSOLV:Modeling:InteractiveBondSelection", ...
                                "Select exactly two molecular atoms for bond editing.");
                        end
                        parameters.bondOrder = contextBondOrder(source);
                    case "delete_bond"
                        if this.isCrystal() || numel(zeroBased) ~= 2
                            error("KSSOLV:Modeling:InteractiveBondSelection", ...
                                "Select exactly two molecular atoms for bond editing.");
                        end
                    case "place_adsorbate"
                        if numel(zeroBased) ~= 1 || ~this.isCrystal()
                            error("KSSOLV:Modeling:InteractiveAdsorbateAnchor", ...
                                "Select one crystal atom as the adsorption anchor.");
                        end
                        if ~isfield(source, "adsorbateCoordinates")
                            error("KSSOLV:Modeling:ContextAdsorbate", ...
                                "Interactive adsorbates require the generic species, coordinates, and bonds protocol.");
                        end
                        parameters.anchorSites = zeroBased + 1;
                        parameters.adsorbateName = ...
                            contextText(source, "adsorbateName");
                        parameters.adsorbateSpecies = ...
                            contextTextArray(source, "adsorbateSpecies");
                        parameters.adsorbateCoordinates = ...
                            contextMatrix(source, ...
                            "adsorbateCoordinates", 3, false);
                        parameters.adsorbateBonds = ...
                            contextMatrix(source, "adsorbateBonds", 3, true);
                        parameters.anchorAtomIndices = ...
                            contextIntegerArray(source, ...
                            "anchorAtomIndices", 1, ...
                            numel(parameters.adsorbateSpecies));
                        if size(parameters.adsorbateCoordinates, 1) ~= ...
                                numel(parameters.adsorbateSpecies)
                            error("KSSOLV:Modeling:ContextAdsorbate", ...
                                "Adsorbate species and coordinate counts must match.");
                        end
                        parameters.minimumDistance = contextScalar( ...
                            source, "minimumDistance");
                    case {"set_distance", "set_angle", "set_dihedral"}
                        parameters.value = contextScalar(source, "value");
                        parameters.scope = contextText(source, "scope");
                        if ~any(parameters.scope == ...
                                ["atom", "subtree", "fragment"])
                            error("KSSOLV:Modeling:ContextScope", ...
                                "Move scope must be atom, subtree, or fragment.");
                        end
                        parameters.referenceCoordinates = contextMatrix( ...
                            source, "referenceCoordinates", 3, false);
                        if size(parameters.referenceCoordinates, 1) ~= ...
                                numel(zeroBased)
                            error("KSSOLV:Modeling:ContextGeometryReference", ...
                                "Reference-coordinate count must match the selected atom count.");
                        end
                end

                commandInfo = kssolv.modeling.CommandCatalog.find(commandId);
                commandLabel = kssolv.ui.util.Localizer.message( ...
                    commandInfo.labelKey);
                transaction = this.previewModelingCommand( ...
                    commandId, parameters);
                result = this.commitModelingTransaction( ...
                    transaction, commandLabel);
                if ~result.changed
                    error("KSSOLV:Modeling:ContextUnchanged", ...
                        "The modeling command did not update the structure.");
                end
                this.sendModelingResult(commandId, "success", "");
            catch exception
                this.sendModelingResult(commandId, "error", ...
                    string(exception.message));
            end

            function value = contextVector(sourceValue, name)
                if ~isfield(sourceValue, name)
                    error("KSSOLV:Modeling:ContextVector", ...
                        "Parameter '%s' is required.", name);
                end
                value = reshape(double(sourceValue.(name)), 1, []);
                if numel(value) ~= 3 || any(~isfinite(value))
                    error("KSSOLV:Modeling:ContextVector", ...
                        "Parameter '%s' must contain three finite values.", ...
                        name);
                end
            end

            function value = contextLogical(sourceValue, name)
                if ~isfield(sourceValue, name)
                    error("KSSOLV:Modeling:ContextLogical", ...
                        "Parameter '%s' is required.", name);
                end
                value = sourceValue.(name);
                if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                    error("KSSOLV:Modeling:ContextLogical", ...
                        "Parameter '%s' must be a logical scalar.", name);
                end
                value = logical(value);
            end

            function value = contextScalar(sourceValue, name)
                if ~isfield(sourceValue, name)
                    error("KSSOLV:Modeling:ContextScalar", ...
                        "Parameter '%s' is required.", name);
                end
                value = double(sourceValue.(name));
                if ~isscalar(value) || ~isfinite(value)
                    error("KSSOLV:Modeling:ContextScalar", ...
                        "Parameter '%s' must be a finite scalar.", name);
                end
            end

            function value = contextInteger(sourceValue, name, minimum, maximum)
                value = contextScalar(sourceValue, name);
                if value ~= fix(value) || value < minimum || value > maximum
                    error("KSSOLV:Modeling:ContextInteger", ...
                        "Parameter '%s' must be an integer from %d to %d.", ...
                        name, minimum, maximum);
                end
            end

            function value = contextText(sourceValue, name)
                if ~isfield(sourceValue, name)
                    error("KSSOLV:Modeling:ContextText", ...
                        "Parameter '%s' is required.", name);
                end
                value = strtrim(string(sourceValue.(name)));
                if ~isscalar(value) || value == ""
                    error("KSSOLV:Modeling:ContextText", ...
                        "Parameter '%s' must be nonempty text.", name);
                end
            end

            function value = contextTextArray(sourceValue, name)
                if ~isfield(sourceValue, name)
                    error("KSSOLV:Modeling:ContextTextArray", ...
                        "Parameter '%s' is required.", name);
                end
                value = reshape(strtrim(string(sourceValue.(name))), 1, []);
                if isempty(value) || any(value == "")
                    error("KSSOLV:Modeling:ContextTextArray", ...
                        "Parameter '%s' must contain nonempty text.", name);
                end
            end

            function value = contextMatrix( ...
                    sourceValue, name, width, allowEmpty)
                if ~isfield(sourceValue, name)
                    error("KSSOLV:Modeling:ContextMatrix", ...
                        "Parameter '%s' is required.", name);
                end
                value = double(sourceValue.(name));
                if isempty(value) && allowEmpty
                    value = zeros(0, width);
                    return
                end
                if size(value, 2) ~= width || any(~isfinite(value), "all")
                    error("KSSOLV:Modeling:ContextMatrix", ...
                        "Parameter '%s' must be a finite N-by-%d array.", ...
                        name, width);
                end
            end

            function value = contextIntegerArray( ...
                    sourceValue, name, minimum, maximum)
                if ~isfield(sourceValue, name)
                    error("KSSOLV:Modeling:ContextIntegerArray", ...
                        "Parameter '%s' is required.", name);
                end
                value = reshape(double(sourceValue.(name)), 1, []);
                if isempty(value) || any(~isfinite(value)) || ...
                        any(value ~= fix(value)) || any(value < minimum) || ...
                        any(value > maximum)
                    error("KSSOLV:Modeling:ContextIntegerArray", ...
                        "Parameter '%s' must contain integers from %d to %d.", ...
                        name, minimum, maximum);
                end
            end

            function value = contextBondOrder(sourceValue)
                value = contextScalar(sourceValue, "bondOrder");
                if ~any(abs(value - [1, 1.5, 2, 3]) < 1e-12)
                    error("KSSOLV:Modeling:ContextBondOrder", ...
                        "Bond order must be 1, 1.5, 2, or 3.");
                end
            end
        end

        function applyHistoryRequest(this, data)
            if ~isstruct(data) || ~isscalar(data) || ...
                    ~isfield(data, "requestId") || ...
                    ~isfield(data, "command")
                return
            end
            if string(data.requestId) ~= this.CurrentRequestId
                return
            end
            switch string(data.command)
                case "undo"
                    this.undo();
                case "redo"
                    this.redo();
            end
        end

        function rebuildScene(this)
            this.renderModel(this.ParsedModel, false);
        end

        function renderModel(this, model, throwOnFailure)
            arguments
                this
                model
                throwOnFailure (1,1) logical = false
            end
            if this.IsClosing
                if throwOnFailure
                    error("KSSOLV:CrystalViewer:SceneClosed", ...
                        "The document closed while scene generation was pending.");
                end
                return
            end
            if this.IsBuilding
                if throwOnFailure
                    error("KSSOLV:CrystalViewer:SceneBusy", ...
                        "A scene build is already in progress. Please retry.");
                end
                this.sendSceneError("MATLAB_SCENE_BUSY", ...
                    "A scene build is already in progress. Please retry.", "");
                return
            end
            % Headless display instances are used by model/history tests and
            % have no viewer to update.
            if isempty(this.HTMLComponent)
                return
            end
            if isempty(model)
                if throwOnFailure
                    error("KSSOLV:CrystalViewer:SceneUnavailable", ...
                        "The structure is not ready for scene generation.");
                end
                this.sendSceneError("MATLAB_SCENE_UNAVAILABLE", ...
                    "The structure is not ready for scene generation.", "");
                return
            end
            this.IsBuilding = true;
            cleanup = onCleanup(@()this.finishBuild());
            this.RequestSerial = this.RequestSerial + 1;
            requestId = string(this.RequestSerial) + "-" + ...
                string(matlab.lang.internal.uuid);
            this.CurrentRequestId = requestId;
            this.HTMLComponent.sendEventToHTMLSource( ...
                "scene:begin", struct("requestId", requestId));
            try
                isMolecule = isa(model, ...
                    "kssolv.analysis.matgenlab.core.IMolecule");
                sceneOptions = this.SceneOptions;
                % Modeling commands can intentionally cross the molecule /
                % periodic-structure boundary (for example amorphous packing).
                % Keep the user's remaining view settings, but translate the
                % connectivity choice to one accepted by the new model type.
                if isMolecule
                    if ~any(string(sceneOptions.algorithm) == ...
                            ["Auto", "Source", "OpenBabelNN"])
                        sceneOptions.algorithm = "Auto";
                    end
                elseif any(string(sceneOptions.algorithm) == ...
                        ["Auto", "Source", "OpenBabelNN"])
                    sceneOptions.algorithm = "CrystalNN";
                end
                % Deliver an atoms-first frame before expensive connectivity
                % for medium and large models. This keeps structure switching
                % responsive while the exact cached scene is compiled.
                if model.num_sites >= 1
                    if isMolecule
                        preview = ...
                            kssolv.ui.scene.atomic.MoleculeSceneBuilder.build( ...
                            model, ...
                            algorithm = sceneOptions.algorithm, ...
                            includeConnectivity = false, ...
                            requestId = requestId);
                    else
                        preview = ...
                            kssolv.ui.scene.atomic.CrystalSceneBuilder.build( ...
                            model, ...
                            algorithm = sceneOptions.algorithm, ...
                            cell = sceneOptions.cell, ...
                            repeat = sceneOptions.repeat, ...
                            includeConnectivity = false, ...
                            includePolyhedra = false, ...
                            requestId = requestId);
                    end
                    this.sendScene(preview);
                    drawnow limitrate
                    if this.IsClosing
                        error("KSSOLV:CrystalViewer:SceneClosed", ...
                            "The document closed while scene generation was pending.");
                    end
                end
                if isMolecule
                    scene = kssolv.ui.scene.atomic.MoleculeSceneCache.build( ...
                        model, sceneOptions, requestId);
                else
                    scene = kssolv.ui.scene.atomic.CrystalSceneCache.build( ...
                        model, sceneOptions, requestId);
                end
                this.sendScene(scene);
                this.sendExportFormats(model);
            catch exception
                this.sendSceneError("MATLAB_SCENE_BUILD", ...
                    string(exception.message), requestId);
                if throwOnFailure
                    rethrow(exception)
                end
                warning("KSSOLV:CrystalViewer:SceneBuild", ...
                    "Unable to build the crystal scene: %s", ...
                    exception.message);
            end
            clear cleanup
        end

        function sendScene(this, scene)
            if this.IsClosing || isempty(this.HTMLComponent) || ...
                    ~isvalid(this.HTMLComponent)
                return
            end
            transport = ...
                kssolv.ui.scene.atomic.CrystalSceneSerializer. ...
                transportScene(scene);
            try
                fragmentStorePath = kssolv.ui.util.DataStorage.getData( ...
                    "ModelingFragmentStorePath");
                if isempty(fragmentStorePath)
                    userFragments = kssolv.modeling.adsorption. ...
                        AdsorbateFragmentCatalog.userFragments();
                else
                    userFragments = kssolv.modeling.adsorption. ...
                        AdsorbateFragmentCatalog.userFragments( ...
                        StorePath = string(fragmentStorePath));
                end
            catch exception
                warning("KSSOLV:Modeling:AdsorbateFragmentCatalog", ...
                    "User adsorbate fragments were skipped: %s", ...
                    exception.message);
                userFragments = struct([]);
            end
            transport.modeling = kssolv.ui.scene.atomic. ...
                CrystalSceneSerializer.modeling(scene, userFragments);
            this.HTMLComponent.sendEventToHTMLSource( ...
                "scene:set", jsonencode(transport));
        end

        function sendPendingSelection(this)
            if ~this.HasPendingSelection || isempty(this.HTMLComponent) || ...
                    ~isvalid(this.HTMLComponent)
                return
            end
            this.HTMLComponent.sendEventToHTMLSource( ...
                "viewer:command", struct( ...
                "command", "select-sites", ...
                "siteIndices", this.PendingSelectionSiteIndices));
        end

        function sendViewerLocale(this)
            if this.IsClosing || isempty(this.HTMLComponent) || ...
                    ~isvalid(this.HTMLComponent)
                return
            end
            locale = this.viewerLocale();
            this.HTMLComponent.sendEventToHTMLSource( ...
                "viewer:locale", struct("locale", locale));
        end

        function locale = viewerLocale(~)
            locale = string(kssolv.ui.util.Localizer. ...
                getInstance().currentLocale);
            if startsWith(locale, "zh")
                locale = "zh-CN";
            else
                locale = "en-US";
            end
        end

        function sendExportFormats(this, model)
            if this.IsClosing || isempty(this.HTMLComponent) || ...
                    ~isvalid(this.HTMLComponent)
                return
            end
            formats = kssolv.ui.scene.atomic.StructureExportCatalog. ...
                list(model, this.structureFileType);
            payload = struct("formats", formats);
            this.HTMLComponent.sendEventToHTMLSource( ...
                "structure:exportFormats", jsonencode(payload));
        end

        function beginClose(this)
            if this.IsClosing, return, end
            this.IsClosing=true;
            this.RequestSerial=this.RequestSerial+1;
            this.CurrentRequestId="closed-"+ ...
                string(matlab.lang.internal.uuid);
            this.cancelImageExportDestinationTimer();
            this.clearPendingImageExport(true);
        end

        function exportStructure(this, data)
            format = "";
            try
                if ischar(data) || (isstring(data) && isscalar(data))
                    data = jsondecode(data);
                end
                if ~isstruct(data) || ~isscalar(data) || ...
                        ~isfield(data, "format")
                    error("KSSOLV:CrystalViewer:ExportRequest", ...
                        "The structure export request is invalid.");
                end
                format = lower(strtrim(string(data.format)));
                descriptor = kssolv.ui.scene.atomic. ...
                    StructureExportCatalog.writableFormat( ...
                    this.ParsedModel, format);
                base = "structure";
                if isfield(data, "filename")
                    base = string(data.filename);
                end
                defaultName = kssolv.ui.scene.atomic. ...
                    StructureExportCatalog.defaultFilename( ...
                    base, format, descriptor);
                filter = kssolv.ui.scene.atomic.StructureExportCatalog. ...
                    fileFilter(format, descriptor);
                [file, location] = uiputfile(filter, ...
                    "Export structure", char(defaultName));
                if isequal(file, 0) || isequal(location, 0)
                    this.sendExportResult(format, "cancelled", "");
                    return
                end
                this.ParsedModel.to(fullfile(location, file), format);
                this.sendExportResult(format, "success", "");
            catch exception
                this.sendExportResult(format, "error", ...
                    string(exception.message));
                warning("KSSOLV:CrystalViewer:StructureExport", ...
                    "Unable to export the current structure: %s", ...
                    exception.message);
            end
        end

        function sendExportResult(this, format, status, message)
            if isempty(this.HTMLComponent)
                return
            end
            payload = struct( ...
                "format", string(format), ...
                "status", string(status), ...
                "message", string(message));
            this.HTMLComponent.sendEventToHTMLSource( ...
                "structure:exportResult", payload);
        end

        function chooseImageExport(this, data)
            requestId = "";
            try
                if ischar(data) || (isstring(data) && isscalar(data))
                    data = jsondecode(data);
                end
                if ~isstruct(data) || ~isscalar(data) || ...
                        ~isfield(data, "requestId") || ...
                        ~isfield(data, "filename") || ...
                        ~isfield(data, "format")
                    error("KSSOLV:CrystalViewer:ImageExportRequest", ...
                        "The image export request is invalid.");
                end
                requestId = string(data.requestId);
                filename = string(data.filename);
                format = lower(string(data.format));
                switch format
                    case "png"
                        filter = {'*.png', 'PNG image (*.png)'};
                    case "jpeg"
                        filter = {'*.jpg;*.jpeg', 'JPEG image (*.jpg, *.jpeg)'};
                    case "tiff"
                        filter = {'*.tif;*.tiff', 'TIFF image (*.tif, *.tiff)'};
                    case "svg"
                        filter = {'*.svg', 'SVG image (*.svg)'};
                    case {"pdf-vector", "pdf-raster"}
                        filter = {'*.pdf', 'PDF document (*.pdf)'};
                    otherwise
                        error("KSSOLV:CrystalViewer:ImageExportFormat", ...
                            "Unsupported image export format '%s'.", format);
                end
                this.clearPendingImageExport(true);
                [file, location] = uiputfile(filter, ...
                    "Export rendered image", char(filename));
                if isequal(file, 0) || isequal(location, 0)
                    this.scheduleImageExportDestination(requestId, ...
                        "cancelled", "");
                    return
                end
                this.PendingImageExportRequestId = requestId;
                this.PendingImageExportPath = string(fullfile(location, file));
                this.PendingImageExportTempPath = string(tempname(location));
                this.PendingImageExportNextChunk = 0;
                this.scheduleImageExportDestination(requestId, "ready", "");
            catch exception
                this.clearPendingImageExport(true);
                this.scheduleImageExportDestination(requestId, "error", ...
                    string(exception.message));
                warning("KSSOLV:CrystalViewer:ImageExport", ...
                    "Unable to choose an image export location: %s", ...
                    exception.message);
            end
        end

        function writeImageExportChunk(this, data)
            requestId = "";
            index = -1;
            try
                if ischar(data) || (isstring(data) && isscalar(data))
                    data = jsondecode(data);
                end
                required = {'requestId', 'index', 'totalChunks', ...
                    'final', 'data'};
                if ~isstruct(data) || ~isscalar(data) || ...
                        ~all(isfield(data, required))
                    error("KSSOLV:CrystalViewer:ImageExportChunk", ...
                        "The image export data block is invalid.");
                end
                requestId = string(data.requestId);
                index = double(data.index);
                totalChunks = double(data.totalChunks);
                final = logical(data.final);
                if requestId ~= this.PendingImageExportRequestId || ...
                        this.PendingImageExportTempPath == ""
                    error("KSSOLV:CrystalViewer:ImageExportSession", ...
                        "The image export session is no longer active.");
                end
                if ~isscalar(index) || ~isfinite(index) || ...
                        index ~= this.PendingImageExportNextChunk || ...
                        ~isscalar(totalChunks) || totalChunks < 1 || ...
                        index >= totalChunks || final ~= (index == totalChunks - 1)
                    error("KSSOLV:CrystalViewer:ImageExportOrder", ...
                        "Image export data blocks arrived out of order.");
                end
                bytes = uint8(matlab.net.base64decode( ...
                    char(string(data.data))));
                permission = 'ab';
                if index == 0
                    permission = 'wb';
                end
                [fileId, message] = fopen( ...
                    char(this.PendingImageExportTempPath), permission);
                if fileId < 0
                    error("KSSOLV:CrystalViewer:ImageExportWrite", ...
                        "Unable to open the image export file: %s", message);
                end
                cleanup = onCleanup(@() fclose(fileId));
                written = fwrite(fileId, bytes, 'uint8');
                if written ~= numel(bytes)
                    error("KSSOLV:CrystalViewer:ImageExportWrite", ...
                        "The complete image data block could not be written.");
                end
                clear cleanup
                this.PendingImageExportNextChunk = index + 1;
                if final
                    [success, message] = movefile( ...
                        char(this.PendingImageExportTempPath), ...
                        char(this.PendingImageExportPath), 'f');
                    if ~success
                        error("KSSOLV:CrystalViewer:ImageExportMove", ...
                            "Unable to finish the image export: %s", message);
                    end
                    this.clearPendingImageExport(false);
                end
                this.sendImageExportChunkResult( ...
                    requestId, index, "success", "");
            catch exception
                this.clearPendingImageExport(true);
                this.sendImageExportChunkResult(requestId, index, ...
                    "error", string(exception.message));
                warning("KSSOLV:CrystalViewer:ImageExport", ...
                    "Unable to write the rendered image: %s", ...
                    exception.message);
            end
        end

        function cancelImageExport(this, data)
            if ischar(data) || (isstring(data) && isscalar(data))
                data = jsondecode(data);
            end
            if ~isstruct(data) || ~isscalar(data) || ...
                    ~isfield(data, "requestId")
                return
            end
            if string(data.requestId) == this.PendingImageExportRequestId
                this.clearPendingImageExport(true);
            end
        end

        function clearPendingImageExport(this, deleteTemporaryFile)
            if deleteTemporaryFile && this.PendingImageExportTempPath ~= "" && ...
                    isfile(this.PendingImageExportTempPath)
                delete(this.PendingImageExportTempPath);
            end
            this.PendingImageExportRequestId = "";
            this.PendingImageExportPath = "";
            this.PendingImageExportTempPath = "";
            this.PendingImageExportNextChunk = 0;
        end

        function sendImageExportDestination(this, requestId, status, message)
            if isempty(this.HTMLComponent)
                return
            end
            payload = struct( ...
                "requestId", string(requestId), ...
                "status", string(status), ...
                "message", string(message));
            this.sendBridgeDataEvent("image:exportDestination", payload);
        end

        function scheduleImageExportDestination(this, requestId, status, message)
            % uiputfile runs a nested native event loop. Sending back into
            % uihtml before its callback fully unwinds is unreliable on macOS
            % and can leave the JavaScript promise waiting forever. Deliver the
            % response from the next MATLAB event-loop turn instead.
            this.cancelImageExportDestinationTimer();
            this.ImageExportDestinationTimer = timer( ...
                "ExecutionMode", "singleShot", ...
                "StartDelay", 0.05, ...
                "TimerFcn", @(~, ~) this.deliverImageExportDestination( ...
                    requestId, status, message));
            start(this.ImageExportDestinationTimer);
        end

        function deliverImageExportDestination(this, requestId, status, message)
            this.sendImageExportDestination(requestId, status, message);
            this.cancelImageExportDestinationTimer();
        end

        function cancelImageExportDestinationTimer(this)
            timerObject = this.ImageExportDestinationTimer;
            this.ImageExportDestinationTimer = [];
            if isempty(timerObject)
                return
            end
            try
                if isvalid(timerObject)
                    stop(timerObject);
                    delete(timerObject);
                end
            catch
            end
        end

        function sendImageExportChunkResult(this, requestId, index, status, message)
            if isempty(this.HTMLComponent)
                return
            end
            payload = struct( ...
                "requestId", string(requestId), ...
                "index", double(index), ...
                "status", string(status), ...
                "message", string(message));
            this.sendBridgeDataEvent("image:exportChunkResult", payload);
        end

        function sendBridgeDataEvent(this, eventName, payload)
            % DataChanged retains the response state across native dialog
            % event-loop transitions, unlike a transient custom HTML event.
            this.BridgeEventSerial = this.BridgeEventSerial + 1;
            this.HTMLComponent.Data = struct( ...
                "kssolvEvent", string(eventName), ...
                "payload", payload, ...
                "serial", this.BridgeEventSerial);
        end

        function sendModelingResult(this, commandId, status, message)
            if isempty(this.HTMLComponent)
                return
            end
            payload = struct( ...
                "commandId", string(commandId), ...
                "status", string(status), ...
                "message", string(message));
            this.HTMLComponent.sendEventToHTMLSource( ...
                "modeling:result", payload);
        end

        function finishBuild(this)
            this.IsBuilding = false;
        end

        function sendSceneError(this, code, message, requestId)
            if isempty(this.HTMLComponent)
                return
            end
            data = struct( ...
                "requestId", string(requestId), ...
                "code", string(code), ...
                "message", string(message));
            this.HTMLComponent.sendEventToHTMLSource("scene:error", data);
        end

        function reportViewerError(~, data)
            if isstruct(data) && isfield(data, "message")
                warning("KSSOLV:CrystalViewer:WebGL", ...
                    "Crystal viewer reported: %s", string(data.message));
            end
        end

        function value = parseTextInput(this)
            try
                value = kssolv.analysis.matgenlab.core.Structure.from_str( ...
                    this.structureFileContent, this.structureFileType);
                return
            catch structureError
            end
            try
                value = kssolv.analysis.matgenlab.core.Molecule.from_str( ...
                    this.structureFileContent, this.structureFileType);
            catch moleculeError
                error("KSSOLV:CrystalViewer:ParseInput", ...
                    "Unable to parse '%s' as a structure (%s) or molecule (%s).", ...
                    this.structureFileType, structureError.message, ...
                    moleculeError.message);
            end
        end
    end

    methods (Hidden)
        function app = qeShow(this)
            % 用于在单元测试中测试 MoleculeDisplay，可通过下面的命令使用：
            % m = kssolv.ui.components.figuredocument.MoleculeDisplay();
            % m.qeShow()

            % 创建 App Container
            appOptions.Tag = sprintf('kssolv(%s)',char(matlab.lang.internal.uuid));
            appOptions.Title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:UnitTestTitle');
            appOptions.ToolstripEnabled = true;
            app = matlab.ui.container.internal.AppContainer(appOptions);

            % 保存 app 至 DataStorage
            import kssolv.ui.util.DataStorage.*
            setData('AppContainer', app);

            % 添加 Document Group
            group = matlab.ui.internal.FigureDocumentGroup();
            group.Tag = 'DocumentGroupTest';
            group.Title = 'DocumentGroupTest';
            group.DefaultRegion = 'left';
            app.add(group);

            % 展示界面
            app.Visible = true;

            % 展示 MolecularDisplay
            this.DocumentGroupTag = 'DocumentGroupTest';
            this.Display();
        end
    end
end
