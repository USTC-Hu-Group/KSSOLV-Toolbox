classdef Workflow < kssolv.services.filemanager.AbstractItem
    %WORKFLOW 定义了以".wf"为扩展名的 KSSOLV Toolbox 工作流类和相关操作函数

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties (Hidden)
        graph kssolv.services.workflow.WorkflowGraph
        graphJSON string
        editedNode = []
    end

    properties (Hidden, Constant)
        version string = 'wf-1.0'   % .wf 文件版本号，默认为 wf-1.0
    end

    methods
        function this = Workflow(label, type)
            %WORKFLOW 构造函数
            arguments
                label string = "Workflow"
                type string = "Workflow"
            end
            this = this@kssolv.services.filemanager.AbstractItem(label, type);
        end

        function showWorkflowDisplay(this)
            % 使用 graphJSON 以打开对应工作流的 document
            kssolv.ui.components.figuredocument.Workflow(this.graphJSON, this.name).Display();
        end

        function createWorkflowItem(this, isBlank)
            % 创建并添加工作流节点
            arguments
                this
                isBlank (1, 1) logical = false
            end

            workflow = kssolv.services.filemanager.Workflow();
            if isBlank
                workflow.graphJSON = '[]';
            else
                workflow.graphJSON = kssolv.ui.components.figuredocument.Workflow.getDagJSON();
            end

            this.addChildrenItem(workflow);
            displayObj = kssolv.ui.components.figuredocument.Workflow(workflow.graphJSON, workflow.name);
            displayObj.Display();
        end

        function addWorkflowItem(this, workflowItem)
            % 添加从 .wf 文件中读取的工作流节点
            arguments
                this
                workflowItem (1, 1) kssolv.services.filemanager.Workflow {mustBeNonempty}
            end

            workflowItem.name = sprintf('Workflow(%s)', char(matlab.lang.internal.uuid));
            this.addChildrenItem(workflowItem);
            displayObj = kssolv.ui.components.figuredocument.Workflow(workflowItem.graphJSON, workflowItem.name);
            displayObj.Display();
        end

        function set.graphJSON(this, newValue)
            this.graphJSON = newValue;
            % Empty folders have no canvas. Loading must retain the saved
            % graph and its task types/options rather than construct new tasks.
            if strlength(newValue) == 0 || ...
                    isequal(kssolv.ui.util.DataStorage.getData('LoadingKsFile'), true)
                return
            end
            thisGraph = this.get("graph");
            if isempty(thisGraph)
                this.set("graph", kssolv.services.workflow.WorkflowGraph(jsondecode(newValue)));
                return
            end

            thisGraph.updateFromJSON(jsondecode(newValue));
        end

        function saveToWfFile(this, filename)
            % 将项目数据结构体保存到 .wf 文件中
            arguments
                this
                filename (1,1) string = this.label + '.wf'
            end

            % 检查 filename 是否为绝对路径，并检查目录是否存在，不存在则创建
            folderPath = fileparts(filename);
            if ~isempty(folderPath) && ~exist(folderPath, 'dir')
                previousWarningState = warning;
                warningCleanup = ...
                    onCleanup(@() warning(previousWarningState));
                warning('off', 'all');
                mkdir(folderPath);
                clear warningCleanup
            end

            % Export only this workflow. Saving its parent also serializes the
            % entire project, including unrelated structures and old parsers.
            previousParent = this.parent;
            parentCleanup = onCleanup(@()this.set('parent', previousParent));
            this.parent = [];
            data = this;
            try
                save(filename, 'data', "-mat", "-v7.3");
            catch ME
                error('KSSOLV:FileManager:Workflow:FileSaveError', ...
                    'Error saving the Workflow file: %s', ME.message);
            end
            clear parentCleanup
        end
    end

    methods (Static)
        function data = loadWfFile(fileName, isTemplate)
            % 从 .wf 文件中加载项目数据结构体
            arguments
                fileName (1, 1) string
                isTemplate (1, 1) logical = false
            end
            [~, ~, ext] = fileparts(fileName);
            if ~strcmp(ext, '.wf')
                % 检查文件的扩展名是否为 .wf
                error('KSSOLV:FileManager:Workflow:FileLoadError', ...
                    'Specified file does not have a .wf extension');
            end

            previousLoading = kssolv.ui.util.DataStorage.getData('LoadingKsFile');
            loadingCleanup = onCleanup(@() kssolv.ui.util.DataStorage.setData( ...
                'LoadingKsFile', previousLoading));
            kssolv.ui.util.DataStorage.setData('LoadingKsFile', true);
            try
                load(fileName, "-mat", 'data');
            catch ME
                error('KSSOLV:FileManager:Workflow:FileLoadError', ...
                    'Error loading the Workflow file: %s', ME.message);
            end

            data.parent = [];
            kssolv.services.filemanager.internal.migrateWorkflowResources(data);
            if isTemplate
                nodeIDs = keys(data.graph.Nodes);
                for i = 1:numel(nodeIDs)
                    task = data.graph.Nodes(nodeIDs{i}).task;
                    if isa(task, ...
                            'kssolv.services.workflow.module.computation.BuildMoleculeTask')
                        task.optionsUI.setupForTemplate();
                        task.options = task.optionsUI.options;
                        task.taskUICreated = true;
                    end
                end
            end
        end
    end
end
