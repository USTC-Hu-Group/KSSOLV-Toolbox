classdef StandaloneWorkerRuntimeTest < matlab.unittest.TestCase
    properties
        Archive string
        Cache string
    end

    methods (TestClassSetup)
        function buildProtectedRuntime(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture());
            [testCase.Archive, cleanup] = ...
                kssolv.services.remote.execution.StandaloneWorkerRuntime.stage( ...
                KSSOLV_Toolbox.RootDirectory, fixture.Folder);
            testCase.addTeardown(@()delete(cleanup));
            testCase.Cache = fullfile(fixture.Folder, 'cache');
        end
    end

    methods (Test)
        function protectedFilesExecuteInAnIsolatedMatlab(testCase)
            root = kssolv.services.remote.execution.StandaloneWorkerRuntime.resolve( ...
                Archive=testCase.Archive, CacheRoot=testCase.Cache);
            testCase.verifyEmpty(dir(fullfile(root, '**', '*.m')));
            resultFile = fullfile(testCase.Cache, 'isolated-result.mat');
            quote = @(s) "'" + replace(string(s), "'", "''") + "'";
            code = "restoredefaultpath; cd(" + quote(root) + "); " + ...
                "addpath(" + quote(root) + "); assert(~usejava('jvm')); " + ...
                "assert(endsWith(string(which('KSSOLV_Toolbox')),'.p')); " + ...
                "addpath(fullfile(pwd,'+kssolv','+core','kssolv-3o')); KSSOLV.startup(); " + ...
                "graph=kssolv.services.workflow.WorkflowGraph({}); " + ...
                "snapshot=kssolv.services.remote.execution.WorkflowSnapshotBuilder.build(graph,'Protected worker'); " + ...
                "envelope=kssolv.services.remote.execution.RemoteWorkflowRunner.execute(snapshot); " + ...
                "save(" + quote(resultFile) + ",'envelope','-v7');";
            executable = fullfile(matlabroot, 'bin', 'matlab');
            shellQuote = @(s) "'" + replace(string(s), "'", "'" + char(34) + "'" + char(34) + "'") + "'";
            [status, output] = system(char(shellQuote(executable) + ...
                " -nojvm -batch " + shellQuote(code)));
            testCase.assertEqual(status, 0, output);
            data = load(resultFile, 'envelope');
            testCase.verifyEqual(data.envelope.WorkflowName, "Protected worker");
        end

        function reusesAndRepairsCachedProtectedRuntime(testCase)
            root = kssolv.services.remote.execution.StandaloneWorkerRuntime.resolve( ...
                Archive=testCase.Archive, CacheRoot=testCase.Cache);
            marker = fullfile(root, 'test-cache-marker');
            writelines('retained', marker);
            second = kssolv.services.remote.execution.StandaloneWorkerRuntime.resolve( ...
                Archive=testCase.Archive, CacheRoot=testCase.Cache);
            testCase.verifyEqual(root, second);
            testCase.verifyTrue(isfile(marker));
            delete(fullfile(root, 'KSSOLV_Toolbox.p'));
            repaired = kssolv.services.remote.execution.StandaloneWorkerRuntime.resolve( ...
                Archive=testCase.Archive, CacheRoot=testCase.Cache);
            testCase.verifyEqual(root, repaired);
            testCase.verifyTrue(isfile(fullfile(repaired, 'KSSOLV_Toolbox.p')));
        end

        function rejectsMissingArchive(testCase)
            testCase.verifyError(@() ...
                kssolv.services.remote.execution.StandaloneWorkerRuntime.resolve( ...
                Archive=testCase.Archive + '.missing', CacheRoot=testCase.Cache), ...
                'KSSOLV:Remote:WorkerRuntimeMissing');
        end
    end
end
