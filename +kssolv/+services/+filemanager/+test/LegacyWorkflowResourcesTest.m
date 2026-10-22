classdef LegacyWorkflowResourcesTest < matlab.unittest.TestCase
    properties (TestParameter)
        extension = {'ks', 'wf'}
    end

    methods (Test)
        function importsLegacyChoicesBeforeOpeningAnyNode(testCase, extension)
            project = kssolv.services.filemanager.Project();
            item = kssolv.services.filemanager.Workflow('Legacy resources');
            nodes = {struct('id', 'a', 'shape', 'dag-node', ...
                'data', struct('label', 'Old thread choice', 'status', 'default')), ...
                struct('id', 'b', 'shape', 'dag-node', ...
                'data', struct('label', 'Process choice', 'status', 'default'))};
            item.graphJSON = jsonencode(struct('cells', {nodes}));
            oldNode = item.graph.Nodes('a');
            oldNode.task.usedParallelType = 'Threads';
            oldNode.task.parallelThreadCount = 3;
            oldNode.task.executionTimeLimit = '1 hour';
            processNode = item.graph.Nodes('b');
            processNode.task = kssolv.services.workflow.module.postprocessing.BandProcessingTask();
            processNode.task.usedParallelType = 'Processes';
            processNode.task.parallelProcessCount = 4;
            processNode.task.parallelThreadCount = 2;
            nested = kssolv.services.filemanager.Workflow('Nested', 'Folder');
            project.children{1}.addChildrenItem(nested);
            nested.addChildrenItem(item);

            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            file = fullfile(folder, ['legacy.', extension]);
            if strcmp(extension, 'ks')
                project.saveToKsFile(file);
                restored = kssolv.services.filemanager.Project.loadKsFile(file);
                restored = restored.findChildrenItem(item.name);
            else
                item.saveToWfFile(file);
                restored = kssolv.services.filemanager.Workflow.loadWfFile(file);
            end
            testCase.verifyEqual(oldNode.task.usedParallelType, 'Threads');
            testCase.verifyEqual(restored.graphJSON, item.graphJSON);
            migrated = restored.graph.Nodes('a').task;
            testCase.verifyFalse(migrated.taskUICreated);
            testCase.verifyEmpty(migrated.optionsUI.widgets);
            testCase.verifyEqual(migrated.usedParallelType, 'None');
            testCase.verifyEqual(migrated.parallelThreadCount, 3);
            testCase.verifyEqual(migrated.executionTimeLimit, '1 hour');
            % Remote submission and execution validation must work before
            % ConfigBrowser has ever normalized these imported nodes.
            snapshot = kssolv.services.remote.execution.WorkflowSnapshotBuilder. ...
                build(restored.graph);
            testCase.verifyEqual(snapshot.RemoteTasks(1).Resources.ParallelType, 'None');
            testCase.verifyEqual(snapshot.RemoteTasks(2).Resources, ...
                struct('ParallelType', 'Processes', 'ProcessCount', 4, 'ThreadCount', 2));
        end
    end
end
