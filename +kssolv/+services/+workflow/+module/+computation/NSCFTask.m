classdef NSCFTask < kssolv.services.workflow.module.AbstractTask
    %NSCFTASK NSCF 计算任务

    %   开发者：杨柳
    %   版权 2025 合肥瀚海量子科技有限公司

    properties (Constant)
        TASK_NAME = 'NSCF'
        IDENTIFIER = 'NSCFTask'
        DESCRIPTION = 'NSCF computation'
    end

    methods (Access = protected)
        function this = setup(this)
            this.module = kssolv.services.workflow.module.ModuleType.Computation;
            this.requiredTasks = [];
            this.supportGPU = true;
            this.supportParallel = true;
        end
    end

    methods
        function setupOptionsUI(this)
            this.optionsUI = kssolv.services.workflow.module.computation.NSCFTaskUI();
        end

        function context = executeTask(this, context, ~)
            arguments
                this
                context containers.Map
                ~
            end

            context = kssolv.services.workflow.module.computation. ...
                NSCFTask.executeWithOptions( ...
                context, this.getExecutionOptions(), this.getExecutionResources());
        end
    end

    methods (Static)
        function context = executeWithOptions(context, taskOptions, resources)
            arguments
                context containers.Map
                taskOptions (1, 1) struct
                resources (1, 1) struct = kssolv.services.workflow.ExecutionResources.defaults()
            end
            resources = kssolv.services.workflow.ExecutionResources. ...
                validate(resources, 'kssolv.services.workflow.module.computation.NSCFTask', taskOptions);
            if strcmp(resources.ParallelType, 'GPU')
                [resourceCleanup, ~] = kssolv.services.workflow.ExecutionResources.prepare( ...
                    resources, 'kssolv.services.workflow.module.computation.NSCFTask', taskOptions); %#ok<ASGLU>
            end

            NSCFOptions = options.NSCF();
            fields = fieldnames(taskOptions);
            for i = 1:length(fields)
                fieldName = fields{i};
                if ismember(fieldName, {'enableGPU', 'enableParallelPool'})
                    continue
                end
                NSCFOptions.(fieldName) = taskOptions.(fieldName);
            end
            NSCFOptions.enableGPU = strcmp(resources.ParallelType, 'GPU');

            % Hybrid exchange on the NSCF grid needs the SCF wavefunctions.
            if isKey(context, "molecule") && ...
                    strcmp(context("molecule").funct, 'HSE06') && ...
                    isempty(NSCFOptions.scfX)
                NSCFOptions.scfX = context("X");
            end

            % 输出 context
            context("NSCFOptions") = NSCFOptions;
            % Actual pools are created, bounded and released by the consumer.
            context('NSCFResources') = resources;
        end
    end
end
