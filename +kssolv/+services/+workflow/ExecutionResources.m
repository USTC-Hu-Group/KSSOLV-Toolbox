classdef ExecutionResources
    %EXECUTIONRESOURCES Bounded process pools and GPU workflow calculations.
    % ThreadCount limits computational threads per worker, not thread workers.

    methods (Static)
        function migrateLegacyChoices(item)
            % Compatibility entry point for previously saved function handles.
            kssolv.services.filemanager.internal.migrateWorkflowResources(item);
        end

        function value = defaults()
            value = struct('ParallelType', 'None', ...
                'ProcessCount', 2, 'ThreadCount', 1);
        end

        function value = supportsProcessPool(taskClass)
            % Process-pool support; GPU support is method dependent.
            value = kssolv.services.workflow.ExecutionResources.usesNSCF(taskClass) || ...
                string(taskClass) == "kssolv.services.workflow.module.computation.NSCFTask";
        end

        function value = usesNSCF(taskClass)
            value = any(string(taskClass) == [ ...
                "kssolv.services.workflow.module.postprocessing.BandProcessingTask"
                "kssolv.services.workflow.module.postprocessing.BandProcessing3DTask"
                "kssolv.services.workflow.module.visualization.DOSTask"]);
        end

        function values = allowedTypes(taskClass, taskOptions)
            arguments
                taskClass (1, 1) string
                taskOptions (1, 1) struct = struct()
            end
            values = {'None'};
            isConsumer = kssolv.services.workflow.ExecutionResources.usesNSCF(taskClass);
            isNSCF = taskClass == "kssolv.services.workflow.module.computation.NSCFTask";
            if isConsumer
                values{end + 1} = 'Inherit';
            end
            usesHT = isfield(taskOptions, 'HT') && taskOptions.HT && ...
                taskClass ~= "kssolv.services.workflow.module.postprocessing.BandProcessing3DTask";
            if kssolv.services.workflow.ExecutionResources.supportsProcessPool(taskClass) && ~usesHT
                values{end + 1} = 'Processes';
            end
            method = "davidson_qe";
            if isNSCF || isConsumer
                method = "lobpcg";
            end
            if isfield(taskOptions, 'eigmethod')
                method = string(taskOptions.eigmethod);
            end
            % SCF and NSCF share the same updateX GPU branches.
            if (taskClass == "kssolv.services.workflow.module.computation.SCFTask" || ...
                    isNSCF || isConsumer) && ~usesHT && any(method == ...
                    ["lobpcg", "davidson", "davidson2", "davpcg"])
                values{end + 1} = 'GPU';
            end
        end

        function value = validate(value, taskClass, taskOptions)
            arguments
                value
                taskClass (1, 1) string
                taskOptions (1, 1) struct = struct()
            end
            required = {'ParallelType', 'ProcessCount', 'ThreadCount'};
            if ~isstruct(value) || ~isscalar(value) || ...
                    ~all(isfield(value, required)) || ...
                    ~(ischar(value.ParallelType) || isstring(value.ParallelType)) || ...
                    ~isscalar(string(value.ParallelType)) || ...
                    ~any(string(value.ParallelType) == ["None", "Processes", "GPU", "Inherit"])
                error('KSSOLV:Workflow:InvalidExecutionResources', ...
                    'Select serial, process-pool parallel, or supported GPU execution.');
            end
            for name = ["ProcessCount", "ThreadCount"]
                count = value.(name);
                if ~isnumeric(count) || ~isreal(count) || ~isscalar(count) || ...
                        ~isfinite(count) || count < 1 || fix(count) ~= count
                    error('KSSOLV:Workflow:InvalidExecutionResources', ...
                        '%s must be a finite positive integer.', name);
                end
                value.(name) = double(count);
            end
            value.ParallelType = char(value.ParallelType);
            if ~ismember(value.ParallelType, ...
                    kssolv.services.workflow.ExecutionResources.allowedTypes(taskClass, taskOptions))
                error('KSSOLV:Workflow:ParallelNotSupported', ...
                    'Task %s does not support %s execution with these options.', ...
                    taskClass, value.ParallelType);
            end
        end

        function value = effectiveOptions(taskClass, taskOptions, nscfOptions)
            % Consumers use the diagonalizer configured by the NSCF node.
            value = taskOptions;
            if kssolv.services.workflow.ExecutionResources.usesNSCF(taskClass)
                value.eigmethod = 'lobpcg';
                value.HT = false;
                for name = ["eigmethod", "HT"]
                    if (isstruct(nscfOptions) && isfield(nscfOptions, name)) || ...
                            (isobject(nscfOptions) && isprop(nscfOptions, name))
                        value.(name) = nscfOptions.(name);
                    end
                end
                if string(taskClass) == ...
                        "kssolv.services.workflow.module.postprocessing.BandProcessing3DTask"
                    value.HT = false; % This node calls nscf directly.
                end
            end
        end

        function [taskOptions, inherited, sourceTask] = nodeOptions(graph, nodeID)
            node = graph.Nodes(nodeID);
            taskOptions = node.task.getExecutionOptions();
            inherited = kssolv.services.workflow.ExecutionResources.defaults();
            sourceTask = [];
            if ~kssolv.services.workflow.ExecutionResources.usesNSCF(class(node.task))
                return
            end
            % Match the runner's shared context and execution order.
            nscfOptions = struct();
            try
                ids = kssolv.services.workflow.codegeneration.CodeGenerator.topologicalSort(graph);
            catch
                ids = {}; % Keep configuration editable while a graph has cycles.
            end
            for index = 1:numel(ids)
                if strcmp(ids{index}, nodeID)
                    break
                end
                candidate = graph.Nodes(ids{index}).task;
                if isa(candidate, 'kssolv.services.workflow.module.computation.NSCFTask')
                    sourceTask = candidate;
                    nscfOptions = candidate.getExecutionOptions();
                    inherited = struct('ParallelType', candidate.usedParallelType, ...
                        'ProcessCount', candidate.parallelProcessCount, ...
                        'ThreadCount', candidate.parallelThreadCount);
                end
            end
            taskOptions = kssolv.services.workflow.ExecutionResources. ...
                effectiveOptions(class(node.task), taskOptions, nscfOptions);
        end

        function [value, cleanup] = prepareNSCF(context, taskClass, taskOptions, resources)
            source = context('NSCFOptions');
            taskOptions = kssolv.services.workflow.ExecutionResources. ...
                effectiveOptions(taskClass, taskOptions, source);
            if strcmp(resources.ParallelType, 'Inherit')
                resources = kssolv.services.workflow.ExecutionResources.defaults();
                if isKey(context, 'NSCFResources')
                    resources = context('NSCFResources');
                end
            end
            [cleanup, ~] = kssolv.services.workflow.ExecutionResources. ...
                prepare(resources, taskClass, taskOptions);
            % Rebuild flags on a fresh object: the core's GPU setter cannot
            % clear an already-enabled flag. Preserve all other public state.
            value = options.NSCF();
            metadata = metaclass(source);
            for index = 1:numel(metadata.PropertyList)
                property = metadata.PropertyList(index);
                if strcmp(property.SetAccess, 'public') && ~property.Constant && ...
                        ~property.Dependent && ~ismember(property.Name, ...
                        {'enableGPU', 'enableParallelPool'})
                    value.(property.Name) = source.(property.Name);
                end
            end
            value.enableGPU = strcmp(resources.ParallelType, 'GPU');
            value.enableParallelPool = strcmp(resources.ParallelType, 'Processes');
            if value.enableGPU ~= strcmp(resources.ParallelType, 'GPU') || ...
                    value.enableParallelPool ~= strcmp(resources.ParallelType, 'Processes')
                error('KSSOLV:Workflow:ParallelUnavailable', ...
                    'The requested NSCF execution environment could not be enabled.');
            end
        end

        function [cleanup, enabled] = prepare(value, taskClass, taskOptions)
            arguments
                value (1, 1) struct
                taskClass (1, 1) string
                taskOptions (1, 1) struct = struct()
            end
            value = kssolv.services.workflow.ExecutionResources. ...
                validate(value, taskClass, taskOptions);
            enabled = strcmp(value.ParallelType, 'Processes');
            cleanup = [];
            if strcmp(value.ParallelType, 'Inherit')
                error('KSSOLV:Workflow:NSCFContextRequired', ...
                    'Resolve inherited resources using the NSCF execution context.');
            end
            if strcmp(value.ParallelType, 'None')
                return
            end
            if strcmp(value.ParallelType, 'GPU')
                if exist('canUseGPU', 'file') == 0 || ~canUseGPU()
                    error('KSSOLV:Workflow:GPUUnavailable', ...
                        ['GPU execution requires a supported GPU and ' ...
                        'Parallel Computing Toolbox on the execution machine.']);
                end
                previousThreads = maxNumCompThreads(value.ThreadCount);
                cleanup = onCleanup(@() maxNumCompThreads(previousThreads));
                return
            end
            if exist('gcp', 'file') == 0 || ...
                    ~license('test', 'Distrib_Computing_Toolbox')
                error('KSSOLV:Workflow:ParallelUnavailable', ...
                    'Parallel execution requires Parallel Computing Toolbox.');
            end

            pool = gcp('nocreate');
            ownedPool = [];
            if isempty(pool)
                if ~isempty(getCurrentTask())
                    error('KSSOLV:Workflow:RemotePoolRequired', ...
                        ['Submit the remote job with a process pool whose ' ...
                        'size and threads fit this node''s resource limits.']);
                end
                cluster = parcluster('Processes');
                if value.ProcessCount > cluster.NumWorkers
                    error('KSSOLV:Workflow:ProcessLimitExceeded', ...
                        'Requested %d workers; the local profile permits %d.', ...
                        value.ProcessCount, cluster.NumWorkers);
                end
                cluster.NumThreads = value.ThreadCount;
                pool = parpool(cluster, value.ProcessCount);
                ownedPool = pool;
            elseif isa(pool, 'parallel.ThreadPool') || ...
                    pool.NumWorkers > value.ProcessCount
                error('KSSOLV:Workflow:PoolResourceConflict', ...
                    ['The existing pool exceeds this node''s process limit ' ...
                    'or uses thread workers. Close it or adjust the node limits.']);
            end

            % Own only pools created here; never resize or delete a user pool.
            poolCleanup = onCleanup(@() releasePool(ownedPool));
            actualThreads = fetchOutputs(parfevalOnAll( ...
                pool, @maxNumCompThreads, 1));
            if any(actualThreads > value.ThreadCount)
                error('KSSOLV:Workflow:PoolResourceConflict', ...
                    ['The existing pool exceeds this node''s threads-per-process ' ...
                    'limit. Close it or adjust the node limits.']);
            end
            previousThreads = maxNumCompThreads(value.ThreadCount);
            cleanup = onCleanup(@() restoreResources(poolCleanup, previousThreads));
        end
    end
end

function releasePool(pool)
if ~isempty(pool) && isvalid(pool)
    delete(pool);
end
end

function restoreResources(poolCleanup, previousThreads)
maxNumCompThreads(previousThreads);
delete(poolCleanup);
end
