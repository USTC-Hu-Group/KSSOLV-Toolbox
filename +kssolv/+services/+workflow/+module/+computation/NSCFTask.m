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
            this.supportParallel = false;
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
                context, this.getExecutionOptions());
        end
    end

    methods (Static)
        function context = executeWithOptions(context, taskOptions)
            arguments
                context containers.Map
                taskOptions (1, 1) struct
            end

            NSCFOptions = options.NSCF();
            fields = fieldnames(taskOptions);
            for i = 1:length(fields)
                fieldName = fields{i};
                NSCFOptions.(fieldName) = taskOptions.(fieldName);
            end

            % 输出 context
            context("NSCFOptions") = NSCFOptions;
        end
    end
end
