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
            g = uigridlayout(fig);
            g.Padding = 0;
            g.RowHeight = {'1x'};
            g.ColumnWidth = {'1x'};
            htmlFile = fullfile(fileparts(mfilename('fullpath')), ...
                'CrystalViewer', 'index.html');
            % uihtml/CEF can retain a local HTML document under the same path
            % after Toolbox updates.  A unique source path guarantees that the
            % current embedded viewer (including render progress UI) is loaded.
            this.HTMLSourcePath = string(tempname) + ".html";
            [copied, copyMessage] = copyfile(htmlFile, this.HTMLSourcePath, 'f');
            if ~copied
                error("KSSOLV:CrystalViewer:HTMLSource", ...
                    "Unable to stage the crystal viewer: %s", copyMessage);
            end
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

        function applyModel(this, model, description)
            %APPLYMODEL Atomically update the document-local modeling draft.
            arguments
                this
                model
                description {mustBeTextScalar} = "Modeling operation"
            end
            this.validateModel(model);
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
            notify(this, "HistoryChanged");
            notify(this, "SelectionChanged");
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

        function saveChangesToProject(this)
            %SAVECHANGESTOPROJECT Commit this document's draft to Project.
            if ~this.hasUnsavedChanges()
                return
            end
            this.persistModel();
            this.InitialModel = this.ParsedModel.copy();
            this.clearHistory();
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

        function delete(this)
            %DELETE Remove the cache-busting viewer copy when the display closes.
            this.cancelImageExportDestinationTimer();
            if this.HTMLSourcePath ~= "" && isfile(this.HTMLSourcePath)
                try
                    delete(this.HTMLSourcePath);
                catch
                    % Temporary files are also reclaimed by the operating system.
                end
            end
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
            if model.num_sites < 1 && ~isa(model, ...
                    "kssolv.analysis.matgenlab.core.IStructure")
                error("KSSOLV:Modeling:EmptyModel", ...
                    "An empty modeled result must be a crystal structure.");
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
            switch string(event.HTMLEventName)
                case "viewer:ready"
                    this.rebuildScene();
                case "viewer:analysisRequested"
                    this.applyAnalysisRequest(event.HTMLEventData);
                case "viewer:selection"
                    this.LastSelection = event.HTMLEventData;
                    notify(this, "SelectionChanged");
                case "viewer:modelingCommandRequested"
                    this.applyModelingRequest(event.HTMLEventData);
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
                if ~this.isCrystal()
                    error("KSSOLV:Modeling:CrystalRequired", ...
                        "Atom modeling commands require a crystal structure.");
                end

                commandId = string(data.commandId);
                allowed = ["delete_atoms", "substitute_atoms", ...
                    "move_atoms", "translate_atoms"];
                if ~isscalar(commandId) || ~any(commandId == allowed)
                    error("KSSOLV:Modeling:ContextCommand", ...
                        "The requested atom modeling command is not available.");
                end

                zeroBased = unique(reshape(double(data.siteIndices), 1, []), ...
                    "stable");
                if isempty(zeroBased) || any(~isfinite(zeroBased)) || ...
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
                    case "translate_atoms"
                        parameters.vector = contextVector(source, "vector");
                        parameters.fractional = contextLogical( ...
                            source, "fractional");
                end

                commandInfo = kssolv.modeling.CommandCatalog.find(commandId);
                commandLabel = kssolv.ui.util.Localizer.message( ...
                    commandInfo.labelKey);
                result = kssolv.modeling.CommandExecutor.execute( ...
                    this.getModel(), commandId, parameters);
                if ~result.changed
                    error("KSSOLV:Modeling:ContextUnchanged", ...
                        "The modeling command did not update the structure.");
                end
                this.applyModel(result.model, commandLabel);
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
                if model.num_sites >= 256
                    if isMolecule
                        preview = ...
                            kssolv.ui.scene.atomic.MoleculeSceneBuilder.build( ...
                            model, ...
                            algorithm = this.SceneOptions.algorithm, ...
                            includeConnectivity = false, ...
                            requestId = requestId);
                    else
                        preview = ...
                            kssolv.ui.scene.atomic.CrystalSceneBuilder.build( ...
                            model, ...
                            algorithm = this.SceneOptions.algorithm, ...
                            cell = this.SceneOptions.cell, ...
                            repeat = this.SceneOptions.repeat, ...
                            includeConnectivity = false, ...
                            includePolyhedra = false, ...
                            requestId = requestId);
                    end
                    this.sendScene(preview);
                    drawnow limitrate
                end
                if isMolecule
                    scene = kssolv.ui.scene.atomic.MoleculeSceneCache.build( ...
                        model, this.SceneOptions, requestId);
                else
                    scene = kssolv.ui.scene.atomic.CrystalSceneCache.build( ...
                        model, this.SceneOptions, requestId);
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
            transport = ...
                kssolv.ui.scene.atomic.CrystalSceneSerializer. ...
                transportScene(scene);
            this.HTMLComponent.sendEventToHTMLSource( ...
                "scene:set", jsonencode(transport));
        end

        function sendExportFormats(this, model)
            formats = kssolv.ui.scene.atomic.StructureExportCatalog. ...
                list(model, this.structureFileType);
            payload = struct("formats", formats);
            this.HTMLComponent.sendEventToHTMLSource( ...
                "structure:exportFormats", jsonencode(payload));
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
