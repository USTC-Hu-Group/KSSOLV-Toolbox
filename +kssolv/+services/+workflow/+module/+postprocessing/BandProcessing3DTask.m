classdef BandProcessing3DTask < kssolv.services.workflow.module.AbstractTask
    %BANDPROCESSING3DTASK 三维能带计算任务

    %   开发者：杨柳
    %   版权 2025 合肥瀚海量子科技有限公司

    properties (Constant)
        TASK_NAME = 'Band Calculation 3D'
        IDENTIFIER = 'BandProcessing3DTask'
        DESCRIPTION = 'K-point path interpolation and NSCF calculation'
    end

    methods (Access = protected)
        function this = setup(this)
            this.module = kssolv.services.workflow.module.ModuleType.Postprocessing;
            this.requiredTasks = ['SCFTask', 'NSCFTask'];
            this.supportGPU = false;
            this.supportParallel = true;
        end
    end

    methods
        function setupOptionsUI(this)
            this.optionsUI = kssolv.services.workflow.module.postprocessing.BandProcessing3DTaskUI();
        end

        function context = executeTask(this, context, ~)
            arguments
                this
                context containers.Map
                ~
            end

            context = kssolv.services.workflow.module.postprocessing. ...
                BandProcessing3DTask.executeWithOptions( ...
                context, this.getExecutionOptions());
        end
    end

    methods (Static)
        function context = executeWithOptions(context, taskOptions)
            arguments
                context containers.Map
                taskOptions (1, 1) struct
            end

            % 获取 UI 中设置的参数
            sliceGridSpacing = taskOptions.sliceGridSpacing;
            kPoint = taskOptions.centerKPoint;
            gridSize = taskOptions.slicePlaneGrid;

            % 生成二维网格
            [X, Y] = ndgrid(linspace(-sliceGridSpacing * gridSize(1)/2, sliceGridSpacing * gridSize(1)/2, gridSize(1)) + kPoint(1), ...
                linspace(-sliceGridSpacing * gridSize(2)/2, sliceGridSpacing * gridSize(2)/2, gridSize(2)) + kPoint(2));

            % 根据指定平面生成对应的坐标
            switch taskOptions.slicePlane
                case 'XY'
                    kPoints = [X(:), Y(:), kPoint(3) * ones(numel(X), 1)];
                case 'XZ'
                    kPoints = [X(:), kPoint(2) * ones(numel(X), 1), Y(:)];
                case 'YZ'
                    kPoints = [kPoint(1) * ones(numel(X), 1), X(:), Y(:)];
            end

            % 进行能带计算（不使用 HT 方法）
            crystal = copy(context("molecule"));
            NSCFOptions = context("NSCFOptions");
            NSCFOptions.rho0 = context("H").rho;
            NSCFOptions.enableParallelPool = true;
            context("NSCFOptions") = NSCFOptions;

            crystal.set('scfkpts', crystal.kpts, 'kpts', kPoints);
            [crystal, ~, ~, infokpts] = nscf(crystal, NSCFOptions);
            energyBands = reshape(infokpts.Eigvals, crystal.nbnd, []);

            if crystal.nspin == 2
                nk = size(energyBands, 2);
                idx_up = 1:nk/2;
                ebands_up = energyBands(:, idx_up);
                ebands_dw = energyBands(:, idx_up + nk/2);
                energyBands = [ebands_up; ebands_dw];
            end

            % 整理能带数据，转换单位为 eV
            eBands = (energyBands - crystal.efermi) * 27.2;

            context("bandProcessing3D") = struct('kPoints', {kPoints}, 'energyBands', eBands, ...
                'slicePlane', taskOptions.slicePlane);
        end
    end
end
