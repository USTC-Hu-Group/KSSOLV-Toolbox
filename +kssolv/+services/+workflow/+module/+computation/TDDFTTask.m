classdef TDDFTTask < kssolv.services.workflow.module.AbstractTask
    %TDDFTTASK TDDFT 计算任务

    %   开发者：杨柳
    %   版权 2025 合肥瀚海量子科技有限公司

    properties (Constant)
        TASK_NAME = 'TDDFT'
        IDENTIFIER = 'TDDFTTask'
        DESCRIPTION = 'TDDFT computation'
    end

    methods (Access = protected)
        function this = setup(this)
            this.module = kssolv.services.workflow.module.ModuleType.Computation;
            this.requiredTasks = 'BuildMoleculeTask';
            this.supportGPU = true;
            this.supportParallel = false;
        end
    end

    methods
        function setupOptionsUI(this)
            this.optionsUI = kssolv.services.workflow.module.computation.TDDFTTaskUI();
        end

        function context = executeTask(this, context, ~)
            arguments
                this
                context containers.Map
                ~
            end

            context = kssolv.services.workflow.module.computation. ...
                TDDFTTask.executeWithOptions( ...
                context, this.getExecutionOptions());
        end
    end

    methods (Static)
        function context = executeWithOptions(context, taskOptions)
            arguments
                context containers.Map
                taskOptions (1, 1) struct
            end

            TDDFTOptions = tddft_setup(context("molecule"), context("SCFOptions"), ...
                context("H"), context("X"), namedargs2cell(taskOptions));
            [Et, Z] = tddft_casida_direct(TDDFTOptions, context("molecule"));

            % 输出 context
            context("TDDFT") = struct('Et', Et, 'Z', Z);
        end
    end
end
