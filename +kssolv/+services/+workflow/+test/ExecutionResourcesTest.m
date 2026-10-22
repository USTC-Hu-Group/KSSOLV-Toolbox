classdef ExecutionResourcesTest < matlab.unittest.TestCase
    % Run with MATLAB -nojvm; process-pool tests require PCT.

    methods (TestClassSetup)
        function loadCore(testCase)
            oldPath = path;
            testCase.addTeardown(@() path(oldPath));
            root = fileparts(which('KSSOLV_Toolbox'));
            addpath(fullfile(root, '+kssolv', '+core', 'kssolv-3o'));
            KSSOLV.startup();
        end
    end

    methods (Test)
        function serialDoesNotTouchTheExecutionEnvironment(testCase)
            before = maxNumCompThreads;
            resources = kssolv.services.workflow.ExecutionResources.defaults();
            [cleanup, enabled] = kssolv.services.workflow.ExecutionResources. ...
                prepare(resources, 'unknown');
            testCase.verifyFalse(enabled);
            testCase.verifyEmpty(cleanup);
            testCase.verifyEqual(maxNumCompThreads, before);
        end

        function invalidCountsAndUnsupportedModesAreRejected(testCase)
            resources = parallelResources();
            for name = ["ProcessCount", "ThreadCount"]
                for count = {0, -1, 1.5, Inf, NaN, [1 2], '2', 1i}
                    invalid = resources;
                    invalid.(name) = count{1};
                    testCase.verifyError(@() ...
                        kssolv.services.workflow.ExecutionResources. ...
                        validate(invalid, bandClass()), ...
                        'KSSOLV:Workflow:InvalidExecutionResources');
                end
            end
            testCase.verifyError(@() ...
                kssolv.services.workflow.ExecutionResources. ...
                validate(resources, scfClass()), ...
                'KSSOLV:Workflow:ParallelNotSupported');
            resources.ParallelType = 'Threads';
            testCase.verifyError(@() ...
                kssolv.services.workflow.ExecutionResources. ...
                validate(resources, bandClass()), ...
                'KSSOLV:Workflow:InvalidExecutionResources');
        end

        function gpuCapabilityFollowsTheActualDiagonalizer(testCase)
            for taskClass = [string(scfClass()), string(nscfClass()), consumerClasses()]
                for method = ["lobpcg", "davidson", "davidson2", "davpcg"]
                    types = kssolv.services.workflow.ExecutionResources. ...
                        allowedTypes(taskClass, struct('eigmethod', method));
                    testCase.verifyTrue(ismember('GPU', types));
                end
                for method = ["davidson_qe", "eigs", "ppcg"]
                    types = kssolv.services.workflow.ExecutionResources. ...
                        allowedTypes(taskClass, struct('eigmethod', method));
                    testCase.verifyFalse(ismember('GPU', types));
                end
            end
            resources = parallelResources();
            resources.ParallelType = 'GPU';
            testCase.verifyError(@() ...
                kssolv.services.workflow.module.computation.SCFTask. ...
                executeWithOptions(containers.Map(), ...
                struct('eigmethod', 'davidson_qe'), resources), ...
                'KSSOLV:Workflow:ParallelNotSupported');
        end

        function unavailableGpuDoesNotSilentlyRunOnCpu(testCase)
            testCase.assumeFalse(canUseGPU());
            resources = parallelResources();
            resources.ParallelType = 'GPU';
            testCase.verifyError(@() ...
                kssolv.services.workflow.module.computation.SCFTask. ...
                executeWithOptions(containers.Map(), ...
                struct('eigmethod', 'lobpcg'), resources), ...
                'KSSOLV:Workflow:GPUUnavailable');
            for taskClass = [string(nscfClass()), consumerClasses()]
                context = containers.Map();
                context('NSCFOptions') = options.NSCF();
                context('NSCFResources') = resources;
                testCase.verifyError(@() ...
                    kssolv.services.remote.execution.ExecutionTaskRegistry. ...
                    execute(taskClass, context, struct('eigmethod', 'lobpcg'), resources), ...
                    'KSSOLV:Workflow:GPUUnavailable');
                if kssolv.services.workflow.ExecutionResources.usesNSCF(taskClass)
                    inherited = resources;
                    inherited.ParallelType = 'Inherit';
                    testCase.verifyError(@() ...
                        kssolv.services.remote.execution.ExecutionTaskRegistry. ...
                        execute(taskClass, context, struct(), inherited), ...
                        'KSSOLV:Workflow:GPUUnavailable');
                end
            end
        end

        function htDoesNotAdvertiseUnusedParallelPaths(testCase)
            taskOptions = struct('eigmethod', 'lobpcg', 'HT', true);
            for taskClass = [string(nscfClass()), consumerClasses()]
                types = kssolv.services.workflow.ExecutionResources. ...
                    allowedTypes(taskClass, taskOptions);
                directNSCF = endsWith(taskClass, '.BandProcessing3DTask');
                testCase.verifyEqual(ismember('GPU', types), directNSCF);
                testCase.verifyEqual(ismember('Processes', types), directNSCF);
            end
        end

        function nscfResourcesAreDeferredAndCpuOverridesAreIndependent(testCase)
            context = containers.Map();
            resources = parallelResources();
            resources.ThreadCount = 2;
            before = gcp('nocreate');
            context = kssolv.services.remote.execution.ExecutionTaskRegistry. ...
                execute(nscfClass(), context, struct('eigmethod', 'lobpcg'), resources);
            testCase.verifyEqual(gcp('nocreate'), before);
            testCase.verifyEqual(context('NSCFResources'), resources);
            source = context('NSCFOptions');
            source.temp = struct('iterscf', 7, 'sentinel', 42);
            source.exxmethod = 'nscf';
            source.enableParallelPool = true;
            [serial, cleanup] = kssolv.services.workflow.ExecutionResources.prepareNSCF( ...
                context, bandClass(), struct(), ...
                kssolv.services.workflow.ExecutionResources.defaults());
            testCase.verifyEmpty(cleanup);
            testCase.verifyFalse(serial.enableGPU);
            testCase.verifyFalse(serial.enableParallelPool);
            testCase.verifyTrue(source.enableParallelPool);
            testCase.verifyEqual(serial.temp, source.temp);
            testCase.verifyEqual(serial.exxmethod, source.exxmethod);
            source.eigmethod = 'eigs';
            gpu = resources;
            gpu.ParallelType = 'GPU';
            for taskClass = consumerClasses()
                testCase.verifyError(@() ...
                    kssolv.services.workflow.ExecutionResources.prepareNSCF( ...
                    context, taskClass, struct('eigmethod', 'lobpcg'), gpu), ...
                    'KSSOLV:Workflow:ParallelNotSupported');
            end
        end

        function snapshotsValidateInheritedNscfMethods(testCase)
            graph = nscfConsumerGraph();
            source = graph.Nodes('nscf').task;
            source.usedParallelType = 'GPU';
            snapshot = kssolv.services.remote.execution.WorkflowSnapshotBuilder.build(graph);
            testCase.verifyEqual(snapshot.RemoteTasks(1).Resources.ParallelType, 'GPU');
            testCase.verifyEqual(snapshot.RemoteTasks(2).Resources.ParallelType, 'Inherit');
            source.usedParallelType = 'None';
            source.optionsUI.widgets.eigMethodValueDropdown.Value = 'eigs';
            consumer = graph.Nodes('band').task;
            consumer.usedParallelType = 'GPU';
            testCase.verifyError(@() ...
                kssolv.services.remote.execution.WorkflowSnapshotBuilder.build(graph), ...
                'KSSOLV:Workflow:ParallelNotSupported');
            consumer.usedParallelType = 'None';
            kssolv.services.remote.execution.WorkflowSnapshotBuilder.build(graph);
        end

        function snapshotsFreezeResourcesAndValidateThem(testCase)
            graph = singleNodeGraph();
            task = kssolv.services.workflow.module.postprocessing.BandProcessingTask();
            node = graph.Nodes('node');
            node.task = task;
            task.usedParallelType = 'Processes';
            task.parallelProcessCount = 3;
            task.parallelThreadCount = 2;
            snapshot = kssolv.services.remote.execution.WorkflowSnapshotBuilder.build(graph);
            task.parallelProcessCount = 4;
            testCase.verifyEqual(snapshot.RemoteTasks.Resources, ...
                struct('ParallelType', 'Processes', 'ProcessCount', 3, 'ThreadCount', 2));
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            file = fullfile(folder, 'resources.mat');
            save(file, 'snapshot');
            loaded = load(file, 'snapshot');
            testCase.verifyEqual(loaded.snapshot.RemoteTasks.Resources, ...
                snapshot.RemoteTasks.Resources);
            snapshot.RemoteTasks.Resources.ProcessCount = Inf;
            testCase.verifyError(@() ...
                kssolv.services.remote.execution.WorkflowSnapshotBuilder.validate(snapshot), ...
                'KSSOLV:Workflow:InvalidExecutionResources');

            node = graph.Nodes('node');
            node.task = ...
                kssolv.services.workflow.module.computation.SCFTask();
            task = graph.Nodes('node').task;
            task.optionsUI.widgets.eigMethodValueDropdown.Value = 'lobpcg';
            task.usedParallelType = 'GPU';
            snapshot = kssolv.services.remote.execution.WorkflowSnapshotBuilder.build(graph);
            testCase.verifyEqual(snapshot.RemoteTasks.Resources.ParallelType, 'GPU');
            snapshot.RemoteTasks.Options.eigmethod = 'eigs';
            testCase.verifyError(@() ...
                kssolv.services.remote.execution.WorkflowSnapshotBuilder.validate(snapshot), ...
                'KSSOLV:Workflow:ParallelNotSupported');
        end

        function workflowFilesPreserveResourceChoices(testCase)
            item = kssolv.services.filemanager.Workflow();
            item.graph = singleNodeGraph();
            task = kssolv.services.workflow.module.postprocessing.BandProcessing3DTask();
            task.usedParallelType = 'Processes';
            task.parallelProcessCount = 3;
            task.parallelThreadCount = 2;
            node = item.graph.Nodes('node');
            node.task = task;
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            file = fullfile(folder, 'resources.wf');
            item.saveToWfFile(file);
            restored = kssolv.services.filemanager.Workflow.loadWfFile(file);
            restoredTask = restored.graph.Nodes('node').task;
            restoredTask.resetOptionsUI();
            testCase.verifyEqual(restored.graph.Nodes('node').task.getExecutionResources(), ...
                task.getExecutionResources());
        end

        function poolAndThreadLimitsAreEnforcedAndRestored(testCase)
            requireUnusedPool(testCase);
            resources = parallelResources();
            resources.ThreadCount = 2;
            previousThreads = maxNumCompThreads;
            [cleanup, enabled] = kssolv.services.workflow.ExecutionResources. ...
                prepare(resources, bandClass()); %#ok<ASGLU>
            testCase.verifyTrue(enabled);
            pool = gcp('nocreate');
            testCase.verifyEqual(pool.NumWorkers, 2);
            actual = fetchOutputs(parfevalOnAll(pool, @maxNumCompThreads, 1));
            testCase.verifyEqual(actual, [2; 2]);
            testCase.verifyEqual(maxNumCompThreads, 2);

            invalid = resources;
            invalid.ProcessCount = 1;
            testCase.verifyError(@() ...
                kssolv.services.workflow.ExecutionResources.prepare(invalid, bandClass()), ...
                'KSSOLV:Workflow:PoolResourceConflict');
            invalid = resources;
            invalid.ThreadCount = 1;
            testCase.verifyError(@() ...
                kssolv.services.workflow.ExecutionResources.prepare(invalid, bandClass()), ...
                'KSSOLV:Workflow:PoolResourceConflict');
            testCase.verifyTrue(isvalid(pool));
            clear cleanup
            testCase.verifyEmpty(gcp('nocreate'));
            testCase.verifyEqual(maxNumCompThreads, previousThreads);
        end

        function computationFailureCleansUpOwnedPool(testCase)
            requireUnusedPool(testCase);
            previousThreads = maxNumCompThreads;
            failure = [];
            context = containers.Map();
            context('NSCFOptions') = options.NSCF();
            try
                kssolv.services.workflow.module.postprocessing.BandProcessingTask. ...
                    executeWithOptions(context, ...
                    struct('numInterpolationPoints', 3), parallelResources());
            catch exception
                failure = exception;
            end
            testCase.verifyNotEmpty(failure, 'A missing scientific input must fail.');
            testCase.verifyEmpty(gcp('nocreate'));
            testCase.verifyEqual(maxNumCompThreads, previousThreads);
        end

        function realBandAndDosCalculationsAgreeAcrossModes(testCase)
            requireUnusedPool(testCase);
            oldPath = path;
            testCase.addTeardown(@() path(oldPath));
            root = fileparts(which('KSSOLV_Toolbox'));
            addpath(fullfile(root, '+kssolv', '+core', 'kssolv-3o'));
            KSSOLV.startup();
            rng(7);
            envelope = kssolv.services.remote.execution.RemoteWorkflowRunner. ...
                execute(kssolv.services.remote.test.smallLiHSnapshot());
            seed = envelope.Context;
            seed('NSCFOptions') = options.NSCF('eigmethod', 'lobpcg', ...
                'maxcgiter', 60, 'cgtol', 1e-10);
            seed('symmetry') = struct('path', {{'GAMMA', 'X'}}, ...
                'point_coords', containers.Map({'GAMMA', 'X'}, ...
                {[0 0 0], [0.25 0 0]}));
            resources = parallelResources();
            [poolCleanup, ~] = kssolv.services.workflow.ExecutionResources. ...
                prepare(resources, bandClass()); %#ok<ASGLU>
            serial = kssolv.services.workflow.ExecutionResources.defaults();
            seed('NSCFResources') = resources;
            inherited = resources;
            inherited.ParallelType = 'Inherit';
            cases = {
                bandClass(), struct('numInterpolationPoints', 3), 'bandProcessing', 'energyBands'
                'kssolv.services.workflow.module.postprocessing.BandProcessing3DTask', ...
                struct('centerKPoint', [0 0 0], 'slicePlane', 'XY', ...
                'slicePlaneGrid', [2 2], 'sliceGridSpacing', 0.1), 'bandProcessing3D', 'energyBands'
                'kssolv.services.workflow.module.visualization.DOSTask', ...
                struct('NSCFGrid', [2 2 2], 'startEnergy', -2, ...
                'stepSize', 1, 'endEnergy', 2), 'DOS', 'dos'};
            pool = gcp('nocreate');
            for index = 1:size(cases, 1)
                taskClass = cases{index, 1};
                taskOptions = cases{index, 2};
                a = cloneInputs(seed);
                b = cloneInputs(seed);
                rng(9);
                a = kssolv.services.remote.execution.ExecutionTaskRegistry. ...
                    execute(taskClass, a, taskOptions, serial);
                rng(9);
                b = kssolv.services.remote.execution.ExecutionTaskRegistry. ...
                    execute(taskClass, b, taskOptions, inherited);
                resultA = a(cases{index, 3});
                resultB = b(cases{index, 3});
                testCase.verifyEqual(resultA.(cases{index, 4}), ...
                    resultB.(cases{index, 4}), AbsTol=1e-6);
                testCase.verifyFalse(a('NSCFOptions').enableParallelPool);
                testCase.verifyTrue(b('NSCFOptions').enableParallelPool);
                testCase.verifyTrue(isvalid(pool));
            end
            testCase.verifyFalse(seed('NSCFOptions').enableParallelPool);
        end

        function gpuResultsMatchCpuOnSupportedHardware(testCase)
            testCase.assumeTrue(canUseGPU(), 'A supported GPU is required for numerical GPU validation.');
            envelope = kssolv.services.remote.execution.RemoteWorkflowRunner. ...
                execute(kssolv.services.remote.test.smallLiHSnapshot());
            seed = envelope.Context;
            resources = parallelResources();
            resources.ParallelType = 'GPU';
            seed = kssolv.services.remote.execution.ExecutionTaskRegistry. ...
                execute(nscfClass(), seed, struct('eigmethod', 'lobpcg', ...
                'maxcgiter', 60, 'cgtol', 1e-10), resources);
            seed('symmetry') = struct('path', {{'GAMMA', 'X'}}, ...
                'point_coords', containers.Map({'GAMMA', 'X'}, {[0 0 0], [0.25 0 0]}));
            cases = {
                bandClass(), struct('numInterpolationPoints', 3), 'bandProcessing', 'energyBands'
                'kssolv.services.workflow.module.postprocessing.BandProcessing3DTask', ...
                struct('centerKPoint', [0 0 0], 'slicePlane', 'XY', ...
                'slicePlaneGrid', [2 2], 'sliceGridSpacing', 0.1), 'bandProcessing3D', 'energyBands'
                'kssolv.services.workflow.module.visualization.DOSTask', ...
                struct('NSCFGrid', [2 2 2], 'startEnergy', -2, ...
                'stepSize', 1, 'endEnergy', 2), 'DOS', 'dos'};
            inherited = resources;
            inherited.ParallelType = 'Inherit';
            for index = 1:size(cases, 1)
                rng(9);
                cpu = kssolv.services.remote.execution.ExecutionTaskRegistry.execute( ...
                    cases{index, 1}, cloneInputs(seed), cases{index, 2}, ...
                    kssolv.services.workflow.ExecutionResources.defaults());
                rng(9);
                gpu = kssolv.services.remote.execution.ExecutionTaskRegistry.execute( ...
                    cases{index, 1}, cloneInputs(seed), cases{index, 2}, inherited);
                a = cpu(cases{index, 3});
                b = gpu(cases{index, 3});
                testCase.verifyEqual(a.(cases{index, 4}), b.(cases{index, 4}), AbsTol=1e-5);
                testCase.verifyFalse(cpu('NSCFOptions').enableGPU);
                testCase.verifyTrue(gpu('NSCFOptions').enableGPU);
            end
            testCase.verifyTrue(seed('NSCFOptions').enableGPU);
        end
    end
