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
    end

    properties (Access = private)
        HTMLComponent
        ParsedModel
        SceneOptions = struct( ...
            "algorithm", "CrystalNN", ...
            "cell", "input", ...
            "repeat", [1, 1, 1])
        RequestSerial (1,1) double = 0
        IsBuilding (1,1) logical = false
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

            % 添加 html 组件
            fig = document.Figure;
            g = uigridlayout(fig);
            g.Padding = 0;
            g.RowHeight = {'1x'};
            g.ColumnWidth = {'1x'};
            htmlFile = fullfile(fileparts(mfilename('fullpath')), ...
                'CrystalViewer', 'index.html');
            this.HTMLComponent = uihtml(g, "HTMLSource", htmlFile);
            this.HTMLComponent.HTMLEventReceivedFcn = @this.eventReceiver;
            if isempty(this.ParsedModel)
                this.ParsedModel = this.parseTextInput();
                if isa(this.ParsedModel, ...
                        "kssolv.analysis.matgenlab.core.IMolecule")
                    this.SceneOptions.algorithm = "Auto";
                end
            end

            % 添加到 App Container
            appContainer.add(document);

            % 等待渲染完成
            waitfor(document.Figure, 'FigureViewReady', true);
            if isdeployed
                % document 会异常地取消停靠（undocked），在渲染完成后需要重新停靠它
                document.Docked = true;
            end
        end
    end

    methods (Access = private)
        function eventReceiver(this, ~, event)
            switch string(event.HTMLEventName)
                case "viewer:ready"
                    this.rebuildScene();
                case "viewer:analysisRequested"
                    this.applyAnalysisRequest(event.HTMLEventData);
                case "viewer:selection"
                    this.LastSelection = event.HTMLEventData;
                case "viewer:error"
                    this.reportViewerError(event.HTMLEventData);
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

        function rebuildScene(this)
            if this.IsBuilding
                this.sendSceneError("MATLAB_SCENE_BUSY", ...
                    "A scene build is already in progress. Please retry.", "");
                return
            end
            if isempty(this.HTMLComponent) || isempty(this.ParsedModel)
                this.sendSceneError("MATLAB_SCENE_UNAVAILABLE", ...
                    "The structure is not ready for scene generation.", "");
                return
            end
            this.IsBuilding = true;
            cleanup = onCleanup(@()this.finishBuild());
            this.RequestSerial = this.RequestSerial + 1;
            requestId = string(this.RequestSerial) + "-" + ...
                string(matlab.lang.internal.uuid);
            this.HTMLComponent.sendEventToHTMLSource( ...
                "scene:begin", struct("requestId", requestId));
            try
                isMolecule = isa(this.ParsedModel, ...
                    "kssolv.analysis.matgenlab.core.IMolecule");
                if this.ParsedModel.num_sites >= 256
                    if isMolecule
                        preview = ...
                            kssolv.ui.crystal.MoleculeSceneBuilder.build( ...
                            this.ParsedModel, ...
                            algorithm = this.SceneOptions.algorithm, ...
                            includeConnectivity = false, ...
                            requestId = requestId);
                    else
                        preview = ...
                            kssolv.ui.crystal.CrystalSceneBuilder.build( ...
                            this.ParsedModel, ...
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
                    scene = kssolv.ui.crystal.MoleculeSceneCache.build( ...
                        this.ParsedModel, this.SceneOptions, requestId);
                else
                    scene = kssolv.ui.crystal.CrystalSceneCache.build( ...
                        this.ParsedModel, this.SceneOptions, requestId);
                end
                this.sendScene(scene);
            catch exception
                this.sendSceneError("MATLAB_SCENE_BUILD", ...
                    string(exception.message), requestId);
                warning("KSSOLV:CrystalViewer:SceneBuild", ...
                    "Unable to build the crystal scene: %s", ...
                    exception.message);
            end
            clear cleanup
        end

        function sendScene(this, scene)
            transport = ...
                kssolv.ui.crystal.CrystalSceneSerializer. ...
                transportScene(scene);
            this.HTMLComponent.sendEventToHTMLSource( ...
                "scene:set", jsonencode(transport));
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
