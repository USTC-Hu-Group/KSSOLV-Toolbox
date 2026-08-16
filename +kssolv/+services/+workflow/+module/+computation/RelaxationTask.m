classdef RelaxationTask < kssolv.services.workflow.module.AbstractTask
    %RELAXATIONTASK 优化已有的结构信息，生成 Molecule/Crystal 类的新实例

    %   开发者：杨柳
    %   版权 2025 合肥瀚海量子科技有限公司

    properties (Constant)
        TASK_NAME = 'Geometry Optimization'
        IDENTIFIER = 'RelaxationTask'
        DESCRIPTION = 'Optimize the structure information of Molecule/Crystal object of KSSOLV'
    end

    methods (Access = protected)
        function this = setup(this)
            this.module = kssolv.services.workflow.module.ModuleType.Computation;
            this.requiredTasks = 'BuildMoleculeTask';
            this.supportGPU = false;
            this.supportParallel = false;
        end
    end

    methods
        function setupOptionsUI(this)
            this.optionsUI = kssolv.services.workflow.module.computation.RelaxationTaskUI();
        end

        function context = executeTask(this, context, ~)
            arguments
                this
                context containers.Map
                ~
            end

            context = kssolv.services.workflow.module.computation. ...
                RelaxationTask.executeWithOptions( ...
                context, this.getExecutionOptions());
        end
    end

    methods (Static)
        function context = executeWithOptions(context, taskOptions)
            arguments
                context containers.Map
                taskOptions (1, 1) struct
            end

            relaxOptions = options.Relaxation();
            fields = fieldnames(taskOptions);
            for i = 1:length(fields)
                fieldName = fields{i};
                relaxOptions.(fieldName) = taskOptions.(fieldName);
            end

            [molecule, H, X, info] = geometryoptimization.relaxatoms(context("molecule"), relaxOptions);

            context("molecule") = molecule;
            context("H") = H;
            context("X") = X;
            context("relaxInfo") = info;
            context("info") = info.lastIonicStepInfo;
        end
    end
end
