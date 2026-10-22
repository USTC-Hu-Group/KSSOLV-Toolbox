classdef BrowserNamespaceCompatibilityTest < matlab.unittest.TestCase
    % Keep old serialized names/handles usable while production uses browser.
    methods (TestMethodSetup)
        function isolateSession(testCase)
            import kssolv.ui.util.DataStorage
            mode = getenv('KSSOLV_ONLINE');
            keys = {'Project', 'AppContainer', 'BrowserReconnectMonitor'};
            previous = cellfun(@(key)DataStorage.getData(key), keys, UniformOutput=false);
            testCase.addTeardown(@()restore(mode, keys, previous));
            setenv('KSSOLV_ONLINE', 'false');
        end
    end

    methods (Test)
        function oldStaticAndFunctionHandlesForwardToTheNewPackage(testCase)
            htmlSource = @kssolv.ui.util.htmlSource;
            links = @kssolv.ui.util.onlineLinks;
            validateName = @kssolv.ui.util.OnlineFileTransfer.validateName;
            encodeName = @kssolv.ui.util.OnlineFileTransfer.encodeFilename;
            testCase.verifyEqual(htmlSource('unread-desktop-file.html'), 'unread-desktop-file.html');
            testCase.verifyEqual(links(), kssolv.ui.browser.onlineLinks());
            testCase.verifyEqual(validateName('legacy.cif'), "legacy.cif");
            testCase.verifyEqual(encodeName('Si #1.cif'), 'Si%20%231.cif');
            testCase.verifyEmpty(kssolv.ui.util.OnlineAxesToolbar.install([]));
            testCase.verifyEqual(functions(validateName).function, ...
                'kssolv.ui.util.OnlineFileTransfer.validateName');
        end

        function oldPublicConstructorsInheritTheCurrentImplementation(testCase)
            import kssolv.ui.util.DataStorage
            sidebar = kssolv.ui.util.SidebarAppContainer(struct('Tag', 'legacy-sidebar'));
            testCase.addTeardown(@()deleteValid(sidebar));
            app = kssolv.ui.util.BrowserAppContainer(struct('Tag', 'legacy-browser'));
            testCase.addTeardown(@()deleteValid(app));
            testCase.verifyTrue(isa(sidebar, 'kssolv.ui.browser.SidebarAppContainer'));
            testCase.verifyTrue(isa(app, 'kssolv.ui.browser.BrowserAppContainer'));
            testCase.verifyEqual(app.getClientPage(), sidebar.getClientPage());
            testCase.verifyTrue(isa(kssolv.ui.util.BrowserSession(), ...
                'kssolv.ui.browser.BrowserSession'));
            testCase.verifyTrue(isa(kssolv.ui.util.OnlineWorkspace(), ...
                'kssolv.ui.browser.OnlineWorkspace'));
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            monitor = kssolv.ui.util.BrowserReconnectMonitor(fullfile(folder, 'session.json'));
            testCase.addTeardown(@()deleteValid(monitor));
            testCase.verifyTrue(isa(monitor, 'kssolv.ui.browser.BrowserReconnectMonitor'));
            testCase.verifySameHandle(DataStorage.getData('BrowserReconnectMonitor'), monitor);
            monitor.arm();
            testCase.verifyTrue(monitor.Armed);
        end

        function oldAndNewModalEntryPointsShareOneRegistry(testCase)
            modal = kssolv.ui.util.OnlineModal.create('Legacy factory', true, false);
            testCase.addTeardown(@()kssolv.ui.browser.OnlineModal.dispose(modal));
            testCase.verifyClass(modal, 'kssolv.ui.browser.OnlineModal');
            old = kssolv.ui.util.OnlineModal.getInstances();
            current = kssolv.ui.browser.OnlineModal.getInstances();
            testCase.verifyEqual(old, current);
            testCase.verifyTrue(any(cellfun(@(item)isequal(item, modal), current)));
            kssolv.ui.util.OnlineModal.dispose(modal);
            testCase.verifyFalse(isvalid(modal));
        end

        function browserResourcesResolveFromThePackagedResourceDirectory(testCase)
            names = {'online-actions.html', 'online-files.html', 'online-modal.html', ...
                'online-fill-figure.js', 'online-html-bootstrap.js', ...
                'online-native-grid.js', 'online-shortcuts.js', 'sidebar.html'};
            for index = 1:numel(names)
                file = kssolv.ui.browser.resourcePath(names{index});
                testCase.verifyEqual(file, fullfile( ...
                    string(KSSOLV_Toolbox.UIResourcesDirectory), 'browser', names{index}));
                testCase.verifyTrue(isfile(file));
                testCase.verifyNotEmpty(fileread(file));
                testCase.verifyFalse(isfile(fullfile( ...
                    fileparts(which('kssolv.ui.browser.htmlSource')), names{index})));
                testCase.verifyFalse(isfile(fullfile( ...
                    fileparts(which('kssolv.ui.util.htmlSource')), names{index})));
            end
            testCase.verifyError(@()kssolv.ui.browser.resourcePath('missing-fixture.js'), ...
                'KSSOLV:Browser:MissingResource');
        end

        function projectAndWorkflowFilesRetainLegacyObjectsAndHandles(testCase)
            project = kssolv.services.filemanager.Project();
            kssolv.ui.util.DataStorage.setData('Project', project);
            workflow = kssolv.services.filemanager.Workflow('Namespace compatibility');
            node = struct('id', 'saved-node', 'shape', 'dag-node', ...
                'data', struct('label', 'Saved SCF', 'status', 'default'));
            workflow.graphJSON = jsonencode(struct('cells', node));
            project.findChildrenItem('Workflow').addChildrenItem(workflow);
            task = workflow.graph.Nodes('saved-node').task;
            widget = task.optionsUI.widgets.maxSCFIterationValueSpinner;
            widget.Value = 87;
            widget.ValueChangedFcn(widget, struct('Value', 87));
            workflow.data = struct('Session', kssolv.ui.util.BrowserSession(), ...
                'ValidateName', @kssolv.ui.util.OnlineFileTransfer.validateName, ...
                'HTMLSource', @kssolv.ui.util.htmlSource);
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            ksFile = fullfile(folder, 'legacy-handles.ks');
            wfFile = fullfile(folder, 'legacy-handles.wf');
            project.saveToKsFile(ksFile);
            workflow.saveToWfFile(wfFile);
            restoredProject = kssolv.services.filemanager.Project.loadKsFile(ksFile);
            testCase.verifyClass(restoredProject, 'kssolv.services.filemanager.Project');
            restored = {restoredProject.findChildrenItem(workflow.name), ...
                kssolv.services.filemanager.Workflow.loadWfFile(wfFile)};
            for index = 1:numel(restored)
                item = restored{index};
                testCase.verifyClass(item, 'kssolv.services.filemanager.Workflow');
                restoredTask = item.graph.Nodes('saved-node').task;
                testCase.verifyClass(restoredTask, ...
                    'kssolv.services.workflow.module.computation.SCFTask');
                testCase.verifyEqual(restoredTask.getExecutionOptions().maxscfiter, 87);
                testCase.verifyClass(item.data.Session, 'kssolv.ui.util.BrowserSession');
                testCase.verifyTrue(isa(item.data.Session, 'kssolv.ui.browser.BrowserSession'));
                testCase.verifyEqual(item.data.ValidateName('legacy.cif'), "legacy.cif");
                testCase.verifyEqual(item.data.HTMLSource('legacy.html'), 'legacy.html');
            end
        end

        function existingWorkflowTemplatesKeepTheirPersistedClassNames(testCase)
            files = dir(fullfile(KSSOLV_Toolbox.UIResourcesDirectory, 'workflows', '*.wf'));
            testCase.assertNotEmpty(files);
            for index = 1:numel(files)
                workflow = kssolv.services.filemanager.Workflow.loadWfFile( ...
                    fullfile(files(index).folder, files(index).name));
                testCase.verifyClass(workflow, 'kssolv.services.filemanager.Workflow');
                nodes = workflow.graph.Nodes.values();
                for node = 1:numel(nodes)
                    testCase.verifyTrue(isa(nodes{node}.task, ...
                        'kssolv.services.workflow.module.AbstractTask'));
                    testCase.verifyTrue(isa(nodes{node}.task.optionsUI, ...
                        'kssolv.services.workflow.module.AbstractTaskUI'));
                    testCase.verifyTrue(isstruct(nodes{node}.task.getExecutionOptions()));
                end
            end
        end

        function preMigrationFilesRestoreSavedOptionsObjectsAndFunctionHandles(testCase)
            folder = fullfile(fileparts(mfilename('fullpath')), ...
                '+fixtures', 'browser-namespace');
            project = kssolv.services.filemanager.Project.loadKsFile( ...
                fullfile(folder, 'pre-migration.ks'));
            testCase.verifyClass(project, 'kssolv.services.filemanager.Project');
            workflows = {project.findChildrenItem('Before browser namespace'), ...
                kssolv.services.filemanager.Workflow.loadWfFile( ...
                fullfile(folder, 'pre-migration.wf'))};
            for index = 1:numel(workflows)
                workflow = workflows{index};
                testCase.assertClass(workflow, 'kssolv.services.filemanager.Workflow');
                testCase.verifyEqual(workflow.label, "Before browser namespace");
                node = workflow.graph.Nodes('saved-node');
                testCase.verifyClass(node.task, ...
                    'kssolv.services.workflow.module.computation.SCFTask');
                testCase.verifyClass(node.task.optionsUI, ...
                    'kssolv.services.workflow.module.computation.SCFTaskUI');
                testCase.verifyEqual(node.task.getExecutionOptions().maxscfiter, 87);
                testCase.verifyClass(workflow.data.Session, 'kssolv.ui.util.BrowserSession');
                testCase.verifyTrue(isa(workflow.data.Session, 'kssolv.ui.browser.BrowserSession'));
                testCase.verifyEqual(workflow.data.ValidateName('legacy.cif'), "legacy.cif");
                testCase.verifyEqual(workflow.data.HTMLSource('legacy.html'), 'legacy.html');
                testCase.verifyEqual(functions(workflow.data.ValidateName).function, ...
                    'kssolv.ui.util.OnlineFileTransfer.validateName');
            end
        end
    end
end

function restore(mode, keys, values)
setenv('KSSOLV_ONLINE', mode);
for index = 1:numel(keys)
    kssolv.ui.util.DataStorage.setData(keys{index}, values{index});
end
end

function deleteValid(object)
if ~isempty(object) && isvalid(object), delete(object); end
end
