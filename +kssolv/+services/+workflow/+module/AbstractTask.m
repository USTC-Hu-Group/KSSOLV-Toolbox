classdef (Abstract) AbstractTask < matlab.mixin.SetGet
    %ABSTRACTTASK 任务的抽象类

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties (Abstract, Constant)
        TASK_NAME
        IDENTIFIER
        DESCRIPTION
    end

    properties (SetAccess = protected)
        module (1, 1) kssolv.services.workflow.module.ModuleType = 1
        requiredTasks = [] % 依赖的任务标识符

        supportGPU logical = false
        supportParallel logical = true
    end

    properties
        taskID (1, 1) string
        taskStatus kssolv.services.workflow.module.TaskStatus = "NotStarted"
        taskInput
        taskOutput

        usedParallelType {mustBeMember(usedParallelType, {'None', 'GPU', 'Processes', 'Threads'})} = 'None'
        executionTimeLimit {mustBeMember(executionTimeLimit, {'No Limit', '30 minutes', '1 hour', '2 hours'})} = 'No Limit'
        canAccessOtherTaskOutputs logical = true
        canShareOutputWithOtherTasks logical = true
        saveOutputToProjectResults logical = false

        options
        optionsUI
        isDebugMode logical = false
    end

    properties (Hidden, Transient)
        taskUICreated (1, 1) logical = false
    end

    methods
        function this = AbstractTask()
            this.setup();
            this.setupOptionsUI();

            if ~isempty(this.optionsUI)
                this.options = this.optionsUI.options;
            end
        end

        function resetOptionsUI(this)
            if this.taskUICreated
                return
            end

            if ~isempty(this.optionsUI)
                this.optionsUI.setupUI();
            else
                this.setupOptionsUI();
            end

            this.taskUICreated = true;
        end

        function value = getExecutionOptions(this)
            %GETEXECUTIONOPTIONS Return a serializable task option snapshot.
            if ~isempty(this.optionsUI)
                value = this.optionsUI.options;
                this.options = value;
            elseif isempty(this.options)
                value = struct();
            else
                value = this.options;
            end
        end
    end

    methods (Abstract, Access = protected)
        setup(this)
    end

    methods (Abstract)
        setupOptionsUI(this)

        %{
        code = generateCodeSnippet(this)
        [output, status] = run(this, input)
        progress = getProgress(this)
        saveResultsToProject()
        exportResultsToWorkspace()
        tf = supportsParallel(this)
        cleanup()
        %}
    end
end
