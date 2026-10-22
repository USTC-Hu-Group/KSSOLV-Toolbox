classdef DOSTask < kssolv.services.workflow.module.AbstractTask
    %DOSTASK 态密度计算任务

    %   开发者：杨柳
    %   版权 2025 合肥瀚海量子科技有限公司

    properties (Constant)
        TASK_NAME = 'DOS'
        IDENTIFIER = 'DOSTask'
        DESCRIPTION = 'Calculate and plot the Density of States (DOS)'
    end

    methods (Access = protected)
        function this = setup(this)
            this.module = kssolv.services.workflow.module.ModuleType.Visualization;
            this.requiredTasks = ['SCFTask', 'NSCFTask'];
            this.supportGPU = true;
            this.usedParallelType = 'Inherit';
            this.supportParallel = true;
        end
    end

    methods
        function setupOptionsUI(this)
            % 该 Task 使用 DOSTaskUI
            this.optionsUI = kssolv.services.workflow.module.visualization.DOSTaskUI();
        end

        function context = executeTask(this, context, ~)
            arguments
                this
                context containers.Map
                ~
            end

            context = kssolv.services.workflow.module.visualization. ...
                DOSTask.executeWithOptions( ...
                context, this.getExecutionOptions(), this.getExecutionResources());
            kssolv.services.workflow.module.visualization. ...
                DOSTask.presentWithContext(context);
        end
    end

    methods (Static)
        function context = executeWithOptions(context, taskOptions, resources)
            arguments
                context containers.Map
                taskOptions (1, 1) struct
                resources (1, 1) struct = kssolv.services.workflow.ExecutionResources.defaults()
            end
            [NSCFOptions, resourceCleanup] = ...
                kssolv.services.workflow.ExecutionResources.prepareNSCF( ...
                context, 'kssolv.services.workflow.module.visualization.DOSTask', ...
                taskOptions, resources); %#ok<ASGLU>
            crystal = copy(context("molecule"));
            NSCFOptions.rho0 = context("H").rho;
            energyBands = eband(crystal, NSCFOptions, ...
                taskOptions.NSCFGrid);
            energyRange = taskOptions.startEnergy:taskOptions.stepSize: ...
                taskOptions.endEnergy;
            dos = zeros(1, numel(energyRange));
            tetra = Tetrahedra(crystal.nkxyz);
            for index = 1:numel(energyRange)
                dos(index) = tetra.computeTDOS( ...
                    crystal, energyBands, energyRange(index));
            end
            context("NSCFOptions") = NSCFOptions;
            context("DOS") = struct("dos", dos, ...
                "energyRange", energyRange);
        end

        function presentWithContext(context)
            arguments
                context containers.Map
            end
            data = context("DOS");
            DOSPlot = kssolv.services.workflow.module.visualization.chart. ...
                DOSPlot("dos", data.dos, ...
                "energyRange", data.energyRange);
            resultsItem = ...
                kssolv.services.filemanager.Results.getResultsItem();
            plotTag = resultsItem.addPlot(copy(DOSPlot), ...
                "Density of States (DOS)");
            projectBrowser = ...
                kssolv.ui.util.DataStorage.getData("ProjectBrowser");
            projectBrowser.refreshUIAfterItemCreation( ...
                resultsItem.plotsItem);
            dataPlot = kssolv.ui.components.figuredocument.DataPlot( ...
                DOSPlot, plotTag);
            dataPlot.Display("Density of States (DOS)");
        end
    end
end
