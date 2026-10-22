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

        function context = execute(taskClass, context, options, resources)
            arguments
                taskClass (1, 1) string
                context containers.Map
                options (1, 1) struct
                resources (1, 1) struct = kssolv.services.workflow.ExecutionResources.defaults()
            end
            if ~any(string(taskClass) == ...
                    kssolv.services.remote.execution.ExecutionTaskRegistry. ...
                    headlessTaskClasses())
                error("KSSOLV:Remote:UnsupportedHeadlessTask", ...
                    "Task class %s has no headless execution entry.", ...
                    taskClass);
            end
            functionHandle = str2func(string(taskClass) + ...
                ".executeWithOptions");
            validationOptions = options;
            if kssolv.services.workflow.ExecutionResources.usesNSCF(taskClass) && ...
                    isKey(context, 'NSCFOptions')
                validationOptions = kssolv.services.workflow.ExecutionResources. ...
                    effectiveOptions(taskClass, options, context('NSCFOptions'));
            end
            resources = kssolv.services.workflow.ExecutionResources. ...
                validate(resources, taskClass, validationOptions);
            if kssolv.services.workflow.ExecutionResources.supportsProcessPool(taskClass) || ...
                    taskClass == "kssolv.services.workflow.module.computation.SCFTask"
                context = functionHandle(context, options, resources);
            else
                context = functionHandle(context, options);
            end
        end
    end
end
