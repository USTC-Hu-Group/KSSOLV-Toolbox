classdef WorkflowPersistenceTest < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function isolateSession(testCase)
            storage = @kssolv.ui.util.DataStorage.getData;
            previousProject = storage('Project');
            previousLoading = storage('LoadingKsFile');
            testCase.addTeardown(@() kssolv.ui.util.DataStorage.setData( ...
                'Project', previousProject));
            testCase.addTeardown(@() kssolv.ui.util.DataStorage.setData( ...
                'LoadingKsFile', previousLoading));
            kssolv.ui.util.DataStorage.removeData('LoadingKsFile');
        end
    end

    methods (Test)
        function acceptsSavedAndEmptyCanvasFormats(testCase)
            node = canvasNode();
            for value = {jsonencode(node), jsonencode(struct('cells', node)), ...
                    '[]', '{"cells":[]}'}
                item = kssolv.services.filemanager.Workflow();
                item.graphJSON = value{1};
                expected = uint64(contains(value{1}, 'dag-node'));
                testCase.verifyEqual(item.graph.Nodes.Count, expected);
                item.graphJSON = value{1}; % Also works without a loading flag.
                testCase.verifyEqual(item.graph.Nodes.Count, expected);
            end
            item.graphJSON = '';
            testCase.verifyEqual(item.graphJSON, "");
        end

        function loadingDoesNotCreateReplacementTasks(testCase)
            item = kssolv.services.filemanager.Workflow();
            kssolv.ui.util.DataStorage.setData('LoadingKsFile', true);
            item.graphJSON = jsonencode(struct('cells', canvasNode()));
            testCase.verifyEmpty(item.graph);
        end

        function projectRoundTripRestoresConfigurationBeforeCanvasSync(testCase)
            project = kssolv.services.filemanager.Project();
            kssolv.ui.util.DataStorage.setData('Project', project);
            item = kssolv.services.filemanager.Workflow('Saved workflow');
            item.graphJSON = jsonencode(struct('cells', canvasNode()));
            project.children{1}.addChildrenItem(item);
            node = item.graph.Nodes('saved-node');
            node.task = kssolv.services.workflow.module.computation.RelaxationTask();
            task = node.task;
            spinner = task.optionsUI.widgets.maxRelaxationIterationsSpinner;
            spinner.Value = 73;
            spinner.ValueChangedFcn(spinner, struct('Value', 73));
            task.executionTimeLimit = '1 hour';
            task.parallelThreadCount = 3;
            expectedOptions = task.getExecutionOptions();
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            file = fullfile(folder, 'workflow.ks');
            project.saveToKsFile(file);

            for iteration = 1:2
                project = kssolv.services.filemanager.Project.loadKsFile(file);
                kssolv.ui.util.DataStorage.setData('Project', project);
                restored = project.findChildrenItem(item.name);
                testCase.verifyEqual(restored.graphJSON, item.graphJSON);
                testCase.verifySameHandle(restored.parent, project.children{1});
                task = restored.graph.Nodes('saved-node').task;
                testCase.verifyClass(task, ...
                    'kssolv.services.workflow.module.computation.RelaxationTask');
                testCase.verifyFalse(task.taskUICreated);
                testCase.verifyEmpty(task.optionsUI.widgets);
                testCase.verifyEqual(task.getExecutionOptions(), expectedOptions);
                testCase.verifyEqual(task.executionTimeLimit, '1 hour');
                testCase.verifyEqual(task.parallelThreadCount, 3);

                % Save once more without opening the canvas or its config UI.
                project.saveToKsFile(file);
            end

            browser = kssolv.ui.components.databrowser.ConfigBrowser();
            testCase.addTeardown(@() delete(browser));
            testCase.addTeardown(@() delete(browser.Figure));
            browser.configureNode(restored.graph, 'saved-node');
            testCase.verifyTrue(task.taskUICreated);
            testCase.verifyEqual(task.getExecutionOptions(), expectedOptions);
            panel = task.optionsUI.widgets.accordionPanel1;
            testCase.verifyNotEmpty(panel.Parent);
            testCase.verifyEqual(task.optionsUI.widgets. ...
                maxRelaxationIterationsSpinner.Value, 73);
            % Subsequent canvas exports must preserve the task and controls.
            restored.graphJSON = restored.graphJSON;
            testCase.verifySameHandle(restored.graph.Nodes('saved-node').task, task);
            testCase.verifySameHandle(task.optionsUI.widgets.accordionPanel1, panel);
            testCase.verifyEqual(task.getExecutionOptions(), expectedOptions);
        end
    end
end

function node = canvasNode()
node = struct('id', 'saved-node', 'shape', 'dag-node', ...
    'data', struct('label', 'Saved configuration', 'status', 'default'));
end
