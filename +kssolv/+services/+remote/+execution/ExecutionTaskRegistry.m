classdef ExecutionTaskRegistry
    %EXECUTIONTASKREGISTRY Tasks that have a headless execution entry.

    methods (Static)
        function names = headlessTaskClasses()
            names = [ ...
                "kssolv.services.workflow.module.computation.BuildMoleculeTask"
                "kssolv.services.workflow.module.computation.SCFTask"
                "kssolv.services.workflow.module.computation.NSCFTask"
                "kssolv.services.workflow.module.computation.RelaxationTask"
                "kssolv.services.workflow.module.computation.TDDFTTask"
                "kssolv.services.workflow.module.preprocessing.SymmetryAnalysisTask"
                "kssolv.services.workflow.module.postprocessing.BandProcessingTask"
                "kssolv.services.workflow.module.postprocessing.BandProcessing3DTask"
                "kssolv.services.workflow.module.visualization.DOSTask"];
        end

        function value = supports(task)
            value = any(string(class(task)) == ...
                kssolv.services.remote.execution.ExecutionTaskRegistry. ...
                headlessTaskClasses());
        end

        function value = requiresLocalPresentation(task)
            taskClass = string(class(task));
            value = task.module == ...
                kssolv.services.workflow.module.ModuleType.Visualization;
            if taskClass == ...
                    "kssolv.services.workflow.module.visualization.DOSTask"
                value = true;
            end
        end

        function context = execute(taskClass, context, options)
            if ~any(string(taskClass) == ...
                    kssolv.services.remote.execution.ExecutionTaskRegistry. ...
                    headlessTaskClasses())
                error("KSSOLV:Remote:UnsupportedHeadlessTask", ...
                    "Task class %s has no headless execution entry.", ...
                    taskClass);
            end
            functionHandle = str2func(string(taskClass) + ...
                ".executeWithOptions");
            context = functionHandle(context, options);
        end
    end
end
