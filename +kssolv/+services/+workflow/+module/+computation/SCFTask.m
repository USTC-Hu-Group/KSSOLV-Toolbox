classdef SCFTask < kssolv.services.workflow.module.AbstractTask
    %SCFTASK SCF 计算任务

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties (Constant)
        TASK_NAME = 'SCF'
        IDENTIFIER = 'SCFTask'
        DESCRIPTION = 'SCF computation'
    end

    methods (Access = protected)
        function this = setup(this)
            this.module = kssolv.services.workflow.module.ModuleType.Computation;
            this.requiredTasks = 'BuildMoleculeTask';
            this.supportGPU = true;
            this.supportParallel = true;
        end
    end

    methods
        function setupOptionsUI(this)
            this.optionsUI = kssolv.services.workflow.module.computation.SCFTaskUI();
        end

        function context = executeTask(this, context, ~)
            arguments
                this
                context containers.Map
                ~
            end

            context = kssolv.services.workflow.module.computation. ...
                SCFTask.executeWithOptions( ...
                context, this.getExecutionOptions());
        end
    end

    methods (Static)
        function context = executeWithOptions(context, taskOptions)
            arguments
                context containers.Map
                taskOptions (1, 1) struct
            end

            SCFOptions = options.SCF();
            fields = fieldnames(taskOptions);
            for i = 1:length(fields)
                fieldName = fields{i};
                SCFOptions.(fieldName) = taskOptions.(fieldName);
            end

            [molecule, H, X, info] = scf(context("molecule"), SCFOptions);

            context("molecule") = molecule;
            context("H") = H;
            context("X") = X;
            context("info") = info;
            context("SCFOptions") = SCFOptions;
        end
    end
end
