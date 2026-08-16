classdef WorkflowRemoteTest < matlab.unittest.TestCase
    %WORKFLOWREMOTETEST Headless snapshot and source bundle tests.

    properties
        TemporaryRoot (1, 1) string
    end

    methods (TestMethodSetup)
        function createTemporaryRoot(testCase)
            testCase.TemporaryRoot = string(tempname);
            mkdir(testCase.TemporaryRoot);
        end
    end

    methods (TestMethodTeardown)
        function removeTemporaryRoot(testCase)
            if isfolder(testCase.TemporaryRoot)
                rmdir(testCase.TemporaryRoot, "s");
            end
        end
    end

    methods (Test)
        function emptySnapshotRoundTripsAndRunsHeadlessly(testCase)
            workflow = kssolv.services.workflow.WorkflowGraph({});
            snapshot = kssolv.services.remote.execution.WorkflowSnapshotBuilder. ...
                build(workflow, "Empty workflow", "project:test");
            file = fullfile(testCase.TemporaryRoot, "snapshot.mat");
            save(file, "snapshot");
            restored = load(file, "snapshot");

            envelope = kssolv.services.remote.execution.RemoteWorkflowRunner. ...
                execute(restored.snapshot);

            testCase.verifyEqual(envelope.WorkflowName, "Empty workflow");
            testCase.verifyEqual(envelope.ProjectIdentity, "project:test");
            testCase.verifyEmpty(envelope.RemoteNodeIds);
            testCase.verifyClass(envelope.Context, "containers.Map");
            testCase.verifyEqual(double(envelope.Context.Count), 0);
        end

        function scientificTaskOptionsAreFrozen(testCase)
            workflow = singleNodeWorkflow("scf-node");
            node = workflow.Nodes("scf-node");
            node.task = ...
                kssolv.services.workflow.module.computation.SCFTask();

            snapshot = kssolv.services.remote.execution.WorkflowSnapshotBuilder. ...
                build(workflow, "SCF workflow", "project:test");

            testCase.verifyEqual(numel(snapshot.RemoteTasks), 1);
            testCase.verifyEqual(snapshot.RemoteTasks.ClassName, ...
                "kssolv.services.workflow.module.computation.SCFTask");
            testCase.verifyTrue(isstruct(snapshot.RemoteTasks.Options));
            testCase.verifyEqual(snapshot.RemoteNodeIds, "scf-node");
            testCase.verifyEmpty(snapshot.LocalNodeIds);
        end

        function rejectsLocalToRemoteDependency(testCase)
            graph = twoNodeWorkflowWithEdge("local-node", "remote-node");
            localNode = graph.Nodes("local-node");
            localNode.task = ...
                kssolv.services.workflow.module.visualization. ...
                EnergyConvergenceTask();
            remoteNode = graph.Nodes("remote-node");
            remoteNode.task = ...
                kssolv.services.workflow.module.computation.SCFTask();

            testCase.verifyError(@() ...
                kssolv.services.remote.execution.WorkflowSnapshotBuilder.build(graph), ...
                "KSSOLV:Remote:LocalToRemoteDependency");
        end

        function rejectsWorkerReleaseMismatch(testCase)
            workflow = kssolv.services.workflow.WorkflowGraph({});
            snapshot = kssolv.services.remote.execution.WorkflowSnapshotBuilder. ...
                build(workflow);
            snapshot.MatlabRelease = "R0000z";

            testCase.verifyError(@() ...
                kssolv.services.remote.execution.RemoteWorkflowRunner. ...
                execute(snapshot), ...
                "KSSOLV:Remote:MatlabReleaseMismatch");
        end

        function bundleContainsRuntimeAndExcludesTests(testCase)
            builder = kssolv.services.remote.execution.CodeBundleBuilder( ...
                testCase.TemporaryRoot);
            [archive, firstManifest] = builder.build();
            testCase.verifyTrue(isfile(archive));
            bundle = fullfile(testCase.TemporaryRoot, "extracted");
            unzip(archive, bundle);

            testCase.verifyTrue(isfile(fullfile(bundle, ...
                "KSSOLV_Toolbox.m")));
            testCase.verifyTrue(isfile(fullfile(bundle, ...
                "remote-bundle-manifest.json")));
            testCase.verifyFalse(isfolder(fullfile(bundle, "+kssolv", ...
                "+services", "+remote", "+test")));
            testCase.verifyFalse(isfolder(fullfile(bundle, "+kssolv", ...
                "+core", "kssolv-3o", "test")));
            testCase.verifyFalse(isfolder(fullfile(bundle, "+kssolv", ...
                "+core", "kssolv-3o", "src", "quantum_simulator", ...
                "+kssolv", "+simulator", "+tests")));
            manifest = jsondecode(fileread(fullfile(bundle, ...
                "remote-bundle-manifest.json")));
            testCase.verifyGreaterThan(manifest.FileCount, 0);
            testCase.verifyGreaterThan(manifest.TotalBytes, 0);
            testCase.verifyEqual(strlength(string( ...
                manifest.ContentIndexSha256)), 64);
            [secondArchive, secondManifest] = builder.build();
            testCase.verifyTrue(isfile(secondArchive));
            testCase.verifyEqual(firstManifest.ContentIndexSha256, ...
                secondManifest.ContentIndexSha256);
        end

        function probeBundleContainsOnlyBridgeRuntime(testCase)
            builder = kssolv.services.remote.execution.CodeBundleBuilder( ...
                testCase.TemporaryRoot);
            archive = builder.build("Probe");
            bundle = fullfile(testCase.TemporaryRoot, "probe-extracted");
            unzip(archive, bundle);

            testCase.verifyTrue(isfile(fullfile(bundle, "+kssolv", ...
                "+services", "+remote", ...
                "+bridge", ...
                "RemoteMatlabBridgeEntrypoint.m")));
            testCase.verifyTrue(isfile(fullfile(bundle, "+kssolv", ...
                "+services", "+remote", "+diagnostics", ...
                "remoteProbe.m")));
            testCase.verifyFalse(isfolder(fullfile(bundle, "+kssolv", ...
                "+core")));
        end

        function installedPcodeRuntimeBuildsUploadBundle(testCase)
            runtimeRoot = fullfile(testCase.TemporaryRoot, ...
                "installed-toolbox");
            createRuntimeFixture(runtimeRoot, ".p");
            builder = kssolv.services.remote.execution.CodeBundleBuilder( ...
                fullfile(testCase.TemporaryRoot, "installed-bundles"), ...
                RuntimeRoot=runtimeRoot);
            archive = builder.build();
            bundle = fullfile(testCase.TemporaryRoot, ...
                "installed-extracted");
            unzip(archive, bundle);

            testCase.verifyTrue(isfile(fullfile(bundle, "+kssolv", ...
                "+core", "kssolv-3o", "KSSOLV.p")));
            testCase.verifyTrue(isfile(fullfile(bundle, "+kssolv", ...
                "+services", "+remote", "+execution", ...
                "RemoteWorkflowRunner.p")));
            testCase.verifyEmpty(dir(fullfile(bundle, "+kssolv", ...
                "**", "*.m")));
        end

        function installedPcodeRuntimeBuildsProbeBundle(testCase)
            runtimeRoot = fullfile(testCase.TemporaryRoot, ...
                "installed-probe-toolbox");
            createRuntimeFixture(runtimeRoot, ".p");
            builder = kssolv.services.remote.execution.CodeBundleBuilder( ...
                fullfile(testCase.TemporaryRoot, "installed-probes"), ...
                RuntimeRoot=runtimeRoot);
            archive = builder.build("Probe");
            bundle = fullfile(testCase.TemporaryRoot, ...
                "installed-probe-extracted");
            unzip(archive, bundle);

            testCase.verifyTrue(isfile(fullfile(bundle, "+kssolv", ...
                "+services", "+remote", "+bridge", ...
                "RemoteMatlabBridgeEntrypoint.p")));
            testCase.verifyTrue(isfile(fullfile(bundle, "+kssolv", ...
                "+services", "+remote", "+diagnostics", ...
                "remoteProbe.p")));
        end

        function smallLiHWorkflowRunsScientificallyHeadless(testCase)
            snapshot = kssolv.services.remote.test.smallLiHSnapshot();
            envelope = kssolv.services.remote.execution.RemoteWorkflowRunner. ...
                execute(snapshot);
            info = envelope.Context("info");

            testCase.verifyTrue(info.converge);
            testCase.verifyLessThan(info.SCFerrvec(end), 1e-6);
            testCase.verifyEqual(info.Etotvec(end), ...
                -5.9666002670969, AbsTol=1e-8);
            testCase.verifyEqual(string({envelope.TaskStates.State}).', ...
                ["Finished"; "Finished"]);
        end
    end
