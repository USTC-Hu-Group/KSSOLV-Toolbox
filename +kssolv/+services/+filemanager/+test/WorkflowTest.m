classdef WorkflowTest < matlab.unittest.TestCase
    %WORKFLOWTEST Standalone exports and sketch-to-template contracts.

    properties
        PreviousProject
        Project
        MoleculeItem
    end

    methods (TestMethodSetup)
        function createSketchProject(testCase)
            testCase.PreviousProject = ...
                kssolv.ui.util.DataStorage.getData('Project');
            testCase.Project = kssolv.services.filemanager.Project();
            kssolv.ui.util.DataStorage.setData('Project', testCase.Project);
            folder = testCase.Project.findChildrenItem('Structure');
            testCase.MoleculeItem = folder.createBlankMolecule(false);
            model = testCase.MoleculeItem.data.MatgenlabObject;
            first = kssolv.modeling.CommandExecutor.execute(model, ...
                'add_atom', struct('species', 'H', 'coordinates', [0, 0, 0]));
            second = kssolv.modeling.CommandExecutor.execute(first.model, ...
                'add_atom', struct('species', 'H', 'coordinates', [0.9, 0, 0]));
            testCase.MoleculeItem.data.updateMatgenlabObject(second.model);
        end
    end

    methods (TestMethodTeardown)
        function restoreProject(testCase)
            kssolv.ui.util.DataStorage.setData('Project', testCase.PreviousProject);
        end
    end

    methods (Test)
        function builtinTemplatesLoadWithoutLegacyObjects(testCase)
            files = dir(fullfile(KSSOLV_Toolbox.UIResourcesDirectory, ...
                'workflows', '*.wf'));
            for i = 1:numel(files)
                file = fullfile(files(i).folder, files(i).name);
                testCase.verifyWarningFree(@()readWorkflowFile(file));
                loaded = load(file, '-mat', 'data');
                testCase.verifyEmpty(loaded.data.parent);
                testCase.verifyEmpty(loaded.data.children);
                testCase.verifyEmpty(loaded.data.data);
            end
        end

        function relaxationTemplateBuildsSketchedHydrogenMolecule(testCase)
            workflow = kssolv.services.filemanager.Workflow.loadWfFile( ...
                relaxationTemplate(), true);
            task = buildTask(workflow);
            opts = task.getExecutionOptions();
            testCase.verifyEqual(opts.type, 'Molecule');
            testCase.verifyEqual(string(opts.structures.node.name), ...
                string(testCase.MoleculeItem.name));
            context = kssolv.services.workflow.module.computation. ...
                BuildMoleculeTask.executeWithOptions(containers.Map(), opts);
            testCase.verifyClass(context('molecule'), 'Molecule');
            testCase.verifyEqual(context('molecule').xyzlist, ...
                opts.structures.xyzList, AbsTol=1e-12);
            testCase.verifyEqual(numel(context('molecule').atomlist), 2);
        end

        function normalImportKeepsExplicitEmptySelection(testCase)
            workflow = kssolv.services.filemanager.Workflow.loadWfFile( ...
                relaxationTemplate());
            task = buildTask(workflow);
            task.resetOptionsUI();
            testCase.verifyEmpty(task.getExecutionOptions().structures);
        end

        function templateUsesCrystalTypeForCrystalProject(testCase)
            folder = testCase.Project.findChildrenItem('Structure');
            folder.children = {};
            folder.createBlankStructure(false);
            workflow = kssolv.services.filemanager.Workflow.loadWfFile( ...
                relaxationTemplate(), true);
            task = buildTask(workflow);
            testCase.verifyEqual(task.getExecutionOptions().type, 'Crystal');
        end

        function exportExcludesProjectAndPreservesLiveWorkflow(testCase)
            workflow = kssolv.services.filemanager.Workflow.loadWfFile( ...
                relaxationTemplate(), true);
            folder = testCase.Project.findChildrenItem('Workflow');
            folder.addChildrenItem(workflow);
            optionsBefore = buildTask(workflow).getExecutionOptions();
            file = string(tempname) + '.wf';
            cleanup = onCleanup(@()delete(file));
            workflow.saveToWfFile(file);
            testCase.verifySameHandle(workflow.parent, folder);
            testCase.verifyEqual(buildTask(workflow).getExecutionOptions(), optionsBefore);
            loaded = load(file, '-mat', 'data');
            testCase.verifyEmpty(loaded.data.parent);
            testCase.verifyEqual(loaded.data.graphJSON, workflow.graphJSON);
            restoredTask = buildTask(loaded.data);
            restoredTask.resetOptionsUI();
            testCase.verifyEqual(restoredTask.getExecutionOptions(), optionsBefore);
            clear cleanup
        end
    end
end

function file = relaxationTemplate()
file = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, 'workflows', 'Relaxation.wf');
end

function task = buildTask(workflow)
ids = keys(workflow.graph.Nodes);
for i = 1:numel(ids)
    task = workflow.graph.Nodes(ids{i}).task;
    if isa(task, 'kssolv.services.workflow.module.computation.BuildMoleculeTask')
        return
    end
end
error('KSSOLV:Test:MissingBuildTask', 'Template has no Build Molecule task.');
end

function readWorkflowFile(file)
loaded = load(file, '-mat', 'data'); %#ok<NASGU>
end