end

function resources = parallelResources()
resources = kssolv.services.workflow.ExecutionResources.defaults();
resources.ParallelType = 'Processes';
end

function value = bandClass()
value = 'kssolv.services.workflow.module.postprocessing.BandProcessingTask';
end

function value = scfClass()
value = 'kssolv.services.workflow.module.computation.SCFTask';
end

function value = nscfClass()
value = 'kssolv.services.workflow.module.computation.NSCFTask';
end

function names = consumerClasses()
names = [string(bandClass()), ...
    "kssolv.services.workflow.module.postprocessing.BandProcessing3DTask", ...
    "kssolv.services.workflow.module.visualization.DOSTask"];
end

function graph = nscfConsumerGraph()
source = struct('shape', 'dag-node', 'id', 'nscf', ...
    'data', struct('label', 'NSCF', 'status', 'default'));
target = source;
target.id = 'band';
edge = struct('shape', 'dag-edge', 'source', struct('cell', 'nscf'), ...
    'target', struct('cell', 'band'));
graph = kssolv.services.workflow.WorkflowGraph({source, target, edge});
node = graph.Nodes('nscf');
node.task = kssolv.services.workflow.module.computation.NSCFTask();
node = graph.Nodes('band');
node.task = kssolv.services.workflow.module.postprocessing.BandProcessingTask();
end

function graph = singleNodeGraph()
graph = kssolv.services.workflow.WorkflowGraph({struct( ...
    'shape', 'dag-node', 'id', 'node', ...
    'data', struct('label', 'Node', 'status', 'default'))});
end

function requireUnusedPool(testCase)
testCase.assumeTrue(logical(license('test', 'Distrib_Computing_Toolbox')));
testCase.assumeEmpty(gcp('nocreate'), 'This test needs an unused process pool.');
end

function context = cloneInputs(source)
context = containers.Map(keys(source), values(source));
context('molecule') = copy(source('molecule'));
context('NSCFOptions') = copy(source('NSCFOptions'));
end