end

function createRuntimeFixture(root, extension)
mkdir(root);
writelines("classdef KSSOLV_Toolbox; end", ...
    fullfile(root, "KSSOLV_Toolbox.m"));
relativeFiles = [ ...
    fullfile("+kssolv", "+core", "kssolv-3o", "KSSOLV"), ...
    fullfile("+kssolv", "+analysis", "analysisRuntime"), ...
    fullfile("+kssolv", "+services", "+remote", "+execution", ...
        "RemoteWorkflowRunner"), ...
    fullfile("+kssolv", "+services", "+remote", "+bridge", ...
        "RemoteMatlabBridgeEntrypoint"), ...
    fullfile("+kssolv", "+services", "+remote", "+diagnostics", ...
        "remoteProbe"), ...
    fullfile("+kssolv", "+services", "+workflow", ...
        "workflowRuntime")];
for relativeFile = relativeFiles
    path = fullfile(root, relativeFile + extension);
    folder = fileparts(path);
    if ~isfolder(folder)
        mkdir(folder);
    end
    if extension == ".m"
        [~, name] = fileparts(path);
        writelines("function value = " + name + ...
            "; value = 1; end", path);
    else
        writelines("protected-runtime-fixture", path);
    end
end
dataPath = fullfile(root, "+kssolv", "+core", "kssolv-3o", ...
    "ppdata", "fixture.upf");
mkdir(fileparts(dataPath));
writelines("pseudopotential-fixture", dataPath);
end

function workflow = singleNodeWorkflow(nodeId)
node = struct("shape", "dag-node", "id", char(nodeId), ...
    "data", struct("label", char(nodeId), "status", "default"));
workflow = kssolv.services.workflow.WorkflowGraph({node});
end

function workflow = twoNodeWorkflowWithEdge(sourceId, targetId)
source = struct("shape", "dag-node", "id", char(sourceId), ...
    "data", struct("label", char(sourceId), "status", "default"));
target = struct("shape", "dag-node", "id", char(targetId), ...
    "data", struct("label", char(targetId), "status", "default"));
edge = struct("shape", "dag-edge", ...
    "source", struct("cell", char(sourceId)), ...
    "target", struct("cell", char(targetId)));
workflow = kssolv.services.workflow.WorkflowGraph({source, target, edge});
end
