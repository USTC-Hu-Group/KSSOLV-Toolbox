classdef WorkflowExecutionResourcesTest < matlab.unittest.TestCase
    methods (Test)
        function destroyedBrowsersReleaseTaskAndSourceListeners(testCase)
            for deleteBrowser = [false, true]
                [browser, ~, ~, ~] = createBrowser(testCase);
                graph = nscfConsumerGraph();
                source = graph.Nodes('nscf').task;
                consumer = graph.Nodes('band').task;
                browser.configureNode(graph, 'band');
                figure = browser.Figure;
                if deleteBrowser
                    delete(browser);
                    delete(figure);
                else
                    % Native AppContainer teardown can destroy the figure
                    % while DataStorage still holds the browser object.
                    delete(figure);
                end
                consumer.taskUICreated = false;
                consumer.resetOptionsUI();
                testCase.verifyWarningFree(@() change( ...
                    source.optionsUI.widgets.eigMethodValueDropdown, 'eigs'));
                testCase.verifyWarningFree(@() change( ...
                    consumer.optionsUI.widgets.numInterpolationPointsValueSpinner, 5));
            end
        end

        function resourceChoicesFollowNodeCapabilitiesAndPersist(testCase)
            [browser, mode, processes, threads] = createBrowser(testCase);
            graph = singleNodeGraph();
            task = kssolv.services.workflow.module.postprocessing.BandProcessingTask();
            node = graph.Nodes('node');
            node.task = task;
            browser.configureNode(graph, 'node');
            testCase.verifyEqual(mode.ItemsData, {'None', 'Inherit', 'Processes', 'GPU'});
            testCase.verifyEqual(mode.Value, 'Inherit');
            testCase.verifyEqual(string(processes.Enable), "off");
            change(mode, 'Processes');
            change(processes, 3);
            change(threads, 2);
            testCase.verifyEqual(task.getExecutionResources(), ...
                struct('ParallelType', 'Processes', 'ProcessCount', 3, 'ThreadCount', 2));

            node = graph.Nodes('node');
            node.task = ...
                kssolv.services.workflow.module.computation.BuildMoleculeTask();
            browser.configureNode(graph, 'node');
            testCase.verifyEqual(mode.ItemsData, {'None'});
            testCase.verifyEqual(mode.Value, 'None');
            testCase.verifyEqual(string(mode.Enable), "off");
            testCase.verifyEqual(string(processes.Enable), "off");
            testCase.verifyEqual(string(threads.Enable), "off");

            node = graph.Nodes('node');
            node.task = task;
            browser.configureNode(graph, 'node');
            testCase.verifyEqual(mode.Value, 'Processes');
            testCase.verifyEqual(processes.Value, 3);
            testCase.verifyEqual(threads.Value, 2);
        end

        function gpuChoiceUpdatesWhenTheScfMethodChanges(testCase)
            [browser, mode, processes, threads] = createBrowser(testCase);
            graph = singleNodeGraph();
            task = graph.Nodes('node').task;
            browser.configureNode(graph, 'node');
            testCase.verifyEqual(mode.ItemsData, {'None'});
            diagonalizer = task.optionsUI.widgets.eigMethodValueDropdown;
            change(diagonalizer, 'lobpcg');
            testCase.verifyEqual(mode.ItemsData, {'None', 'GPU'});
            change(mode, 'GPU');
            testCase.verifyEqual(task.usedParallelType, 'GPU');
            testCase.verifyEqual(string(processes.Enable), "off");
            testCase.verifyEqual(string(threads.Enable), "on");
            change(diagonalizer, 'davidson');
            testCase.verifyEqual(mode.Value, 'GPU');
            change(diagonalizer, 'ppcg');
            testCase.verifyEqual(mode.ItemsData, {'None'});
            testCase.verifyEqual(mode.Value, 'None');
            testCase.verifyEqual(task.usedParallelType, 'None');
            testCase.verifyEqual(string(threads.Enable), "off");
        end

        function nscfGpuAndInheritedConsumerChoicesFollowTheEffectiveMethod(testCase)
            [browser, mode, processes, threads] = createBrowser(testCase);
            graph = nscfConsumerGraph();
            source = graph.Nodes('nscf').task;
            consumer = graph.Nodes('band').task;
            browser.configureNode(graph, 'nscf');
            testCase.verifyEqual(mode.ItemsData, {'None', 'Processes', 'GPU'});
            change(mode, 'GPU');
            change(threads, 2);
            browser.configureNode(graph, 'band');
            testCase.verifyEqual(mode.Value, 'Inherit');
            testCase.verifyEqual(threads.Value, 2);
            testCase.verifyEqual(string(threads.Enable), "off");
            testCase.verifyEqual(string(processes.Enable), "off");
            change(mode, 'GPU');
            testCase.verifyEqual(consumer.usedParallelType, 'GPU');
            % The selected consumer also listens to its NSCF parameter source.
            change(source.optionsUI.widgets.eigMethodValueDropdown, 'eigs');
            testCase.verifyEqual(mode.ItemsData, {'None', 'Processes'});
            testCase.verifyEqual(consumer.usedParallelType, 'None');
            browser.configureNode(graph, 'nscf');
            testCase.verifyEqual(source.usedParallelType, 'None');
            change(source.optionsUI.widgets.eigMethodValueDropdown, 'lobpcg');
            change(mode, 'GPU');
            change(source.optionsUI.widgets.HTCheckbox, true);
            testCase.verifyEqual(mode.ItemsData, {'None'});
            testCase.verifyEqual(source.usedParallelType, 'None');
            browser.configureNode(graph, 'band');
            testCase.verifyEqual(mode.ItemsData, {'None', 'Inherit'});
        end
    end
end

function [browser, mode, processes, threads] = createBrowser(testCase)
browser = kssolv.ui.components.databrowser.ConfigBrowser();
mode = findall(browser.Figure, 'Tag', 'WorkflowParallelType');
processes = findall(browser.Figure, 'Tag', 'WorkflowParallelProcessCount');
threads = findall(browser.Figure, 'Tag', 'WorkflowParallelThreadCount');
testCase.assertNumElements(mode, 1);
figure = ancestor(mode, 'figure');
testCase.addTeardown(@() delete(figure));
testCase.addTeardown(@() delete(browser));
end

function graph = singleNodeGraph()
graph = kssolv.services.workflow.WorkflowGraph({struct( ...
    'shape', 'dag-node', 'id', 'node', ...
    'data', struct('label', 'Node', 'status', 'default'))});
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

function change(widget, value)
widget.Value = value;
widget.ValueChangedFcn(widget, struct('Value', value));
end
