classdef BrowserReconnectMonitorTest < matlab.unittest.TestCase
    % Real Online waits, without a connected page, in MATLAB -nojvm.
    properties (Access = private)
        App
        Monitor
        SessionFile string
        NestedSelection = ''
        TransferFolder string = ""
    end
    properties (SetAccess = private)
        CallbackFinished logical = false
    end

    methods (TestClassSetup)
        function loadCore(testCase)
            previous = path;
            testCase.addTeardown(@()path(previous));
            addpath(fullfile(fileparts(which('KSSOLV_Toolbox')), ...
                '+kssolv', '+core', 'kssolv-3o'));
            KSSOLV.startup();
        end
    end

    methods (TestMethodSetup)
        function createSession(testCase)
            import kssolv.ui.util.DataStorage
            [warningMessage, warningId] = lastwarn;
            testCase.addTeardown(@()lastwarn(warningMessage, warningId));
            mode = getenv('KSSOLV_ONLINE');
            data = getenv('KSSOLV_USER_DATA_DIR');
            keys = {'AppContainer', 'BrowserReconnectMonitor', 'Project', ...
                'ProjectFilename', 'CommandWindow', 'ModelingSessionRegistry'};
            previous = cellfun(@(key)DataStorage.getData(key), keys, UniformOutput=false);
            testCase.addTeardown(@()restore(mode, data, keys, previous));
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            setenv('KSSOLV_ONLINE', 'true');
            setenv('KSSOLV_USER_DATA_DIR', folder);
            DataStorage.setData('ModelingSessionRegistry', []);
            testCase.SessionFile = fullfile(folder, 'session.json');
            testCase.App = matlab.ui.container.internal.AppContainer(struct( ...
                'Tag', ['reconnect-wait-', char(matlab.lang.internal.uuid)]));
            testCase.addTeardown(@()deleteValid(testCase.App));
            host = matlab.ui.internal.FigurePanel(struct('Tag', 'ProjectBrowser'));
            testCase.App.add(host);
            DataStorage.setData('AppContainer', testCase.App);
            testCase.Monitor = kssolv.ui.browser.BrowserReconnectMonitor(testCase.SessionFile);
            testCase.addTeardown(@()deleteValid(testCase.Monitor));
            testCase.addTeardown(@disposeModals);
        end
    end

    methods (Test)
        function initialAndInvalidRequestsDoNotCancelInput(testCase)
            modal = kssolv.ui.browser.OnlineModal.create('Unshown fixture', true, false);
            modal.CanCloseFcn = @(~)false;
            testCase.writeRequest();
            testCase.Monitor.poll();
            testCase.verifyFalse(testCase.Monitor.Pending);
            testCase.verifyTrue(isvalid(modal));
            writelines('invalid request', testCase.SessionFile + '.request');
            testCase.Monitor.arm();
            testCase.Monitor.poll();
            testCase.verifyFalse(testCase.Monitor.Pending);
            testCase.verifyTrue(isvalid(modal));
            testCase.writeRequest();
            testCase.Monitor.poll();
            testCase.verifyTrue(testCase.Monitor.Pending);
            testCase.verifyFalse(isvalid(modal));
        end

        function monitorTimerReleasesAnExistingPropertyWait(testCase)
            modal = kssolv.ui.browser.OnlineModal.create('Timer fixture', true, false);
            listener = addlistener(modal.Figure, 'ObjectBeingDestroyed', ...
                @(~,~)testCase.noteFinished());
            cleanup = onCleanup(@()deleteValid(listener));
            testCase.Monitor.arm();
            testCase.writeRequest();
            started = tic;
            waitfor(testCase, 'CallbackFinished', true);
            testCase.verifyLessThan(toc(started), 5);
            testCase.verifyTrue(testCase.Monitor.Pending);
        end

        function cancelledInputKeepsDraftAndAllowsAFreshEntry(testCase)
            import kssolv.ui.util.DataStorage
            project = kssolv.services.filemanager.Project();
            DataStorage.setData('Project', project);
            DataStorage.setData('ProjectFilename', fullfile(tempdir, 'unsaved.ks'));
            item = project.findChildrenItem('Structure').createBlankMolecule(false);
            display = kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                item.data.MatgenlabObject, '', item.name);
            testCase.addTeardown(@()deleteValid(display));
            document = matlab.ui.internal.FigureDocument(struct( ...
                'DocumentGroupTag', 'Structure', 'Tag', char(item.name)));
            testCase.App.add(document);
            registry = kssolv.ui.features.modeling.SessionRegistry.getInstance();
            testCase.addTeardown(@()deleteValid(registry));
            registry.register(document, display);
            result = kssolv.modeling.CommandExecutor.execute(display.getModel(), ...
                'add_atom', struct('species', 'H', 'coordinates', [1, 2, 3]));
            display.applyModel(result.model);
            testCase.assertTrue(display.hasUnsavedChanges());
            commands = struct('Workspace', struct('marker', 42), 'ChatBot', [], ...
                'RemoteExecutionEnabled', false);
            DataStorage.setData('CommandWindow', struct('captureBrowserSession', @()commands));
            testCase.Monitor.arm();
            testCase.schedule(@()testCase.writeRequest());
            started = tic;
            answer = kssolv.ui.util.SessionPrompt.input('Name', 'Disconnected input', 1, {'edited'});
            testCase.verifyEmpty(answer);
            testCase.verifyLessThan(toc(started), 5);
            testCase.verifyTrue(display.hasUnsavedChanges());
            app = struct('getAppContainer', @()testCase.App);
            state = kssolv.ui.browser.OnlineReconnectState.capture(app);
            testCase.verifySameHandle(state.Project, project);
            testCase.verifyTrue(state.Project.isDirty);
            testCase.verifyEqual(item.data.MatgenlabObject.cart_coords, [1, 2, 3]);
            testCase.verifyEqual(state.Commands.Workspace.marker, 42);
            testCase.verifyTrue(any(state.Documents == string(item.name)));
            testCase.publishReplacement();
        end

        function nestedPromptInsideTimerCancelsBothWaits(testCase)
            testCase.Monitor.arm();
            testCase.schedule(@()testCase.openNestedPrompt());
            answer = kssolv.ui.util.SessionPrompt.input('Name', 'Outer input', 1, {'keep'});
            testCase.verifyEmpty(answer);
            testCase.verifyEqual(string(testCase.NestedSelection), "Cancel");
            testCase.verifyEmpty(kssolv.ui.browser.OnlineModal.getInstances());
            testCase.publishReplacement();
        end

        function documentReadinessWaitReturnsWithoutClientAcknowledgement(testCase)
            import kssolv.ui.util.DataStorage
            project = kssolv.services.filemanager.Project();
            DataStorage.setData('Project', project);
            workflow = kssolv.services.filemanager.Workflow('Unrendered workflow');
            workflow.graphJSON = '[]';
            project.findChildrenItem('Workflow').addChildrenItem(workflow);
            testCase.Monitor.arm();
            testCase.schedule(@()testCase.writeRequest());
            workflow.showWorkflowDisplay();
            document = testCase.App.getDocument('Workflow', workflow.name);
            testCase.verifyNotEmpty(document);
            testCase.verifyFalse(document.Figure.FigureViewReady);
            testCase.verifyTrue(isvalid(document));
            testCase.verifyTrue(testCase.Monitor.Pending);
            testCase.verifySameHandle(project.findChildrenItem(workflow.name), workflow);
            testCase.publishReplacement();
        end

        function cancelledPartialUploadRemovesItsTemporaryFiles(testCase)
            testCase.Monitor.arm();
            testCase.schedule(@()testCase.startPartialUpload());
            [file, folder, index] = kssolv.ui.browser.OnlineFileTransfer.choose( ...
                'open', {'*.*', 'All files'}, 'Disconnected upload');
            testCase.verifyEqual(file, 0);
            testCase.verifyEqual(folder, 0);
            testCase.verifyEqual(index, 0);
            testCase.verifyNotEqual(testCase.TransferFolder, "");
            testCase.verifyFalse(isfolder(testCase.TransferFolder));
            testCase.publishReplacement();
        end

        function monitorDeletionStopsPollingAndRemovesTheStoredHandle(testCase)
            import kssolv.ui.util.DataStorage
            testCase.Monitor.arm();
            delete(testCase.Monitor);
            testCase.verifyEmpty(DataStorage.getData('BrowserReconnectMonitor'));
            testCase.verifyEmpty(timerfindall('Name', 'KSSOLV browser reconnect monitor'));
        end

        function failedCaptureRetainsTheRequestForRetry(testCase)
            import kssolv.ui.util.DataStorage
            project = kssolv.services.filemanager.Project();
            project.isDirty = true;
            DataStorage.setData('Project', project);
            DataStorage.setData('ProjectFilename', 'unsaved.ks');
            DataStorage.setData('CommandWindow', struct('captureBrowserSession', ...
                @captureFailure));
            testCase.Monitor.arm();
            testCase.writeRequest();
            testCase.Monitor.poll();
            app = struct('getAppContainer', @()testCase.App);
            testCase.verifyError(@()kssolv.ui.browser.OnlineReconnectState.capture(app), ...
                'KSSOLV:Test:Capture');
            testCase.verifyTrue(testCase.Monitor.Pending);
            testCase.verifyTrue(isfile(testCase.SessionFile + '.request'));
            DataStorage.setData('CommandWindow', struct('captureBrowserSession', ...
                @()struct('Workspace', struct('marker', 42))));
            state = kssolv.ui.browser.OnlineReconnectState.capture(app);
            testCase.verifySameHandle(state.Project, project);
            testCase.verifyTrue(state.Project.isDirty);
            testCase.publishReplacement();
        end
    end

    methods (Access = private)
        function schedule(testCase, callback)
            driver = timer('StartDelay', 0.3, 'TimerFcn', @(~,~)callback());
            testCase.addTeardown(@()deleteValid(driver));
            start(driver);
        end

        function noteFinished(testCase)
            testCase.CallbackFinished = true;
        end

        function writeRequest(testCase)
            writelines(repmat('a', 1, 32), testCase.SessionFile + '.request');
        end

        function openNestedPrompt(testCase)
            % A second timer cannot run here. The nested wait must poll itself.
            testCase.writeRequest();
            testCase.NestedSelection = kssolv.ui.util.SessionPrompt.confirm([], ...
                'Unsaved changes', 'Nested confirmation', ...
                'Options', {'Save', 'Discard', 'Cancel'}, 'CancelOption', 3);
        end

        function startPartialUpload(testCase)
            modals = kssolv.ui.browser.OnlineModal.getInstances();
            html = findall(modals{end}.Figure, 'Tag', 'OnlineFileTransfer');
            name = ['partial-', char(matlab.lang.internal.uuid), '.bin'];
            callback = html.HTMLEventReceivedFcn;
            callback(html, struct('HTMLEventName', 'upload', ...
                'HTMLEventData', struct('name', name, 'index', 0, ...
                'bytes', matlab.net.base64encode(uint8('partial')), 'final', false)));
            found = dir(fullfile(tempdir, '*', name));
            testCase.TransferFolder = string(found.folder);
            testCase.writeRequest();
        end

        function publishReplacement(testCase)
            testCase.Monitor.disarm();
            testCase.verifyTrue(kssolv.ui.browser.BrowserSession.respond( ...
                testCase.SessionFile, @()"http://localhost:1234/new?snc=replacement"));
            reply = jsondecode(fileread(testCase.SessionFile));
            testCase.verifyEqual(reply.request_id, repmat('a', 1, 32));
            testCase.verifySubstring(reply.url, 'snc=replacement');
            testCase.verifyFalse(isfile(testCase.SessionFile + '.request'));
            testCase.Monitor.arm();
            testCase.verifyFalse(testCase.Monitor.Pending);
        end
    end
end

function restore(mode, directory, keys, values)
setenv('KSSOLV_ONLINE', mode);
setenv('KSSOLV_USER_DATA_DIR', directory);
for index = 1:numel(keys)
    kssolv.ui.util.DataStorage.setData(keys{index}, values{index});
end
end

function deleteValid(object)
if ~isempty(object) && isvalid(object), delete(object); end
end

function disposeModals()
modals = kssolv.ui.browser.OnlineModal.getInstances();
for index = 1:numel(modals)
    kssolv.ui.browser.OnlineModal.dispose(modals{index});
end
end

function result = captureFailure() %#ok<STOUT>
error('KSSOLV:Test:Capture', 'Transient capture failure.');
end
